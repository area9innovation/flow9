#ifndef QUITSUPPORT_H
#define QUITSUPPORT_H

#include "core/ByteCodeRunner.h"

#include <QObject>

class QtQuitSupport : public QObject, public NativeMethodHost
{
    Q_OBJECT
public:
    QtQuitSupport(ByteCodeRunner *Runner);

protected:
    NativeFunction *MakeNativeFunction(const char *name, int num_args);

private:
    ByteCodeRunner* Runner;

    DECLARE_NATIVE_METHOD(quit)
};

#endif // QUITSUPPORT_H
