#ifndef NATIVES_H
#define NATIVES_H

#include "core/ByteCodeRunner.h"

#include <QObject>

class QtNatives : public QObject, public NativeMethodHost
{
    Q_OBJECT
public:
    QtNatives(ByteCodeRunner *Runner);

protected:
    NativeFunction *MakeNativeFunction(const char *name, int num_args);

private:
    ByteCodeRunner* Runner;

    DECLARE_NATIVE_METHOD(quit)
	DECLARE_NATIVE_METHOD(availableProcessors)
};

#endif // NATIVES_H
