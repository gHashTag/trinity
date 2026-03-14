/*
 * jtag_common.c — Shared JTAG primitives for Xilinx 7-series
 *
 * Extracted from jtag_program.c. Used by both jtag_program and jtag_switcher.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "xpc.h"
#include "jtag_common.h"

uint8_t bitrev(uint8_t b)
{
    b = ((b & 0xF0) >> 4) | ((b & 0x0F) << 4);
    b = ((b & 0xCC) >> 2) | ((b & 0x33) << 2);
    return ((b & 0xAA) >> 1) | ((b & 0x55) << 1);
}

int jtag_scan(const uint8_t *tdi, const uint8_t *tms, uint8_t *tdo, int bits)
{
    return io_scan(tdi, tms, tdo, bits);
}

void jtag_reset_to_idle(void)
{
    uint8_t tdi[1] = {0};
    uint8_t tms[1] = {0x1F};  /* 5x TMS=1 → TLR */
    uint8_t tdo[1] = {0};
    jtag_scan(tdi, tms, tdo, 5);
    /* TMS=0 → RTI */
    tms[0] = 0;
    jtag_scan(tdi, tms, tdo, 1);
}

void jtag_runtest(int clocks)
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

void jtag_load_ir(uint8_t ir_value)
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

uint32_t jtag_read_idcode(void)
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

uint8_t *parse_bit_file(const char *filename, int *data_len)
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
            uint32_t len = ((uint32_t)raw[i+1] << 24) | ((uint32_t)raw[i+2] << 16) |
                           ((uint32_t)raw[i+3] << 8) | raw[i+4];
            if (len > 1000000 && len < (uint32_t)file_size) {
                pos = i + 5;
                *data_len = (int)len;
                printf("  Field 'e' at offset 0x%X, length %u bytes (%.1f MB)\n",
                       pos, len, len / (1024.0 * 1024.0));
                break;
            }
        }
    }

    if (pos < 0) {
        fprintf(stderr, "Warning: field 'e' not found, using sync word fallback\n");
        for (int i = 0; i < file_size - 4; i++) {
            if (raw[i] == 0xAA && raw[i+1] == 0x99 && raw[i+2] == 0x55 && raw[i+3] == 0x66) {
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

    /* Verify sync word */
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

    /* Bit-reverse each byte for JTAG TDI shift order */
    uint8_t *bitstream = malloc(*data_len);
    if (!bitstream) { free(raw); return NULL; }

    for (int i = 0; i < *data_len; i++) {
        bitstream[i] = bitrev(raw[pos + i]);
    }

    free(raw);
    return bitstream;
}

int jtag_shift_dr_large(const uint8_t *data, int total_bits)
{
    /* RTI → Select-DR → Capture-DR → Shift-DR: TMS=1,0,0 */
    uint8_t nav_tdi[1] = {0}, nav_tms[1] = {0x01}, nav_tdo[1] = {0};
    jtag_scan(nav_tdi, nav_tms, nav_tdo, 3);

    int sent = 0;
    int chunk_size = 2048;
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

        for (int i = 0; i < chunk; i++) {
            int src = sent + i;
            if (data[src >> 3] & (1 << (src & 7)))
                c_tdi[i >> 3] |= (1 << (i & 7));
        }

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
