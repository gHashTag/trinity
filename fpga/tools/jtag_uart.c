/*
 * jtag_uart.c — JTAG UART via BSCANE2 USER4
 *
 * Communicates with FPGA through JTAG cable using USER4 instruction.
 * Sends a byte, reads back the previous byte (echo).
 *
 * Usage:
 *   sudo ./jtag_uart ping          # Send 0x55, read back
 *   sudo ./jtag_uart send 0x41     # Send 'A', read back
 *   sudo ./jtag_uart echo "Hello"  # Send string, read echoes
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdint.h>
#include "xpc.h"

int verbose = 0;
int trace_usb = 0;
int trace_protocol = 0;

#define IR_LEN   6
#define IR_USER4 0x23   /* USER4 instruction for Xilinx 7-series */
#define DR_LEN   8      /* 8-bit data register */

/* Send raw TMS/TDI bits through JTAG */
static int jtag_scan(const uint8_t *tdi, const uint8_t *tms, uint8_t *tdo, int bits)
{
    return io_scan(tdi, tms, tdo, bits);
}

/* Move TAP to Test-Logic-Reset then Run-Test/Idle */
static void jtag_reset_to_idle(void)
{
    uint8_t tdi[1] = {0};
    uint8_t tms[1] = {0x1F};  /* 5x TMS=1 */
    uint8_t tdo[1] = {0};
    jtag_scan(tdi, tms, tdo, 5);
    tms[0] = 0;
    jtag_scan(tdi, tms, tdo, 1);
}

/* Load IR value: RTI → Shift-IR → shift data → Update-IR → RTI */
static void jtag_load_ir(uint8_t ir_value)
{
    /* RTI → Select-DR → Select-IR → Capture-IR → Shift-IR: TMS=1,1,0,0 */
    uint8_t nav_tdi[1] = {0}, nav_tms[1] = {0x03}, nav_tdo[1] = {0};
    jtag_scan(nav_tdi, nav_tms, nav_tdo, 4);

    /* Shift 6-bit IR, last bit has TMS=1 */
    uint8_t ir_tdi[1] = {0}, ir_tms[1] = {0}, ir_tdo[1] = {0};
    for (int i = 0; i < IR_LEN; i++) {
        if (ir_value & (1 << i))
            ir_tdi[0] |= (1 << i);
        if (i == IR_LEN - 1)
            ir_tms[0] |= (1 << i);
    }
    jtag_scan(ir_tdi, ir_tms, ir_tdo, IR_LEN);

    /* Exit1-IR → Update-IR → RTI: TMS=1,0 */
    uint8_t ex_tdi[1] = {0}, ex_tms[1] = {0x01}, ex_tdo[1] = {0};
    jtag_scan(ex_tdi, ex_tms, ex_tdo, 2);
}

/*
 * Shift 8 bits through DR (USER4 data register).
 * Sends tx_byte, returns received byte.
 */
static uint8_t jtag_dr_shift8(uint8_t tx_byte)
{
    /* RTI → Select-DR → Capture-DR → Shift-DR: TMS=1,0,0 */
    uint8_t nav_tdi[1] = {0}, nav_tms[1] = {0x01}, nav_tdo[1] = {0};
    jtag_scan(nav_tdi, nav_tms, nav_tdo, 3);

    /* Shift 8 bits, last bit TMS=1 */
    uint8_t dr_tdi[1] = {0}, dr_tms[1] = {0}, dr_tdo[1] = {0};
    for (int i = 0; i < DR_LEN; i++) {
        if (tx_byte & (1 << i))
            dr_tdi[0] |= (1 << i);
        if (i == DR_LEN - 1)
            dr_tms[0] |= (1 << i);
    }
    jtag_scan(dr_tdi, dr_tms, dr_tdo, DR_LEN);

    /* Exit1-DR → Update-DR → RTI: TMS=1,0 */
    uint8_t ex_tdi[1] = {0}, ex_tms[1] = {0x01}, ex_tdo[1] = {0};
    jtag_scan(ex_tdi, ex_tms, ex_tdo, 2);

    return dr_tdo[0];
}

static void print_usage(void)
{
    printf("Usage: sudo jtag_uart <command> [args]\n");
    printf("\n");
    printf("Commands:\n");
    printf("  ping              Send 0x55, read back echo\n");
    printf("  send <hex>        Send byte (e.g. 0x41), print echo\n");
    printf("  echo <string>     Send each char, print echoes\n");
    printf("  idcode            Read JTAG IDCODE\n");
    printf("\n");
}

int main(int argc, char **argv)
{
    if (argc < 2) {
        print_usage();
        return 1;
    }

    printf("═══════════════════════════════════════════════\n");
    printf(" TRINITY JTAG UART — BSCANE2 USER4\n");
    printf("═══════════════════════════════════════════════\n\n");

    /* Init USB connection to Xilinx Platform Cable */
    if (io_init(VENDOR_ID, PRODUCT_ID, NULL) < 0) {
        fprintf(stderr, "Failed to connect to Platform Cable USB II\n");
        fprintf(stderr, "  Is cable at PID 0x0008? Run fxload first.\n");
        return 1;
    }
    printf("[1] Connected to Platform Cable USB II\n");

    jtag_reset_to_idle();
    printf("[2] TAP reset → Run-Test/Idle\n");

    if (strcmp(argv[1], "idcode") == 0) {
        /* Read IDCODE */
        jtag_load_ir(0x09);
        uint8_t nav_tdi[1] = {0}, nav_tms[1] = {0x01}, nav_tdo[1] = {0};
        jtag_scan(nav_tdi, nav_tms, nav_tdo, 3);
        uint8_t dr_tdi[4] = {0}, dr_tms[4] = {0,0,0,0x80}, dr_tdo[4] = {0};
        jtag_scan(dr_tdi, dr_tms, dr_tdo, 32);
        uint8_t ex_tdi[1] = {0}, ex_tms[1] = {0x01}, ex_tdo[1] = {0};
        jtag_scan(ex_tdi, ex_tms, ex_tdo, 2);
        uint32_t id = dr_tdo[0] | (dr_tdo[1]<<8) | (dr_tdo[2]<<16) | ((uint32_t)dr_tdo[3]<<24);
        printf("[3] IDCODE: 0x%08X\n", id);
    }
    else if (strcmp(argv[1], "ping") == 0) {
        /* Select USER4 */
        jtag_load_ir(IR_USER4);
        printf("[3] IR = USER4 (0x%02X)\n", IR_USER4);

        /* Send 0x55, read back */
        uint8_t rx1 = jtag_dr_shift8(0x55);
        printf("[4] TX: 0x55 → RX: 0x%02X\n", rx1);

        /* Second read should get 0x55 back (echo) */
        uint8_t rx2 = jtag_dr_shift8(0xAA);
        printf("[5] TX: 0xAA → RX: 0x%02X\n", rx2);

        if (rx2 == 0x55) {
            printf("\n  ✓ ECHO WORKS! BSCANE2 JTAG UART is alive!\n");
        } else {
            printf("\n  ✗ Echo mismatch (expected 0x55, got 0x%02X)\n", rx2);
            printf("    This may be normal on first run. Try again.\n");
        }
    }
    else if (strcmp(argv[1], "send") == 0 && argc >= 3) {
        uint8_t byte = (uint8_t)strtol(argv[2], NULL, 0);
        jtag_load_ir(IR_USER4);
        printf("[3] IR = USER4\n");
        uint8_t rx = jtag_dr_shift8(byte);
        printf("[4] TX: 0x%02X → RX: 0x%02X\n", byte, rx);
    }
    else if (strcmp(argv[1], "echo") == 0 && argc >= 3) {
        const char *msg = argv[2];
        int len = strlen(msg);
        jtag_load_ir(IR_USER4);
        printf("[3] IR = USER4\n");
        printf("[4] Sending \"%s\" (%d bytes):\n", msg, len);

        /* Prime with first byte */
        uint8_t rx = jtag_dr_shift8((uint8_t)msg[0]);
        printf("    TX: '%c' (0x%02X) → RX: 0x%02X (init)\n", msg[0], msg[0], rx);

        for (int i = 1; i < len; i++) {
            rx = jtag_dr_shift8((uint8_t)msg[i]);
            printf("    TX: '%c' (0x%02X) → RX: '%c' (0x%02X)%s\n",
                   msg[i], msg[i], rx, rx,
                   (rx == (uint8_t)msg[i-1]) ? " ✓" : " ✗");
        }

        /* Read last echo */
        rx = jtag_dr_shift8(0x00);
        printf("    TX: 0x00 (flush) → RX: '%c' (0x%02X)%s\n",
               rx, rx,
               (rx == (uint8_t)msg[len-1]) ? " ✓" : " ✗");
    }
    else {
        print_usage();
        io_close();
        return 1;
    }

    printf("\n═══════════════════════════════════════════════\n");
    printf(" φ² + 1/φ² = 3 = TRINITY\n");
    printf("═══════════════════════════════════════════════\n");

    io_close();
    return 0;
}
