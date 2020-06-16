#ifndef FLOWFILESTRUCT_H
#define FLOWFILESTRUCT_H

#include "core/nativefunction.h"

#include <fstream>

class FlowFile : public FlowNativeObject
{
private:
    std::ifstream file;
    std::string _filepath;
    std::streampos _offset, _end;

    bool temporary = false;
public:
    FlowFile(ByteCodeRunner *owner, std::string filepath);
    ~FlowFile();

    DEFINE_FLOW_NATIVE_OBJECT(FlowFile, FlowNativeObject)

    std::string getFilepath();
    std::string getFilename();
    std::streampos getFileSize();
    double getFileLastModified();

    std::streampos getSliceSize();

    bool open();
    std::vector<uint8_t> readBytes();
    void close();

    void setSliceRange(int offset, int end);
    void setSliceRange(std::streampos offset, std::streampos end);

    static std::streampos getFileSize(std::string filepath);
    static double getFileLastModified(std::string filepath);

    void setTemporary(bool value);
};

#endif // FLOWFILESTRUCT_H
