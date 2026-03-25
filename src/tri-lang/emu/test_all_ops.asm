; TRI-27 Test - All Opcodes
; =============================================

; Load initial values
LDI t0, 42
LDI t1, 10

; TERNARY opcodes test
DOT t2, t0, t1         ; t2 = DOT(t0, t1)
BIND t3, t0, t1         ; t3 = BIND(t0, t1)
BUNDLE2 t4, t0, t1       ; t4 = BUNDLE2(t0, t1)
BUNDLE3 t5, t0, t1, t2 ; t5 = BUNDLE3(t0, t1, t2)

; SACRED constants test
PHI_CONST t6               ; t6 = φ
PI_CONST t7                ; t7 = π
E_CONST t8                 ; t8 = e

; SACRED arithmetic test
SACR add, t9, t0      ; t9 = t9 + t0
SACR mul, t10, t0     ; t10 = t10 * t0
SACR div, t11, t0     ; t11 = t11 / t0
SACR pow, t12, t0     ; t12 = t12 ^ t0

; Control test
HALT

; Verify ternary values are loaded
NOP
