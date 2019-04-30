#ifndef TIMERSUPPORT_H
#define TIMERSUPPORT_H

#include "core/ByteCodeRunner.h"

#include <QObject>
#include <QMap>
#include <QTimerEvent>

class QtTimerSupport : public QObject, public NativeMethodHost
{
    Q_OBJECT
public:
    QtTimerSupport(ByteCodeRunner *Runner);

protected:
    NativeFunction *MakeNativeFunction(const char *name, int num_args);

private:
    ByteCodeRunner* Runner;

    // Timer id -> FLow Call back
    QMap<int, int> TimersMap;

    void timerEvent(QTimerEvent*);
    static StackSlot KillTimer(ByteCodeRunner*, StackSlot*, void*);

    DECLARE_NATIVE_METHOD(Timer)
    DECLARE_NATIVE_METHOD(InterruptibleTimer)
};

#endif // TIMERSUPPORT_H
