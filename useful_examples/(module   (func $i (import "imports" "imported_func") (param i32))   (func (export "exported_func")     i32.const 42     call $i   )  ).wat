(module
  (func (export "fail_me") (result i32)
    i32.const 1
    i32.const 0
    i32.div_s
  )
)

(module
  (global $g (import "js" "global") (mut i32))
  (func (export "getGlobal") (result i32)
    (global.get $g)
  )
  (func (export "incGlobal")
    (global.set $g (i32.add (global.get $g) (i32.const 1)))
  )
)


(module
  (memory (import "js" "mem") 1)
  (func (export "accumulate") (param $ptr i32) (param $len i32) (result i32)
    (local $end i32)
    (local $sum i32)
    (local.set $end
      (i32.add
        (local.get $ptr)
        (i32.mul
          (local.get $len)
          (i32.const 4))))
    (block $break
      (loop $top
        (br_if $break
          (i32.eq
            (local.get $ptr)
            (local.get $end)))
        (local.set $sum
          (i32.add
            (local.get $sum)
            (i32.load
              (local.get $ptr))))
        (local.set $ptr
          (i32.add
            (local.get $ptr)
            (i32.const 4)))
        (br $top)
      )
    )
    (local.get $sum)
  )
)

(module
  (func $i (import "imports" "imported_func") (param i32))
  (func (export "exported_func")
    i32.const 42
    call $i
  )
)

(module
  (import "js" "tbl" (table 2 anyfunc))
  (func $f42 (result i32) i32.const 42)
  (func $f83 (result i32) i32.const 83)
  (elem (i32.const 0) $f42 $f83)
)

(module
  (func $i (import "imports" "imported_func") (param i32))
  (func (export "exported_func")
    i32.const 42
    call $i
  )
 )
