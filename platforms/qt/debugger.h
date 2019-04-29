#ifndef DEBUGGER_H
#define DEBUGGER_H

#include "core/ByteCodeRunner.h"

#ifdef WIN32
#include <windows.h>
#else
#include <QSocketNotifier>
#endif

#include <fstream>

#include <QMutex>
#include <QWaitCondition>

class GDBMIStreambuf : public std::streambuf
{
protected:
    QMutex &target_lock;
    ostream &target;
    std::string tag;
    std::vector<char> buffer;

public:
    GDBMIStreambuf(QMutex &target_lock, ostream &target, std::string tag);
    virtual ~GDBMIStreambuf();

protected:
    int flushBuffer ();
    virtual int overflow(int c = EOF);
    virtual int sync();
};

struct FlowVarReference;

class Debugger : public QObject, public FlowDebuggerBase
{
    Q_OBJECT

public:
    Debugger(ByteCodeRunner *runner, bool gdbmi = false);
    ~Debugger();

protected:
    virtual void onRunnerInit();
    virtual void onRunnerReset();

    virtual void onBreakpointTrap(FlowPtr insn);
    virtual void onInsnTrap(FlowPtr insn);
    virtual void onCallTrap(FlowPtr insn, bool tail);
    virtual void onReturnTrap(FlowPtr insn);
    virtual void onAsyncInterrupt(FlowPtr insn);
    virtual void onError(RuntimeError err, FlowPtr insn);

private:
    bool gdbmi;
    GDBMIStreambuf mibuf_flow;
    GDBMIStreambuf mibuf_debug;
    GDBMIStreambuf mibuf_log;
    ostream debug_out;
    ostream log_out;
    std::ofstream tty_out;

    QMutex debugger_lock;
    static QMutex output_lock;

    // These fields are protected by debugger_lock.
    // When suspended is false, runner cannot be accessed by the input thread.
    bool suspended;
    FlowPtr suspend_insn;
    std::string suspend_reason, suspend_token;
    QWaitCondition suspend_cond;
    QWaitCondition resume_cond;

    int cur_stack_frame;
    std::vector<FlowStackFrame> stack_frames;

    class InputThread : public QThread {
    public:
        InputThread(Debugger *owner) : QThread(owner), owner(owner) {}
    protected:
        Debugger *owner;
        void run();
    };
    InputThread *input_thread;

    // Protected by debugger_lock
    std::string last_cmd;
    bool cur_cmd_ok;
    std::string cur_cmd_result, cur_cmd_token;

    bool cmdError(const std::string &str);

    // Owned by the 'unsuspended' thread
    enum Command {
        CMD_NONE,
        CMD_STEP,
        CMD_NEXT,
        CMD_STEPI,
        CMD_NEXTI,
        CMD_FINISH
    };
    Command cmd;
    bool wait_return;
    unsigned return_depth;
    unsigned call_depth_check, data_depth_check;
    ExtendedDebugInfo::LineEntry *cur_line;

    bool setCommand(Command cmd, FlowPtr cur_insn);

    // Owned by the 'unsuspended' thread
    struct Breakpoint {
        int id;
        FlowPtr addr;
        bool enabled;
    };

    int next_breakpoint_id;
    typedef std::map<int, Breakpoint> T_breakpoint_table;
    T_breakpoint_table breakpoint_table;
    typedef std::map<FlowPtr, int> T_breakpoint_id_table;
    T_breakpoint_id_table breakpoint_id_table;

    void updateBreakpoint(FlowPtr addr);

    struct Variable {
        unsigned stack_place;
        ExtendedDebugInfo::FunctionEntry *function;
        ExtendedDebugInfo::LocalEntry *local;

        struct Val {
            int numchild;
            std::string value;
        };

        std::map<std::string,Val> values;
    };
    std::map<std::string, Variable> vars;
    int next_var_id;

    bool makeVarRef(Variable &rv, int frame, const std::string &name);
    FlowVarReference resolveVarRef(const Variable &var, bool silent = false);
    FlowVarReference resolveLocalRef(const FlowStackFrame &frame, ExtendedDebugInfo::LocalEntry *local, bool silent = false);
    FlowVarReference lookupVarByName(Variable **pvar, std::string name, bool silent = false);

    Variable::Val evaluateVar(FlowVarReference pslot, Variable *pvar, std::string key, std::vector<FlowVarReference> *pchildren = NULL);

    // Controlled by debugger_lock
    typedef std::vector<std::string> T_file_lines;
    typedef std::map<std::string, T_file_lines> T_file_table;
    T_file_table file_table;

    std::map<std::string, ExtendedDebugInfo::FileEntry*> fname_table;

    std::string cur_list_file;
    int cur_list_line;
    int print_length, print_depth;

    void loadFile(const std::string &file);
    void printLines(const std::string &file, int min_line, int max_line);

    ExtendedDebugInfo::LineEntry *getLine(FlowPtr addr);

    void attachSigHandler();
    void runCommandLine(FlowPtr insn, const std::string &reason);
    void reportPosition(FlowPtr insn, const std::string &prefix);
    void reportCodeLine(FlowPtr insn);

    std::string canonifyFilePath(const std::string &name);

    void waitSuspend();
    void handleCommand(std::string cur_cmdline);

    void printMIFrame(ostream &out, const FlowStackFrame &frame);
    std::string printMIFrame(const FlowStackFrame &frame);

    bool skipReserveLocals(FlowPtr *ptr);

    void disassemble(ostream &out, const FlowInstruction::Pair &insn, ExtendedDebugInfo::FunctionEntry *function);
    void disassemble(const FlowInstruction::Pair &insn);
    void disassemble(FlowPtr addr);

    std::string function_relative(FlowPtr addr);
    std::string function_relative(ExtendedDebugInfo::FunctionEntry *function, FlowPtr addr);

    bool command_set(std::vector<std::string> &tokens);
    bool command_info(std::vector<std::string> &tokens);
    bool command_break(std::vector<std::string> &tokens, FlowPtr insn);
    bool command_disable(std::vector<std::string> &tokens);
    bool command_enable(std::vector<std::string> &tokens);
    bool command_delete(std::vector<std::string> &tokens);
    bool command_list(std::vector<std::string> &tokens);
    bool command_print(std::vector<std::string> &tokens, FlowPtr insn);

    void listLocals(ostream &out, const FlowStackFrame &frame, int type = -1);

    bool command_list_frames(std::vector<std::string> &tokens, FlowPtr insn);

    bool command_var_create(std::vector<std::string> &tokens);
    bool command_list_locals(std::vector<std::string> &tokens);
    bool command_list_children(std::vector<std::string> &tokens);
    bool command_var_show_attrs(std::vector<std::string> &tokens);
    bool command_var_assign(std::vector<std::string> &tokens);
    bool command_var_update(std::vector<std::string> &tokens);

    void command_switch_bp(std::vector<std::string> &tokens, int start, int mode);

    bool command_data_disasm(std::vector<std::string> &tokens, FlowPtr insn);

    bool command_tty_set(std::vector<std::string> &tokens);

    bool command_live_objects(std::vector<std::string> &tokens);

#ifdef FLOW_INSTRUCTION_PROFILING
    bool command_profile(std::vector<std::string> &tokens);
#endif

    static Debugger *instance;

#ifdef WIN32
    static BOOL WINAPI intSignalHandler(DWORD);
#else
    static void intSignalHandler(int unused);

    int sigintFd[2];
    QSocketNotifier *snInt;
#endif

private slots:
    // Qt signal handler
    void handleSigInt();
    void handleAsyncInterrupt();
    void handleReloadBytecode();
};

#endif // DEBUGGER_H
