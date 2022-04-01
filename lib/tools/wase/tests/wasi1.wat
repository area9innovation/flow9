(module
  (type (;0;) (func (param i32 i32 i32 i32) (result i32)))
  (type (;1;) (func))
  (import "wasi_snapshot_preview1" "fd_write" (func (;0;) (type 0)))
  (func (;1;) (type 1)
    i32.const 4
    i32.const 32
    i32.store
    i32.const 8
    i32.const 13
    i32.store
    i32.const 1
    i32.const 4
    i32.const 1
    i32.const 20
    call 0
    drop)
  (memory (;0;) 1)
  (export "memory" (memory 0))
  (export "_start" (func 1))
  (data (;0;) (i32.const 32) "Hello, world!"))
