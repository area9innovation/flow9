(module
  (type (;0;) (func))
  (import "module" "mytable" (table (;0;) 1 funcref))
  (import "module" "mytable2" (table (;1;) 1 funcref))
  (import "module" "myexterns" (table (;2;) 5 10 externref))
  (func (;0;) (type 0)
    (local funcref funcref externref i32 i32)
    i32.const 0
    table.get 0
    local.set 0
    i32.const 1
    table.get 0
    local.set 1
    i32.const 5
    table.get 2
    local.set 2
    table.size 0
    local.set 3
    local.get 0
    i32.const 2
    table.grow 1
    local.set 4
    i32.const 2
    local.get 1
    table.set 1
    i32.const 2
    i32.const 0
    i32.const 0
    table.copy 0 1
    i32.const 4
    local.get 0
    i32.const 0
    table.fill 1)
  (memory (;0;) 1)
  (start 0))
