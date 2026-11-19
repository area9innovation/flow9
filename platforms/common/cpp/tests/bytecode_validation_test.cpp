#include "core/ByteCodeRunner.h"
#include "core/HeapWalker.h"
#include "gen_common.h" // compact_closure.flow, built with the C++ backend

#include <array>
#include <cstdlib>
#include <fstream>
#include <iterator>
#include <memory>
#include <set>

static void check(bool ok, const char *message)
{
    if (!ok) {
        std::cerr << message << '\n';
        std::exit(1);
    }
}

template <typename F>
static void rejects(CodeMemory &code, F operation)
{
    const FlowPtr position = code.GetPosition();
    try {
        operation();
    } catch (const CodeMemory::DecodeError &) {
        check(code.GetPosition() == position, "Failed bounds check moved the cursor");
        return;
    }
    check(false, "Reader did not reject an invalid request");
}

#ifdef FLOW_DEBUGGER
class BreakAtEntry : public FlowDebuggerBase {
public:
    int hits = 0;
    enum { Resume, StopCoverage, StopCoverageAndRemove } action = Resume;
    explicit BreakAtEntry(ByteCodeRunner *runner) : FlowDebuggerBase(runner) { arm(); }
    void arm() { SetBreakpoint(MakeFlowPtr(0), true); }
    void onRunnerInit() override { FlowDebuggerBase::onRunnerInit(); arm(); }
    void onBreakpointTrap(FlowPtr addr) override {
        check(addr == 0, "Entry breakpoint");
        ++hits;
        if (action != Resume) {
            check(breakpoints().at(addr) == CCodeCoverageTrap, "Expected pending entry coverage");
            getFlowRunner()->StopProfiling();
            if (action == StopCoverageAndRemove) SetBreakpoint(addr, false);
        }
    }
    void onInsnTrap(FlowPtr) override {}
    void onCallTrap(FlowPtr, bool) override {}
    void onReturnTrap(FlowPtr) override {}
    void onAsyncInterrupt(FlowPtr) override {}
    void onError(RuntimeError, FlowPtr) override { check(false, "Debugger reported a runner error"); }
};

// Keeps a breakpoint at the entry through a runtime error.
class BreakpointAfterError : public FlowDebuggerBase {
public:
    int errors = 0;
    explicit BreakpointAfterError(ByteCodeRunner *runner) : FlowDebuggerBase(runner) { set(true); }
    void set(bool enable) { SetBreakpoint(MakeFlowPtr(0), enable); }
    bool hasBreakpoints() { return !breakpoints().empty(); }
    void onBreakpointTrap(FlowPtr) override {}
    void onInsnTrap(FlowPtr) override {}
    void onCallTrap(FlowPtr, bool) override {}
    void onReturnTrap(FlowPtr) override {}
    void onAsyncInterrupt(FlowPtr) override {}
    void onError(RuntimeError, FlowPtr) override { ++errors; }
};
#endif

// Bytecode that adds with one value on the stack.
static std::string plusWithOneOperand()
{
    std::string image(1, CInt);
    const int one = 1;
    image.append(reinterpret_cast<const char*>(&one), sizeof(one));
    image += char(CPlus);
    image += char(CLast);
    return image;
}

static void testMissingOperands()
{
    // Each instruction takes more values than the stack holds.
    for (const std::string &image : {plusWithOneOperand(), std::string{char(CPop), char(CLast)},
                                     std::string{char(CNot), char(CLast)}, std::string{char(CEqual), char(CLast)}}) {
        ByteCodeRunner runner;
        runner.Init(image.data(), image.size());
        runner.RunMain();
        check(runner.IsErrorReported(), "An instruction without its operands must be rejected");
    }

#ifdef FLOW_DEBUGGER
    // A breakpoint can still be removed after the program stopped with an error.
    const std::string image = plusWithOneOperand();
    std::unique_ptr<BreakpointAfterError> debugger; // Outlives the attached runner.
    ByteCodeRunner runner;
    runner.Init(image.data(), image.size());
    debugger.reset(new BreakpointAfterError(&runner));
    check(debugger->hasBreakpoints(), "Entry breakpoint was not installed");
    runner.RunMain();
    check(runner.IsErrorReported() && debugger->errors == 1, "Expected the missing operand error");
    debugger->set(false);
    check(!debugger->hasBreakpoints(), "Breakpoint must be removable after a runtime error");
#endif
}

class ConstantProgram : public NativeProgram {
public:
    bool ran = false;
    const char *getByteCode(int *length) override {
        static const char literal[] = "compiled program constant";
        *length = sizeof(literal);
        return literal;
    }
    void onRunMain() override { ran = true; }
};

static void testCompactClosure()
{
    flowgen_native_program::NativeProgramImpl program;
    ByteCodeRunner runner;
    runner.Init(&program);
    runner.RunMain();
    check(!runner.IsErrorReported(), "Compact closure did not run");

    struct Captures : StatisticsHeapWalker {
        using StatisticsHeapWalker::StatisticsHeapWalker;
        std::multiset<int> ints;
        void VisitScalar(StackSlot &slot) override {
            if (slot.IsInt()) ints.insert(slot.GetInt());
        }
    };
    for (bool collect : {false, true}) {
        if (collect) runner.ForceGC(0, true);
        Captures walker(&runner);
        walker.ProcessGlobalRoots();
        check(walker.ints == std::multiset<int>{40, 2}, "Expected both the packed int and the nested Offset value");
        // The closure layout and Offset each have one live instance.
        for (const auto &def : runner.GetStructDefs())
            check(walker.GetStructBytes().at(def.StructId) == def.ByteSize, "Expected exact compact storage sizes");
    }
}

int main(int argc, char **argv)
{
    char letters[] = "abcd";
    CodeMemory code(letters, 1, 3);
    check(code.CanRead(3) && !code.CanRead(4), "Byte range check");
    check(!code.CanRead(-1) && !code.CanRead(1, 0), "Invalid count or width");
    check(code.CanRead(1, 2) && !code.CanRead(2, 2), "Element range check");
    rejects(code, [&] { code.ReadInt32(); });
    rejects(code, [&] { code.SkipInt(); });
    rejects(code, [&] { code.GetBytes(-1); });
    rejects(code, [&] { code.GetBytes(4); });
    rejects(code, [&] { code.ReadString(-1); });
    rejects(code, [&] { code.ReadString(4); });
    rejects(code, [&] { code.ReadWideString(2); });
    check(code.RelativeTarget(MakeFlowPtr(3), -2) == 1, "Backward target within range");
    rejects(code, [&] { code.RelativeTarget(MakeFlowPtr(3), -3); });
    rejects(code, [&] { code.RelativeTarget(MakeFlowPtr(3), 2); });
    code.SetPosition(MakeFlowPtr(0));
    check(code.ReadString(3) == "bcd" && code.Eof(), "Exact fit at a nonzero start");
    check(code.ReadString(0).empty(), "Zero-length read at end");
    rejects(code, [&] { code.ReadByte(); });

    unicode_string text(255, 0x263a);
    code.SetBuffer(reinterpret_cast<char*>(&text[0]), 0, int(text.size() * 2));
    check(code.ReadWideString(255) == text && code.Eof(), "Maximum short UTF-16 string");
    std::vector<char> wide_instruction(2 + text.size() * 2);
    wide_instruction[0] = CWString;
    wide_instruction[1] = char(text.size());
    memcpy(wide_instruction.data() + 2, text.data(), text.size() * 2);
    code.SetBuffer(wide_instruction.data(), 0, int(wide_instruction.size()));
    FlowInstruction wide;
    check(code.ParseOpcode(&wide) && code.Eof() && wide.StrValue == encodeUtf8(text),
          "Unsigned UTF-16 instruction length");

    char bad_opcode[] = {char(0x50)};
    code.SetBuffer(bad_opcode, 0, sizeof(bad_opcode));
    FlowInstruction bad;
    check(!code.ParseOpcode(&bad) && bad.op == OpCode(0x50) && code.GetPosition() == 0,
          "An invalid opcode keeps its byte and the cursor");

    char type[] = {FTMutable, FTTypedArray, FTTypedRefTo, FTInt};
    char is_mutable = false;
    code.SetBuffer(type, 0, sizeof(type));
    auto markers = code.ReadFieldType(&is_mutable, NULL);
    check(code.Eof() && is_mutable && markers.size() == 3 && markers.back() == FTInt,
          "Nested mutable field type");

    std::array<char, 257> deep_type;
    deep_type.fill(FTTypedArray);
    deep_type.back() = FTInt;
    code.SetBuffer(deep_type.data(), 0, deep_type.size());
    markers = code.ReadFieldType(&is_mutable, NULL);
    check(code.Eof() && !is_mutable && markers.size() == deep_type.size(), "Deep field type");

    // Struct definitions have 32-bit counts and individually named fields.
    const int fields = 32769;
    std::string record(1, CStructDef);
    auto writeInt = [&](int n) { record.append(reinterpret_cast<const char*>(&n), sizeof(n)); };
    auto writeName = [&](const std::string &name) { writeInt(name.size()); record += name; };
    writeInt(0);
    writeName("Wide");
    writeInt(fields);
    for (int i = 0; i < fields; ++i) {
        writeName("f" + std::to_string(i));
        if (i == fields-1) record.append(deep_type.data(), deep_type.size());
        else record += char(FTInt);
    }
    code.SetBuffer(&record[0], 0, record.size());
    std::vector<bool> starts;
    code.BuildInstructionIndex(starts);
    check(starts.front() && starts.back(), "Boundaries of a wide struct definition");
    code.ResetPosition();
    FlowInstruction def;
    check(code.ParseOpcode(&def) && code.Eof() && def.IntValue2 == fields &&
          def.fields[fields-1].name == "f32768" && def.fields[fields-1].type.size() == deep_type.size(),
          "Large field tables and extended types do not depend on cache width");

    for (OpCode opcode : {CSwitch, CSimpleSwitch}) {
        // All arms fall through. Both the count and the case IDs exceed the
        // narrowed reads historically used by this dispatch path.
        record.assign(1, opcode);
        writeInt(300);
        writeInt(0);
        for (int i = 0; i < 300; ++i) { writeInt(32768 + i); writeInt(0); }
        record += char(CLast);
        code.SetBuffer(&record[0], 0, record.size());
        code.BuildInstructionIndex(starts);
        code.ResetPosition();
        FlowInstruction sw;
        check(code.ParseOpcode(&sw) && sw.IntValue == 300 && sw.cases[299].id == 33067
              && sw.cases[299].target == code.GetPosition() && code.ReadOpcode() == CLast && code.Eof(),
              "Full-width switch table");
    }

    check(argc == 3, "Expected compiler output and a coverage output path");
    for (bool raw : {false, true}) {
#ifdef FLOW_DEBUGGER
        std::unique_ptr<BreakAtEntry> debugger; // Outlives the attached runner.
#endif
        ByteCodeRunner runner;
        std::ifstream file(argv[1], std::ios::binary);
        std::string image((std::istreambuf_iterator<char>(file)), {});
        check(!image.empty(), "Empty compiler output");
        if (raw) runner.Init(image.data(), image.size()); else runner.Init(std::string(argv[1]));
#ifdef FLOW_DEBUGGER
        // Install coverage before and after a breakpoint; both must see the
        // original instruction and leave an executable image for reload.
        if (raw) runner.BeginCoverageProfile(argv[2]);
        debugger.reset(new BreakAtEntry(&runner));
        if (!raw) runner.BeginCoverageProfile(argv[2]);
#endif
        runner.RunMain();
        check(!runner.IsErrorReported(), "Compiler output did not run successfully");

        int root = runner.RegisterRoot(runner.AllocateConstClosure(0, StackSlot::MakeInt(42)));
        runner.ForceGC(0, true);
        StackSlot live = runner.LookupRoot(root);
        check(runner.GetClosureSize(live) == 1, "Collection must preserve the exact capture count");
        check(runner.EvalFunction(live, 0).GetInt() == 42, "Retained capture after collection");
        runner.ReleaseRoot(root);

        runner.ReloadBytecode();
        runner.RunMain();
        check(!runner.IsErrorReported(), "Reloaded compiler output did not run successfully");
#ifdef FLOW_DEBUGGER
        check(debugger->hits == 2, "Entry trap must fire in both images");

        runner.ReloadBytecode();
        runner.BeginCoverageProfile(argv[2]);
        debugger->action = raw ? BreakAtEntry::StopCoverageAndRemove : BreakAtEntry::StopCoverage;
        runner.RunMain();
        check(debugger->hits == 3 && !runner.IsErrorReported(), "Failed to resume after stopping coverage");
#endif
        ConstantProgram compiled;
        runner.Init(&compiled);
        runner.RunMain();
        check(compiled.ran && !runner.IsErrorReported(), "Native constant buffer is not interpreter code");
    }
    testCompactClosure();
    testMissingOperands();
}
