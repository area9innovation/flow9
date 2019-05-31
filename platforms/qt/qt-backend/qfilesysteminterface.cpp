#include "qfilesysteminterface.h"
#include "utils/flowfilestruct.h"

#include <limits.h>
#include "core/STLHelpers.h"
#include "core/RunnerMacros.h"

#include <QFile>
#include <QMimeType>
#include <QFileInfo>
#include <QFileDialog>


class TextCodec {
    static const char *ENC_UTF8;
    static const char *ENC_CP1252;
public:
    static const char *SUPPORTED_ENCODINGS[2];
    static QString decode(QByteArray blob, std::string encoding) {
        QString r("");
        if (encoding=="auto") {
            for (signed char i=sizeof(SUPPORTED_ENCODINGS)/sizeof(SUPPORTED_ENCODINGS[0])-1; i>=0; --i) {
                std::string enc(SUPPORTED_ENCODINGS[i]);
                r = decode(blob, enc);
                if (-1 == r.indexOf(QChar::ReplacementCharacter)) return r;
            }
            return r;
        }

        // Put each decoding line to separate func and hash mapping when more encodings support added.
        if (encoding==ENC_UTF8) return QString(blob);
        if (encoding==ENC_CP1252) return QString::fromLatin1(blob).toUtf8().data();

        return r;
    }
};

const char *TextCodec::ENC_UTF8 = "UTF8";
const char *TextCodec::ENC_CP1252 = "CP1252";
const char *TextCodec::SUPPORTED_ENCODINGS[2] = {TextCodec::ENC_UTF8, TextCodec::ENC_CP1252};


char* QFileSystemInterface::doResolveRelativePath(std::string &filename, char* buffer) {
  QString s(filename.c_str());
  QFileInfo fi(s);
  s = fi.absoluteFilePath();
  // QString guarantees that it has zero at the end,
  // so usage of strcpy is safe.
  return strcpy(buffer, s.toStdString().c_str());
}


QFileSystemInterface::QFileSystemInterface(ByteCodeRunner *owner, QtHttpSupport *http) : FileSystemInterface(owner), owner(owner), http_manager(http)
{
    mimeDatabase = new QMimeDatabase();
}

StackSlot QFileSystemInterface::doGetFileByPath(std::string path)
{
    return owner->AllocNative(new FlowFile(owner, new QFile(QString::fromUtf8(path.c_str()))));
}

void QFileSystemInterface::selectAccepted()
{
    QFileDialog *currentDialog = (QFileDialog*)sender();

    RUNNER_VAR = owner;
    RUNNER_DefSlots1(flowFilesArray);

    QStringList filePaths = currentDialog->selectedFiles();
    int length = std::min(filePaths.length(), maxSelectFiles);

    flowFilesArray = RUNNER->AllocateArray(length);

    for (int i = 0; i < length; ++i) {
        FlowFile *file = new FlowFile(RUNNER, new QFile(filePaths.at(i)));
        RUNNER->SetArraySlot(flowFilesArray, i, RUNNER->AllocNative(file));
    }

    RUNNER->EvalFunction(RUNNER->LookupRoot(selectCallbackId), 1, flowFilesArray);

    RUNNER->ReleaseRoot(selectCallbackId);
    delete currentDialog;
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
    if (!http_manager->window)
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

    QFileDialog *dialog = new QFileDialog(http_manager->window, "Open file", "");
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
        connect(dialog, &QFileDialog::finished, [=](int v){http_manager->window->setUpdatesEnabled(true);});
        http_manager->window->setUpdatesEnabled(false);
    #endif

    dialog->show();
#endif
}

StackSlot QFileSystemInterface::doUploadNativeFile(
        const StackSlot &file, std::string url, const StackSlot &params,
        const StackSlot &onOpenFn, const StackSlot &onDataFn, const StackSlot &onErrorFn, const StackSlot &onProgressFn, const StackSlot &onCancelFn)
{
    FlowFile* flowFile = (FlowFile*)owner->GetNative<FlowFile*>(file);

    RUNNER_VAR = owner;
    WITH_RUNNER_LOCK_DEFERRED(RUNNER);

    int id = http_manager->next_http_request++;

    HttpRequest &rq = http_manager->active_requests[id];
    rq.req_id = id;

    rq.url = parseUtf8(url);
    rq.method = parseUtf8("POST");

    rq.open_cb = onOpenFn;
    rq.select_cb = StackSlot::MakeVoid();
    rq.data_cb = onDataFn;
    rq.error_cb = onErrorFn;
    rq.progress_cb = onProgressFn;
    rq.cancel_cb = onCancelFn;

    http_manager->decodeMap(owner, &rq.params, params);

    http_manager->doUploadFlowFile(rq, flowFile);

    return RUNNER->AllocateNativeClosure(QtHttpSupport::cbCancel, "uploadNativeFile$cancel", 0, http_manager, 1, StackSlot::MakeInt(id));
}

std::string QFileSystemInterface::doFileName(const StackSlot &file)
{
    QFile *flowFile = ((FlowFile*)owner->GetNative<FlowFile*>(file))->getFile();

    return flowFile->fileName().toStdString();
}

std::string QFileSystemInterface::doFileType(const StackSlot &file)
{
    QFile *flowFile = ((FlowFile*)owner->GetNative<FlowFile*>(file))->getFile();

    QMimeType type = mimeDatabase->mimeTypeForFile(QFileInfo(*flowFile));

    return type.name().toStdString();
}

double QFileSystemInterface::doFileSizeNative(const StackSlot &file)
{
    FlowFile *flowFile = (FlowFile*)owner->GetNative<FlowFile*>(file);

    return flowFile->size();
}

double QFileSystemInterface::doFileModifiedNative(const StackSlot &file)
{
    QFile *flowFile = ((FlowFile*)owner->GetNative<FlowFile*>(file))->getFile();

    QFileInfo *info = new QFileInfo(*flowFile);

    return info->lastModified().toMSecsSinceEpoch();
}


StackSlot QFileSystemInterface::doFileSlice(const StackSlot &file, int offset, int end)
{
    RUNNER_VAR = owner;
    WITH_RUNNER_LOCK_DEFERRED(RUNNER);

    QFile *flowFile = ((FlowFile*)RUNNER->GetNative<FlowFile*>(file))->getFile();

    QFile *chunk = new QFile(flowFile->fileName());
    FlowFile *chunkFlowFile = new FlowFile(owner, chunk);
    chunkFlowFile->setSliceRange(offset, end);

    return RUNNER->AllocNative(chunkFlowFile);
}

void QFileSystemInterface::doFileRead(const StackSlot &file, std::string readAs, std::string readEncoding, const StackSlot &onData, const StackSlot &onError)
{
    RUNNER_VAR = owner;
    WITH_RUNNER_LOCK_DEFERRED(RUNNER);

    FlowFile *flowFile = (FlowFile*)RUNNER->GetNative<FlowFile*>(file);

    if (!flowFile->getFile()->open(QIODevice::ReadOnly)) {
        RUNNER->EvalFunction(onError, 1, RUNNER->AllocateString("Cannot open file for reading!"));
        return;
    }

    flowFile->getFile()->seek(flowFile->getOffset());

    QByteArray blob = flowFile->getFile()->read(flowFile->getEnd() - flowFile->getOffset());

    if (readAs == "data") {
        int n = blob.size();
        unicode_char * unicode = new unicode_char[n];
        for (int i = 0; i != n; ++i) {
            unicode[i] = blob.at(i);
        }
        RUNNER->EvalFunction(onData, 1, RUNNER->AllocateString(unicode, n));
    } else if (readAs == "uri") {
        QString dataUrl = "data:" + QString::fromStdString(doFileType(file)) + ";base64," + blob.toBase64(QByteArray::Base64Encoding);
        RUNNER->EvalFunction(onData, 1, RUNNER->AllocateString(dataUrl));
    } else {
        RUNNER->EvalFunction(onData, 1, RUNNER->AllocateString(TextCodec::decode(blob, readEncoding)));
    }

    flowFile->getFile()->close();
}
