#include "FileSystemInterface.h"

#include "core/RunnerMacros.h"
#include "utils/AbstractHttpSupport.h"
#include "utils/flowfilestruct.h"

#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <errno.h>

#include <utils/base64.h>

#ifndef _MSC_VER
	#include <dirent.h>
	#include <unistd.h>
#else
#include <windows.h>
#include <tchar.h>
#include <stdio.h>
#include <strsafe.h>
#endif

#ifdef WIN32
#include <io.h>

    #ifdef _MSC_VER
        #include <direct.h>
        #define mkdir _mkdir
    #endif

#endif


class TextCodec {
    static const char *ENC_UTF8;
    static const char *ENC_CP1252;
public:
    static const char *SUPPORTED_ENCODINGS[2];
    static unicode_string decode(std::vector<uint8_t> blob, std::string encoding) {
        unicode_string r;
        if (encoding=="auto") {
            for (signed char i=sizeof(SUPPORTED_ENCODINGS)/sizeof(SUPPORTED_ENCODINGS[0])-1; i>=0; --i) {
                std::string enc(SUPPORTED_ENCODINGS[i]);
                r = decode(blob, enc);
                if (r.find(0xfffd) == std::string::npos) {
                    return r;
                }

            }
            return r;
        }

        // Put each decoding line to separate func and hash mapping when more encodings support added.
        if (encoding==ENC_UTF8) return parseUtf8(std::string(blob.begin(), blob.end()));

        if (encoding==ENC_CP1252) return unicode_string(blob.begin(), blob.end());

        return r;
    }
};

const char *TextCodec::ENC_UTF8 = "UTF8";
const char *TextCodec::ENC_CP1252 = "CP1252";
const char *TextCodec::SUPPORTED_ENCODINGS[2] = {TextCodec::ENC_CP1252, TextCodec::ENC_UTF8};

FileSystemInterface::FileSystemInterface(ByteCodeRunner *owner)
    : NativeMethodHost(owner), owner(owner)
{

}


NativeFunction *FileSystemInterface::MakeNativeFunction(const char *name, int num_args)
{
#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "FlowFileSystem."

    TRY_USE_NATIVE_METHOD(FileSystemInterface, createDirectory, 1);
    TRY_USE_NATIVE_METHOD(FileSystemInterface, deleteDirectory, 1);
    TRY_USE_NATIVE_METHOD(FileSystemInterface, deleteFile, 1);
    TRY_USE_NATIVE_METHOD(FileSystemInterface, renameFile, 2);

    TRY_USE_NATIVE_METHOD(FileSystemInterface, fileExists, 1);
    TRY_USE_NATIVE_METHOD(FileSystemInterface, isDirectory, 1);
    TRY_USE_NATIVE_METHOD(FileSystemInterface, readDirectory, 1);

    TRY_USE_NATIVE_METHOD(FileSystemInterface, fileSize, 1);
    TRY_USE_NATIVE_METHOD(FileSystemInterface, fileModified, 1);

    TRY_USE_NATIVE_METHOD(FileSystemInterface, resolveRelativePath, 1);

    TRY_USE_NATIVE_METHOD(FileSystemInterface, getFileByPath, 1);
    TRY_USE_NATIVE_METHOD(FileSystemInterface, createTempFile, 2);
    TRY_USE_NATIVE_METHOD(FileSystemInterface, openFileDialog, 3);
    TRY_USE_NATIVE_METHOD(FileSystemInterface, fileName, 1);
    TRY_USE_NATIVE_METHOD(FileSystemInterface, fileType, 1);
    TRY_USE_NATIVE_METHOD(FileSystemInterface, fileSizeNative, 1);
    TRY_USE_NATIVE_METHOD(FileSystemInterface, fileModifiedNative, 1);
    TRY_USE_NATIVE_METHOD(FileSystemInterface, fileSlice, 3);
    TRY_USE_NATIVE_METHOD(FileSystemInterface, readFile, 4);
    TRY_USE_NATIVE_METHOD(FileSystemInterface, readFileEnc, 5);

    return NULL;
}

StackSlot FileSystemInterface::createDirectory(RUNNER_ARGS)
{
    RUNNER_PopArgs1(name_str);
    RUNNER_CheckTag1(TString, name_str);

    std::string filename = encodeUtf8(RUNNER->GetString(name_str));

#ifdef WIN32
    if (mkdir(filename.c_str()))
#else
    if (mkdir(filename.c_str(), 0770))
#endif
        return RUNNER->AllocateString("mkdir failed");

    return RUNNER->AllocateString("");
}

StackSlot FileSystemInterface::deleteDirectory(RUNNER_ARGS)
{
    RUNNER_PopArgs1(name_str);
    RUNNER_CheckTag1(TString, name_str);

    std::string filename = encodeUtf8(RUNNER->GetString(name_str));

    if (rmdir(filename.c_str()))
        return RUNNER->AllocateString("rmdir failed");

    return RUNNER->AllocateString("");
}

StackSlot FileSystemInterface::deleteFile(RUNNER_ARGS)
{
    RUNNER_PopArgs1(name_str);
    RUNNER_CheckTag1(TString, name_str);

    std::string filename = encodeUtf8(RUNNER->GetString(name_str));

    if (unlink(filename.c_str()))
        return RUNNER->AllocateString("unlink failed");

    return RUNNER->AllocateString("");
}

StackSlot FileSystemInterface::renameFile(RUNNER_ARGS)
{
    RUNNER_PopArgs2(old_name_str, new_name_str);
    RUNNER_CheckTag2(TString, old_name_str, new_name_str);

    std::string old_filename = encodeUtf8(RUNNER->GetString(old_name_str));
    std::string new_filename = encodeUtf8(RUNNER->GetString(new_name_str));

    if (rename(old_filename.c_str(), new_filename.c_str()))
        return RUNNER->AllocateString("rename failed");

    return RUNNER->AllocateString("");
}

StackSlot FileSystemInterface::fileExists(RUNNER_ARGS)
{
    RUNNER_PopArgs1(name_str);
    RUNNER_CheckTag1(TString, name_str);

    std::string filename = encodeUtf8(RUNNER->GetString(name_str));

    struct stat info;
    return StackSlot::MakeBool(stat(filename.c_str(), &info) >= 0);
}

StackSlot FileSystemInterface::isDirectory(RUNNER_ARGS)
{
    RUNNER_PopArgs1(name_str);
    RUNNER_CheckTag1(TString, name_str);

    std::string filename = encodeUtf8(RUNNER->GetString(name_str));

#ifdef _MSC_VER
    DWORD ftyp = GetFileAttributesA(filename.c_str());
    return StackSlot::MakeBool(ftyp != INVALID_FILE_ATTRIBUTES && ftyp & FILE_ATTRIBUTE_DIRECTORY);
#else
    struct stat info;
    if (stat(filename.c_str(), &info) < 0)
        return StackSlot::MakeBool(false);
    return StackSlot::MakeBool(S_ISDIR(info.st_mode));
#endif
}

StackSlot FileSystemInterface::readDirectory(RUNNER_ARGS)
{
    RUNNER_PopArgs1(name_str);
    RUNNER_CheckTag1(TString, name_str);

    std::string filename = encodeUtf8(RUNNER->GetString(name_str));
#ifdef _MSC_VER
    WIN32_FIND_DATA ffd;
    HANDLE hFind = INVALID_HANDLE_VALUE;
    std::wstring dir_name = std::wstring(filename.begin(), filename.end()) + L"\\*";
    hFind = FindFirstFile(dir_name.c_str(), &ffd);

    if (hFind == INVALID_HANDLE_VALUE)
        return RUNNER->AllocateArray(0);

    std::vector<std::string> items;
    do {
        std::wstring name = std::wstring(ffd.cFileName);
        items.push_back(std::string(name.begin(), name.end()));
    } while(FindNextFile(hFind, &ffd));

    FindClose(hFind);
#else
    DIR *dir = opendir(filename.c_str());
    if (!dir)
        return RUNNER->AllocateArray(0);

    std::vector<std::string> items;
    struct dirent *info;

    while ((info = readdir(dir)) != NULL)
    {
        std::string name(info->d_name);
        if (name != "." && name != "..")
            items.push_back(std::string(info->d_name));
    }

    closedir(dir);
#endif
    RUNNER_DefSlotAlias(result, name_str);
    result = RUNNER->AllocateArray(items.size());

    for (size_t i = 0; i < items.size(); i++)
        RUNNER->SetArraySlot(result, i, RUNNER->AllocateString(parseUtf8(items[i])));

    return result;
}

StackSlot FileSystemInterface::fileSize(RUNNER_ARGS)
{
    RUNNER_PopArgs1(name_str);
    RUNNER_CheckTag1(TString, name_str);

    std::string filename = encodeUtf8(RUNNER->GetString(name_str));
    return StackSlot::MakeDouble(FlowFile::getFileSize(filename));
}

StackSlot FileSystemInterface::fileModified(RUNNER_ARGS)
{
    RUNNER_PopArgs1(name_str);
    RUNNER_CheckTag1(TString, name_str);

    std::string filename = encodeUtf8(RUNNER->GetString(name_str));
    return StackSlot::MakeDouble(FlowFile::getFileLastModified(filename));
}

#ifdef _MSC_VER
#define PATH_MAX 4096
#endif

char * FileSystemInterface::doResolveRelativePath(std::string &filename, char* buffer) {
#ifdef WIN32
  return _fullpath(buffer, filename.c_str(), PATH_MAX);
#else
  return realpath(filename.c_str(), buffer);
#endif
}

StackSlot FileSystemInterface::resolveRelativePath(RUNNER_ARGS)
{
    RUNNER_PopArgs1(name_str);
    RUNNER_CheckTag1(TString, name_str);

    std::string filename = encodeUtf8(RUNNER->GetString(name_str));

    char buf[PATH_MAX];

    if (doResolveRelativePath(filename, buf) == NULL)
	return name_str;

    return RUNNER->AllocateString(buf);
}

StackSlot FileSystemInterface::getFileByPath(RUNNER_ARGS)
{
    RUNNER_PopArgs1(path_str);
    RUNNER_CheckTag1(TString, path_str);

    std::string path = encodeUtf8(RUNNER->GetString(path_str));

    return RUNNER->AllocNative(new FlowFile(owner, path));
}

StackSlot FileSystemInterface::createTempFile(RUNNER_ARGS)
{
    RUNNER_PopArgs2(filename, content);
    RUNNER_CheckTag2(TString, filename, content);

    std::string path = encodeUtf8(RUNNER->GetString(filename));

    std::ofstream fs(path);
    if (fs && fs.is_open()) {
        fs << encodeUtf8(RUNNER->GetString(content));
        fs.close();
    }

    FlowFile *flowFile = new FlowFile(owner, path);
    flowFile->setTemporary(true);

    return RUNNER->AllocNative(flowFile);
}

StackSlot FileSystemInterface::openFileDialog(RUNNER_ARGS)
{
    RUNNER_PopArgs3(max_files, types, callback);
    RUNNER_CheckTag1(TInt, max_files);
    RUNNER_CheckTag1(TArray, types);

    int maxFiles = max_files.GetInt();

    std::vector<std::string> fileTypes;

    for (unsigned int i = 0; i < RUNNER->GetArraySize(types); i++)
    {
        const StackSlot &str = RUNNER->GetArraySlot(types, i);
        RUNNER_CheckTag1(TString, str);
        fileTypes.push_back(encodeUtf8(RUNNER->GetString(str)));
    }

    doOpenFileDialog(maxFiles, fileTypes, callback);

    RETVOID;
}

StackSlot FileSystemInterface::fileName(RUNNER_ARGS)
{
    RUNNER_PopArgs1(file);

    FlowFile *flowFile = owner->GetNative<FlowFile*>(file);
    std::string filepath = flowFile->getFilepath();

    char buf[PATH_MAX];
    if (doResolveRelativePath(filepath, buf) == NULL)
        return RUNNER->AllocateString(filepath.c_str());

    return RUNNER->AllocateString(buf);
}

StackSlot FileSystemInterface::fileType(RUNNER_ARGS)
{
    RUNNER_PopArgs1(file);

    return RUNNER->AllocateString(doFileType(file).c_str());
}

StackSlot FileSystemInterface::fileSizeNative(RUNNER_ARGS)
{
    RUNNER_PopArgs1(file);

    FlowFile *flowFile = owner->GetNative<FlowFile*>(file);

    return StackSlot::MakeDouble(flowFile->getSliceSize());
}

StackSlot FileSystemInterface::fileModifiedNative(RUNNER_ARGS)
{
    RUNNER_PopArgs1(file);

    FlowFile *flowFile = owner->GetNative<FlowFile*>(file);

    return StackSlot::MakeDouble(flowFile->getFileLastModified());
}

StackSlot FileSystemInterface::fileSlice(RUNNER_ARGS)
{
    RUNNER_PopArgs3(file, offset, end);
    RUNNER_CheckTag2(TInt, offset, end);

    FlowFile *flowFile = RUNNER->GetNative<FlowFile*>(file);

    FlowFile *chunkFlowFile = new FlowFile(owner, flowFile->getFilepath());
    chunkFlowFile->setSliceRange(offset.GetInt(), end.GetInt());
    return RUNNER->AllocNative(chunkFlowFile);
}

StackSlot FileSystemInterface::readFile(RUNNER_ARGS)
{
    RUNNER_PopArgs4(file, as, onDone, onError);
    RUNNER_CheckTag1(TString, as);

    doFileRead(file, encodeUtf8(RUNNER->GetString(as)), "UTF8", onDone, onError);

    RETVOID;
}

StackSlot FileSystemInterface::readFileEnc(RUNNER_ARGS)
{
    RUNNER_PopArgs5(file, as, en, onDone, onError);
    RUNNER_CheckTag2(TString, as, en);

    doFileRead(file, encodeUtf8(RUNNER->GetString(as)), encodeUtf8(RUNNER->GetString(en)), onDone, onError);

    RETVOID;
}

void FileSystemInterface::doFileRead(const StackSlot &file, std::string readAs, std::string readEncoding, const StackSlot &onData, const StackSlot &onError)
{
    RUNNER_VAR = owner;
    WITH_RUNNER_LOCK_DEFERRED(RUNNER);

    FlowFile *flowFile = (FlowFile*)RUNNER->GetNative<FlowFile*>(file);

    if (!flowFile->open()) {
        RUNNER->EvalFunction(onError, 1, RUNNER->AllocateString("Cannot open file for reading!"));
        return;
    }

    std::vector<uint8_t> blob = flowFile->readBytes();

    if (readAs == "data") {
        int n = blob.size();
        unicode_char * unicode = new unicode_char[n];
        for (int i = 0; i != n; ++i) {
            unicode[i] = blob.at(i);
        }
        RUNNER->EvalFunction(onData, 1, RUNNER->AllocateString(unicode, n));
    } else if (readAs == "uri") {
        size_t base64_length = 0;
        unsigned char *str = Base64::encode(&blob[0], blob.size(), &base64_length);

        std::string dataUrl = "data:" + doFileType(file) + ";base64," + std::string(str, str+base64_length);

        RUNNER->EvalFunction(onData, 1, RUNNER->AllocateString(parseUtf8(dataUrl)));
    } else {
        RUNNER->EvalFunction(onData, 1, RUNNER->AllocateString(TextCodec::decode(blob, readEncoding)));
    }

    flowFile->close();
}

