(module
  (type $type0 (func (param i32) (result i32)))
  (type $type1 (func (result i32)))
  (table 0 anyfunc)
  (memory 1)
  (export "memory" memory)
  (export "_Z3faci" $func0)
  (export "main" $func1)
  (func $func0 (param $var0 i32) (result i32)
    block $label0
      get_local $var0
      i32.const 2
      i32.ge_s
      br_if $label0
      get_local $var0
      return
    end $label0
    get_local $var0
    i32.const -1
    i32.add
    call $func0
    get_local $var0
    i32.mul
  )
  (func $func1 (result i32)
    i32.const 2
    call $func0
  )
)