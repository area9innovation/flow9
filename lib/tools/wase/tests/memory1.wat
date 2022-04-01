(module
  (type (;0;) (func))
  (func (;0;) (type 0)
    (local i32 i32 i32 i32 i32 i32 i32 i64 i64 i64 i64 i64 i64 i64)
    memory.size
    local.set 0
    i32.const 1
    memory.grow
    local.set 1
    i32.const 128
    i32.const 42
    i32.const 0
    memory.fill
    i32.const 128
    i32.const 0
    i32.const 256
    memory.copy
    i32.const 0
    i32.load
    local.set 2
    i32.const 0
    i32.load8_s
    local.set 3
    i32.const 0
    i32.load8_u
    local.set 4
    i32.const 0
    i32.load16_s
    local.set 5
    i32.const 0
    i32.load16_u
    local.set 6
    i32.const 0
    i64.load
    local.set 7
    i32.const 0
    i64.load8_s
    local.set 8
    i32.const 0
    i64.load8_u
    local.set 9
    i32.const 0
    i64.load16_s
    local.set 10
    i32.const 0
    i64.load16_u
    local.set 11
    i32.const 0
    i64.load32_s
    local.set 12
    i32.const 0
    i64.load32_u
    local.set 13
    i32.const 0
    i32.const 32
    i32.store
    i32.const 0
    i32.const 32
    i32.store8
    i32.const 0
    i32.const 32
    i32.store16
    i32.const 0
    local.get 8
    i64.store
    i32.const 0
    local.get 8
    i64.store8
    i32.const 0
    local.get 8
    i64.store16
    i32.const 0
    local.get 8
    i64.store32)
  (memory (;0;) 1)
  (start 0))
