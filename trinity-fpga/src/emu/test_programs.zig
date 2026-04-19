// Test programs for TRI-27 assembler

pub const PROGRAM_NOP =
    \\nop
    \\halt
;

pub const PROGRAM_ARITHMETIC =
    \\# Arithmetic test
    \\ldi r0, 10
    \\ldi r1, 20
    \\add r2, r0, r1    ; r2 = 10 + 20 = 30
    \\sub r3, r2, r0    ; r3 = 30 - 10 = 20
    \\mul r4, r3, r1    ; r4 = 20 * 20 = 400
    \\div r5, r4, r0    ; r5 = 400 / 10 = 40
    \\inc r6
    \\inc r6            ; r6 = 2
    \\dec r7
    \\dec r7            ; r7 = -2 (underflow)
    \\halt
;

pub const PROGRAM_LOGIC =
    \\# Logic test
    \\ldi r0, 0xFF
    \\ldi r1, 0x0F
    \\and r2, r0, r1    ; r2 = 0x0F (15)
    \\or r3, r2, r1     ; r3 = 0x0F | 0x0F = 0x0F
    \\xor r4, r0, r1    ; r4 = 0xFF ^ 0x0F = 0xF0
    \\not r5             ; r5 should be tested
    \\halt
;

pub const PROGRAM_LOOPS =
    \\# Loop test
    \\ldi r0, 0
    \\ldi r1, 5
    \\loop:
    \\  inc r0
    \\  jz r1, end      ; if r1 == 0, jump to end
    \\  dec r1
    \\  jmp loop
    \\end:
    \\halt
;

pub const PROGRAM_SHIFTS =
    \\# Shift test
    \\ldi r0, 1
    \\ldi r1, 4
    \\shl r2, r1        ; r2 = 1 << 4 = 16
    \\shr r3, r2        ; r3 = 16 >> 4 = 1
    \\halt
;

pub const PROGRAM_CONTROL_FLOW =
    \\# Control flow with labels
    \\ldi r0, 1
    \\loop:
    \\ldi r1, 0
    \\jz r1, loop       ; infinite loop (r1 always 0)
    \\halt
;
