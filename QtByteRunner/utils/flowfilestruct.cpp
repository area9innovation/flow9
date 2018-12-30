#include "flowfilestruct.h"

IMPLEMENT_FLOW_NATIVE_OBJECT(FlowFile, FlowNativeObject);

FlowFile::FlowFile(ByteCodeRunner *owner, QFile *file) : FlowNativeObject(owner), file(file)
{
    _offset = 0;
    _end = file->size();
}

QFile* FlowFile::getFile()
{
    return file;
}

void FlowFile::setSliceRange(int offset, int end)
{
    // Make same behaviour as JS Blob slice has
    if (file->size() < offset) {
        _offset = file->size();
        _end = file->size();
    } else if (file->size() < end && offset < end) {
        _offset = offset;
        _end = file->size();
    } else if (end < 0) {
        setSliceRange(offset, file->size() - end);
    } else if (offset < 0) {
        setSliceRange(file->size() - offset, end);
    } else if (end < offset) {
        _offset = end;
        _end = offset;
    } else {
        _offset = offset;
        _end = end;
    }
}
