#include "core/NativeProgram.h"
#include "core/RunnerMacros.h"

NativeProgram *load_native_program() {
    printf("The runner is not compiled with a native program.\n");
    exit(1);
    return NULL;
}
