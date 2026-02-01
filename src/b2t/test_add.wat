;; Test WASM module for B2T converter
;; Simple add function: (a + b) * 2

(module
  ;; Function that adds two numbers and doubles the result
  (func $add_double (param $a i32) (param $b i32) (result i32)
    local.get $a
    local.get $b
    i32.add
    i32.const 2
    i32.mul
  )

  ;; Export the function
  (export "add_double" (func $add_double))

  ;; Simple function that returns 42
  (func $answer (result i32)
    i32.const 42
  )

  (export "answer" (func $answer))
)
