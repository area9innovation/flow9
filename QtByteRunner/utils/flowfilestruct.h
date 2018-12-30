#ifndef FLOWFILESTRUCT_H
#define FLOWFILESTRUCT_H

#include "nativefunction.h"

#include <QFile>

class FlowFile : public FlowNativeObject
{
private:
    QFile* file;

    qint64 _offset, _end;
public:
    FlowFile(ByteCodeRunner *owner, QFile *file);

    DEFINE_FLOW_NATIVE_OBJECT(FlowFile, FlowNativeObject);

    QFile* getFile();

    void setSliceRange(int offset, int end);
    qint64 size() { return _end - _offset; }
    qint64 getOffset() { return _offset; }
    qint64 getEnd() { return _end; }
};

#endif // FLOWFILESTRUCT_H
