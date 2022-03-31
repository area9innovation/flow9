(module
  (type (;0;) (func (param i32) (result i32)))
  (func (;0;) (type 0) (param i32) (result i32)
    (local i32 i32)
    i32.const 1
    local.set 1
    i32.const 0
    local.set 2
    loop  ;; label = @1
      local.get 2
      local.get 1
      local.get 0
      i32.ge_s
      br_if 1 (;@0;)
      local.get 1
      i32.const 3
      i32.rem_s
      i32.const 0
      i32.eq
      local.get 1
      i32.const 5
      i32.rem_s
      i32.const 0
      i32.eq
      i32.or
      if  ;; label = @2
        local.get 2
        local.get 1
        i32.add
        local.set 2
      end
      local.get 1
      i32.const 1
      i32.add
      local.set 1
      br 0 (;@1;)
    end
    local.get 2))
