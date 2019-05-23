#include "RunParallel.h"

#include "utils/FileLocalStore.h"
#include "qt-backend/HttpSupport.h"
#include "qt-backend/QtTimerSupport.h"
#include "qt-backend/DatabaseSupport.h"
#include "qt-backend/StartProcess.h"
#include "qt-backend/NotificationsSupport.h"
#include "qt-backend/QtGeolocationSupport.h"
#include "qt-backend/qfilesysteminterface.h"

#include <QSettings>
#include <QCoreApplication>

IMPLEMENT_FLOW_NATIVE_OBJECT(LoadedBytecode, FlowNativeObject)
IMPLEMENT_FLOW_NATIVE_OBJECT(FlowRunnerThreadRef, FlowNativeObject)

#ifdef FLOW_JIT
FlowJitProgram *loadJitProgram(ostream &e, const std::string &bytecode_file, const std::string &log_file, const unsigned long memory_limit = 0);
void deleteJitProgram(FlowJitProgram *program);
#endif

FlowRunnerThread::BytecodeInfo::~BytecodeInfo()
{
#ifdef FLOW_JIT
    deleteJitProgram(jit_program);
#endif
}

FlowRunnerThread::FlowRunnerThread(RunParallelHost *host, QObject *parent) : QThread(parent), host(host)
{
    error = false;
    retcode = 0;
}

void FlowRunnerThread::detach()
{
    host = NULL;
}

void FlowRunnerThread::childMessage(QByteArray id, QByteArray data)
{
    if (host)
        host->notifyChildMessage(this, id, data);
}

void FlowRunnerThread::run()
{
    ByteCodeRunner FlowRunner;

    FlowRunner.flow_out.rdbuf(output.rdbuf());

    QtTimerSupport QtTimer(&FlowRunner);
    FileLocalStore LocalStore(&FlowRunner);
    DatabaseSupport DbManager(&FlowRunner);
    StartProcess ProcStarter(&FlowRunner);

    QSettings ini(QSettings::IniFormat, QSettings::UserScope,
                  QCoreApplication::organizationName(),
                  QCoreApplication::applicationName());

    QString config_dir = QFileInfo(ini.fileName()).absolutePath();

    LocalStore.SetBasePath(encodeUtf8(qt2unicode(config_dir)) + "/flow-local-store/");

    QtHttpSupport HttpManager(&FlowRunner, NULL);
    QFileSystemInterface FileSystem(&FlowRunner, &HttpManager);
    QtNotificationsSupport NotificationsManager(&FlowRunner, false);
    QtGeolocationSupport GeolocationManager(&FlowRunner);

    RunParallelHost ParallelHost(&FlowRunner, this);

#ifdef FLOW_JIT
    if (bytecode->jit_program)
    {
        FlowRunner.Init(bytecode->jit_program);
    }
    else
#endif
    {
        FlowRunner.Init(bytecode->filename);
    }

    FlowRunner.setUrl(url);
    FlowRunner.RunMain();

    if (!FlowRunner.IsErrorReported())
        exec();

    error = FlowRunner.IsErrorReported();
}

LoadedBytecode::LoadedBytecode(RunParallelHost *host, std::string bytecode)
    : FlowNativeObject(host->getFlowRunner()), host(host)
{
    this->bytecode = std::make_shared<FlowRunnerThread::BytecodeInfo>(bytecode);
}

bool LoadedBytecode::load()
{
#ifdef FLOW_JIT
    if (true)
    {
		bytecode->jit_program = loadJitProgram(getFlowRunner()->flow_err, bytecode->filename, "");

        if (!bytecode->jit_program)
            return false;
    }
#endif

    return true;
}

RunParallelHost::RunParallelHost(ByteCodeRunner *owner, FlowRunnerThread *self)
    : NativeMethodHost(owner), self_thread(self)
{
    message_cb = StackSlot::MakeVoid();

    if (self)
    {
        connect(self, SIGNAL(parentMessage(QByteArray,QByteArray)), this, SLOT(parentMessage(QByteArray,QByteArray)), Qt::QueuedConnection);
    }
}

RunParallelHost::~RunParallelHost()
{

}

void RunParallelHost::detachChildren()
{
    for(auto it = callbacks.begin(); it != callbacks.end(); ++it)
    {
        FlowRunnerThread *thread = it->first;

        thread->detach();
        it->second->detach();

        disconnect(thread, SIGNAL(finished()), this, SLOT(threadFinished()));
        connect(thread, SIGNAL(finished()), thread, SLOT(deleteLater()));
    }

    callbacks.clear();
}

inline GarbageCollectorFn operator<< (GarbageCollectorFn fn, FlowRunnerThread *) { return fn; }

void RunParallelHost::flowGCObject(GarbageCollectorFn fn)
{
    fn << callbacks << message_cb;
}

void RunParallelHost::OnHostEvent(HostEvent ev)
{
    NativeMethodHost::OnHostEvent(ev);
}

void RunParallelHost::OnRunnerReset(bool dtor)
{
    NativeMethodHost::OnRunnerReset(dtor);

    detachChildren();
}

NativeFunction *RunParallelHost::MakeNativeFunction(const char *name, int num_args)
{
#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "Native."

    if (self_thread)
    {
        TRY_USE_NATIVE_METHOD(RunParallelHost, notifyParentRunner, 2);
        TRY_USE_NATIVE_METHOD(RunParallelHost, quit, 1);

        TRY_USE_NATIVE_METHOD(RunParallelHost, registerParentRunnerCallback, 1);
    }
    else
    {
        TRY_USE_NATIVE_METHOD(RunParallelHost, loadBytecode, 1);
        TRY_USE_OBJECT_METHOD(LoadedBytecode, runBytecode, 4);

        TRY_USE_OBJECT_METHOD(FlowRunnerThreadRef, notifyChildRunner, 3);
    }

    return NULL;
}

StackSlot RunParallelHost::registerParentRunnerCallback(RUNNER_ARGS)
{
    RUNNER_PopArgs1(callback);

    message_cb = callback;

    RETVOID;
}

StackSlot RunParallelHost::loadBytecode(RUNNER_ARGS)
{
    RUNNER_PopArgs1(bcode_str);
    RUNNER_CheckTag1(TString, bcode_str);

    std::string bcode = encodeUtf8(RUNNER->GetString(bcode_str));

    LoadedBytecode *data = new LoadedBytecode(this, bcode);

	if (!data->load()) {
		delete data;
		return StackSlot::MakeVoid();
	}

    return RUNNER->AllocNative(data);
}

FlowRunnerThreadRef::FlowRunnerThreadRef(RunParallelHost *host, FlowRunnerThread *thread, const StackSlot &finish_cb, const StackSlot &message_cb)
    : FlowNativeObject(host->getFlowRunner()), host(host), thread(thread), finish_cb(finish_cb), message_cb(message_cb)
{
    host->callbacks[thread] = this;
}

void FlowRunnerThreadRef::flowGCObject(GarbageCollectorFn fn)
{
    fn << finish_cb << message_cb;
}

StackSlot FlowRunnerThreadRef::notifyChildRunner(RUNNER_ARGS)
{
    RUNNER_PopArgs2(ids, message);
    RUNNER_CheckTag2(TString, ids, message);

    if (thread)
    {
        unsigned len;
        const unicode_char *pids = RUNNER->GetStringPtrSize(ids, &len);
        QByteArray id((const char*)pids, len * sizeof(unicode_char));

        const unicode_char *pdata = RUNNER->GetStringPtrSize(message, &len);
        QByteArray data((const char*)pdata, len * sizeof(unicode_char));

        thread->parentMessage(id, data);
    }

    RETVOID;
}


StackSlot LoadedBytecode::runBytecode(RUNNER_ARGS)
{
    RUNNER_PopArgs3(url_str, callback, info_callback);
    RUNNER_CheckTag1(TString, url_str);

    QString url = unicode2qt(RUNNER->GetString(url_str));

    FlowRunnerThread *thread = new FlowRunnerThread(host);

    thread->setBytecode(bytecode);

    QUrl base(unicode2qt(RUNNER->getUrlString()));

    base.setQuery(QString());
    base.setFragment(QString());

    thread->setUrl(base.resolved(QUrl(url)));

    FlowRunnerThreadRef *ref = new FlowRunnerThreadRef(host, thread, callback, info_callback);

    host->connect(thread, SIGNAL(finished()), host, SLOT(threadFinished()));

    thread->start();

    return RUNNER->AllocNative(ref);
}

StackSlot RunParallelHost::notifyParentRunner(RUNNER_ARGS)
{
    RUNNER_PopArgs2(ids, message);
    RUNNER_CheckTag2(TString, ids, message);

    unsigned len;
    const unicode_char *pids = RUNNER->GetStringPtrSize(ids, &len);
    QByteArray id((const char*)pids, len * sizeof(unicode_char));

    const unicode_char *pdata = RUNNER->GetStringPtrSize(message, &len);
    QByteArray data((const char*)pdata, len * sizeof(unicode_char));

    QMetaObject::invokeMethod(self_thread, "childMessage", Qt::QueuedConnection, Q_ARG(QByteArray, id), Q_ARG(QByteArray, data));

    RETVOID;
}

StackSlot RunParallelHost::quit(RUNNER_ARGS)
{
    RUNNER_PopArgs1(rawcode);
    RUNNER_CheckTag(TInt, rawcode);

    self_thread->retcode = rawcode.GetInt();
    self_thread->quit();

    RETVOID;
}

void RunParallelHost::notifyChildMessage(FlowRunnerThread *thread, QByteArray id, QByteArray data)
{
    auto it = callbacks.find(thread);

    if (it != callbacks.end())
    {
        it->second->notifyChildMessage(id, data);
    }
}

void FlowRunnerThreadRef::notifyChildMessage(QByteArray id, QByteArray data)
{
    if (message_cb.IsVoid())
        return;

    RUNNER_VAR = getFlowRunner();
    RUNNER_DefSlotArray(cbargs, 3);

    cbargs[0] = message_cb;
    cbargs[1] = RUNNER->AllocateString((unicode_char*)id.data(), id.length()/sizeof(unicode_char));
    cbargs[2] = RUNNER->AllocateString((unicode_char*)data.data(), data.length()/sizeof(unicode_char));

    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    RUNNER->FastEvalFunction(cbargs, 2);

    RUNNER->NotifyHostEvent(NativeMethodHost::HostEventNetworkIO);
}

void RunParallelHost::threadFinished()
{
    FlowRunnerThread *thread = static_cast<FlowRunnerThread*>(QObject::sender());

    auto it = callbacks.find(thread);

    if (it != callbacks.end())
    {
        it->second->notifyFinish();

        callbacks.erase(thread);
    }

    thread->deleteLater();
}

void RunParallelHost::parentMessage(QByteArray id, QByteArray data)
{
    if (message_cb.IsVoid())
        return;

    RUNNER_VAR = getFlowRunner();
    RUNNER_DefSlotArray(cbargs, 3);

    cbargs[0] = message_cb;
    cbargs[1] = RUNNER->AllocateString((unicode_char*)id.data(), id.length()/sizeof(unicode_char));
    cbargs[2] = RUNNER->AllocateString((unicode_char*)data.data(), data.length()/sizeof(unicode_char));

    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    RUNNER->FastEvalFunction(cbargs, 2);

    RUNNER->NotifyHostEvent(NativeMethodHost::HostEventNetworkIO);
}

void FlowRunnerThreadRef::detach()
{
    finish_cb = message_cb = StackSlot::MakeVoid();
    thread = NULL;
}

void FlowRunnerThreadRef::notifyFinish()
{
    if (message_cb.IsVoid())
    {
        detach();
        return;
    }

    RUNNER_VAR = getFlowRunner();
    RUNNER_DefSlotArray(cbargs, 3);

    cbargs[0] = finish_cb;
    cbargs[1] = StackSlot::MakeInt(thread->error ? -1 : thread->retcode);
    cbargs[2] = RUNNER->AllocateString(parseUtf8(thread->output.str()));

    detach();

    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    RUNNER->FastEvalFunction(cbargs, 2);

    RUNNER->NotifyHostEvent(NativeMethodHost::HostEventNetworkIO);
}

