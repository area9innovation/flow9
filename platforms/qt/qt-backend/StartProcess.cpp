#include "StartProcess.h"
#include "core/RunnerMacros.h"

#include <QProcess>
#include <QCoreApplication>
#include <QDir>

#include <sstream>

using std::endl;
using std::stringstream;

StartProcess::StartProcess(ByteCodeRunner *Runner) : NativeMethodHost(Runner), owner(Runner)
{

}

StartProcess::~StartProcess()
{
    process_set.clear();
}

void StartProcess::flowGCObject(GarbageCollectorFn gc)
{
    for (T_process_set::iterator it = process_set.begin(); it != process_set.end(); it++) {
        gc << it->second;
    }
}

void StartProcess::OnRunnerReset(bool inDestructor)
{
    NativeMethodHost::OnRunnerReset(inDestructor);

    process_set.clear();
}

NativeFunction *StartProcess::MakeNativeFunction(const char *name, int num_args)
{
    #undef NATIVE_NAME_PREFIX
    #define NATIVE_NAME_PREFIX "Native."
	TRY_USE_NATIVE_METHOD(StartProcess, execSystemProcess, 5);
    TRY_USE_NATIVE_METHOD(StartProcess, startProcess, 5);
    TRY_USE_NATIVE_METHOD(StartProcess, runSystemProcess, 6);
    TRY_USE_NATIVE_METHOD(StartProcess, writeProcessStdin, 2);
    TRY_USE_NATIVE_METHOD(StartProcess, killProcess, 1);
    TRY_USE_NATIVE_METHOD(StartProcess, startDetachedProcess, 3);
    TRY_USE_NATIVE_METHOD(StartProcess, getApplicationPath, 0);
    TRY_USE_NATIVE_METHOD(StartProcess, getApplicationArguments, 0);
    TRY_USE_NATIVE_METHOD(StartProcess, setCurrentDirectory, 1)
    TRY_USE_NATIVE_METHOD(StartProcess, getCurrentDirectory, 0)
    return NULL;
}

// native execSystemProcess : io (
//	command : string, 
//	args : [string], 
//	currentWorkingDirectory : string, 
//	onStdOutLine : (out : string) -> void, 
//	onStdErr : (error : string) -> void
//) -> int = Native.execSystemProcess;

StackSlot StartProcess::execSystemProcess(RUNNER_ARGS)
{
    RUNNER_PopArgs5(command_str, args_str, cwd_str, onstdout, onstderr);
    RUNNER_CheckTag2(TString, command_str, cwd_str);
    RUNNER_CheckTag(TArray, args_str);

    // Extract args in case an error occurs
    QStringList args;
    int nargs = RUNNER->GetArraySize(args_str);

    for (int i = 0; i != nargs; i++) {
      const StackSlot &item = RUNNER->GetArraySlot(args_str, i);
      RUNNER_CheckTag(TString, item);
      args.append(QString::fromUtf16(RUNNER->GetStringPtr(item), RUNNER->GetStringSize(item)));
    }

    // Allocate the process
    FlowProcess *p = new FlowProcess(this);

    p->controlled_process = true;
    p->out_pos = p->stdout_pos = p->stderr_pos = 0;
    p->stdout_cb = onstdout;
    p->stderr_cb = onstderr;
    p->exit_cb = FLOWVOID;

    process_set[p->process] = p;

    QString cwd = RUNNER->GetQString(cwd_str);
    if (!cwd.isEmpty())
        p->process->setWorkingDirectory(cwd);

    connect(p->process, SIGNAL(started()), SLOT(processReadyWrite()));

    connect(p->process, SIGNAL(bytesWritten(qint64)), SLOT(processReadyWrite()));
    connect(p->process, SIGNAL(readyReadStandardOutput()), SLOT(processReadyStdout()));
    connect(p->process, SIGNAL(readyReadStandardError()), SLOT(processReadyStderr()));

    connect(p->process, SIGNAL(finished(int,QProcess::ExitStatus)), SLOT(processFinished(int,QProcess::ExitStatus)));
    connect(p->process, SIGNAL(error(QProcess::ProcessError)), SLOT(processFailed(QProcess::ProcessError)));

    p->process->start(RUNNER->GetQString(command_str), args);
	p->process->waitForFinished(-1);

    return StackSlot::MakeInt(p->process->exitCode());
}

// 	native startProcess : io (command : string, args : [string],
//                  currentWorkingDirectory : string, stdin : string,
//                  onExit : (errorcode : int, stdout : string, stderr : string) -> void) -> void = Native.startProcess;
StackSlot StartProcess::startProcess(RUNNER_ARGS)
{
    RUNNER_PopArgs5(command_str, args_str, cwd_str, stdin_str, onexit);
    RUNNER_CheckTag3(TString, command_str, cwd_str, stdin_str);
    RUNNER_CheckTag(TArray, args_str);

    // Extract args in case an error occurs
    QStringList args;
    int nargs = RUNNER->GetArraySize(args_str);

    for (int i = 0; i != nargs; i++) {
      const StackSlot &item = RUNNER->GetArraySlot(args_str, i);
      RUNNER_CheckTag(TString, item);
      args.append(QString::fromUtf16(RUNNER->GetStringPtr(item), RUNNER->GetStringSize(item)));
    }

    // Allocate the process
    FlowProcess *p = new FlowProcess(this);

    p->controlled_process = false;
    p->out_pos = p->stdout_pos = p->stderr_pos = 0;
    p->out_buffer = encodeUtf8(RUNNER->GetString(stdin_str));
    p->exit_cb = onexit;

    process_set[p->process] = p;

    QString cwd = RUNNER->GetQString(cwd_str);
    if (!cwd.isEmpty())
        p->process->setWorkingDirectory(cwd);

    connect(p->process, SIGNAL(started()), SLOT(processReadyWrite()));

    connect(p->process, SIGNAL(bytesWritten(qint64)), SLOT(processReadyWrite()));
    connect(p->process, SIGNAL(readyReadStandardOutput()), SLOT(processReadyStdout()));
    connect(p->process, SIGNAL(readyReadStandardError()), SLOT(processReadyStderr()));

    connect(p->process, SIGNAL(finished(int,QProcess::ExitStatus)), SLOT(processFinished(int,QProcess::ExitStatus)));
    connect(p->process, SIGNAL(error(QProcess::ProcessError)), SLOT(processFailed(QProcess::ProcessError)));

    p->process->start(RUNNER->GetQString(command_str), args);

    RETVOID;
}

StackSlot StartProcess::runSystemProcess(RUNNER_ARGS)
{
    RUNNER_PopArgs6(command_str, args_str, cwd_str, onstdout, onstderr, onexit);
    RUNNER_CheckTag2(TString, command_str, cwd_str);
    RUNNER_CheckTag(TArray, args_str);

    // Extract args in case an error occurs
    QStringList args;
    int nargs = RUNNER->GetArraySize(args_str);

    for (int i = 0; i != nargs; i++) {
      const StackSlot &item = RUNNER->GetArraySlot(args_str, i);
      RUNNER_CheckTag(TString, item);
      args.append(QString::fromUtf16(RUNNER->GetStringPtr(item), RUNNER->GetStringSize(item)));
    }

    // Allocate the process
    FlowProcess *p = new FlowProcess(this);

    p->controlled_process = true;
    p->out_pos = p->stdout_pos = p->stderr_pos = 0;
    p->exit_cb = onexit;
    p->stdout_cb = onstdout;
    p->stderr_cb = onstderr;

    process_set[p->process] = p;

    QString cwd = RUNNER->GetQString(cwd_str);
    if (!cwd.isEmpty())
        p->process->setWorkingDirectory(cwd);

    connect(p->process, SIGNAL(started()), SLOT(processReadyWrite()));

    connect(p->process, SIGNAL(bytesWritten(qint64)), SLOT(processReadyWrite()));
    connect(p->process, SIGNAL(readyReadStandardOutput()), SLOT(processReadyStdout()));
    connect(p->process, SIGNAL(readyReadStandardError()), SLOT(processReadyStderr()));

    connect(p->process, SIGNAL(finished(int,QProcess::ExitStatus)), SLOT(processFinished(int,QProcess::ExitStatus)));
    connect(p->process, SIGNAL(error(QProcess::ProcessError)), SLOT(processFailed(QProcess::ProcessError)));

    p->process->start(RUNNER->GetQString(command_str), args);

    return RUNNER->AllocNative(p);
}

StackSlot StartProcess::writeProcessStdin(RUNNER_ARGS)
{
    RUNNER_PopArgs2(process, stdin_str);
    RUNNER_CheckTag1(TNative, process);
    RUNNER_CheckTag1(TString, stdin_str);

    FlowProcess *p = (FlowProcess*)RUNNER->GetNative<FlowProcess*>(process);

    if (p != NULL)
    {
        p->out_buffer += encodeUtf8(RUNNER->GetString(stdin_str));

        if (p->process->bytesToWrite() == 0) {
            qint64 sz = p->process->write(p->out_buffer.data() + p->out_pos, p->out_buffer.size() - p->out_pos);
            if (sz < 0)
                RETVOID;

            p->out_pos += (size_t)sz;
        }
    }

    RETVOID;
}

StackSlot StartProcess::killProcess(RUNNER_ARGS)
{
    RUNNER_PopArgs1(process);
    RUNNER_CheckTag1(TNative, process);

    FlowProcess *p = (FlowProcess*)RUNNER->GetNative<FlowProcess*>(process);

    if (p != NULL)
    {
        p->process->kill();

        endProcess(p, -100);
    }

    RETVOID;
}

StackSlot StartProcess::startDetachedProcess(RUNNER_ARGS)
{
    RUNNER_PopArgs3(command_str, args_str, cwd_str);
    RUNNER_CheckTag2(TString, command_str, cwd_str);
    RUNNER_CheckTag(TArray, args_str);

    QString cmd = RUNNER->GetQString(command_str);
    QString cwd = RUNNER->GetQString(cwd_str);

    // Extract args in case an error occurs
    QStringList args;
    int nargs = RUNNER->GetArraySize(args_str);

    for (int i = 0; i != nargs; i++) {
      const StackSlot &item = RUNNER->GetArraySlot(args_str, i);
      RUNNER_CheckTag(TString, item);
      args.append(QString::fromUtf16(RUNNER->GetStringPtr(item), RUNNER->GetStringSize(item)));
    }

    bool isOK = QProcess::startDetached(cmd, args, cwd);

    return StackSlot::MakeBool(isOK);
}

void StartProcess::processReadyWrite()
{
    FlowProcess *p = safeMapAt(process_set, (QProcess*)QObject::sender());

    if (p == NULL || p->process->state() != QProcess::Running)
        return;

    if (p->out_buffer.size() <= p->out_pos)
        return;

    qint64 sz = p->process->write(p->out_buffer.data() + p->out_pos, p->out_buffer.size() - p->out_pos);
    if (sz < 0)
        return;

    p->out_pos += (size_t)sz;
}

void StartProcess::processReadyStdout()
{
    FlowProcess *p = safeMapAt(process_set, (QProcess*)QObject::sender());

    if (p != NULL)
        provideStdout(p);
}

void StartProcess::provideStdout(FlowProcess *p)
{
    // check whether stdout changed
    QByteArray stdout_str = p->process->readAllStandardOutput();
    if (stdout_str.size() != 0)
    {
        p->stdout_buf.append(stdout_str);

        if (p->controlled_process)
        {
            if (size_t(p->stdout_buf.size()) <= p->stdout_pos)
                return;

            RUNNER_VAR = getFlowRunner();
            WITH_RUNNER_LOCK_DEFERRED(RUNNER);

            StackSlot stdout_str = RUNNER->AllocateString(parseUtf8(p->stdout_buf.data() + p->stdout_pos, p->stdout_buf.size() - p->stdout_pos));
            RUNNER->EvalFunction(p->stdout_cb, 1, stdout_str);

            p->stdout_pos = p->stdout_buf.size();
        }
    }
}

void StartProcess::provideStderr(FlowProcess *p)
{
    QByteArray stderr_str = p->process->readAllStandardError();
    if (stderr_str.size() != 0)
    {
        p->stderr_buf.append(stderr_str);

        if (p->controlled_process)
        {
            if (size_t(p->stderr_buf.size()) <= p->stderr_pos)
                return;
            RUNNER_VAR = getFlowRunner();
            WITH_RUNNER_LOCK_DEFERRED(RUNNER);

            StackSlot stderr_str = RUNNER->AllocateString(parseUtf8(p->stderr_buf.data() + p->stderr_pos, p->stderr_buf.size() - p->stderr_pos));
            RUNNER->EvalFunction(p->stderr_cb, 1, stderr_str);

            p->stderr_pos = p->stderr_buf.size();
        }
    }
}

void StartProcess::processReadyStderr()
{
    FlowProcess *p = safeMapAt(process_set, (QProcess*)QObject::sender());

    if (p != NULL)
    {
        provideStderr(p);
    }
}

void StartProcess::processFinished(int code, QProcess::ExitStatus status)
{
    FlowProcess *p = safeMapAt(process_set, (QProcess*)QObject::sender());

    if (p != NULL)
        endProcess(p, status == QProcess::NormalExit ? code : -100);
}

void StartProcess::processFailed(QProcess::ProcessError)
{
    FlowProcess *p = safeMapAt(process_set, (QProcess*)QObject::sender());

    if (p != NULL)
        endProcess(p, -200);
}

void StartProcess::endProcess(FlowProcess *p, int code)
{
    RUNNER_VAR = getFlowRunner();

    if (p->out_pos >= p->out_buffer.size())
        p->process->closeWriteChannel();

    if (p->controlled_process)
    {
        provideStdout(p);
        provideStderr(p);

        WITH_RUNNER_LOCK_DEFERRED(RUNNER);

        if (p->exit_cb.GetType() != TVoid) {
            RUNNER->EvalFunction(p->exit_cb, 1, StackSlot::MakeInt(code));
        }
    } else {
        p->stdout_buf.append(p->process->readAllStandardOutput());
        p->stderr_buf.append(p->process->readAllStandardError());

        RUNNER->EvalFunction(p->exit_cb, 3,
                             StackSlot::MakeInt(code),
                             RUNNER->AllocateString(parseUtf8(p->stdout_buf.data(), p->stdout_buf.size())),
                             RUNNER->AllocateString(parseUtf8(p->stderr_buf.data(), p->stderr_buf.size())));

        process_set.erase(p->process);
        RUNNER->DeleteNative(p);
    }

    RUNNER->NotifyHostEvent(HostEventNetworkIO);
}

IMPLEMENT_FLOW_NATIVE_OBJECT(StartProcess::FlowProcess, FlowNativeObject)

StartProcess::FlowProcess::FlowProcess(StartProcess *owner) : FlowNativeObject(owner->getFlowRunner())
{
    process = new QProcess(owner);
}

bool StartProcess::FlowProcess::flowDestroyObject() {
    process->deleteLater();
    return true;
}

void StartProcess::FlowProcess::flowGCObject(GarbageCollectorFn gc)
{
    gc << exit_cb << stdout_cb << stderr_cb;
}

StackSlot StartProcess::getApplicationPath(RUNNER_ARGS) {
    IGNORE_RUNNER_ARGS;
    return RUNNER->AllocateString(QCoreApplication::applicationFilePath());
}

StackSlot StartProcess::getApplicationArguments(RUNNER_ARGS) {
    IGNORE_RUNNER_ARGS;

    QStringList args = QCoreApplication::arguments().mid(3);

    RUNNER_DefSlots1(array);
    array = RUNNER->AllocateArray(args.size());
    for (QStringList::iterator it = args.begin(); it != args.end(); ++it) {
        RUNNER_DefSlots1(value);
        value = RUNNER->AllocateString(qt2unicode(*it));

        RUNNER->SetArraySlot(array, it - args.begin(), value);
    }

    return array;
}

StackSlot StartProcess::setCurrentDirectory(RUNNER_ARGS)
{
    RUNNER_PopArgs1(_path);
    RUNNER_CheckTag1(TString, _path);

    QString path = unicode2qt(RUNNER->GetString(_path));
    QDir::setCurrent(path);

    RETVOID;
}

StackSlot StartProcess::getCurrentDirectory(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;

    QString path = QDir::currentPath();

    return RUNNER->AllocateString(path);
}
