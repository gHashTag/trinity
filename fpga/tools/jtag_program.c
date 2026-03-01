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
#include <unistd.h>
#include <stdint.h>
#include "xpc.h"

int verbose = 0;
int trace_usb = 0;
int trace_protocol = 0;

/* Xilinx 7-series JTAG IR instructions (6-bit) */
#define IR_LEN      6
#define IR_IDCODE   0x09
#define IR_JPROGRAM 0x0B
#define IR_CFG_IN   0x05
#define IR_JSTART   0x0C
#define IR_BYPASS   0x3F

/* Send raw TMS/TDI bits through JTAG */
static int jtag_scan(const uint8_t *tdi, const uint8_t *tms, uint8_t *tdo, int bits)
{
    return io_scan(tdi, tms, tdo, bits);
}

/* Move TAP to Test-Logic-Reset (5x TMS=1) then Run-Test/Idle (1x TMS=0) */
static void jtag_reset_to_idle(void)
{
    uint8_t tdi[1] = {0};
    uint8_t tms[1] = {0x1F};  /* bits: 11111 → 5x TMS=1 */
    uint8_t tdo[1] = {0};
    jtag_scan(tdi, tms, tdo, 5);
    /* TMS=0 → RTI */
    tms[0] = 0;
    jtag_scan(tdi, tms, tdo, 1);
}

/* Run N TCK cycles in Run-Test/Idle */
static void jtag_runtest(int clocks)
{
    while (clocks > 0) {
        int n = (clocks > 64) ? 64 : clocks;
        uint8_t tdi[8] = {0};
        uint8_t tms[8] = {0};
        uint8_t tdo[8] = {0};
        jtag_scan(tdi, tms, tdo, n);
        clocks -= n;
    }
}

/*
 * From Run-Test/Idle, navigate to Shift-IR and shift IR data.
 * RTI →(TMS=1)→ Select-DR →(TMS=1)→ Select-IR →(TMS=0)→ Capture-IR →(TMS=0)→ Shift-IR
 * Then shift IR_LEN bits (last bit with TMS=1 to exit)
 * Exit1-IR →(TMS=1)→ Update-IR →(TMS=0)→ RTI
 */
static void jtag_load_ir(uint8_t ir_value)
{
    /* RTI → Select-DR → Select-IR → Capture-IR → Shift-IR: TMS=1,1,0,0 */
    uint8_t nav_tdi[1] = {0}, nav_tms[1] = {0x03}, nav_tdo[1] = {0};
    jtag_scan(nav_tdi, nav_tms, nav_tdo, 4);

    /* Shift 6-bit IR, last bit has TMS=1 to exit to Exit1-IR */
    uint8_t ir_tdi[1] = {0}, ir_tms[1] = {0}, ir_tdo[1] = {0};

    for (int i = 0; i < IR_LEN; i++) {
        if (ir_value & (1 << i))
            ir_tdi[0] |= (1 << i);
        if (i == IR_LEN - 1)
            ir_tms[0] |= (1 << i);  /* TMS=1 on last bit */
    }
    jtag_scan(ir_tdi, ir_tms, ir_tdo, IR_LEN);

    /* Exit1-IR → Update-IR → RTI: TMS=1,0 */
    uint8_t ex_tdi[1] = {0}, ex_tms[1] = {0x01}, ex_tdo[1] = {0};
    jtag_scan(ex_tdi, ex_tms, ex_tdo, 2);
}

/* Read 32-bit IDCODE */
static uint32_t jtag_read_idcode(void)
{
    jtag_load_ir(IR_IDCODE);

    /* RTI → Select-DR → Capture-DR → Shift-DR: TMS=1,0,0 */
    uint8_t nav_tdi[1] = {0}, nav_tms[1] = {0x01}, nav_tdo[1] = {0};
    jtag_scan(nav_tdi, nav_tms, nav_tdo, 3);

    /* Shift 32 bits out, last bit TMS=1 */
    uint8_t dr_tdi[4] = {0};
    uint8_t dr_tms[4] = {0, 0, 0, 0x80};  /* bit 31: TMS=1 */
    uint8_t dr_tdo[4] = {0};
    jtag_scan(dr_tdi, dr_tms, dr_tdo, 32);

    /* Exit1-DR → Update-DR → RTI: TMS=1,0 */
    uint8_t ex_tdi[1] = {0}, ex_tms[1] = {0x01}, ex_tdo[1] = {0};
    jtag_scan(ex_tdi, ex_tms, ex_tdo, 2);

    return dr_tdo[0] | (dr_tdo[1] << 8) | (dr_tdo[2] << 16) | ((uint32_t)dr_tdo[3] << 24);
}

/*
 * Parse Xilinx .bit file — extract FULL bitstream from field 'e'
 * Field 'e' contains: 4-byte big-endian length + raw bitstream data
 * The raw data includes dummy words, bus-width detect, sync word, and configuration data.
 * ALL of it must be sent via CFG_IN.
 */
static uint8_t *parse_bit_file(const char *filename, int *data_len)
{
    FILE *f = fopen(filename, "rb");
    if (!f) {
        fprintf(stderr, "Cannot open %s\n", filename);
        return NULL;
    }

    fseek(f, 0, SEEK_END);
    long file_size = ftell(f);
    fseek(f, 0, SEEK_SET);

    uint8_t *raw = malloc(file_size);
    if (!raw) { fclose(f); return NULL; }
    fread(raw, 1, file_size, f);
    fclose(f);

    /* Find field 'e' (bitstream data field) */
    int pos = -1;
    for (int i = 0; i < file_size - 5; i++) {
        if (raw[i] == 0x65) {  /* field 'e' marker */
            /* Next 4 bytes = big-endian length */
            uint32_t len = ((uint32_t)raw[i+1] << 24) | ((uint32_t)raw[i+2] << 16) |
                           ((uint32_t)raw[i+3] << 8) | raw[i+4];
            if (len > 1000000 && len < (uint32_t)file_size) {
                pos = i + 5;  /* data starts after marker + 4-byte length */
                *data_len = (int)len;
                printf("  Field 'e' at offset 0x%X, length %u bytes (%.1f MB)\n",
                       pos, len, len / (1024.0 * 1024.0));
                break;
            }
        }
    }

    if (pos < 0) {
        /* Fallback: find sync word and include everything before it */
        fprintf(stderr, "Warning: field 'e' not found, using sync word fallback\n");
        for (int i = 0; i < file_size - 4; i++) {
            if (raw[i] == 0xAA && raw[i+1] == 0x99 && raw[i+2] == 0x55 && raw[i+3] == 0x66) {
                /* Go back to find 0xFF padding */
                pos = i;
                while (pos > 0 && raw[pos - 1] == 0xFF) pos--;
                *data_len = file_size - pos;
                break;
            }
        }
        if (pos < 0) {
            fprintf(stderr, "Cannot find bitstream data\n");
            free(raw);
            return NULL;
        }
    }

    /* Verify sync word exists in data */
    int found_sync = 0;
    for (int i = 0; i < *data_len - 4; i++) {
        if (raw[pos+i] == 0xAA && raw[pos+i+1] == 0x99 &&
            raw[pos+i+2] == 0x55 && raw[pos+i+3] == 0x66) {
            printf("  Sync word 0xAA995566 at offset +0x%X\n", i);
            found_sync = 1;
            break;
        }
    }
    if (!found_sync) {
        fprintf(stderr, "Warning: sync word not found in bitstream data\n");
    }

    /*
     * Bit-reverse each byte for JTAG TDI shift order.
     * Xilinx .bit files are MSB-first, but io_scan shifts LSB-first per byte.
     */
    uint8_t *bitstream = malloc(*data_len);
    if (!bitstream) { free(raw); return NULL; }

    for (int i = 0; i < *data_len; i++) {
        uint8_t b = raw[pos + i];
        b = ((b & 0xF0) >> 4) | ((b & 0x0F) << 4);
        b = ((b & 0xCC) >> 2) | ((b & 0x33) << 2);
        b = ((b & 0xAA) >> 1) | ((b & 0x55) << 1);
        bitstream[i] = b;
    }

    free(raw);
    return bitstream;
}

/*
 * Shift large data block through DR (bitstream programming).
 * Enters Shift-DR, sends all data, exits on last bit.
 */
static int jtag_shift_dr_large(const uint8_t *data, int total_bits)
{
    /* RTI → Select-DR → Capture-DR → Shift-DR: TMS=1,0,0 */
    uint8_t nav_tdi[1] = {0}, nav_tms[1] = {0x01}, nav_tdo[1] = {0};
    jtag_scan(nav_tdi, nav_tms, nav_tdo, 3);

    /* Send data in chunks */
    int sent = 0;
    int chunk_size = 2048;  /* bits per USB transfer */
    int last_pct = -1;

    while (sent < total_bits) {
        int remaining = total_bits - sent;
        int chunk = (remaining > chunk_size) ? chunk_size : remaining;
        int byte_len = (chunk + 7) / 8;
        int is_last = (sent + chunk >= total_bits);

        uint8_t *c_tdi = calloc(byte_len, 1);
        uint8_t *c_tms = calloc(byte_len, 1);
        uint8_t *c_tdo = calloc(byte_len, 1);
        if (!c_tdi || !c_tms || !c_tdo) {
            free(c_tdi); free(c_tms); free(c_tdo);
            return -1;
        }

        /* Copy TDI data from bitstream */
        for (int i = 0; i < chunk; i++) {
            int src = sent + i;
            if (data[src >> 3] & (1 << (src & 7)))
                c_tdi[i >> 3] |= (1 << (i & 7));
        }

        /* On last bit of entire transfer: TMS=1 to exit Shift-DR */
        if (is_last && chunk > 0) {
            c_tms[(chunk - 1) >> 3] |= (1 << ((chunk - 1) & 7));
        }

        jtag_scan(c_tdi, c_tms, c_tdo, chunk);

        free(c_tdi);
        free(c_tms);
        free(c_tdo);

        sent += chunk;

        int pct = (int)((100LL * sent) / total_bits);
        if (pct / 5 != last_pct / 5) {
            printf("\r  Sending: %d%%", pct);
            fflush(stdout);
            last_pct = pct;
        }
    }
    printf("\r  Sending: 100%% — done.          \n");

    /* Exit1-DR → Update-DR → RTI: TMS=1,0 */
    uint8_t ex_tdi[1] = {0}, ex_tms[1] = {0x01}, ex_tdo[1] = {0};
    jtag_scan(ex_tdi, ex_tms, ex_tdo, 2);

    return 0;
}

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

    /*
     * === XILINX 7-SERIES JTAG CONFIGURATION (per UG470) ===
     *
     * Step 1: Load JPROGRAM → clears configuration memory
     * Step 2: Immediately load CFG_IN (no extra runtest needed!)
     *         The dummy 0xFF words at start of bitstream provide
     *         the wait time while config memory clears.
     * Step 3: Shift entire bitstream through DR
     * Step 4: Load JSTART
     * Step 5: Run 32+ TCK in RTI for startup
     */

    /* Step 3: JPROGRAM — initiate configuration memory clear */
    printf("\n[3/6] JPROGRAM — clearing configuration...\n");
    jtag_load_ir(IR_JPROGRAM);

    /*
     * Per UG470: After JPROGRAM, go to RTI.
     * The bitstream's dummy words (0xFFFFFFFF) at the start of field 'e'
     * provide the delay while configuration memory clears.
     * However, we need some TCK cycles for INIT_B to assert.
     */
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

    /* Run at least 32 TCK cycles in RTI for startup sequence (CCLK in JTAG mode) */
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
