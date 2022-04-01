(module
  (type (;0;) (func))
  (import "module" "memory" (memory (;0;) 1))
  (func (;0;) (type 0)
    (local i32)
    i32.const 0
    i32.load
    local.set 0
    local.get 0
    i32.const 1
    i32.add
    drop)
  (start 0))
