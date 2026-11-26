// Tests of FlowStack, the growable stack behind the call stack, the GC array stack and the
// native function tables. Run with run_tests.sh, which builds it with the sanitizers, so a
// buffer freed the wrong way, freed twice or read past its end fails the run.

#include <cstring>
#include "core/CommonTypes.h"

#include <cstdio>
#include <string>

static int failures = 0;

static void fail(const std::string &message) {
    failures++;
    printf("FAIL: %s\n", message.c_str());
}

static void testGrowth() {
    FlowStack<int, 4> stack;
    for (int i = 0; i < 1000; ++i)
        stack.push_back(i);
    bool kept = stack.size() == 1000 && stack.capacity() == 1024;
    for (int i = 0; i < 1000; ++i)
        kept = kept && stack[i] == i;
    if (!kept)
        fail("push_back should keep every value while the stack grows");

    // One request several doublings above the capacity
    stack.resize(5000);
    if (stack.size() != 5000 || stack.capacity() != 8192 || stack[999] != 999)
        fail("resize should grow over several doublings and keep the values");
    stack[4999] = 4999;

    stack.resize(10);
    stack.reserve(20000);
    if (stack.size() != 10 || stack.capacity() != 32768 || stack[9] != 9)
        fail("reserve should grow the capacity and keep the size and values");
}

static void testPopAndCopy() {
    FlowStack<int, 4> stack;
    for (int i = 0; i < 1000; ++i)
        stack.push_back(i);
    if (stack.top() != 999 || stack.pop() != 999 || *stack.pop_ptr(2) != 997 || stack.size() != 997)
        fail("pop should take values from the top");

    FlowStack<int, 4> other;
    other.push_back(-1);
    other.push_all(stack, 990); // All but the top 990 values, as stack snapshots skip frames
    if (other.size() != 8 || other[0] != -1 || other[1] != 0 || other.top() != 6)
        fail("push_all should append all but the top skip values");

    other.swap(stack);
    if (stack.size() != 8 || other.size() != 997 || other[996] != 996)
        fail("swap should exchange the contents");

    stack.clear();
    stack.resize(5);
    if (stack.size() != 5 || stack.capacity() != 8)
        fail("clear should start again from the minimum size");
}

// The JIT reads the native function tables, which hold pointers, straight from the buffer.
static void testPointers() {
    int values[300];
    FlowStack<int*, 128> stack;
    for (int i = 0; i < 300; ++i)
        stack.push_back(&values[i]);
    bool kept = stack.size() == 300 && stack.capacity() == 512;
    for (int i = 0; i < 300; ++i)
        kept = kept && stack[i] == &values[i];
    if (!kept)
        fail("a stack of pointers should keep them while it grows");
}

struct ThrowingItem {
    static bool fail_construction;
    int value = 0;
    ThrowingItem() { if (fail_construction) throw 1; }
};
bool ThrowingItem::fail_construction = false;

// If clear() cannot allocate, the stack keeps its buffer, so its destructor frees it once.
static void testFailedClear() {
    FlowStack<ThrowingItem, 4> stack;
    stack.push_ptr(10)->value = 7;
    ThrowingItem::fail_construction = true;
    bool thrown = false;
    try {
        stack.clear();
    } catch (int) {
        thrown = true;
    }
    ThrowingItem::fail_construction = false;
    if (!thrown || stack.size() != 10 || stack[0].value != 7)
        fail("a failed clear should leave the stack as it was");
}

int main() {
    testGrowth();
    testPopAndCopy();
    testPointers();
    testFailedClear();
    printf(failures ? "%d FlowStack tests FAILED\n" : "All FlowStack tests passed\n", failures);
    return failures != 0;
}
