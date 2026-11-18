// Benign operations and API boundaries; no malformed bytecode or heap objects.
#include "core/NativeProgram.h"

#include <cstdio>
#include <cstdlib>
#include <sstream>

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

    runner.Init(&program);
    testDataFiles(runner);
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
    puts("Runtime memory tests passed");
}
