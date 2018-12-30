#ifndef FILESYSTEMINTERFACE_H
#define FILESYSTEMINTERFACE_H

#include "core/ByteCodeRunner.h"

class FileSystemInterface : public NativeMethodHost {
private:
    ByteCodeRunner *owner;
public:
    FileSystemInterface(ByteCodeRunner *owner);

protected:
    NativeFunction *MakeNativeFunction(const char *name, int num_args);

    virtual StackSlot doGetFileByPath(std::string path) { return StackSlot::MakeVoid(); }
    virtual void doOpenFileDialog(int /*maxFilesCount*/, std::vector<std::string> /*fileTypes*/, StackSlot /*callback*/) { }
    virtual StackSlot doUploadNativeFile(
            const StackSlot& /*file*/, std::string /*url*/, const StackSlot& /*params*/,
            const StackSlot& /*onOpenFn*/, const StackSlot& /*onDataFn*/, const StackSlot& /*onErrorFn*/, const StackSlot& /*onProgressFn*/, const StackSlot& /*onCancelFn*/) { return StackSlot::MakeVoid(); }
    virtual std::string doFileName(const StackSlot& /*file*/) { return ""; }
    virtual std::string doFileType(const StackSlot& /*file*/) { return ""; }
    virtual double doFileSizeNative(const StackSlot& /*file*/) { return 0.0; }
    virtual double doFileModifiedNative(const StackSlot& /*file*/) { return 0.0; }
    virtual StackSlot doFileSlice(const StackSlot &file, int /*offset*/, int /*end*/) { return file; }
    virtual void doFileRead(const StackSlot& /*file*/, std::string /*readAs*/, const StackSlot& /*onData*/, const StackSlot& /*onError*/) { }
    virtual char* doResolveRelativePath(std::string& /*filename*/, char* /*buffer*/);

    static StackSlot cbCancel(ByteCodeRunner*, StackSlot*, void *ptr);
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
    DECLARE_NATIVE_METHOD(uploadNativeFile)
    DECLARE_NATIVE_METHOD(fileName)
    DECLARE_NATIVE_METHOD(fileType)
    DECLARE_NATIVE_METHOD(fileSizeNative)
    DECLARE_NATIVE_METHOD(fileModifiedNative)
    DECLARE_NATIVE_METHOD(fileSlice)
    DECLARE_NATIVE_METHOD(readFile)
};

#endif // FILESYSTEMINTERFACE_H
