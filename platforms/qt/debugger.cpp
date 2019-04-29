#include "debugger.h"

#include "core/HeapWalker.h"

#include <stdio.h>

#ifndef WIN32
#include <sys/types.h>
#include <sys/socket.h>
#include <signal.h>
#ifndef _MSC_VER
#include <unistd.h>
#endif
#endif

#include <QFileInfo>

#include <fstream>
#include <sstream>

using std::max;
using std::min;
using std::cout;

GDBMIStreambuf::GDBMIStreambuf(QMutex &target_lock, ostream &target, std::string tag) :
    target_lock(target_lock), target(target), tag(tag), buffer(8*1024+2)
{
    // Leave 2 characters beyond the end
    setp(&buffer[0], &buffer[buffer.size()-2]);
}

GDBMIStreambuf::~GDBMIStreambuf()
{
    sync();
}

int GDBMIStreambuf::flushBuffer () {
    char *base = pbase();
    int num = pptr() - base, last_nl;

    // Nothing to do
    if (num <= 0) return 0;

    // Find last newline
    for (last_nl = num-1; last_nl >= 0 && base[last_nl] != '\n'; --last_nl);

    // If none, do a line break at the end
    if (last_nl < 0) last_nl = num;

    // Output the lines if there's anything to output
    if (last_nl > 0 || last_nl < num) {
        std::string line(base, min(last_nl+1,num));

        QMutexLocker lock(&target_lock);
        Q_UNUSED(lock);

        target << tag;
        printQuotedString(target, line);
        target << endl;
    }

    // Shift the remaining characters
    if (last_nl < num) {
        last_nl++;
        memmove(base, base + last_nl, num - last_nl);
    }

    pbump(-last_nl);

    return num;
}

int GDBMIStreambuf::overflow (int c) {
    if (c != EOF) {
        *pptr() = c;    // insert character into the buffer
        pbump(1);
    }
    if (flushBuffer() == EOF)
        return EOF;
    return c;
}

int GDBMIStreambuf::sync() {
    if (flushBuffer() == EOF)
        return -1;    // ERROR
    return 0;
}

QMutex Debugger::output_lock(QMutex::Recursive);
Debugger *Debugger::instance = NULL;

Debugger::Debugger(ByteCodeRunner *runner, bool gdbmi) :
    FlowDebuggerBase(runner),
    gdbmi(gdbmi),
    mibuf_flow(output_lock, std::cout, "@"),
    mibuf_debug(output_lock, std::cout, "~"),
    mibuf_log(output_lock, std::cout, "&"),
    debug_out(runner->flow_out.rdbuf()),
    log_out(runner->flow_out.rdbuf()),
    debugger_lock(QMutex::NonRecursive)
{
    instance = this;
    suspended = false;

    next_breakpoint_id = 1;
    next_var_id = 1;
    print_length = 20;
    print_depth = 2;
    call_depth_check = data_depth_check = 0;

    if (gdbmi)
    {
        runner->flow_out.rdbuf(&mibuf_flow);
        runner->flow_err.rdbuf(&mibuf_flow);
        debug_out.rdbuf(&mibuf_debug);
        log_out.rdbuf(&mibuf_log);
    }

    attachSigHandler();

    input_thread = new InputThread(this);
    input_thread->start();

    log_out << "Debugger initialized." << endl;
}

Debugger::~Debugger()
{
    if (instance == this)
        instance = NULL;
}

#ifdef WIN32
void Debugger::attachSigHandler()
{
    SetConsoleCtrlHandler(intSignalHandler, TRUE);
}

BOOL WINAPI Debugger::intSignalHandler(DWORD event)
{
    if (event != CTRL_C_EVENT)
        return FALSE;
    if (!instance)
        return FALSE;

    instance->SetAsyncInterrupt(true);
    QMetaObject::invokeMethod(instance, "handleAsyncInterrupt", Qt::QueuedConnection);
    return TRUE;
}
#else
void Debugger::attachSigHandler()
{
    if (::socketpair(AF_UNIX, SOCK_STREAM, 0, sigintFd))
        qFatal("Couldn't create INT socketpair");

    snInt = new QSocketNotifier(sigintFd[1], QSocketNotifier::Read, this);
    connect(snInt, SIGNAL(activated(int)), this, SLOT(handleSigInt()));

    struct sigaction intaction;

    intaction.sa_handler = intSignalHandler;
    sigemptyset(&intaction.sa_mask);
    intaction.sa_flags = 0;
    intaction.sa_flags |= SA_RESTART;

    sigaction(SIGINT, &intaction, 0);
}

void Debugger::intSignalHandler(int)
{
    if (!instance)
        return;

    instance->SetAsyncInterrupt(true);

    char a = 1;
    ::write(instance->sigintFd[0], &a, sizeof(a));
}
#endif

void Debugger::handleSigInt()
{
#ifdef WIN32
#else
    snInt->setEnabled(false);
    char tmp;
    ::read(sigintFd[1], &tmp, sizeof(tmp));
    snInt->setEnabled(true);
#endif

    handleAsyncInterrupt();
}

void Debugger::handleAsyncInterrupt()
{
    if (AsyncInterruptPending())
    {
        SetAsyncInterrupt(false);
        onAsyncInterrupt(GetLastInstruction());
    }
}

void Debugger::handleReloadBytecode()
{
    SetAsyncInterrupt(false);

    getFlowRunner()->ReloadBytecode();
    getFlowRunner()->RunMain();
}

void Debugger::onRunnerInit()
{
    FlowDebuggerBase::onRunnerInit();

    setCommand(CMD_NONE, MakeFlowPtr(0));

    breakpoint_id_table.clear();
    cur_list_file.clear();

    if (!insns().empty())
    {
        fname_table.clear();

        for (ExtendedDebugInfo::T_files::iterator it = DebugInfo()->files.begin();
             it != DebugInfo()->files.end(); ++it)
        {
            fname_table[it->first] = &it->second;
            fname_table[canonifyFilePath(it->first)] = &it->second;
        }

        for (T_breakpoint_table::iterator it = breakpoint_table.begin();
             it != breakpoint_table.end(); ++it)
            updateBreakpoint(it->second.addr);

        if (gdbmi) {
            QMutexLocker lock_out(&output_lock); Q_UNUSED(lock_out);

            cout << "=thread-group-added,id=\"i1\"" << endl;
            cout << "=thread-created,id=\"1\",group-id=\"i1\"" << endl;
        }

        runCommandLine(MakeFlowPtr(-1), "Program is loaded.");
    }
}

void Debugger::onRunnerReset()
{
    FlowDebuggerBase::onRunnerReset();

    fname_table.clear();
}

bool Debugger::setCommand(Command cmd, FlowPtr insn)
{
    this->cmd = cmd;
    wait_return = false;

    bool check_calls = (call_depth_check != 0 || data_depth_check != 0);

    switch (cmd) {
    case CMD_NONE:
        SetTraps(false, check_calls, false);
        break;

    case CMD_STEP:
        if (DebugInfo()->chunk_ranges.empty())
            return false;
        cur_line = getLine(insn);

    case CMD_STEPI:
        SetTraps(true, check_calls, false);
        break;

    case CMD_NEXT:
        if (DebugInfo()->chunk_ranges.empty())
            return false;
        cur_line = getLine(insn);

    case CMD_NEXTI:
        SetTraps(true, true, false);
        break;

    case CMD_FINISH:
        if (call_stack().size() == 0)
        {
            SetTraps(true, check_calls, false);
            return false;
        }

        wait_return = true;
        return_depth = call_stack().size()-1;
        SetTraps(false, check_calls, true);
        break;
    }

    return true;
}

void Debugger::updateBreakpoint(FlowPtr addr)
{
    int id = 0;

    for (T_breakpoint_table::iterator it = breakpoint_table.begin();
         it != breakpoint_table.end(); ++it)
    {
        if (it->second.addr == addr && it->second.enabled)
        {
            id = it->first;
            break;
        }
    }

    SetBreakpoint(addr, id != 0);
    if (id)
        breakpoint_id_table[addr] = id;
    else
        breakpoint_id_table.erase(addr);
}

void Debugger::onBreakpointTrap(FlowPtr insn) {
    std::string pfx = "Breakpoint ";

    if (breakpoint_id_table.count(insn))
        pfx += stl_sprintf("%d", breakpoint_id_table[insn]);
    else
        pfx += "?";

    runCommandLine(insn, pfx);
}

void Debugger::onInsnTrap(FlowPtr insn) {
    switch (cmd)
    {
    case CMD_STEP:
    case CMD_NEXT:
        if (getLine(insn) == cur_line)
            return;
        // don't stop on CReserveLocals
        if (skipReserveLocals(&insn))
            return;
        break;

    default:
        break;
    }

    runCommandLine(insn, "");
}

void Debugger::onCallTrap(FlowPtr insn, bool tail) {
    bool check_calls = (call_depth_check != 0 || data_depth_check != 0);

    if (check_calls)
    {
        if (call_depth_check && call_stack().size() >= call_depth_check)
        {
            runCommandLine(insn, "Call stack depth trap");
            return;
        }
        if (data_depth_check && data_stack().size() >= data_depth_check)
        {
            runCommandLine(insn, "Data stack depth trap");
            return;
        }
    }

    switch (cmd) {
    case CMD_NEXT:
    case CMD_NEXTI:
        if (tail)
            return;
        if (wait_return)
            break;
        wait_return = true;
        return_depth = call_stack().size();
        SetTraps(false, check_calls, true);
        return;

    default:
        break;
    }

    if (check_calls)
        return;

    runCommandLine(insn, "Unexpected call trap");
}

void Debugger::onReturnTrap(FlowPtr insn) {
    if (wait_return && call_stack().size() > return_depth)
        return;

    switch (cmd) {
    case CMD_NEXT:
    case CMD_NEXTI:
        if (!wait_return)
            break;
        SetTraps(true, true, false);
        wait_return = false;
        return;

    case CMD_FINISH:
        if (!wait_return)
            break;
        SetTraps(true, false, false);
        wait_return = false;
        return;

    default:
        break;
    }

    runCommandLine(insn, "Unexpected return trap");
}

void Debugger::onAsyncInterrupt(FlowPtr insn) {
    runCommandLine(insn, "Interrupt");
}

void Debugger::onError(RuntimeError /*err*/, FlowPtr insn) {
    runCommandLine(insn, "Error");
}

std::string Debugger::function_relative(FlowPtr addr)
{
    ExtendedDebugInfo::FunctionEntry *function = DebugInfo()->find_function(addr);
    return function_relative(function, addr);
}

std::string Debugger::function_relative(ExtendedDebugInfo::FunctionEntry *function, FlowPtr addr)
{
    if (function)
    {
        const std::string &name = function->name;
        int disp = addr - function->ranges.front();

        if (disp == 0)
            return "<" + name + ">";
        else if (!name.empty() && isdigit(name[name.size()-1]))
            return stl_sprintf("<%s +%d>", name.c_str(), disp);
        else
            return stl_sprintf("<%s+%d>", name.c_str(), disp);
    }
    else
        return "";
}

void Debugger::disassemble(const FlowInstruction::Pair &insn)
{
    ExtendedDebugInfo::FunctionEntry *function = DebugInfo()->find_function(insn.first);

    /* Basic disassembly */
    std::string func = function_relative(function, insn.first);

    debug_out << stl_sprintf("   0x%08x",FlowPtrToInt(insn.first));
    if (!func.empty())
        debug_out << " " << func;
    debug_out << ":\t";

    disassemble(debug_out, insn, function);

    /* End of line */
    debug_out << endl;
}

void Debugger::disassemble(ostream &out, const FlowInstruction::Pair &insn, ExtendedDebugInfo::FunctionEntry *function)
{
    out << insn.second;

    /* Additional debug info comment */
    std::string comment;

    switch (insn.second.shape)
    {
    case FlowInstruction::Ptr:
    case FlowInstruction::IntPtr:
        comment = function_relative(insn.second.PtrValue);
        break;
    default:
        break;
    }

    switch (insn.second.op)
    {
    case CStruct:
    {
        FlowInstruction *pdef = findStructDef(insn.second.IntValue);
        if (pdef)
            comment = pdef->StrValue;
        break;
    }

    case CGetGlobal:
        comment = safeVectorAt(global_names(), insn.second.IntValue);
        break;

    case CGetLocal:
    case CSetLocal:
        if (function)
        {
            ExtendedDebugInfo::LocalEntry *local = function->find_local(ExtendedDebugInfo::LOCAL_VAR, insn.second.IntValue);
            if (!local)
                local = function->find_local(ExtendedDebugInfo::LOCAL_ARG, insn.second.IntValue);
            if (local)
                comment = local->name;
        }
        break;

    case CGetFreeVar:
        if (function)
        {
            ExtendedDebugInfo::LocalEntry *local = function->find_local(ExtendedDebugInfo::LOCAL_UPVAR, insn.second.IntValue);
            if (local)
                comment = local->name;
        }
        break;

    default:
        break;
    }

    if (!comment.empty())
        out << "\t; " << comment;
}

ExtendedDebugInfo::LineEntry *Debugger::getLine(FlowPtr addr)
{
    ExtendedDebugInfo::ChunkEntry *chunk = DebugInfo()->find_chunk(addr);
    if (chunk)
        return chunk->line;
    else
        return NULL;
}

void Debugger::loadFile(const std::string &file)
{
    std::ifstream fs(file.c_str());

    T_file_lines &lines = file_table[file];

    for (int i = 0; fs.good(); i++)
    {
        std::string line;
        getline(fs, line);

        if (!line.empty() && line[line.size()-1] == '\r')
            line.resize(line.size()-1);

        lines.push_back(line);
    }
}

void Debugger::printLines(const std::string &file, int min_line, int max_line)
{
    if (!file_table.count(file))
        loadFile(file);

    T_file_lines &lines = file_table[file];

    if (min_line < 1)
        min_line = 1;
    if (lines.size() < unsigned(max_line))
        max_line = lines.size();

    for (int i = min_line; i <= max_line; i++)
        debug_out << i << "\t" << lines[i-1] << endl;
}

void Debugger::reportPosition(FlowPtr insn, const std::string &prefix)
{
    if (prefix.empty())
        debug_out << "In";
    else
        debug_out << prefix << " in";

    debug_out << " function " << DebugInfo()->getFunctionLocation(insn) << endl;

    reportCodeLine(insn);
}

void Debugger::reportCodeLine(FlowPtr insn)
{
    ExtendedDebugInfo::LineEntry *line = getLine(insn);
    if (line)
    {
        cur_list_file = line->file->name;
        cur_list_line = line->line_idx - 5;
        printLines(line->file->name, line->line_idx, line->line_idx);
    }

    if (insn == GetNativeReturnInstruction())
        debug_out << "   <native code>" << endl;
    else
    {
        FlowInstruction::Map::const_iterator it = insns().find(insn);
        if (it != insns().end())
            disassemble(*it);
        else
            debug_out << "   <INVALID INSTRUCTION POINTER>" << endl;
    }
}

void Debugger::printMIFrame(ostream &out, const FlowStackFrame &frame)
{
    out << "{level=\"" << frame.index
        << "\",addr=\"0x" << std::hex << FlowPtrToInt(frame.insn) << std::dec << "\"";

    if (frame.insn == GetNativeReturnInstruction())
        out << ",func=\"<native>\",args=[]";
    else
    {
        ExtendedDebugInfo::FunctionEntry *function = frame.function;

        if (function)
        {
            out << ",func=\"";
            if (frame.impersonate_function)
                out << "~" << frame.impersonate_function->name << " VIA ";
            out << function->name << "\",args=[";

            if (!function->locals.empty() &&
                frame.frame + function->num_args <= data_stack().size())
            {
                for (int i = 0; i < function->num_args; i++)
                {
                    ExtendedDebugInfo::LocalEntry *local = function->find_local(ExtendedDebugInfo::LOCAL_ARG, i);

                    if (i > 0) out << ",";
                    out << "{name=\"" << (local ? local->name : "?")
                        << "\", value=";

                    std::stringstream ss;
                    getFlowRunner()->PrintData(ss, data_stack()[frame.frame+i], 1, 3);
                    printQuotedString2(out, ss.str());

                    out << "}";
                }
            }

            out << "]";
        }
        else if (frame.special_id >= 0)
        {
            out << ",func=\"<special " << frame.special_id << ">\"";
        }

        ExtendedDebugInfo::ChunkEntry *chunk = frame.chunk;
        if (frame.impersonate_chunk)
            chunk = frame.impersonate_chunk;

        if (chunk)
        {
            out << ",file=";
            printQuotedString(out, chunk->line->file->name);
            out << ",fullname=";
            printQuotedString(out, canonifyFilePath(chunk->line->file->name));
            out << ",line=\"" << chunk->line->line_idx << "\"";
        }
    }

    out << "}";
}

std::string Debugger::printMIFrame(const FlowStackFrame &frame)
{
    std::stringstream ss;
    printMIFrame(ss, frame);
    return ss.str();
}

void Debugger::runCommandLine(FlowPtr insn, const std::string &reason)
{
    QMutexLocker lock(&debugger_lock); Q_UNUSED(lock);

    if (insn == MakeFlowPtr(-1))
    {
        stack_frames.clear();
        cur_stack_frame = -1;
    }
    else
    {
        getFlowRunner()->ParseCallStack(&stack_frames, call_stack(), insn, DebugInfo());
        cur_stack_frame = 0;
    }

    {
        QMutexLocker lock_out(&output_lock); Q_UNUSED(lock_out);

        if (cur_stack_frame >= 0)
            reportPosition(stack_frames[cur_stack_frame].insn, reason);
        else if (!reason.empty())
            debug_out << reason << std::endl;

        if (gdbmi)
        {
            if (cur_stack_frame >= 0)
            {
                cout << suspend_token << "*stopped,frame=";
                printMIFrame(cout, stack_frames[cur_stack_frame]);
                cout << ",stopped-threads=\"all\"" << endl;
            }

            cout << "(gdb)" << endl;
        }
    }

    SetAsyncInterrupt(false);
    setCommand(CMD_NONE, insn);

    suspend_insn = insn;
    suspend_reason = reason;

    suspended = true;
    suspend_cond.wakeAll();

    while (suspended)
        resume_cond.wait(&debugger_lock);
}

void Debugger::InputThread::run()
{
    setTerminationEnabled(false);

    // Always wait for suspend at start
    owner->waitSuspend();

    for (;;) {
        {
            QMutexLocker lock_out(&output_lock); Q_UNUSED(lock_out);

            if (owner->gdbmi)
                cout << "(gdb)" << endl;
            else
                printf("(fdb) ");

            fflush(stdout);
        }

        setTerminationEnabled(true);

        if (feof(stdin) || ferror(stdin))
            exit(0);

        char buf[65536];
#ifdef _MSC_VER
        gets_s(buf, 65536);
#else
        gets(buf);
#endif

        setTerminationEnabled(false);

        owner->handleCommand(buf);

        if (!owner->gdbmi)
            owner->waitSuspend();
    }
}

void Debugger::waitSuspend()
{
    QMutexLocker lock(&debugger_lock); Q_UNUSED(lock);

    while (!suspended)
        suspend_cond.wait(&debugger_lock);
}

void Debugger::handleCommand(std::string cur_cmdline)
{
    QMutexLocker lock(&debugger_lock); Q_UNUSED(lock);
    QMutexLocker lock_out(&output_lock); Q_UNUSED(lock_out);

    SetAsyncInterrupt(false);

    if (gdbmi) {
        size_t i = 0;
        while (i < cur_cmdline.size() && isdigit(cur_cmdline[i])) i++;
        cur_cmd_token = cur_cmdline.substr(0,i);
        cur_cmdline = cur_cmdline.substr(i);

        log_out << cur_cmdline << endl;
    }

    std::vector<std::string> tokens;
    tokenize_string(&tokens, cur_cmdline);

    if (tokens.empty())
    {
        if (gdbmi) {
            cout << cur_cmd_token << "^done" << endl;
            return;
        }

        cur_cmdline = last_cmd;
        tokenize_string(&tokens, cur_cmdline);
        if (tokens.empty())
            return;
    }

    bool resume = false;
    cur_cmd_ok = true;
    cur_cmd_result = "^done";

    std::string cmd = tokens[0];

    if (cmd == "-exec-interrupt")
    {
        if (!suspended)
        {
            SetAsyncInterrupt(true);
            QMetaObject::invokeMethod(this, "handleAsyncInterrupt", Qt::QueuedConnection);
        }
        else
            cmdError("The program is not running");
    }
    else if (cmd == "q" || cmd == "quit" || cmd == "-gdb-exit")
    {
        if (gdbmi)
            cout << cur_cmd_token << "^done" << endl;
        exit(0);
    }
    else if (cmd == "list")
    {
        command_list(tokens);
        cur_cmdline = "list";
    }
    else if (cmd == "help")
    {
        debug_out << "Supported commands:\n"
                     "  continue,c    - Continue program execution.\n"
                     "  step,s        - Step one line.\n"
                     "  next,n        - Step one line without entering functions.\n"
                     "  stepi,si      - Step one instruction.\n"
                     "  nexti,ni      - Step one instruction without entering functions.\n"
                     "  finish        - Finish executing the current stack frame.\n"
                     "  backtrace,bt  - Print backtrace.\n"
                     "  up,down       - Change current frame.\n"
                     "  break,b       - Add breakpoint.\n"
                     "  info break    - List breakpoints.\n"
                     "  info args     - List arguments of current frame.\n"
                     "  info locals   - List private locals of current frame.\n"
                     "  info upvalues - List closure variables of current frame.\n"
                     "  info vars     - List all of the locals.\n"
                     "  disable       - Disable breakpoints.\n"
                     "  enable        - Enable breakpoints.\n"
                     "  delete        - Delete breakpoints.\n"
                     "  print,p       - Print variable value.\n"
                     "  list          - List source code.\n"
                     "  quit,q        - Quit execution.\n"
                     "  force-full-gc - Immediately do a full gc.\n"
                     "  live-obj-info - Write statistics about memory usage to a file.\n"
                     "  set           - Set parameters.\n"
                     "  reload        - Reload bytecode and start over.\n"
#ifdef FLOW_INSTRUCTION_PROFILING
                     "  profile       - Start or stop profiling.\n"
#endif
                     "Settable parameters:\n"
                     "  print-length - array element number cutoff in 'print' output.\n"
                     "  print-depth  - structure nesting depth cutoff for 'print'\n"
                     "  call-stack-limit - when nonzero, breaks on call stack depth.\n"
                     "  data-stack-limit - when nonzero, breaks on data stack depth.\n"
                     "An empty line repeats the previous command." << endl;
    }
    else
    {
        FlowPtr insn = suspend_insn;

        if (!suspended)
        {
            cmdError("Program is not suspended");
        }
        else
        if (cmd == "c" || cmd == "continue" ||
            cmd == "r" || cmd == "run" ||
            cmd == "-exec-run" || cmd == "-exec-continue")
        {
            cur_cmd_result = "^running";
            setCommand(CMD_NONE, insn);
            resume = true;
        }
        else if (cmd == "s" || cmd == "step" || cmd == "-exec-step")
        {
            cur_cmd_result = "^running";
            bool ok = setCommand(CMD_STEP, insn);
            if (ok)
                resume = true;
            else
                cmdError("No line number information.");
        }
        else if (cmd == "si" || cmd == "stepi" || cmd == "-exec-step-instruction")
        {
            cur_cmd_result = "^running";
            setCommand(CMD_STEPI, insn);
            resume = true;
        }
        else if (cmd == "n" || cmd == "next" || cmd == "-exec-next")
        {
            cur_cmd_result = "^running";
            bool ok = setCommand(CMD_NEXT, insn);
            if (ok)
                resume = true;
            else
                cmdError("No line number information.");
        }
        else if (cmd == "ni" || cmd == "nexti" || cmd == "-exec-next-instruction")
        {
            cur_cmd_result = "^running";
            setCommand(CMD_NEXTI, insn);
            resume = true;
        }
        else if (cmd == "finish" || cmd == "-exec-finish")
        {
            cur_cmd_result = "^running";
            bool ok = setCommand(CMD_FINISH, insn);
            if (ok)
                resume = true;
            else
                cmdError("No stack.");
        }
        else if (cmd == "bt" || cmd == "backtrace")
        {
            for (size_t i = 0; i < stack_frames.size(); i++)
                getFlowRunner()->PrintCallStackLine(debug_out, stack_frames[i], true);
        }
        else if (cmd == "up" || cmd == "down")
        {
            int new_frame = cur_stack_frame + (cmd == "up" ? 1 : -1);
            if (unsigned(new_frame) >= stack_frames.size())
            {
                if (cmd == "up")
                    cmdError("Initial frame selected; you cannot go up.");
                else
                    cmdError("Bottom (innermost) frame selected; you cannot go down.");
            }
            else
            {
                cur_stack_frame = new_frame;
                getFlowRunner()->PrintCallStackLine(debug_out, stack_frames[cur_stack_frame], true);
                reportCodeLine(stack_frames[cur_stack_frame].insn);
            }
        }
        else if (cmd == "set")
            command_set(tokens);
        else if (cmd == "info")
            command_info(tokens);
        else if (cmd == "disable" || cmd == "-break-disable")
            command_disable(tokens);
        else if (cmd == "enable" || cmd == "-break-enable")
            command_enable(tokens);
        else if (cmd == "delete" || cmd == "-break-delete")
            command_delete(tokens);
        else if (cmd == "p" || cmd == "print" || cmd == "-data-evaluate-expression")
            command_print(tokens, insn);
        else if (cmd == "b" || cmd == "break" || cmd == "breakpoint" || cmd == "-break-insert")
            command_break(tokens, insn);
        else if (cmd == "-stack-list-frames" || cmd == "-stack-list-arguments")
            command_list_frames(tokens, insn);
        else if (cmd == "-thread-list-ids")
            cur_cmd_result = "^done,thread-ids={thread-id=\"1\"},current-thread-id=\"1\",number-of-threads=\"1\"";
        else if (cmd == "-data-disassemble")
            command_data_disasm(tokens, insn);
        else if (cmd == "-stack-select-frame")
        {
            if (tokens.size() < 2)
                cmdError("frame index required");
            else
            {
                unsigned idx = atoi(tokens[1].c_str());
                if (idx >= stack_frames.size())
                    cmdError("invalid frame index");
                else
                    cur_stack_frame = idx;
            }
        }
        else if (cmd == "-stack-info-frame" || cmd == "-thread-info" || cmd == "-thread-select")
        {
            if (cur_stack_frame < 0)
                cmdError("No stack.");
            else if (cmd == "-stack-info-frame")
                cur_cmd_result = "^done,frame=" + printMIFrame(stack_frames[cur_stack_frame]);
            else if (cmd == "-thread-info")
                cur_cmd_result = "^done,threads=[{id=\"1\",target-id=\"MAIN\",name=\"Flow\",frame="
                    + printMIFrame(stack_frames[0]) + ",state=\"stopped\"}],current-thread-id=\"1\"";
            else
                cur_cmd_result = "^done,new-thread-id=\"1\",frame=" + printMIFrame(stack_frames[0]);
        }
        else if (cmd == "-var-update")
            command_var_update(tokens);
        else if (cmd == "-var-create")
            command_var_create(tokens);
        else if (cmd == "-stack-list-locals")
            command_list_locals(tokens);
        else if (cmd == "-var-list-children")
            command_list_children(tokens);
        else if (cmd == "-var-show-attributes")
            command_var_show_attrs(tokens);
        else if (cmd == "-var-assign")
            command_var_assign(tokens);
        else if (cmd == "-var-delete")
        {
            if (tokens.size() < 2 || vars.count(tokens[1]) == 0)
                cmdError("No such variable");
            else
                vars.erase(tokens[1]);
        }
        else if (cmd == "-inferior-tty-set")
            command_tty_set(tokens);
        else if (cmd == "force-full-gc")
            getFlowRunner()->ForceGC(0, true);
        else if (cmd == "live-obj-info")
            command_live_objects(tokens);
        else if (cmd == "reload")
        {
            // remove breakpoints
            for (T_breakpoint_id_table::iterator it = breakpoint_id_table.begin();
                 it != breakpoint_id_table.end(); ++it)
                SetBreakpoint(it->first, false);

            breakpoint_id_table.clear();

            // queue reload
            QMetaObject::invokeMethod(this, "handleReloadBytecode", Qt::QueuedConnection);

            // continue
            cur_cmd_result = "^running";
            setCommand(CMD_NONE, insn);
            resume = true;
        }
#ifdef FLOW_INSTRUCTION_PROFILING
        else if (cmd == "profile")
            command_profile(tokens);
#endif
        else
            cmdError("Unsupported command.");
    }

    if (cur_cmd_ok)
        last_cmd = cur_cmdline;
    else
        cur_cmdline = last_cmd;

    if (gdbmi)
        cout << (cur_cmd_token + cur_cmd_result) << endl;

    if (resume)
    {
        SetAsyncInterrupt(false);

        if (gdbmi)
            cout << "*running,thread-id=\"all\"" << endl;

        suspend_token = cur_cmd_token;
        suspended = false;
        resume_cond.wakeAll();
    }
}

bool Debugger::cmdError(const std::string &str)
{
    cur_cmd_ok = false;
    log_out << str << endl;

    if (gdbmi)
    {
        std::stringstream ss;
        ss << "^error,msg=";
        printQuotedString(ss, str);
        cur_cmd_result = ss.str();
    }

    return false;
}

bool Debugger::command_set(std::vector<std::string> &tokens)
{
    if (tokens.size() < 3)
    {
        cmdError("\"set\" must be followed by a variable name and new value.");
        return false;
    }

    std::string cmd = tokens[1];

    if (cmd == "print-length")
        print_length = atoi(tokens[2].c_str());
    else if (cmd == "print-depth")
        print_depth = atoi(tokens[2].c_str());
    else if (cmd == "call-stack-limit")
        call_depth_check = atoi(tokens[2].c_str());
    else if (cmd == "data-stack-limit")
        data_depth_check = atoi(tokens[2].c_str());
    else
    {
        cmdError("Unknown option in set: '"+cmd+"'");
        return false;
    }

    return true;
}

bool Debugger::command_info(std::vector<std::string> &tokens)
{
    if (tokens.size() < 2)
    {
        cmdError("\"info\" must be followed by the name of an info command.");
        return false;
    }

    std::string cmd = tokens[1];

    if (cmd == "break" || cmd == "breakpoint")
    {
        if (breakpoint_table.empty())
        {
            debug_out << "No breakpoints or watchpoints." << endl;
            return true;
        }

        debug_out << "Num     Type           Disp Enb Address    What" << endl;

        T_breakpoint_table::const_iterator it = breakpoint_table.begin();
        for (; it != breakpoint_table.end(); ++it)
        {
            debug_out << stl_sprintf("%-7d %-14s %-4s %-3c 0x%08x in %s\n",
                                    it->second.id, "breakpoint", "keep",
                                    it->second.enabled ? 'y' : 'n',
                                    FlowPtrToInt(it->second.addr),
                                    DebugInfo()->getFunctionLocation(it->second.addr).c_str());
        }
    }
    else if (cmd == "args" || cmd == "locals" || cmd == "upvalues" || cmd == "vars")
    {
        int type = -1;
        if (cmd == "args")
            type = ExtendedDebugInfo::LOCAL_ARG;
        else if (cmd == "locals")
            type = ExtendedDebugInfo::LOCAL_VAR;
        else if (cmd == "upvalues")
            type = ExtendedDebugInfo::LOCAL_UPVAR;

        listLocals(debug_out, stack_frames[cur_stack_frame], type);
    }
    else
    {
        cmdError("Invalid info subcommand.");
        return false;
    }

    return true;
}

bool Debugger::skipReserveLocals(FlowPtr *ptr)
{
    FlowInstruction::Map::const_iterator it = insns().find(*ptr);
    if (it == insns().end() || it->second.op != CReserveLocals)
        return false;
    ++it;
    if (it != insns().end())
        *ptr = it->first;
    return true;
}

bool Debugger::command_break(std::vector<std::string> &tokens, FlowPtr insn)
{
    FlowPtr addr;

    if (tokens.size() < 2)
    {
        addr = insn;
    }
    else if (tokens[1].find(':') != std::string::npos)
    {
        int pos = tokens[1].rfind(':');
        std::string fname = tokens[1].substr(0,pos);
        int line = atoi(tokens[1].substr(pos+1).c_str());

        if (line <= 0)
        {
            cmdError("Invalid file:line spec: '" + tokens[1] + "'.");
            return false;
        }

        // Strip away quotes in the filename part to support "fname":line syntax.
        // This is not true C-string quoting - its only effect on gdb parser is to
        // protect spaces in the filename.
        if (!fname.empty() && fname[0] == '"')
            fname = fname.substr(1);
        if (!fname.empty() && fname[fname.size()-1] == '"')
            fname = fname.substr(0, fname.size()-1);

        ExtendedDebugInfo::FileEntry *file = safeMapAt(fname_table, canonifyFilePath(fname));
        if (!file)
        {
            cmdError("File '" + fname + "' not found.");
            return false;
        }

        ExtendedDebugInfo::T_lines::iterator itl = file->lines.lower_bound(line);
        if (itl == file->lines.end())
        {
            cmdError("No such line: '" + tokens[1]);
            return false;
        }

        addr = itl->second.chunks.begin()->second.ranges.front();
    }
    else
    {
        ExtendedDebugInfo::FunctionEntry *fun =  DebugInfo()->find_function(tokens[1]);
        if (!fun)
        {
            cmdError("Function '" + tokens[1] + "' not found.");
            return false;
        }

        addr = fun->ranges.front();
    }

    // Adjust the address to a valid instruction
    {
        FlowInstruction::Map::const_iterator it = mapFindLE(insns(), addr);
        if (it != insns().end())
            addr = it->first;
    }

    // don't put breakpoint on CReserveLocals
    skipReserveLocals(&addr);

    int id = next_breakpoint_id++;

    Breakpoint &bp = breakpoint_table[id];
    bp.id = id;
    bp.addr = addr;
    bp.enabled = true;

    if (breakpoint_id_table.count(addr))
    {
        debug_out << "Note: breakpoint " << breakpoint_id_table[addr]
                 << " also set at pc 0x" << std::hex << FlowPtrToInt(addr) << std::dec << "." << endl;
    }

    updateBreakpoint(addr);

    ExtendedDebugInfo::ChunkEntry *chunk = DebugInfo()->find_chunk(addr);

    debug_out << "Breakpoint " << id << " at 0x" << std::hex << FlowPtrToInt(addr) << std::dec;
    if (chunk)
        debug_out << ": file " << chunk->line->file->name << ", line " << chunk->line->line_idx;
    debug_out << endl;

    if (gdbmi) {
        ExtendedDebugInfo::FunctionEntry *func = DebugInfo()->find_function(addr);

        std::stringstream sstr;
        sstr << "bkpt={number=\"" << id << "\",type=\"breakpoint\",disp=\"keep\",enabled=\"y\","
             << "addr=\"0x" << std::hex << FlowPtrToInt(addr) << std::dec
             << "\",func=\"" << (func ? func->name : "?")
             << "\",file=";
        printQuotedString(sstr, chunk ? chunk->line->file->name : "?");
        sstr << ", fullname=";
        printQuotedString(sstr, chunk ? canonifyFilePath(chunk->line->file->name) : "?");
        sstr << ",line=\"" << (chunk ? chunk->line->line_idx : 0)
             << "\",times=\"0\",original-location=";
        printQuotedString(sstr, tokens[1]);
        sstr << "}" << endl;

        cout << "=breakpoint-created," << sstr.str() << endl;
        cur_cmd_result = "^done," + sstr.str();
    }

    return true;
}

void Debugger::command_switch_bp(std::vector<std::string> &tokens, int start, int mode)
{
    for (unsigned i = start; i < tokens.size(); i++)
    {
        int id = atoi(tokens[i].c_str());

        if (!breakpoint_table.count(id))
        {
            debug_out << "No breakpoint number " << id << "." << endl;
            continue;
        }

        FlowPtr addr = breakpoint_table[id].addr;

        switch (mode) {
        case 0:
            breakpoint_table[id].enabled = false;
            break;

        case 1:
            breakpoint_table[id].enabled = true;
            break;

        case 2:
            breakpoint_table.erase(id);
            break;
        }

        updateBreakpoint(addr);
    }
}

bool Debugger::command_disable(std::vector<std::string> &tokens)
{
    command_switch_bp(tokens, 1, 0);
    return true;
}

bool Debugger::command_enable(std::vector<std::string> &tokens)
{
    command_switch_bp(tokens, 1, 1);
    return true;
}

bool Debugger::command_delete(std::vector<std::string> &tokens)
{
    command_switch_bp(tokens, 1, 2);
    return true;
}

bool Debugger::command_list(std::vector<std::string> &tokens)
{
    if (tokens.size() >= 2)
    {
        if (tokens[1] == "-")
            cur_list_line -= 20;
        else
        {
            int line = atoi(tokens[1].c_str());

            if (line > 0)
                cur_list_line = line;
            else
            {
                ExtendedDebugInfo::FunctionEntry *fun =  DebugInfo()->find_function(tokens[1]);
                if (!fun)
                {
                    cmdError("Function '" + tokens[1] + "' not found.");
                    return false;
                }

                ExtendedDebugInfo::LineEntry *line = getLine(fun->ranges.front());
                if (!line)
                {
                    cmdError("Source line for function '" + tokens[1] + "' not known.");
                    return false;
                }

                cur_list_file = line->file->name;
                cur_list_line = line->line_idx;
            }

            cur_list_line -= 5;
        }
    }

    if (cur_list_file.empty())
    {
        cmdError("No current source file.");
        return false;
    }

    printLines(cur_list_file, cur_list_line, cur_list_line+9);
    cur_list_line += 10;

    return true;
}

bool Debugger::makeVarRef(Variable &rv, int frame, const std::string &name)
{
    if (unsigned(frame) >= stack_frames.size())
    {
        cmdError("Invalid stack frame.");
        return false;
    }

    FlowStackFrame &fframe = stack_frames[frame];

    ExtendedDebugInfo::LocalEntry *local = NULL;
    if (fframe.function)
        local = fframe.function->find_local(name);

    if (local)
    {
        rv.stack_place = fframe.stack_place;
        rv.function = fframe.function;
        rv.local = local;
        return true;
    }
    else
    {
        int gid = findGlobalByName(name);
        if (unsigned(gid) >= data_stack().size())
        {
            cmdError("Invalid global index.");
            return false;
        }

        rv.stack_place = gid;
        rv.function = NULL;
        rv.local = NULL;
        return true;
    }

    cmdError("Unknown variable: " + name);
    return false;
}

FlowVarReference Debugger::resolveVarRef(const Variable &var, bool silent)
{
    if (var.local)
    {
        FlowStackFrame *frame = NULL;

        for (size_t i = 0; i < stack_frames.size(); i++)
        {
            if (stack_frames[i].stack_place != var.stack_place ||
                stack_frames[i].function != var.function)
                continue;

            frame = &stack_frames[i];
        }

        if (!frame)
        {
            if (!silent)
                cmdError("Stack frame out of scope.");
            return NULL;
        }

        return resolveLocalRef(*frame, var.local, silent);
    }
    else
    {
        if (var.stack_place < data_stack().size())
            return &data_stack()[var.stack_place];

        if (!silent)
            cmdError("Invalid global index.");
        return NULL;
    }
}

FlowVarReference Debugger::resolveLocalRef(const FlowStackFrame &frame, ExtendedDebugInfo::LocalEntry *local, bool silent)
{
    switch (local->type)
    {
    case ExtendedDebugInfo::LOCAL_ARG:
    case ExtendedDebugInfo::LOCAL_VAR:
        {
            int gid = frame.frame + local->id;
            if (unsigned(gid) < data_stack().size())
                return &data_stack()[gid];

            if (!silent)
                cmdError("Invalid local index.");
            return NULL;
        }
        break;

    case ExtendedDebugInfo::LOCAL_UPVAR:
        {
            FlowPtr ptr = frame.closure + local->id*STACK_SLOT_SIZE;
            if (memory().IsValid(ptr, STACK_SLOT_SIZE))
                return &memory().GetStackSlot(ptr);

            if (!silent)
                cmdError("Invalid memory area.");
            return NULL;
        }
        break;
    }

    if (!silent)
        cmdError("Invalid local type.");
    return NULL;
}

void Debugger::listLocals(ostream &out, const FlowStackFrame &frame, int type)
{
    ExtendedDebugInfo::FunctionEntry *function = frame.function;

    if (!function || function->locals.empty())
        return;

    for (unsigned i = 0; i < function->locals.size(); i++)
    {
        ExtendedDebugInfo::LocalEntry &local = function->locals[i];
        if (type >= 0 && local.type != type)
            continue;

        out << local.name << " = " ;

        FlowVarReference slot = resolveLocalRef(frame, &local, true);
        if (slot)
            getFlowRunner()->PrintData(out, slot.get(), print_depth, print_length);
        else
            out << "<ERROR>";

        out << endl;
    }
}

bool Debugger::command_print(std::vector<std::string> &tokens, FlowPtr insn)
{
    if (tokens.size() < 2 || tokens[1].empty())
    {
        cmdError("Usage: print expr");
        return false;
    }

    std::string name = tokens[1];

    std::stringstream ss;

    if (name[0] == '$')
    {
        if (name == "$pc")
            ss << "0x" << std::hex << FlowPtrToInt(insn);
        else
        {
            cmdError("Unknown built-in variable: " + name);
            return false;
        }
    }
    else
    {
        Variable var;
        if (!makeVarRef(var, cur_stack_frame, name))
            return false;

        FlowVarReference pslot = resolveVarRef(var);
        if (!pslot)
            return false;

        getFlowRunner()->PrintData(ss, pslot.get(), print_depth, print_length);
    }

    debug_out << ss.str() << endl;

    if (gdbmi)
    {
        std::stringstream rv;
        rv << "^done,value=";
        printQuotedString2(rv, ss.str());
        cur_cmd_result = rv.str();
    }

    return true;
}

bool Debugger::command_list_frames(std::vector<std::string> &tokens, FlowPtr /*insn*/)
{
    bool is_list_args = (tokens[0] == "-stack-list-arguments");
    if (is_list_args && tokens.size() > 1)
        tokens.erase(tokens.begin()+1);

    unsigned first_frame = 0, last_frame = stack_frames.size()-1;

    if (last_frame > 1000)
        last_frame = 1000;

    if (tokens.size() >= 3) {
        first_frame = atoi(safeVectorAt(tokens, 1).c_str());
        last_frame = atoi(safeVectorAt(tokens, 2).c_str());
    }

    std::stringstream ss;

    for (unsigned i = first_frame; i < stack_frames.size() && i <= last_frame; i++)
    {
        if (i > first_frame) ss << ",";
        ss << "frame=";
        printMIFrame(ss, stack_frames[i]);
    }

    if (is_list_args)
        cur_cmd_result = "^done,stack-args=[" + ss.str() + "]";
    else
        cur_cmd_result = "^done,stack=[" + ss.str() + "]";
    return true;
}

class ChildLister : protected HeapWalker {
    bool in_child;

public:
    bool ok;
    std::vector<FlowVarReference> children;

    ChildLister(ByteCodeRunner *Runner) : HeapWalker(Runner), in_child(false), ok(false) {}

    ChildLister(ByteCodeRunner *Runner, FlowVarReference cur) : HeapWalker(Runner)
    {
        parse(cur);
    }

    int count() { return children.size(); }

    void parse(FlowVarReference cur)
    {
        in_child = ok = false;
        children.clear();
        if (cur)
        {
            StackSlot val = cur.get();
            Process(val);
        }
    }

protected:
    void VisitSlot(StackSlot &slot) {
        if (in_child)
            children.push_back(&slot);
        else
            ok = true;
    }

    void VisitSlotVector(StackSlot &val, StackSlot *data, int size) {
        HeapWalker::VisitSlotVector(val, data, size);

        if (!in_child)
        {
            for (int i = 0; i < size; i++)
                children.push_back(&data[i]);
        }
    }

    void VisitNativeObj(StackSlot &val, FlowNativeObject *obj) {
        HeapWalker::VisitNativeObj(val, obj);

        if (!in_child)
        {
            in_child = true;
            ProcessRefs(obj);
        }
    }

#ifdef FLOW_COMPACT_STRUCTS
    void VisitStruct(StackSlot &ref, FlowStructHeader *data, int size, StructDef *def)
    {
        HeapWalker::VisitStruct(ref, data, size, def);

        if (!in_child)
        {
            for (int i = 0; i < size; i++)
                children.push_back(FlowVarReference(getFlowRunner(), data, &def->FieldDefs[i]));
        }
    }
#endif
};


FlowVarReference Debugger::lookupVarByName(Variable **pvar, std::string name, bool silent)
{
    std::vector<std::string> nodes;
    split_string(&nodes, name, ".", false);

    if (!vars.count(nodes[0]))
    {
        if (!silent)
            cmdError("Unknown variable: " + nodes[0]);
        return NULL;
    }

    *pvar = &vars[nodes[0]];

    FlowVarReference pslot = resolveVarRef(**pvar, silent);
    if (!pslot)
        return NULL;

    for (size_t i = 1; i < nodes.size(); i++)
    {
        int idx = atoi(nodes[i].c_str());

        ChildLister walker(getFlowRunner(), pslot);

        if (idx < 0 || !walker.ok || idx >= walker.count())
        {
            if (!silent)
                cmdError("Invalid child path: " + name);
            return NULL;
        }

        pslot = walker.children[idx];
    }

    return pslot;
}

Debugger::Variable::Val Debugger::evaluateVar(FlowVarReference pslot, Variable *pvar, std::string key, std::vector<FlowVarReference> *pchildren)
{
    Variable::Val val;

    ChildLister walker(getFlowRunner(), pslot);

    val.numchild = walker.count();
    if (pchildren)
        pchildren->swap(walker.children);

    std::stringstream ss;
    getFlowRunner()->PrintData(ss, pslot.get(), 1, print_length);
    val.value = ss.str();

    pvar->values[key] = val;
    return val;
}

bool Debugger::command_var_create(std::vector<std::string> &tokens)
{
    if (tokens.size() < 4)
    {
        cmdError("Usage: -var-create name frame expr");
        return false;
    }

    std::string name = tokens[1];
    int frame = cur_stack_frame;
    if (tokens[2] != "*")
        frame = atoi(tokens[2].c_str());

    Variable var;
    if (!makeVarRef(var, frame, tokens[3]))
        return false;

    FlowVarReference pslot = resolveVarRef(var);
    if (!pslot)
        return false;

    if (name == "-")
        name = stl_sprintf("var%d", next_var_id++);

    if (vars.count(name))
    {
        cmdError("Duplicate variable name: " + name);
        return false;
    }

    vars[name] = var;

    Variable::Val val = evaluateVar(pslot, &vars[name], name);

    std::stringstream ss2;
    ss2 << "^done,name=";
    printQuotedString(ss2, name);
    ss2 << ",numchild=\"" << val.numchild
        << "\",type=\"var\",value=";
    printQuotedString2(ss2, val.value);

    cur_cmd_result = ss2.str();
    return true;
}

bool Debugger::command_list_children(std::vector<std::string> &tokens)
{
    if (tokens.size() < 2)
    {
        cmdError("Usage: -var-list-children name");
        return false;
    }

    if (tokens.size() == 3)
        tokens.erase(tokens.begin()+1);

    Variable *pvar;
    FlowVarReference pslot = lookupVarByName(&pvar, tokens[1]);
    if (!pslot)
        return false;

    std::vector<FlowVarReference> children;
    Variable::Val val = evaluateVar(pslot, pvar, tokens[1], &children);

    int ccnt = val.numchild;

    std::stringstream rv;
    rv << "^done,numchild=\"" << ccnt << "\",children=[";

    FlowInstruction *sdef = NULL;
    ExtendedDebugInfo::FunctionEntry *cfun = NULL;

    if (pslot.get().IsStruct())
        sdef = findStructDef(pslot.get().GetStructId());
    else if (pslot.get().IsClosurePointer())
        cfun = DebugInfo()->find_function(getFlowRunner()->GetCodePointer(pslot.get()));

    for (int i = 0; i < ccnt; i++)
    {
        StackSlot slot = children[i].get();

        std::string vkey = stl_sprintf("%s.%d", tokens[1].c_str(),i);
        Variable::Val val = evaluateVar(&slot, pvar, vkey);

        std::string vname;
        if (sdef)
            vname = sdef->fields[i].name;
        else if (pslot.get().IsRefTo())
            vname = "ref";
        else if (cfun)
        {
            ExtendedDebugInfo::LocalEntry *local = cfun->find_local(ExtendedDebugInfo::LOCAL_UPVAR, i);
            if (local)
                vname = local->name;
        }

        if (vname.empty())
            vname = stl_sprintf("%d",i);

        if (i > 0) rv << ",";
        rv << "child={name=";
        printQuotedString(rv, vkey);
        rv << ",exp=\"" << vname
           << "\",numchild=\"" << val.numchild
           << "\",value=";
        printQuotedString2(rv, val.value);
        rv << ",type=\"var\"}";
    }

    rv << "]";

    cur_cmd_result = rv.str();
    return false;
}

bool Debugger::command_var_show_attrs(std::vector<std::string> &tokens)
{
    if (tokens.size() < 2)
    {
        cmdError("Usage: -var-show-attributes name");
        return false;
    }

    Variable *pvar;
    FlowVarReference pslot = lookupVarByName(&pvar, tokens[1]);
    if (!pslot)
        return false;

    switch (pslot.get().GetType())
    {
    case TVoid:
        cur_cmd_result = "^done,attr=\"TBD\"";
        break;

    case TBool:
    case TDouble:
    case TInt:
    case TString:
        cur_cmd_result = "^done,attr=\"editable\"";
        break;

    default:
        cur_cmd_result = "^done,attr=\"noneditable\"";
        break;
    }

    return true;
}

bool Debugger::command_var_assign(std::vector<std::string> &tokens)
{
    if (tokens.size() != 3)
    {
        cmdError("Usage: -var-assign name value");
        return false;
    }

    Variable *pvar;
    FlowVarReference pslot = lookupVarByName(&pvar, tokens[1]);
    if (!pslot)
        return false;

    StackSlot slot = pslot.get();
    std::string value = tokens[2];

    switch (slot.GetType())
    {
    case TBool:
        if (value == "true")
            slot.SetBoolValue(true);
        else if (value == "false")
            slot.SetBoolValue(false);
        else
            return cmdError("Invalid boolean value");
        break;

    case TDouble:
        slot.SetDoubleValue(atof(value.c_str()));
        break;

    case TInt:
        slot.SetIntValue(atoi(value.c_str()));
        break;

    case TString:
        if (!value.empty() && value[0] == '"')
        {
            std::vector<std::string> out;
            tokenize_string(&out, value);
            if (out.size() != 1)
                return cmdError("Invalid quoted string");
            value = out[0];
        }
        slot = getFlowRunner()->AllocateString(parseUtf8(value));
        break;

    default:
        return cmdError("Cannot assign variable");
    }

    if (!pslot.set(slot))
        return cmdError("Cannot assign variable: type mismatch");

    Variable::Val val = evaluateVar(pslot, pvar, tokens[1]);

    std::stringstream ss;
    ss << "^done,value=";
    printQuotedString(ss, val.value);
    cur_cmd_result = ss.str();

    return true;
}

bool Debugger::command_var_update(std::vector<std::string> &tokens)
{
    if (tokens.size() < 2)
    {
        cmdError("Usage: -var-update name");
        return false;
    }

    if (tokens.size() == 3)
        tokens.erase(tokens.begin()+1);

    std::map<std::string,Variable>::iterator it = vars.begin(), iend = vars.end();

    if (tokens[1] != "*")
    {
        it = vars.find(tokens[1]);
        if (it == vars.end())
        {
            cmdError("No such var: " + tokens[1]);
            return false;
        }
        iend = it; ++iend;
    }

    std::stringstream rv;
    rv << "^done,changelist=[";

    int changes = 0;

    for (; it != iend; ++it)
    {
        std::map<std::string,Variable::Val>::iterator vit = it->second.values.begin(), vit2;

        while (vit != it->second.values.end())
        {
            Variable *pvar;
            FlowVarReference pslot = lookupVarByName(&pvar, vit->first, true);

            if (!pslot)
            {
                if (changes++) rv << ",";
                rv << "{name=";
                printQuotedString(rv, vit->first);
                rv << ",in_scope=\"false\"}";
                vit2 = vit; ++vit;
                it->second.values.erase(vit2);
                continue;
            }

            Variable::Val old = vit->second;
            Variable::Val val = evaluateVar(pslot, pvar, vit->first);

            if (val.numchild != old.numchild || val.value != old.value)
            {
                if (changes++) rv << ",";
                rv << "{name=";
                printQuotedString(rv, vit->first);
                rv << ",in_scope=\"true\",new_num_children=\"" << val.numchild
                   << "\",value=";
                printQuotedString2(rv, val.value);
                rv << "}";
            }

            ++vit;
        }
    }

    rv << "]";

    cur_cmd_result = rv.str();
    return true;
}

bool Debugger::command_list_locals(std::vector<std::string>& tokens)
{
    if (unsigned(cur_stack_frame) >= stack_frames.size())
    {
        cmdError("Invalid stack frame.");
        return false;
    }


    FlowStackFrame &fframe = stack_frames[cur_stack_frame];

    std::stringstream rv;
    rv << "^done,locals=[";

    if (fframe.function)
    {
    	size_t c = 0;
        for (size_t i = 0; i < fframe.function->locals.size(); i++)
        {
            if (fframe.function->locals[i].type == ExtendedDebugInfo::LOCAL_ARG)
                continue;

            if (c++ > 0) rv << ",";
            if ((tokens.size() < 2)) {
                rv << "name=";
                printQuotedString(rv, fframe.function->locals[i].name);
            } else if (tokens[1] == "--all-values") {
                ExtendedDebugInfo::LocalEntry& local = fframe.function->locals[i];
                std::string name = fframe.function->locals[i].name;
                rv << "{name=";
                printQuotedString(rv, local.name);
                rv << ",value=";
                FlowVarReference slot = resolveLocalRef(fframe, &local, true);
                std::stringstream val_ss;
                if (slot) getFlowRunner()->PrintData(val_ss, slot.get(), print_depth, print_length);
                else val_ss << "{}";
                printQuotedString(rv, val_ss.str());
                rv << "}";
            } else if (tokens[1] == "--simple-values") {
                // TODO: implement following GDB MI
                rv << "name=";
                printQuotedString(rv, fframe.function->locals[i].name);
            } else {
            	// The default behavior
            	rv << "name=";
                printQuotedString(rv, fframe.function->locals[i].name);
            }
        }
    }

    rv << "]";

    cur_cmd_result = rv.str();
    return true;
}

static FlowPtr eval_addr(std::string str, FlowPtr insn)
{
    FlowPtr addr = MakeFlowPtr(0);
    bool neg = false;

    if (str.substr(0,3) == "$pc")
    {
        addr = insn;
        str = str.substr(3);
    }

    if (str.substr(0,1) == "+")
        str = str.substr(1);
    else if (str.substr(0,1) == "-")
    {
        neg = true;
        str = str.substr(1);
    }

    int delta = 0;
    if (str.substr(0,2) == "0x")
        delta = strtol(str.c_str()+2, NULL, 16);
    else if (!str.empty())
        delta = strtol(str.c_str(), NULL, 10);
    addr += (neg ? -delta : delta);

    return addr;
}

bool Debugger::command_data_disasm(std::vector<std::string> &tokens, FlowPtr insn)
{
    if (tokens.size() < 2 ||
        tokens[1] != "-s" || tokens[3] != "-e" || tokens[5] != "--")
    {
        cmdError("Usage: -data-disassemble -s start -e end -- 01");
        return false;
    }

    FlowPtr start = eval_addr(tokens[2], insn);
    FlowPtr end = eval_addr(tokens[4], insn);
    int source = atoi(tokens[6].c_str());

    std::stringstream rv;
    rv << "^done,asm_insns=[";

    int line_idx = 0, idx = 0;
    ExtendedDebugInfo::LineEntry *line = NULL, *cline;

    FlowInstruction::Map::const_iterator it = insns().lower_bound(start), it2 = insns().upper_bound(end);
    for (;it != it2; ++it)
    {
        ExtendedDebugInfo::FunctionEntry *function = DebugInfo()->find_function(it->first);

        if (source)
        {
            cline = getLine(it->first);

            if (cline != line || !line_idx)
            {
                if (line_idx++) rv << "]},";
                rv << "src_and_asm_line={line=\"" << (cline ? cline->line_idx : 0) << "\",file=";
                printQuotedString(rv, cline ? canonifyFilePath(cline->file->name) : "?");
                rv << ",line_asm_insn=[";
                idx = 0;
            }

            line = cline;
        }

        if (idx++) rv << ",";

        rv << "{address=\"0x" << std::hex << FlowPtrToInt(it->first) << std::dec << "\"";
        if (function)
        {
            rv << ",func-name=";
            printQuotedString(rv, function->name);
            rv << ",offset=\"" << (it->first - function->ranges.front()) << "\"";
        }
        rv << ",inst=";

        std::stringstream ss;
        disassemble(ss, *it, function);
        printQuotedString(rv, ss.str());
        rv << "}";
    }

    if (source)
        rv << "]}";
    rv << "]";

    cur_cmd_result = rv.str();
    return true;
}

bool Debugger::command_tty_set(std::vector<std::string> &tokens)
{
    if (tokens.size() != 2)
    {
        cmdError("Usage: -inferior-tty-set <file>");
        return false;
    }

    if (tty_out.is_open())
        tty_out.close();

    tty_out.open(tokens[1].c_str(), std::fstream::out);

    if (tty_out.fail())
    {
        getFlowRunner()->flow_out.rdbuf(&mibuf_flow);
        getFlowRunner()->flow_err.rdbuf(&mibuf_flow);

        cmdError("Could not open file: " + tokens[1]);
        return false;
    }
    else
    {
        getFlowRunner()->flow_out.rdbuf(tty_out.rdbuf());
        getFlowRunner()->flow_err.rdbuf(tty_out.rdbuf());
    }

    return true;
}

static void write_live_info(ostream &out, std::string name, StatisticsHeapWalker &walker, ExtendedDebugInfo *dbg)
{
    int str_bytes = walker.GetStringBytes();
    int slot_bytes = walker.GetSlotBytes();

    if (str_bytes + slot_bytes < 500)
        return;

    out << stl_sprintf("%s\t%d\t\%d\t%d\t%d\n", name.c_str(), str_bytes + slot_bytes, str_bytes, slot_bytes, walker.NumClosureSlots*STACK_SLOT_SIZE);

    for (size_t i = 0; i < walker.GetStructBytes().size(); i++)
    {
        int bv = walker.GetStructBytes()[i];
        if (bv < 5000) continue;
        out << stl_sprintf("\t%s\t%d\n", walker.getFlowRunner()->GetStructDef(i).Name.c_str(), bv);
    }

    for (std::map<int,int>::const_iterator it = walker.GetClosureBytes().begin();
         it != walker.GetClosureBytes().end(); ++it)
    {
        if (it->second < 5000) continue;
        ExtendedDebugInfo::FunctionEntry *fun = dbg->find_function(MakeFlowPtr(it->first));
        if (fun)
            out << stl_sprintf("\t%s\t%d\n", fun->name.c_str(), it->second);
    }
}

bool Debugger::command_live_objects(std::vector<std::string> &tokens)
{
    if (tokens.size() > 2)
    {
        cmdError("Usage: live-obj-info [file]");
        return false;
    }

    std::ofstream fs;
    std::ostream *pstream = &debug_out;

    if (tokens.size() > 1)
    {
        fs.open(tokens[1].c_str());

        if (fs.fail())
        {
            cmdError("Could not open file.");
            return false;
        }

        pstream = &fs;
    }

    {
        StatisticsHeapWalker walker(getFlowRunner());
        walker.ProcessNativeRoots();
        write_live_info(*pstream, "<NATIVE>", walker, DebugInfo());
    }

    {
        StatisticsHeapWalker walker(getFlowRunner());
        walker.ProcessStackRoots();
        write_live_info(*pstream, "<STACK>", walker, DebugInfo());
    }

    size_t ssize = min(global_names().size(), (size_t)data_stack().size());

    for (size_t i = 0; i < ssize; i++)
    {
        StatisticsHeapWalker walker(getFlowRunner());
        walker.Process(data_stack()[i]);
        write_live_info(*pstream, global_names()[i], walker, DebugInfo());
    }

    return true;
}

#ifdef FLOW_INSTRUCTION_PROFILING
bool Debugger::command_profile(std::vector<std::string> &tokens)
{
    if (tokens.size() < 2)
    {
        cmdError("Usage: profile code|mem|off [step] [filename]");
        return false;
    }

    getFlowRunner()->StopProfiling();

    int step = (tokens.size() >= 3) ? atoi(tokens[2].c_str()) : 1000;
    const char *fn = (tokens.size() >= 4) ? tokens[3].c_str() : NULL;

    if (step <= 0)
    {
        cmdError("Usage: profile code|mem|off [step] [filename]");
        return false;
    }

    if (tokens[1] == "off")
        return true;
    else if (tokens[1] == "code")
        getFlowRunner()->BeginInstructionProfile(fn ? fn : "flowprof.ins", step);
    else if (tokens[1] == "mem")
        getFlowRunner()->BeginMemoryProfile(fn ? fn : "flowprof.mem", step);
    else
    {
        cmdError("Invalid profiling type, valid: code|mem|off");
        return false;
    }

    return true;
}
#endif

std::string Debugger::canonifyFilePath(const std::string &name)
{
    QFileInfo info(unicode2qt(parseUtf8(name)));

    QString path = info.canonicalFilePath();
    if (path.isEmpty() || path.isNull())
        path = info.absoluteFilePath();

#ifdef WIN32
    path = path.toLower();
#endif

    if (path.isEmpty() || path.isNull())
        return name;
    else
        return encodeUtf8(qt2unicode(path));
}
