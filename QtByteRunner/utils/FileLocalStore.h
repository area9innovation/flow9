#ifndef FILELOCALSTORE_H
#define FILELOCALSTORE_H

#include "core/ByteCodeRunner.h"

std::string urlEscapePath(std::string path);
bool endsWithAsterisk(std::string str);

class FileLocalStore : public NativeMethodHost {
    std::string base_path;

    std::string makePath(unicode_string key);

public:
    FileLocalStore(ByteCodeRunner *owner);

    void SetBasePath(std::string path);

protected:
    NativeFunction *MakeNativeFunction(const char *name, int num_args);

private:
    DECLARE_NATIVE_METHOD(getKeyValue);
    DECLARE_NATIVE_METHOD(setKeyValue);
    DECLARE_NATIVE_METHOD(removeKeyValue);

};

#endif // FILELOCALSTORE_H
