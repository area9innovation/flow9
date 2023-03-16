(module
  (type (;0;) (func (result i32)))
  (func (;0;) (type 0) (result i32)
    (local i32)
    i32.const 0
    i32.load offset=4
    i32.const 16
    i32.sub
    local.tee 0
    i32.const 0
    i32.store offset=12
    local.get 0
    i32.const 0
    i32.store offset=8
    block  ;; label = @1
      loop  ;; label = @2
        local.get 0
        i32.load offset=8
        i32.const 9
        i32.gt_s
        br_if 1 (;@1;)
        local.get 0
        local.get 0
        i32.load offset=8
        i32.const 1
        i32.add
        i32.store offset=8
        br 0 (;@2;)
      end
    end
    local.get 0
    i32.load offset=8)
  (table (;0;) 0 funcref)
  (memory (;0;) 1)
  (export "memory" (memory 0))
  (export "main" (func 0)))
