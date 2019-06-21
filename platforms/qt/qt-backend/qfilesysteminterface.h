#ifndef QFILESYSTEMINTERFACE_H
#define QFILESYSTEMINTERFACE_H

#include "utils/FileSystemInterface.h"

#include <QMimeDatabase>

class QFileSystemInterface : public QObject, public FileSystemInterface
{
    Q_OBJECT

private:
    ByteCodeRunner *owner;

    QMimeDatabase *mimeDatabase;

    int selectCallbackId;
    int maxSelectFiles;

#ifdef QT_GUI_LIB
    QWidget *window;
#endif

public:
#ifdef QT_GUI_LIB
    QFileSystemInterface(ByteCodeRunner* runner, QWidget *window = NULL);
#else
    QFileSystemInterface(ByteCodeRunner* runner, QObject *parent = NULL);
#endif

protected:
    void doOpenFileDialog(int maxFilesCount, std::vector<std::string> fileTypes, StackSlot callback);
    std::string doFileType(const StackSlot &file);
    char* doResolveRelativePath(std::string &filename, char* buffer);

private slots:
    void selectAccepted();
    void selectRejected();
};

#endif // QFILESYSTEMINTERFACE_H
