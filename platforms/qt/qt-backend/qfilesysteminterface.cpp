#include "qfilesysteminterface.h"
#include "utils/flowfilestruct.h"

#include <limits.h>
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

    /* Fix for drawing file dialog contents under Linux */
    #ifdef __linux__
    if (window) {
        window->setUpdatesEnabled(true);
    }
    #endif

    RUNNER_VAR = owner;
    RUNNER_DefSlots1(flowFilesArray);

    QStringList filePaths = currentDialog->selectedFiles();
    int length = std::min(filePaths.length(), maxSelectFiles);

    flowFilesArray = RUNNER->AllocateArray(length);

    for (int i = 0; i < length; ++i) {
        FlowFile *file = new FlowFile(RUNNER, filePaths.at(i).toStdString());
        RUNNER->SetArraySlot(flowFilesArray, i, RUNNER->AllocNative(file));
    }

    RUNNER->EvalFunction(RUNNER->LookupRoot(selectCallbackId), 1, flowFilesArray);

    RUNNER->ReleaseRoot(selectCallbackId);
    delete currentDialog;
#endif
}

void QFileSystemInterface::selectRejected()
{
#ifdef QT_GUI_LIB
    RUNNER_VAR = owner;

    /* Fix for drawing file dialog contents under Linux */
    #ifdef __linux__
    if (window) {
        window->setUpdatesEnabled(true);
    }
    #endif

    RUNNER->EvalFunction(RUNNER->LookupRoot(selectCallbackId), 1, RUNNER->AllocateArray(0));

    RUNNER->ReleaseRoot(selectCallbackId);
    delete sender();
#endif
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
