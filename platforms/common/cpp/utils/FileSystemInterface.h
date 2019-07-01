#ifndef FILESYSTEMINTERFACE_H
#define FILESYSTEMINTERFACE_H

#include "core/ByteCodeRunner.h"

class FileSystemInterface : public NativeMethodHost {
private:
    ByteCodeRunner *owner;
    void doFileRead(const StackSlot& /*file*/, std::string /*readAs*/, std::string /*readEncoding*/, const StackSlot& /*onData*/, const StackSlot& /*onError*/);
public:
    FileSystemInterface(ByteCodeRunner *owner);

protected:
    NativeFunction *MakeNativeFunction(const char *name, int num_args);

    virtual void doOpenFileDialog(int /*maxFilesCount*/, std::vector<std::string> /*fileTypes*/, StackSlot /*callback*/) { }
    virtual std::string doFileType(const StackSlot& /*file*/) { return ""; }
    virtual char* doResolveRelativePath(std::string& /*filename*/, char* /*buffer*/);

private:
    DECLARE_NATIVE_METHOD(createDirectory)
    DECLARE_NATIVE_METHOD(deleteDirectory)
    DECLARE_NATIVE_METHOD(deleteFile)
    DECLARE_NATIVE_METHOD(renameFile)

    DECLARE_NATIVE_METHOD(fileExists)
    DECLARE_NATIVE_METHOD(isDirectory)
    DECLARE_NATIVE_METHOD(readDirectory)

    DECLARE_NATIVE_METHOD(fileSize)
    DECLARE_NATIVE_METHOD(fileModified)

    DECLARE_NATIVE_METHOD(resolveRelativePath)

    DECLARE_NATIVE_METHOD(getFileByPath)
    DECLARE_NATIVE_METHOD(openFileDialog)
    DECLARE_NATIVE_METHOD(fileName)
    DECLARE_NATIVE_METHOD(fileType)
    DECLARE_NATIVE_METHOD(fileSizeNative)
    DECLARE_NATIVE_METHOD(fileModifiedNative)
    DECLARE_NATIVE_METHOD(fileSlice)
    DECLARE_NATIVE_METHOD(readFile)
    DECLARE_NATIVE_METHOD(readFileEnc)
};

#endif // FILESYSTEMINTERFACE_H
