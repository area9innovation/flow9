#ifndef QFILESYSTEMINTERFACE_H
#define QFILESYSTEMINTERFACE_H

#include "utils/FileSystemInterface.h"
#include "qt-backend/HttpSupport.h"

#include <QMimeDatabase>

class QFileSystemInterface : public QObject, public FileSystemInterface
{
    Q_OBJECT

private:
    ByteCodeRunner *owner;
    QtHttpSupport *http_manager;

    QMimeDatabase *mimeDatabase;

    int selectCallbackId;
    int maxSelectFiles;

public:
    QFileSystemInterface(ByteCodeRunner *owner, QtHttpSupport* http);

protected:
    StackSlot doGetFileByPath(std::string path);
    void doOpenFileDialog(int maxFilesCount, std::vector<std::string> fileTypes, StackSlot callback);

    StackSlot doUploadNativeFile(
            const StackSlot &file, std::string url, const StackSlot &params,
            const StackSlot &onOpenFn, const StackSlot &onDataFn, const StackSlot &onErrorFn, const StackSlot &onProgressFn, const StackSlot &onCancelFn);

    std::string doFileName(const StackSlot &file);
    std::string doFileType(const StackSlot &file);

    double doFileSizeNative(const StackSlot &file);
    double doFileModifiedNative(const StackSlot &file);

    StackSlot doFileSlice(const StackSlot &file, int offset, int end);
    void doFileRead(const StackSlot &file, std::string readAs, std::string readEncoding, const StackSlot &onData, const StackSlot &onError);
    char* doResolveRelativePath(std::string &filename, char* buffer);

private slots:
    void selectAccepted();
    void selectRejected();
};

#endif // QFILESYSTEMINTERFACE_H
