/*
 * jtag_program.c — Direct JTAG programmer for Xilinx 7-series via Platform Cable USB II
 *
 * Correct Xilinx 7-series JTAG configuration sequence (per UG470):
 *   1. TLR → RTI
 *   2. Shift-IR: JPROGRAM  (clear config memory)
 *   3. RTI (no extra runtest — dummy words in bitstream provide the wait)
 *   4. Shift-IR: CFG_IN
 *   5. Shift-DR: entire bitstream (field 'e' data including dummy/sync words)
 *   6. Shift-IR: JSTART
 *   7. RTI with 32+ TCK cycles (startup sequence)
 *
 * Usage: sudo ./jtag_program [-v] <bitstream.bit>
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "xpc.h"
#include "jtag_common.h"

int verbose = 0;
int trace_usb = 0;
int trace_protocol = 0;

int main(int argc, char *argv[])
{
    const char *bitfile = NULL;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-v") == 0)
            verbose = 1;
        else
            bitfile = argv[i];
    }

    if (!bitfile) {
        fprintf(stderr, "Usage: %s [-v] <bitstream.bit>\n", argv[0]);
        return 1;
    }

    printf("═══════════════════════════════════════════════\n");
    printf(" TRINITY JTAG PROGRAMMER v2\n");
    printf(" Xilinx 7-series via Platform Cable USB II\n");
    printf(" File: %s\n", bitfile);
    printf("═══════════════════════════════════════════════\n\n");

    /* Parse bitstream — get full field 'e' data */
    int data_len = 0;
    uint8_t *bitstream = parse_bit_file(bitfile, &data_len);
    if (!bitstream) return 1;

    int total_bits = data_len * 8;

    /* Connect to Platform Cable USB II */
    printf("\n[1/6] Connecting to Platform Cable USB II...\n");
    if (io_init(VENDOR_ID, PRODUCT_ID, NULL) != 0) {
        fprintf(stderr, "Failed to connect. Is cable at PID 0x0008? Running sudo?\n");
        free(bitstream);
        return 1;
    }
    printf("  Connected.\n");

    /* Reset TAP → Run-Test/Idle */
    printf("\n[2/6] Resetting JTAG TAP...\n");
    jtag_reset_to_idle();

    /* Read IDCODE */
    uint32_t idcode = jtag_read_idcode();
    printf("  IDCODE: 0x%08X", idcode);
    if ((idcode & 0x0FFFFFFF) == 0x03631093)
        printf(" (XC7A100T ✓)\n");
    else
        printf("\n");

    /* Step 3: JPROGRAM — initiate configuration memory clear */
    printf("\n[3/6] JPROGRAM — clearing configuration...\n");
    jtag_load_ir(IR_JPROGRAM);
    jtag_runtest(10000);  /* ~200μs of TCK cycles for INIT_B */

    /* Step 4: Load CFG_IN — prepare to receive configuration data */
    printf("[4/6] CFG_IN — loading configuration data...\n");
    jtag_load_ir(IR_CFG_IN);

    /* Step 5: Shift entire bitstream through DR */
    printf("[5/6] Sending bitstream (%d bytes = %.1f MB)...\n",
           data_len, data_len / (1024.0 * 1024.0));

    if (jtag_shift_dr_large(bitstream, total_bits) != 0) {
        fprintf(stderr, "Failed to send bitstream\n");
        io_close();
        free(bitstream);
        return 1;
    }

    /* Step 6: JSTART — trigger startup sequence */
    printf("\n[6/6] JSTART — starting configuration...\n");
    jtag_load_ir(IR_JSTART);
    jtag_runtest(256);

    /* Return to TLR for clean state */
    jtag_reset_to_idle();

    /* Verify — read IDCODE to confirm JTAG is still alive */
    uint32_t idcode2 = jtag_read_idcode();

    io_close();
    free(bitstream);

    printf("\n═══════════════════════════════════════════════\n");
    printf(" PROGRAMMING COMPLETE — IDCODE: 0x%08X\n", idcode2);
    printf(" LED D5 should be blinking ~3 Hz\n");
    printf(" φ² + 1/φ² = 3 = TRINITY\n");
    printf("═══════════════════════════════════════════════\n");

    return 0;
}
