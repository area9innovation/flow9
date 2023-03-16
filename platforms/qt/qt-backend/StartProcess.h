#ifndef STARTPROCESS_H
#define STARTPROCESS_H

#include "core/ByteCodeRunner.h"

#include <QObject>
#include <QMap>
#include <QUrl>
#include <QTimerEvent>
#include <QProcess>

class StartProcess : public QObject, public NativeMethodHost
{
    Q_OBJECT

public:
    StartProcess(ByteCodeRunner *Runner);
    ~StartProcess();

    class FlowProcess : public FlowNativeObject
    {
    public:
        QProcess *process;

        std::string out_buffer;
        size_t out_pos;

        QByteArray stdout_buf, stderr_buf;
        size_t stdout_pos, stderr_pos;

        StackSlot stdout_cb;
        StackSlot stderr_cb;
        StackSlot exit_cb;

        bool controlled_process;

        FlowProcess(StartProcess *owner);

        DEFINE_FLOW_NATIVE_OBJECT(FlowProcess, FlowNativeObject)

    protected:
        void flowGCObject(GarbageCollectorFn gc);
        bool flowDestroyObject();
    };

protected:
    NativeFunction *MakeNativeFunction(const char *name, int num_args);

    void flowGCObject(GarbageCollectorFn gc);
    void OnRunnerReset(bool inDestructor);

private:
    ByteCodeRunner *owner;

    typedef std::map<QProcess*, FlowProcess*> T_process_set;
    T_process_set process_set;

    void provideStdout(FlowProcess *p);
    void provideStderr(FlowProcess *p);
    void endProcess(FlowProcess *p, int code);
	DECLARE_NATIVE_METHOD(execSystemProcess);
    DECLARE_NATIVE_METHOD(startProcess);
    DECLARE_NATIVE_METHOD(runSystemProcess);
    DECLARE_NATIVE_METHOD(writeProcessStdin);
    DECLARE_NATIVE_METHOD(killProcess);
    DECLARE_NATIVE_METHOD(startDetachedProcess);
    DECLARE_NATIVE_METHOD(getApplicationPath);

private slots:
    void processReadyWrite();
    void processReadyStdout();
    void processReadyStderr();
    void processFinished(int code, QProcess::ExitStatus status);
    void processFailed(QProcess::ProcessError);
};

#endif // STARTPROCESS_H
