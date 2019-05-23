#ifndef FILELOCALSTORE_H
#define FILELOCALSTORE_H

#include "core/ByteCodeRunner.h"

std::string urlEscapePath(std::string path);
bool endsWithAsterisk(std::string str);

typedef std::vector<std::string> KeysVector;

class FileLocalStore : public NativeMethodHost {
    std::string base_path;

    std::string makePath(unicode_string key);
    KeysVector getKeysList();

public:
    FileLocalStore(ByteCodeRunner *owner);

    void SetBasePath(std::string path);

protected:
    NativeFunction *MakeNativeFunction(const char *name, int num_args);

private:
    DECLARE_NATIVE_METHOD(getKeyValue);
    DECLARE_NATIVE_METHOD(setKeyValue);
    DECLARE_NATIVE_METHOD(removeKeyValue);
    DECLARE_NATIVE_METHOD(removeAllKeyValues);
    DECLARE_NATIVE_METHOD(getKeysList);

};

#endif // FILELOCALSTORE_H
