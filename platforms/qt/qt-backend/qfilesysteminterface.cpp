#include "qfilesysteminterface.h"
#include "utils/flowfilestruct.h"

#include <limits.h>
#include <filesystem>
#include "core/STLHelpers.h"
#include "core/RunnerMacros.h"

#include <QFile>
#include <QMimeType>
#include <QFileInfo>

#ifdef QT_GUI_LIB
#include <QFileDialog>
#endif

#ifdef QT_GUI_LIB
QFileSystemInterface::QFileSystemInterface(ByteCodeRunner *owner, QWidget *window)
#else
QFileSystemInterface::QFileSystemInterface(ByteCodeRunner *owner, QObject *window)
#endif
     : FileSystemInterface(owner), owner(owner)
#ifdef QT_GUI_LIB
        , window(window)
#endif
{
#ifndef QT_GUI_LIB
	Q_UNUSED(window)
#endif
    mimeDatabase = new QMimeDatabase();
}

NativeFunction *QFileSystemInterface::MakeNativeFunction(const char *name, int num_args) {
#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "FlowFileSystem."
    TRY_USE_NATIVE_METHOD(QFileSystemInterface, canCopyLocal, 3);
    TRY_USE_NATIVE_METHOD(QFileSystemInterface, listLocalCopyDirectory, 1);
    return FileSystemInterface::MakeNativeFunction(name, num_args);
}

StackSlot QFileSystemInterface::listLocalCopyDirectory(RUNNER_ARGS) {
    RUNNER_PopArgs1(src);
    RUNNER_CheckTag(TString, src);
    namespace fs = std::filesystem;
    auto dir = fs::u8path(encodeUtf8(RUNNER->GetString(src)));
    // A trailing separator would make symlink_status inspect the referent.
    while (!dir.has_filename() && dir.has_relative_path()) dir = dir.parent_path();
    std::error_code ec;
    if (!fs::is_directory(fs::symlink_status(dir, ec)) || ec ||
        QFileInfo(QString::fromStdString(dir.u8string())).isJunction())
        return RUNNER->MakeStruct("None", 0, nullptr);
    std::vector<std::string> names;
    for (fs::directory_iterator it(dir, ec), end; !ec && it != end; it.increment(ec))
        names.push_back(it->path().filename().u8string());
    if (ec) return RUNNER->MakeStruct("None", 0, nullptr);
    RUNNER_DefSlots1(children);
    children = RUNNER->AllocateStringArray(names);
    if (RUNNER->IsErrorReported()) return StackSlot::MakeVoid();
    return RUNNER->MakeStruct("Some", 1, &children);
}

StackSlot QFileSystemInterface::canCopyLocal(RUNNER_ARGS) {
    RUNNER_PopArgs3(src, folder, dest);
    RUNNER_CheckTag3(TString, src, folder, dest);
    namespace fs = std::filesystem;
    auto path = [&](const StackSlot &s) { return fs::u8path(encodeUtf8(RUNNER->GetString(s))); };
    const auto source = path(src), target = path(dest);
    std::error_code ec;
    if (fs::exists(target, ec) && fs::equivalent(source, target, ec)) return StackSlot::MakeBool(false);
    if (ec) return StackSlot::MakeBool(false);
    if (fs::is_directory(source, ec)) {
        // Resolve the existing folder, not the possibly absent target. Compare
        // identities all the way to the root (also on case-insensitive volumes).
        auto dir = fs::canonical(path(folder), ec);
        while (!ec) {
            if (fs::equivalent(source, dir, ec)) return StackSlot::MakeBool(false);
            if (dir == dir.root_path()) break;
            dir = dir.parent_path();
        }
    }
    return StackSlot::MakeBool(!ec);
}

char* QFileSystemInterface::doResolveRelativePath(std::string &filename, char* buffer) {
    QString s(filename.c_str());
    QFileInfo fi(s);
    s = fi.absoluteFilePath();
    // QString guarantees that it has zero at the end,
    // so usage of strcpy is safe.
    return strcpy(buffer, s.toStdString().c_str());
}

void QFileSystemInterface::selectAccepted()
{
#ifdef QT_GUI_LIB
    QFileDialog *currentDialog = (QFileDialog*)sender();

    RUNNER_VAR = owner;
    RUNNER_DefSlots1(flowFilesArray);

    QStringList filePaths = currentDialog->selectedFiles();
    int length = std::min((int)filePaths.length(), maxSelectFiles);

    flowFilesArray = RUNNER->AllocateArray(length);

    for (int i = 0; !RUNNER->IsErrorReported() && i < length; ++i) {
        FlowFile *file = new FlowFile(RUNNER, filePaths.at(i).toStdString());
        RUNNER->SetArraySlot(flowFilesArray, i, RUNNER->AllocNative(file));
    }

    if (!RUNNER->IsErrorReported())
        RUNNER->EvalFunction(RUNNER->LookupRoot(selectCallbackId), 1, flowFilesArray);

    RUNNER->ReleaseRoot(selectCallbackId);
    delete currentDialog;
#endif
}

void QFileSystemInterface::selectRejected()
{
    RUNNER_VAR = owner;

    RUNNER->EvalFunction(RUNNER->LookupRoot(selectCallbackId), 1, RUNNER->AllocateArray(0));

    RUNNER->ReleaseRoot(selectCallbackId);
    delete sender();
}

void QFileSystemInterface::doOpenFileDialog(int maxFilesCount, std::vector<std::string> fileTypes, StackSlot callback)
{
#ifdef QT_GUI_LIB
    if (!window)
        return ;

    RUNNER_VAR = owner;

    selectCallbackId = RUNNER->RegisterRoot(callback);
    maxSelectFiles = maxFilesCount;

    if (maxSelectFiles == -1)
        maxSelectFiles = INT_MAX;

    QStringList mimeTypeFilters;
    QString filter = "";
    for (unsigned i = 0; i < fileTypes.size(); i++)
        filter += (i ? " " : "") + QString::fromUtf8(fileTypes[i].c_str());

    QFileDialog *dialog = new QFileDialog(window, "Open file", "");
    dialog->setFileMode(maxFilesCount == 1 ? QFileDialog::ExistingFile : QFileDialog::ExistingFiles);
    dialog->setOption(QFileDialog::HideNameFilterDetails, false);
    if (!filter.isEmpty()) {
        if (filter.contains("/")) { // MIME-type
            mimeTypeFilters << filter;
        } else { // File extension
            dialog->setNameFilter("Specific files ("+filter+");;All files (*)");
        }

        dialog->setMimeTypeFilters(mimeTypeFilters);
    }
    dialog->setWindowModality(Qt::WindowModal);

    connect(dialog, SIGNAL(accepted()), SLOT(selectAccepted()));
    connect(dialog, SIGNAL(rejected()), SLOT(selectRejected()));

    /* Fix for drawing file dialog contents under Linux */
    #ifdef __linux__
        connect(dialog, &QFileDialog::finished, [=](int){window->setUpdatesEnabled(true);});
        window->setUpdatesEnabled(false);
    #endif

    dialog->show();
#else
	Q_UNUSED(maxFilesCount)
	Q_UNUSED(fileTypes)
	Q_UNUSED(callback)
#endif
}

std::string QFileSystemInterface::doFileType(const StackSlot &file)
{
    FlowFile *flowFile = owner->GetNative<FlowFile*>(file);

    QMimeType type = mimeDatabase->mimeTypeForFile(QString::fromStdString(flowFile->getFilepath()));

    return type.name().toStdString();
}
