#include "FileLocalStore.h"

#include "core/RunnerMacros.h"

#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <errno.h>

#ifdef WIN32
#include <io.h>
#include <windows.h>

    #ifdef _MSC_VER
        #include <direct.h>
        #define mkdir _mkdir
    #endif
#else
#include <dirent.h>
#endif

std::string urlEscapePath(std::string path)
{
    std::string output;
    output.reserve(path.size()+10);

    static const char hex_chars[16] = { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f' };

    for (unsigned i = 0; i < path.size(); ++i) {
        unsigned char c = path[i];
        if ((c >= 'A' && c <= 'Z') ||
            (c >= 'a' && c <= 'z') ||
            (c >= '0' && c <= '9') ||
            c == '+' || c == '-' ||
            c == '_' || c == ' ')
        {
            output.push_back(c);
        } else {
            output.push_back('%');
            output.push_back(hex_chars[c>>4]);
            output.push_back(hex_chars[c&0xF]);
        }
    }

    return output;
}

FileLocalStore::FileLocalStore(ByteCodeRunner *owner)
    : NativeMethodHost(owner)
{

}

void FileLocalStore::SetBasePath(std::string path)
{
    base_path = path;

    if (!base_path.empty()) {
        char lchar = base_path[base_path.size()-1];
        if (lchar != '/' && lchar != '\\')
            base_path += "/";

#ifdef WIN32
        if (mkdir(base_path.c_str()) && errno != EEXIST)
#else
        if (mkdir(base_path.c_str(), 0770) && errno != EEXIST)
#endif
            cerr << "Could not create directory: " << base_path << endl;
    }
}

std::string FileLocalStore::makePath(unicode_string key)
{
    return base_path + urlEscapePath(encodeUtf8(key));
}

KeysVector FileLocalStore::getKeysList()
{
    KeysVector files;
#ifdef WIN32
    WIN32_FIND_DATAA FindFileData;
    HANDLE hFind = FindFirstFileA((base_path + "*").c_str(), &FindFileData);
    while (hFind != INVALID_HANDLE_VALUE) {
        if (!(FindFileData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY))
            files.push_back(FindFileData.cFileName);

        if (!FindNextFileA(hFind, &FindFileData)) {
            FindClose(hFind);
            hFind = INVALID_HANDLE_VALUE;
        }
    }
#else
    DIR* storage = opendir(base_path.c_str());
    if (storage == NULL) return files;
    while(struct dirent * file = readdir(storage)) {
        if (file->d_type != 4)
            files.push_back(file->d_name);
    }
    
    closedir(storage);
#endif
    
    return files;
}

NativeFunction *FileLocalStore::MakeNativeFunction(const char *name, int num_args)
{
#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "Native."

    TRY_USE_NATIVE_METHOD(FileLocalStore, getKeyValue, 2);
    TRY_USE_NATIVE_METHOD(FileLocalStore, setKeyValue, 2);
    TRY_USE_NATIVE_METHOD(FileLocalStore, removeKeyValue, 1);
    TRY_USE_NATIVE_METHOD(FileLocalStore, removeAllKeyValues, 0);
    TRY_USE_NATIVE_METHOD(FileLocalStore, getKeysList, 0);

    return NULL;
}

StackSlot FileLocalStore::getKeyValue(RUNNER_ARGS)
{
    RUNNER_PopArgs2(key_str, def_str);
    RUNNER_CheckTag2(TString, key_str, def_str);

    if (base_path.empty()) {
        return def_str;
    }

    std::string filename = makePath(RUNNER->GetString(key_str));

    // This may mmap the file instead of reading it, if the size is big enough.
    key_str = RUNNER->LoadFileAsString(filename, false);

    if (key_str.IsVoid())
        return def_str;
    else
        return key_str;
}

StackSlot FileLocalStore::setKeyValue(RUNNER_ARGS)
{
    RUNNER_PopArgs2(key_str, value_str);
    RUNNER_CheckTag2(TString, key_str, value_str);

    if (base_path.empty()) {
        return StackSlot::MakeBool(false);
    }

    std::string filename = makePath(RUNNER->GetString(key_str));
    unsigned size;
    const unicode_char *pdata = RUNNER->GetStringPtrSize(value_str, &size);
    size_t bytes = size * FLOW_CHAR_SIZE;

    bool ok = false;
    std::string tmp_fn = filename + ".tmp";

    if (FILE *out = fopen(tmp_fn.c_str(), "wb")) {
        ok = (fwrite(pdata, 1, bytes, out) == bytes);
        fclose(out);

        if (ok) {
#ifdef WIN32
            unlink(filename.c_str());
#endif
            ok = !rename(tmp_fn.c_str(), filename.c_str());
            RUNNER->InvalidateFileCache(filename);
        }
    }

    return StackSlot::MakeBool(ok);
}

StackSlot FileLocalStore::removeKeyValue(RUNNER_ARGS)
{
    RUNNER_PopArgs1(key_str);
    RUNNER_CheckTag(TString, key_str);

    if (base_path.empty()) RETVOID;

    std::string filename = makePath(RUNNER->GetString(key_str));
    if (endsWithAsterisk(filename)) {
#ifdef WIN32
        WIN32_FIND_DATAA FindFileData;
        std::string filename2 = filename;
        const char* fname2 = filename2.replace(filename2.length()-3, 3, "*").c_str();
        std::string bp;
        HANDLE hFind = FindFirstFileA(fname2, &FindFileData);
        while (hFind != INVALID_HANDLE_VALUE) {
            bp = base_path;
            DeleteFileA(bp.append(FindFileData.cFileName).c_str());
            if (!FindNextFileA(hFind, &FindFileData)) {
                FindClose(hFind);
                hFind = INVALID_HANDLE_VALUE;
            }
        }
#endif
    } else remove(filename.c_str());

    RETVOID;
}


StackSlot FileLocalStore::removeAllKeyValues(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    
    if (base_path.empty()) RETVOID;
    
    KeysVector keys = getKeysList();
    for (KeysVector::iterator it = keys.begin(); it != keys.end(); it++) {
        std::string filename = base_path + *it;
        remove(filename.c_str());
    }
    
    RETVOID;
}

StackSlot FileLocalStore::getKeysList(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    
    KeysVector keys = getKeysList();
    RUNNER_DefSlots1(list);
    list = RUNNER->AllocateArray(keys.size());
    for (KeysVector::iterator it = keys.begin(); it != keys.end(); it++)
        RUNNER->SetArraySlot(list, it - keys.begin(), RUNNER->AllocateString(parseUtf8(*it)));
    
    return list;
}

bool endsWithAsterisk(std::string str)
{
    return str.substr(str.length()-3).compare("%2a") == 0;
}
