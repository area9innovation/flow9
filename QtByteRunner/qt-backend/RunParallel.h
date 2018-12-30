#ifndef RUNPARALLEL_H
#define RUNPARALLEL_H

#include "core/ByteCodeRunner.h"

#include <sstream>

#include <QThread>
#include <QMutex>

class RunParallelHost;

class FlowRunnerThread : public QThread
{
public:
    struct BytecodeInfo {
        typedef std::shared_ptr<BytecodeInfo> Ptr;

        std::string filename;
#ifdef FLOW_JIT
        FlowJitProgram *jit_program;
#endif

        BytecodeInfo(std::string filename) : filename(filename)
#ifdef FLOW_JIT
            , jit_program(NULL)
#endif
        {}
        ~BytecodeInfo();
    };

private:
    Q_OBJECT

    RunParallelHost *host;

    BytecodeInfo::Ptr bytecode;
    QUrl url;

public:
    FlowRunnerThread(RunParallelHost *host, QObject *parent = NULL);

    bool error;
    int retcode;
    std::stringstream output;

    void setBytecode(BytecodeInfo::Ptr ptr) { bytecode = ptr; }
    void setUrl(QUrl url) { this->url = url; }

    void detach();

    virtual void run();

signals:
    void parentMessage(QByteArray id, QByteArray data);

public slots:
    void childMessage(QByteArray id, QByteArray data);
};

class LoadedBytecode : public FlowNativeObject
{
    RunParallelHost *host;

    FlowRunnerThread::BytecodeInfo::Ptr bytecode;

public:
    LoadedBytecode(RunParallelHost *host, std::string bytecode);

    bool load();

public:
    DEFINE_FLOW_NATIVE_OBJECT(LoadedBytecode, FlowNativeObject)

    DECLARE_NATIVE_METHOD(runBytecode)
};

class FlowRunnerThreadRef : public FlowNativeObject
{
    RunParallelHost *host;
    FlowRunnerThread *thread;

    StackSlot finish_cb, message_cb;

public:
    FlowRunnerThreadRef(RunParallelHost *host, FlowRunnerThread *thread, const StackSlot &finish_cb, const StackSlot &message_cb);

    DEFINE_FLOW_NATIVE_OBJECT(FlowRunnerThreadRef, FlowNativeObject)

    void detach();
    void notifyFinish();
    void notifyChildMessage(QByteArray id, QByteArray data);

    DECLARE_NATIVE_METHOD(notifyChildRunner)

protected:
    virtual void flowGCObject(GarbageCollectorFn fn);
};

class RunParallelHost : public QObject, public NativeMethodHost
{
    Q_OBJECT

    friend class LoadedBytecode;
    friend class FlowRunnerThread;
    friend class FlowRunnerThreadRef;

    StackSlot message_cb;

    FlowRunnerThread *self_thread;
    std::map<FlowRunnerThread*, FlowRunnerThreadRef*> callbacks;

    void detachChildren();
    void notifyChildMessage(FlowRunnerThread *thread, QByteArray id, QByteArray data);

public:
    RunParallelHost(ByteCodeRunner *owner, FlowRunnerThread *self = NULL);
    ~RunParallelHost();

protected:
    virtual void flowGCObject(GarbageCollectorFn fn);

    void OnHostEvent(HostEvent ev);
    void OnRunnerReset(bool dtor);

    NativeFunction *MakeNativeFunction(const char *name, int num_args);

private:
    DECLARE_NATIVE_METHOD(loadBytecode)
    DECLARE_NATIVE_METHOD(notifyParentRunner)
    DECLARE_NATIVE_METHOD(quit)
    DECLARE_NATIVE_METHOD(registerParentRunnerCallback)

private slots:
    void threadFinished();
    void parentMessage(QByteArray id, QByteArray data);
};


#endif
