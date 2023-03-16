(module
  (type (;0;) (func (param i32) (result i32)))
  (type (;1;) (func (result i32)))
  (func (;0;) (type 0) (param i32) (result i32)
    block  ;; label = @1
      local.get 0
      i32.const 2
      i32.ge_s
      br_if 0 (;@1;)
      local.get 0
      return
    end
    local.get 0
    i32.const -1
    i32.add
    call 0
    local.get 0
    i32.mul)
  (func (;1;) (type 1) (result i32)
    i32.const 2
    call 0)
  (table (;0;) 0 funcref)
  (memory (;0;) 1)
  (export "memory" (memory 0))
  (export "_Z3faci" (func 0))
  (export "main" (func 1)))
