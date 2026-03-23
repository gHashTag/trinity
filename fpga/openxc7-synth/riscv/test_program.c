// ╔════════════════════════════════════════════════════════════════════════════╗
// ║  TRINITY OS — RISC-V Test Program                                          ║
// ║                                                                              ║
// ║  Simple C program to verify RISC-V CPU is working on FPGA                   ║
// ║  Features:                                                                  ║
// ║  - Fibonacci calculation (tests ALU, branches)                             ║
// ║  - Memory read/write (tests data bus)                                      ║
// ║  - Infinite loop with pattern (tests instructions fetch)                   ║
// ║                                                                              ║
// ║  Compile: riscv32-unknown-elf-gcc -march=rv32imc -mabi=ilp32 -nostdlib    ║
// ║          -Wl,-Ttext=0x0 -o test_program.elf test_program.c                 ║
// ║  Extract: riscv32-unknown-elf-objcopy -O binary test_program.elf prog.bin  ║
// ╚════════════════════════════════════════════════════════════════════════════╝

// Volatile pointer to LED output (memory-mapped I/O)
// Address 0x1000 = LED control register
volatile unsigned int* const LED_CTRL = (unsigned int*)0x1000;

// Simple delay loop
void delay(volatile unsigned int count) {
    while (count--) {
        __asm__ volatile ("nop");
    }
}

// Fibonacci calculation (iterative)
unsigned int fibonacci(unsigned int n) {
    if (n <= 1)
        return n;

    unsigned int a = 0, b = 1, c, i;
    for (i = 2; i <= n; i++) {
        c = a + b;
        a = b;
        b = c;
    }
    return b;
}

// Test memory read/write
unsigned int test_memory(void) {
    volatile unsigned int* test_addr = (unsigned int*)0x2000;

    // Write pattern
    *test_addr = 0xDEADBEEF;
    *test_addr = 0x12345678;

    // Read back
    unsigned int val = *test_addr;

    return (val == 0x12345678) ? 1 : 0;
}

// Main function
void _start(void) {
    unsigned int counter = 0;
    unsigned int fib_result;
    unsigned int mem_ok;

    // Test 1: Fibonacci (ALU + branches)
    fib_result = fibonacci(10);  // Should be 55

    // Test 2: Memory (data bus)
    mem_ok = test_memory();

    // Main loop: LED blink pattern
    while (1) {
        // Pattern: Fibonacci sequence on LED
        counter++;

        // Blink pattern
        for (int i = 0; i < 5; i++) {
            *LED_CTRL = 0x01;  // LED on
            delay(100000);
            *LED_CTRL = 0x00;  // LED off
            delay(100000);
        }

        // Fast blink (fibonacci count)
        for (int i = 0; i < (fib_result % 10); i++) {
            *LED_CTRL = 0x01;
            delay(20000);
            *LED_CTRL = 0x00;
            delay(20000);
        }

        // Longer pause
        delay(500000);
    }
}

// ╔════════════════════════════════════════════════════════════════════════════╗
// ║  EXPECTED BEHAVIOR                                                          ║
// ╠════════════════════════════════════════════════════════════════════════════╣
// ║  1. 5 normal blinks                                                          ║
// ║  2. Fibonacci(10) = 55 → 5 fast blinks                                      ║
// ║  3. Pause                                                                    ║
// ║  4. Repeat forever                                                           ║
// ╚════════════════════════════════════════════════════════════════════════════╝
