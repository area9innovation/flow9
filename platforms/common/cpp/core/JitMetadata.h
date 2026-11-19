#ifndef FLOW_JIT_METADATA_H
#define FLOW_JIT_METADATA_H

#include <cstring>
#include "CommonTypes.h"
#include <asmjit/asmjit.h>

namespace jit_metadata {

inline bool valid_frame(int args, int locals, unsigned capacity) {
    return unsigned(args) <= FLOW_MAX_FRAME_ARGS && unsigned(locals) <= FLOW_MAX_FRAME_LOCALS &&
           unsigned(args + locals) <= capacity;
}

inline bool valid_slot(int index, size_t count) {
    return unsigned(index) <= FLOW_MAX_SLOT_INDEX && size_t(index) < count;
}

template<class Globals>
bool valid_global(int index, const Globals &globals, unsigned capacity) {
    return valid_slot(index, globals.size()) && unsigned(index) < capacity &&
           globals[index]->name != "--end--";
}

template<class StructMap>
typename StructMap::mapped_type find_struct(int id, const StructMap &definitions) {
    if (unsigned(id) > FLOW_MAX_STRUCT_ID)
        return typename StructMap::mapped_type();
    return safeMapAt(definitions, id);
}

inline bool valid_reserve_position(bool is_function, size_t index) {
    return is_function && index == 0;
}

// CTailCall has an integer operand. This only bounds the count used by code
// generation; it does not establish callee arity or the number of live values.
inline bool valid_tail_count(int count, unsigned capacity) {
    return count >= 0 && unsigned(count) <= capacity;
}

// base contains the data stack base and is available as scratch. The frame
// has already been validated; the live top may equal the last allowed top.
inline void branch_if_locals_fit(asmjit::X86Assembler &as, asmjit::X86Gp base, asmjit::X86Gp top,
                                 int capacity, int locals, asmjit::Label available) {
    as.lea(base, asmjit::x86::ptr(base, (capacity - locals) * STACK_SLOT_SIZE));
    as.cmp(top, base);
    as.short_().jbe(available);
}

} // namespace jit_metadata

#endif
