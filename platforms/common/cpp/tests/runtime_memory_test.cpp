// Benign operations and API boundaries; no malformed bytecode or heap objects.
#include "core/NativeProgram.h"

#include <cstdio>
#include <cstdlib>
#include <memory>
#include <sstream>
#ifndef _WIN32
#include <sys/stat.h>
#include <unistd.h>
#endif

static void require(bool ok, const char *message) {
    if (!ok) {
        fprintf(stderr, "FAIL: %s\n", message);
        exit(1);
    }
}

static void testMemory() {
    FlowStack<std::string, 1> stack;
    stack.push_back("first");
    stack.push_back("second");
    require(stack.size() == 2 && stack[0] == "first", "stack growth preserves owned values");
    stack.clear();
    require(stack.empty() && stack.capacity() == 1, "stack clear restores initial capacity");

    const size_t page = MemoryArea::page_size();
    MemoryArea area;
    require(!area.reserve(SIZE_MAX), "unrepresentable reservation rejected");
    require(area.reserve(page), "reserve one page");
    area.commit(0, page);
    area.readonly(page, page); // A valid empty range at the end.
    area.unmap();
    require(area.size() == 0, "unmap clears the reservation size");

    std::string name;
    FILE *file = MakeTemporaryFile(&name);
    require(file && !name.empty(), "create named temporary file");
    require(fwrite("abcd", 1, 4, file) == 4 && fflush(file) == 0, "write temporary file");
    require(fseek(file, 0, SEEK_SET) == 0 && fgetc(file) == 'a', "read from returned stream");

    ByteMemory memory(page);
    const FlowPtr low = MakeFlowPtr(0), high = MakeFlowPtr(2 * page);
    require(memory.IsValid(MakeFlowPtr(page), 0), "empty range at the heap boundary");
    require(!memory.IsValid(MakeFlowPtr(page), 1), "nonempty range outside the heap");
    require(!memory.IsValid(MakeFlowPtr(1), SIZE_MAX), "unrepresentable bulk span rejected");
    memory.SetBytes(low, "abcd", 4);
    memory.Copy(low, low + 1, 3);
    char out[4];
    memory.GetBytes(low, out, sizeof(out));
    require(memcmp(out, "aabc", 4) == 0, "bulk copy preserves overlap semantics");
    memory.CommitRange(high, high + page);
    memory.FillBytes(high, 'z', 4);
    memory.GetBytes(high, out, sizeof(out));
    require(memcmp(out, "zzzz", 4) == 0, "committed range outside the heap is accessible");
    memory.DecommitRange(high, high + page);

#ifndef _WIN32
    require(!memory.MapFile(high, 0, file), "empty fixed mapping rejected");
    require(memory.MapFile(high, 4, file), "map from open stream");
    require(fclose(file) == 0, "caller retains stream ownership");
    memory.Copy(high, low, 4);
    memory.GetBytes(low, out, sizeof(out));
    require(memcmp(out, "abcd", 4) == 0, "read-only mapping can be a bulk copy source");
#else
    require(fclose(file) == 0, "close temporary stream");
#endif

    StaticBuffer buffer;
    require(buffer.load_file(name) && buffer.size() == 4, "load small static buffer");
    require(memcmp(buffer.data(), "abcd", 4) == 0, "static buffer contents");
    require(remove(name.c_str()) == 0, "remove temporary file");

    FILE *empty = fopen("empty.dat", "wb");
    require(empty && fclose(empty) == 0, "create empty file");
    require(buffer.load_file("empty.dat") && buffer.size() == 0, "load empty buffer");
}

class TestProgram : public NativeProgram {
    const char *getByteCode(int *length) override { *length = 0; return NULL; }
    void onRunMain() override {}
    void onRunnerAttach() override {
        static const char *fields[] = { "value" };
        static const int types[] = { FTTypedArray, -1 };
        StructSpec spec = {};
        spec.name = "TestRecord";
        spec.num_fields = 1;
        spec.field_names = fields;
        spec.field_type_info = types;
        require(InitStructTable(&spec, 1), "register an ordinary struct");
    }
};

static void testDataFiles(ByteCodeRunner &runner) {
    require(runner.LoadFileAsString("absent.dat").IsVoid() && !runner.IsErrorReported(), "missing data has no value");
    StackSlot empty = runner.LoadFileAsString("empty.dat");
    require(empty.IsString() && !runner.GetStringSize(empty), "present empty data has a value");

    for (size_t n : {size_t(3), size_t(MIN_MMAP_SIZE + 3)}) {
        std::string bytes(n, 'x');
        bytes.back() = 'z';
        FILE *f = fopen("odd.dat", "wb");
        require(f && fwrite(bytes.data(), 1, n, f) == n && !fclose(f), "write odd-length file");
        StackSlot data = runner.LoadFileAsString("odd.dat", true);
        require(data.IsString() && runner.GetStringSize(data) == (n + 1) / 2, "retain the final partial code unit");
#ifdef FLOW_MMAP_HEAP
        require(runner.IsMappedArea(runner.GetStringAddr(data)) == (n >= MIN_MMAP_SIZE), "exercise read and map paths");
#endif
        bytes.push_back('\0');
        require(!memcmp(bytes.data(), runner.GetStringPtr(data), bytes.size()), "identical padding for read and map");
        require(runner.LoadFileAsString("odd.dat").IsVoid(), "temporary input removed");
    }
}

static void testCopyFile(ByteCodeRunner &runner) {
    StackSlot paths[] = {StackSlot::MakeVoid(), StackSlot::MakeVoid()};
    LocalRootDefinition frame(&runner, 2, paths);
    paths[0] = runner.AllocateString("source.dat");
    paths[1] = runner.AllocateString("copy.dat");
    for (size_t n : {size_t(3), size_t(4), size_t(MIN_MMAP_SIZE + 1), size_t(0)}) {
        std::string bytes(n, '\0');
        for (size_t i = 0; i < n; ++i) bytes[i] = char(i * 131);
        FILE *f = fopen("source.dat", "wb");
        require(f && fwrite(bytes.data(), 1, n, f) == n && !fclose(f), "write copy source");
        require(ByteCodeRunner::copyFile(&runner, paths).GetBool(), "copy regular file");
        StaticBuffer dest;
        require(dest.load_file("copy.dat") && dest.size() == n && (!n || !memcmp(dest.data(), bytes.data(), n)),
                "destination has exactly the source bytes");
        // A failed copy must not replace the existing destination.
        require(!remove("source.dat") && !ByteCodeRunner::copyFile(&runner, paths).GetBool(), "missing source returns false");
        StaticBuffer retained;
        require(retained.load_file("copy.dat") && retained.size() == n && (!n || !memcmp(retained.data(), bytes.data(), n)),
                "failed copy preserves destination");
    }
#ifndef _WIN32
    FILE *f = fopen("source.dat", "wb");
    require(f && fputs("self", f) >= 0 && !fclose(f) && !link("source.dat", "link.dat"), "write source and a hard link");
    for (const char *dest : {"source.dat", "link.dat"}) {
        paths[1] = runner.AllocateString(dest);
        require(!ByteCodeRunner::copyFile(&runner, paths).GetBool(), "no copy onto the same file");
    }
    struct stat st;
    StaticBuffer kept;
    require(!stat("source.dat", &st) && st.st_nlink == 2 && kept.load_file("source.dat") && kept.size() == 4 &&
            !memcmp(kept.data(), "self", 4), "the file and its hard link are unchanged");
    require(!remove("link.dat") && !remove("source.dat"), "remove the same-file inputs");
#endif
}

static void testLegacyFileValues() {
    ByteCodeRunner runner("valid.flowbc");
    StackSlot roots[5];
    std::fill(roots, roots + 5, StackSlot::MakeVoid());
    LocalRootDefinition frame(&runner, 5, roots);
    auto read = [&](const char *name, const std::string &bytes, int slot) {
        FILE *f = fopen(name, "wb");
        require(f && fwrite(bytes.data(), 1, bytes.size(), f) == bytes.size() && !fclose(f), "prepare packed file");
        roots[0] = runner.AllocateString(name);
        roots[slot] = ByteCodeRunner::getFileContentBinary(&runner, roots);
        require(roots[slot].IsString(), "legacy packed read");
    };
    auto write = [&](int slot, const std::string &expected, bool packed) {
        roots[0] = runner.AllocateString("legacy-out.dat");
        roots[1] = roots[slot];
        require((packed ? ByteCodeRunner::setFileContentBinary : ByteCodeRunner::setFileContentBytes)(&runner, roots).GetBool(),
                "legacy write after GC");
        StaticBuffer out;
        require(out.load_file("legacy-out.dat") && out.size() == expected.size() &&
                !memcmp(out.data(), expected.data(), expected.size()), "write original bytes of this file value");
    };
    std::string odd("ABC"), even("ABC\0", 4), large(MIN_MMAP_SIZE + 3, '\xff');
    read("legacy-odd.dat", odd, 2);
    read("legacy-even.dat", even, 3);
    read("legacy-large.dat", large, 4);
    runner.ForceGC(0, false);
    runner.ForceGC(0, true);
    require(runner.GetString(roots[2]) == runner.GetString(roots[3]), "old strings have equal packed values");
    write(2, odd, false);
    write(3, even, false);
    write(4, large, true);

    // A fresh read of identical data still has both normal string writer contracts.
    roots[0] = runner.AllocateString("legacy-odd.dat");
    roots[2] = ByteCodeRunner::readPackedFile(&runner, roots);
    write(2, even, true);
    const unicode_string units = runner.GetString(roots[2]);
    write(2, std::string({char(units[0]), char(units[1])}), false);
    roots[0] = runner.AllocateString("legacy-large.dat");
    roots[2] = ByteCodeRunner::readPackedFile(&runner, roots);
    write(2, large + '\0', true);
    write(4, large, true); // The original mapping still has its exact byte count.
#ifdef FLOW_MMAP_HEAP
    // Reads of one file through both readers each reuse their own mapping.
    roots[0] = runner.AllocateString("legacy-large.dat");
    roots[1] = ByteCodeRunner::getFileContentBinary(&runner, roots);
    roots[0] = runner.AllocateString("legacy-large.dat");
    roots[3] = ByteCodeRunner::readPackedFile(&runner, roots);
    require(runner.GetStringAddr(roots[1]) == runner.GetStringAddr(roots[4]) &&
            runner.GetStringAddr(roots[3]) == runner.GetStringAddr(roots[2]), "alternate readers reuse their mappings");
#endif
#ifndef _WIN32 // Windows cannot rename a mapped file
    roots[0] = runner.AllocateString("legacy-large.dat");
    roots[4] = ByteCodeRunner::getFileContentBinary(&runner, roots);
    require(!rename("legacy-large.dat", "previous-large.dat"), "remove cached source name");
    roots[0] = runner.AllocateString("legacy-large.dat");
    require(ByteCodeRunner::getFileContentBinary(&runner, roots).IsVoid(), "missing source is not a cached copy");
    std::string replacement(large.size(), 'Z');
    read("legacy-large.dat", replacement, 3);
    write(3, replacement, false);
    write(4, large, false);
#endif
}

static unsigned heapSize(ByteCodeRunner &runner) {
    return FlowPtrToInt(runner.GetHeapLimits(true).Start) - FlowPtrToInt(runner.GetHeapLimits(false).Bound);
}

#ifdef FLOW_MMAP_HEAP
static void writeSnapshotFile(const std::string &bytes) {
    FILE *f = fopen("snapshot.dat", "wb");
    require(f && fwrite(bytes.data(), 1, bytes.size(), f) == bytes.size() && !fclose(f), "write snapshot fixture");
}

static StackSlot readSnapshot(ByteCodeRunner &runner, bool legacy) {
    StackSlot path = runner.AllocateString("snapshot.dat");
    LocalRootDefinition root(&runner, 1, &path);
    return legacy ? ByteCodeRunner::getFileContentBinary(&runner, &path) : ByteCodeRunner::readPackedFile(&runner, &path);
}

static void checkSnapshot(ByteCodeRunner &runner, const StackSlot &value, const std::string &bytes) {
    require(value.IsString() && !runner.IsErrorReported() &&
            size_t(runner.GetStringSize(value)) == (bytes.size() + 1) / 2, "snapshot length after GC");
    const char *p = reinterpret_cast<const char *>(runner.GetStringPtr(value));
    require(!memcmp(p, bytes.data(), bytes.size()) && (!(bytes.size() % 2) || !p[bytes.size()]),
            "snapshot retains original bytes and odd-length padding");
}

static void testNamedSnapshotBudget(unsigned initial, unsigned cap, bool legacy) {
    const unsigned mib = 1024 * 1024;
    MIN_HEAP_SIZE = initial * mib;
    MAX_HEAP_SIZE = cap * mib;
    EPHEMERAL_HEAP_SIZE = mib;
    ByteCodeRunner runner("valid.flowbc");
    require(heapSize(runner) == MIN_HEAP_SIZE, "snapshot test starts at the configured minimum");
    StackSlot keep = runner.AllocateString("live across growth");
    LocalRootDefinition survivor(&runner, 1, &keep);
    for (unsigned n : {MAX_HEAP_SIZE / 4 + mib + 1, MAX_HEAP_SIZE / 2 + mib + 1}) {
        std::string bytes(n, 'p');
        writeSnapshotFile(bytes);
        StackSlot old = readSnapshot(runner, legacy);
        LocalRootDefinition root(&runner, 1, &old);
        require(old.IsString() && !runner.IsErrorReported(), "read file beyond private cache budget");
        require(runner.IsMappedArea(runner.GetStringAddr(old)) == (n > MAX_HEAP_SIZE / 2),
                "collectible snapshot when it fits; large-string arena otherwise");
        require(heapSize(runner) == cap * mib, "heap grew enough for the first managed snapshot");
        writeSnapshotFile("new");
        runner.ForceGC(0, true);
        checkSnapshot(runner, old, bytes);
        require(runner.GetString(keep) == parseUtf8("live across growth"), "root retained across heap growth");
    }
}

static void testSnapshotWithLiveData() {
    const unsigned mib = 1024 * 1024;
    MIN_HEAP_SIZE = MAX_HEAP_SIZE = 16 * mib;
    EPHEMERAL_HEAP_SIZE = mib;
    ByteCodeRunner runner("valid.flowbc");
    StackSlot roots[3] = {StackSlot::MakeVoid(), StackSlot::MakeVoid(), StackSlot::MakeVoid()};
    LocalRootDefinition frame(&runner, 3, roots);
    roots[0] = runner.AllocateArray(2);
    const unicode_string live(3 * mib / 2, 'r');
    StackSlot text = runner.AllocateString(live);
    runner.SetArraySlot(roots[0], 0, text);
    runner.SetArraySlot(roots[0], 1, StackSlot::MakeInt(42));
    // 7 MiB of old space: either value fits, but not the 3 MiB root and
    // the 5 MiB snapshot together. Both readers must be able to continue.
    const std::string bytes(5 * mib + 1, 's');
    writeSnapshotFile(bytes);
    for (int i = 1; i <= 2; ++i) {
        roots[i] = readSnapshot(runner, i == 2);
        require(!runner.IsErrorReported() && roots[i].IsString() && runner.IsMappedArea(runner.GetStringAddr(roots[i])),
                "use arena when an optional old-space reservation cannot fit");
    }
    writeSnapshotFile("new");
    for (int i = 0; i < 3; ++i) {
        runner.ForceGC(0, true);
        require(!runner.IsErrorReported() && runner.GetArraySize(roots[0]) == 2 &&
                runner.GetString(runner.GetArraySlot(roots[0], 0)) == live &&
                runner.GetArraySlot(roots[0], 1).GetInt() == 42, "root graph intact after full collections");
        checkSnapshot(runner, roots[1], bytes);
        checkSnapshot(runner, roots[2], bytes);
    }
}

static void testYoungSnapshot() {
    const unsigned mib = 1024 * 1024;
    const unsigned savedLimit = MAX_EPHEMERAL_ALLOC;
    MAX_EPHEMERAL_ALLOC = mib;
    MIN_HEAP_SIZE = 8 * mib;
    MAX_HEAP_SIZE = 32 * mib;
    EPHEMERAL_HEAP_SIZE = 4 * mib;
    ByteCodeRunner runner("valid.flowbc");
    StackSlot roots[3] = {StackSlot::MakeVoid(), StackSlot::MakeVoid(), StackSlot::MakeVoid()};
    LocalRootDefinition frame(&runner, 3, roots);
    // Initially all usable space is young. Fill the private cache budget.
    writeSnapshotFile(std::string(8 * mib, 'a'));
    roots[0] = readSnapshot(runner, false);
    require(roots[0].IsString() && runner.IsMappedArea(runner.GetStringAddr(roots[0])), "fill snapshot arena budget");
    const std::string bytes(256 * 1024 + 1, 'y');
    writeSnapshotFile(bytes);
    for (int i = 1; i <= 2; ++i) {
        roots[i] = readSnapshot(runner, i == 2);
        require(roots[i].IsString() && !runner.IsMappedArea(runner.GetStringAddr(roots[i])) &&
                heapSize(runner) == 8 * mib, "young snapshot uses managed space without growing the heap");
    }
    // Padding the last UTF-16 unit gives exactly the young allocation limit;
    // adding the long-string header makes this an old-generation allocation.
    const std::string boundary(MAX_EPHEMERAL_ALLOC - 1, 'h');
    writeSnapshotFile(boundary);
    roots[0] = readSnapshot(runner, false);
    require(roots[0].IsString() && !runner.IsMappedArea(runner.GetStringAddr(roots[0])) &&
            heapSize(runner) == 16 * mib, "string header crosses the generation boundary");
    writeSnapshotFile("new");
    runner.ForceGC(0, true);
    checkSnapshot(runner, roots[0], boundary);
    checkSnapshot(runner, roots[1], bytes);
    checkSnapshot(runner, roots[2], bytes);
    MAX_EPHEMERAL_ALLOC = savedLimit;
}
#endif

static void testGrowth(unsigned initial, unsigned cap, unsigned young, unsigned count) {
    const unsigned mib = 1024 * 1024;
    MIN_HEAP_SIZE = initial * mib;
    MAX_HEAP_SIZE = cap * mib;
    EPHEMERAL_HEAP_SIZE = young * mib;
    ByteCodeRunner runner;
    runner.Init("valid.flowbc");
    require(!runner.IsErrorReported() && heapSize(runner) == MIN_HEAP_SIZE, "start at configured minimum");
    int text = runner.RegisterRoot(runner.AllocateString("root"));
    StackSlot arr = runner.AllocateArray(count);
    require(!runner.IsErrorReported() && runner.GetArraySize(arr) == count, "allocate beyond the initial old generation");
    require(heapSize(runner) == MAX_HEAP_SIZE, "use the final semispace within the cap");
    runner.SetArraySlot(arr, count - 1, runner.LookupRoot(text));
    int root = runner.RegisterRoot(arr);
    for (int i = 0; i < 2; ++i) {
        runner.ForceGC(0, true);
        arr = runner.LookupRoot(root);
        require(!runner.IsErrorReported() && heapSize(runner) == MAX_HEAP_SIZE &&
                runner.GetString(runner.GetArraySlot(arr, count - 1)) == parseUtf8("root"), "live data survives both flips");
    }
    runner.ReleaseRoot(root);
    runner.ReleaseRoot(text);
}

static StackSlot generateItem(ByteCodeRunner *runner, StackSlot *args, void *data) {
    require(!runner->IsErrorReported(), "no callback after an allocation error");
    ++*static_cast<int *>(data);
    return args[0];
}

static void testYoungAllocation() {
    MIN_HEAP_SIZE = MAX_HEAP_SIZE = 4 * 1024 * 1024;
    EPHEMERAL_HEAP_SIZE = 1024 * 1024;
    ByteCodeRunner runner("valid.flowbc");
    const int count = 20479; // Six such arrays fit in either generation; seven do not.
    int roots[7];
    for (int i = 0; i < 7; ++i) {
        StackSlot arr = runner.AllocateArray(count);
        require(!runner.IsErrorReported(), "allocate rooted arrays across a young collection");
        runner.SetArraySlot(arr, count - 1, StackSlot::MakeInt(i));
        roots[i] = runner.RegisterRoot(arr);
    }
    runner.ReleaseRoot(roots[0]); // Recoverable old space; one survivor is still young.
    for (int i = 0; i < 5; ++i) {
        runner.AllocateArray(count);
        require(!runner.IsErrorReported(), "fill the remaining young space");
    }
    StackSlot next = runner.AllocateArray(count); // Needs automatic full GC, then goes into young space.
    require(!runner.IsErrorReported() && runner.GetArraySize(next) == count && heapSize(runner) == MAX_HEAP_SIZE,
            "young allocation succeeds at the same cap after automatic collection");
    for (int i = 1; i < 7; ++i) {
        require(runner.GetArraySlot(runner.LookupRoot(roots[i]), count - 1).GetInt() == i, "retain each live array");
        runner.ReleaseRoot(roots[i]);
    }
}

#ifdef FLOW_DEBUGGER
class ErrorNotificationProbe : public FlowDebuggerBase {
public:
    using FlowDebuggerBase::FlowDebuggerBase;
    int notifications = 0;
    RuntimeError code = NoError;
    bool latched = false;
    std::string message;
    void onError(RuntimeError err, FlowPtr) override {
        ++notifications;
        code = err;
        latched = getFlowRunner()->IsErrorReported();
        message = getFlowRunner()->GetLastErrorMsg();
    }
    void onBreakpointTrap(FlowPtr) override {}
    void onInsnTrap(FlowPtr) override {}
    void onCallTrap(FlowPtr, bool) override {}
    void onReturnTrap(FlowPtr) override {}
    void onAsyncInterrupt(FlowPtr) override {}
};
#endif

static void testAllocationResults() {
    EPHEMERAL_HEAP_SIZE = 1024 * 1024;
    MIN_HEAP_SIZE = MAX_HEAP_SIZE = 2 * EPHEMERAL_HEAP_SIZE;
#ifdef FLOW_DEBUGGER
    std::unique_ptr<ErrorNotificationProbe> debugger; // Must outlive the attached runner.
#endif
    ByteCodeRunner runner;
    std::ostringstream errors;
    runner.flow_err.rdbuf(errors.rdbuf());
    // A capped heap with no room for promotion. Keep one ordinary array live.
    auto leaveFree = [&](unsigned bytes) {
        runner.Init("valid.flowbc");
        runner.RegisterRoot(runner.AllocateArray((EPHEMERAL_HEAP_SIZE - bytes - 4) / STACK_SLOT_SIZE));
        require(!runner.IsErrorReported(), "set up rooted array within the heap cap");
    };
    leaveFree(40);
#ifdef FLOW_DEBUGGER
    debugger.reset(new ErrorNotificationProbe(&runner));
#endif
    runner.ForceGC(0, true);
    require(runner.IsErrorReported(), "failure to promote the live set itself is a runtime error");
#ifdef FLOW_DEBUGGER
    require(debugger->notifications == 1 && debugger->code == HeapFull && debugger->latched &&
            debugger->message == "Cannot allocate memory: live objects exceed the old-generation capacity.",
            "debugger receives the first HeapFull with the GC guard active and original diagnostic");
    runner.Init("valid.flowbc");
    require(!runner.IsErrorReported() && runner.GetLastErrorMsg().empty() && runner.GetLastErrorInfo().empty(),
            "reinitialization clears the terminal error and its diagnostic");
    runner.ReportError(InvalidArgument, "argument diagnostic");
    require(debugger->notifications == 2 && debugger->code == InvalidArgument && !debugger->latched &&
            debugger->message == "argument diagnostic" && runner.IsErrorReported(),
            "ordinary error retains its pre-latch debugger notification");
#endif
    leaveFree(40); // The three-element list and its first name fit; the second name does not.
    StackSlot names = runner.AllocateStringArray({"a", "second-filename", "third"});
    require(names.IsVoid() && runner.GetLastErrorMsg().find("Cannot allocate memory") == 0,
            "directory result propagates element allocation failure");

    StackSlot capture = StackSlot::MakeInt(42);
    leaveFree(4);
    require(runner.AllocateClosure(StackSlot::MakeCodePointer(runner.CodeStartPtr()), 1, &capture).IsVoid() &&
            runner.GetLastErrorMsg().find("Cannot allocate memory") == 0, "Flow closure preserves allocation error");
    leaveFree(4);
    require(runner.AllocateNativeClosure(generateItem, "item", 1, NULL, 1, capture).IsVoid() &&
            runner.GetLastErrorMsg().find("Cannot allocate memory") == 0, "native closure preserves allocation error");
    runner.flow_err.rdbuf(std::cerr.rdbuf());
}

static void testGenerate() {
    MIN_HEAP_SIZE = MAX_HEAP_SIZE = 4 * 1024 * 1024;
    EPHEMERAL_HEAP_SIZE = 1024 * 1024;
    ByteCodeRunner runner;
    runner.Init("valid.flowbc");
    int calls = 0;
    StackSlot args[] = {StackSlot::MakeInt(-1), StackSlot::MakeInt(2),
                        runner.AllocateNativeClosure(generateItem, "item", 1, &calls, 1, StackSlot::MakeVoid())};
    StackSlot arr = ByteCodeRunner::generate(&runner, args);
    require(calls == 3 && runner.GetArraySize(arr) == 3 && runner.GetArraySlot(arr, 2).GetInt() == 1, "generate an ordinary range");
    std::ostringstream errors;
    runner.flow_err.rdbuf(errors.rdbuf());
    args[1] = StackSlot::MakeInt(160000); // Ordinary range, but exceeds this runner's old generation.
    require(ByteCodeRunner::generate(&runner, args).IsVoid() && runner.IsErrorReported() && calls == 3,
            "generate propagates allocation failure before invoking the callback");
    runner.flow_err.rdbuf(std::cerr.rdbuf());
}

static void testRunner() {
    require(FlowSlotsFit(3, 4, 28) && !FlowSlotsFit(3, 4, 27), "slot count includes header bytes");
    require(FlowSlotsFit((INT_MAX - 8u) / STACK_SLOT_SIZE, 8) &&
            !FlowSlotsFit((INT_MAX - 8u) / STACK_SLOT_SIZE + 1, 8), "closure byte-count boundary");

    TestProgram program;
    ByteCodeRunner runner;
    std::ostringstream errors;
    runner.flow_err.rdbuf(errors.rdbuf());
    runner.Init("not-present.flowbc");
    require(runner.IsErrorReported(), "missing bytecode file is an initialization error");
    runner.Init("empty.dat");
    require(!runner.IsErrorReported() && runner.CodeSize() == 0, "empty input still initializes");

    FILE *file = fopen("valid.flowbc", "wb");
    require(file && fputc(CLast, file) != EOF && fclose(file) == 0, "write valid bytecode file");
    runner.Init("valid.flowbc");
    require(!runner.IsErrorReported() && runner.CodeSize() == 1, "load nonempty bytecode");
    runner.RunMain();
    require(!runner.IsErrorReported(), "run valid bytecode");
    runner.Init("not-present.flowbc");
    require(runner.IsErrorReported() && runner.CodeSize() == 0, "failed reload clears the previous code size");

    runner.Init(&program);
    testDataFiles(runner);
    testCopyFile(runner);
    StackSlot text = runner.AllocateString("flow9");
    StackSlot tail = text;
    require(runner.DoSubstring(&text, 0, 4) && runner.DoSubstring(&tail, 4, 1), "take adjacent slices");
    runner.DoPlusString(text, tail);
    require(runner.GetString(text) == parseUtf8("flow9"), "join adjacent slices");

    StackSlot left = runner.AllocateString(unicode_string(32768, 'x'));
    StackSlot right = runner.AllocateString(unicode_string(32768, 'y'));
    runner.DoPlusString(left, right);
    require(!runner.IsErrorReported() && runner.GetString(left) == unicode_string(32768, 'x') + unicode_string(32768, 'y'),
            "join strings across the short-string length boundary");

    StackSlot arr = runner.AllocateArray(65536);
    runner.SetArraySlot(arr, 65535, left);
    StackSlot record = runner.AllocateStruct("TestRecord", 1);
    runner.SetStructSlot(record, 0, arr);
    int root = runner.RegisterRoot(record);
    runner.ForceGC(0, true);
    record = runner.LookupRoot(root);
    arr = runner.GetStructSlot(record, 0);
    require(!runner.IsErrorReported() && runner.GetArraySize(arr) == 65536, "GC preserves a struct and its array");
    require(runner.GetStringSize(runner.GetArraySlot(arr, 65535)) == 65536, "GC preserves the string in the array");
    runner.ReleaseRoot(root);
    runner.flow_err.rdbuf(std::cerr.rdbuf());
}

int main() {
    testMemory();
    testRunner();
    testLegacyFileValues();
#ifdef FLOW_MMAP_HEAP
    for (bool legacy : {false, true}) {
        testNamedSnapshotBudget(16, 16, legacy);
        testNamedSnapshotBudget(8, 32, legacy);
    }
    testSnapshotWithLiveData();
    testYoungSnapshot();
#endif
    testGrowth(256, 384, 128, 262144);
    testGrowth(8, 40, 2, 2 * 1024 * 1024);
    testYoungAllocation();
    testAllocationResults();
    testGenerate();
    puts("Runtime memory tests passed");
}
