#include "flowfilestruct.h"

#include <sys/types.h>
#include <sys/stat.h>
#ifndef WIN32
#include <unistd.h>
#endif

IMPLEMENT_FLOW_NATIVE_OBJECT(FlowFile, FlowNativeObject)

FlowFile::FlowFile(ByteCodeRunner *owner, std::string filepath) : FlowNativeObject(owner)
{
    _filepath = filepath;
    _offset = 0;
    _end = getFileSize();
}

std::string FlowFile::getFilepath()
{
    return _filepath;
}

std::string FlowFile::getFilename()
{
    return _filepath.substr(_filepath.find_last_of("/\\") + 1);
}

std::streampos FlowFile::getFileSize()
{
    return getFileSize(_filepath);
}

double FlowFile::getFileLastModified()
{
    return getFileLastModified(_filepath);
}

bool FlowFile::open()
{
    file.open(_filepath, std::ios_base::binary | std::ios_base::in);
    return file.is_open();
}

std::vector<uint8_t> FlowFile::readBytes()
{
    std::vector<uint8_t> fileContent(getSliceSize());
    file.seekg(_offset);
    file.read((char*)&fileContent[0], fileContent.size());
    return fileContent;
}

void FlowFile::close()
{
    file.close();
}

void FlowFile::setSliceRange(int offset, int end)
{
    setSliceRange(std::streampos(offset), std::streampos(end));
}

void FlowFile::setSliceRange(std::streampos offset, std::streampos end)
{
    std::streampos size = getFileSize();
    // Make same behaviour as JS Blob slice has
    if (size < offset) {
        _offset = size;
        _end = size;
    } else if (size < end && offset < end) {
        _offset = offset;
        _end = size;
    } else if (end < 0) {
        setSliceRange(offset, std::streampos(size + end));
    } else if (offset < 0) {
        setSliceRange(std::streampos(size + offset), end);
    } else if (end < offset) {
        _offset = end;
        _end = offset;
    } else {
        _offset = offset;
        _end = end;
    }
}

std::streampos FlowFile::getSliceSize()
{
    return _end - _offset;
}

std::streampos FlowFile::getFileSize(std::string filepath)
{
    struct stat info;
    if (stat(filepath.c_str(), &info) < 0)
        return 0;

    return info.st_size;
}

double FlowFile::getFileLastModified(std::string filepath)
{
    struct stat info;
    if (stat(filepath.c_str(), &info) < 0)
        return 0;

    return info.st_mtime * 1000.0;
}

