#include <cassert>
#include "core/JitMetadata.h"

using namespace jit_metadata;

static void test_metadata() {
    const unsigned capacity = 100000;
    assert(valid_frame(0, 0, capacity));
    assert(valid_frame(255, 65535, capacity));
    assert(!valid_frame(256, 0, capacity));
    assert(!valid_frame(0, 65536, capacity));
    assert(!valid_frame(-1, 1, capacity));
    assert(!valid_frame(1, -1, capacity));
    assert(!valid_frame(2, 3, 4));

    assert(!valid_slot(0, 0));
    assert(valid_slot(2, 3));
    assert(!valid_slot(3, 3));
    assert(!valid_slot(-1, 3));
    assert(valid_slot(65535, 65790));
    assert(!valid_slot(65536, 65790));

    struct Global { std::string name; } value = {"value"}, end = {"--end--"};
    std::vector<Global*> globals = { &value, &value, &end };
    assert(valid_global(1, globals, 2));
    assert(!valid_global(1, globals, 1));
    assert(!valid_global(2, globals, capacity));
    assert(!valid_global(3, globals, capacity));
    assert(!valid_global(-1, globals, capacity));

    int definition = 0;
    const std::map<int, int*> structs = {{65535, &definition}, {65536, &definition}};
    assert(find_struct(65535, structs) == &definition);
    assert(!find_struct(1, structs));
    assert(!find_struct(65536, structs));

    assert(valid_reserve_position(true, 0));
    assert(!valid_reserve_position(true, 1));
    assert(!valid_reserve_position(false, 0));

    assert(valid_tail_count(0, capacity));
    assert(valid_tail_count(capacity, capacity));
    assert(!valid_tail_count(capacity + 1, capacity));
    assert(!valid_tail_count(-1, capacity));
}

// Exercise only the comparison emitted by the JIT, without entering a Flow
// function or writing any stack slots.
static void test_local_capacity() {
    using namespace asmjit;
    using namespace asmjit::x86;
    JitRuntime runtime;
    CodeHolder code;
    code.init(runtime.getCodeInfo());
    X86Assembler as(&code);
    Label fits = as.newLabel();
    const int capacity = 8, locals = 3;
#ifdef _WIN32
    branch_if_locals_fit(as, rcx, rdx, capacity, locals, fits);
#else
    branch_if_locals_fit(as, rdi, rsi, capacity, locals, fits);
#endif
    as.mov(eax, 0);
    as.ret();
    as.bind(fits);
    as.mov(eax, 1);
    as.ret();

    int (*can_reserve)(StackSlot *, StackSlot *) = nullptr;
    Error err = runtime.add(&can_reserve, &code);
    assert(err == kErrorOk);
    StackSlot stack[capacity];
    assert(can_reserve(stack, stack + 5)); // exactly three slots left
    assert(!can_reserve(stack, stack + 6)); // one slot short
    runtime.release(can_reserve);
}

int main() {
    test_metadata();
    test_local_capacity();
    std::cout << "JIT metadata validators and stack capacity passed" << std::endl;
}
