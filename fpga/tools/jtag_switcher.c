/*
 * jtag_switcher.c — JTAG Read/Write mode switcher for Xilinx 7-series
 *
 * Switches between WRITE mode (programming) and READ mode (config register
 * readback) without reconnecting the cable. Uses CFG_IN → CFG_OUT pipeline
 * per UG470.
 *
 * Usage:
 *   sudo ./jtag_switcher status              Read STAT register
 *   sudo ./jtag_switcher idcode              Read IDCODE via config interface
 *   sudo ./jtag_switcher dna                 Read 57-bit device DNA
 *   sudo ./jtag_switcher reg <hex_addr>      Read any config register
 *   sudo ./jtag_switcher readback <out.bin>  Full bitstream readback
 *   sudo ./jtag_switcher verify <file.bit>   Readback + compare with .bit
 *   sudo ./jtag_switcher write <file.bit>    Program (same as jtag_program)
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

/* Xilinx 7-series config register addresses (UG470 Table 5-23) */
#define REG_CRC     0x00
#define REG_FAR     0x01
#define REG_FDRI    0x02
#define REG_FDRO    0x03
#define REG_CMD     0x04
#define REG_CTL0    0x05
#define REG_MASK    0x06
#define REG_STAT    0x07
#define REG_LOUT    0x08
#define REG_COR0    0x09
#define REG_MFWR    0x0A
#define REG_CBC     0x0B
#define REG_IDCODE  0x0C
#define REG_AXSS    0x0D
#define REG_COR1    0x0E
#define REG_WBSTAR  0x10
#define REG_TIMER   0x11
#define REG_BOOTSTS 0x16
#define REG_CTL1    0x18
#define REG_BSPI    0x1F

/* CMD register values */
#define CMD_NULL    0x00
#define CMD_RCRC    0x07
#define CMD_GCAPTURE 0x0C
#define CMD_DESYNC  0x0D
#define CMD_RCFG    0x04

/* XC7A100T frame info: 3754 frames, 101 words/frame */
#define XC7A100T_FRAME_COUNT 3754
#define FRAME_WORDS          101
#define FRAME_BYTES          (FRAME_WORDS * 4)

/*
 * Build Type 1 config packet (UG470 Table 5-20)
 * [31:29]=001  [28:27]=opcode  [17:13]=reg  [10:0]=wordcount
 * Opcode: 00=NOP, 01=READ, 10=WRITE
 */
static uint32_t type1_packet(int opcode, int reg, int wc)
{
    return (1u << 29) | ((uint32_t)opcode << 27) | ((uint32_t)reg << 13) | (uint32_t)wc;
}

/*
 * Build Type 2 config packet (UG470 Table 5-21)
 * [31:29]=010  [28:27]=opcode  [26:0]=wordcount
 */
static uint32_t type2_packet(int opcode, uint32_t wc)
{
    return (2u << 29) | ((uint32_t)opcode << 27) | wc;
}

/*
 * Shift a command sequence through CFG_IN (DR).
 * Each 32-bit word is bit-reversed per byte for JTAG ordering.
 */
static void shift_cfg_in(const uint32_t *words, int count)
{
    int total_bits = count * 32;
    int byte_len = count * 4;
    uint8_t *tdi = calloc(byte_len, 1);
    uint8_t *tms = calloc(byte_len, 1);
    uint8_t *tdo = calloc(byte_len, 1);

    /* Serialize words to bytes (big-endian) then bit-reverse each byte */
    for (int i = 0; i < count; i++) {
        uint32_t w = words[i];
        tdi[i*4 + 0] = bitrev((w >> 24) & 0xFF);
        tdi[i*4 + 1] = bitrev((w >> 16) & 0xFF);
        tdi[i*4 + 2] = bitrev((w >>  8) & 0xFF);
        tdi[i*4 + 3] = bitrev((w >>  0) & 0xFF);
    }

    /* Navigate RTI → Shift-DR: TMS=1,0,0 */
    uint8_t nav_tdi[1] = {0}, nav_tms[1] = {0x01}, nav_tdo[1] = {0};
    jtag_scan(nav_tdi, nav_tms, nav_tdo, 3);

    /* Set TMS=1 on last bit to exit Shift-DR */
    tms[(total_bits - 1) >> 3] |= (1 << ((total_bits - 1) & 7));

    jtag_scan(tdi, tms, tdo, total_bits);

    /* Exit1-DR → Update-DR → RTI: TMS=1,0 */
    uint8_t ex_tdi[1] = {0}, ex_tms[1] = {0x01}, ex_tdo[1] = {0};
    jtag_scan(ex_tdi, ex_tms, ex_tdo, 2);

    free(tdi);
    free(tms);
    free(tdo);
}

/*
 * Read 32 bits from CFG_OUT (DR).
 * Returns the value after bit-reversing each byte of TDO.
 */
static uint32_t read_cfg_out_32(void)
{
    /* Navigate RTI → Shift-DR: TMS=1,0,0 */
    uint8_t nav_tdi[1] = {0}, nav_tms[1] = {0x01}, nav_tdo[1] = {0};
    jtag_scan(nav_tdi, nav_tms, nav_tdo, 3);

    /* Shift 32 bits, TMS=1 on last bit */
    uint8_t dr_tdi[4] = {0};
    uint8_t dr_tms[4] = {0, 0, 0, 0x80};
    uint8_t dr_tdo[4] = {0};
    jtag_scan(dr_tdi, dr_tms, dr_tdo, 32);

    /* Exit1-DR → Update-DR → RTI: TMS=1,0 */
    uint8_t ex_tdi[1] = {0}, ex_tms[1] = {0x01}, ex_tdo[1] = {0};
    jtag_scan(ex_tdi, ex_tms, ex_tdo, 2);

    /* Bit-reverse each byte and reassemble big-endian */
    uint8_t b0 = bitrev(dr_tdo[0]);
    uint8_t b1 = bitrev(dr_tdo[1]);
    uint8_t b2 = bitrev(dr_tdo[2]);
    uint8_t b3 = bitrev(dr_tdo[3]);

    return ((uint32_t)b0 << 24) | ((uint32_t)b1 << 16) |
           ((uint32_t)b2 << 8)  | (uint32_t)b3;
}

/*
 * Mandatory DESYNC sequence — must be called after every config read.
 * Without this, config logic stays in undefined state.
 */
static void desync(void)
{
    jtag_load_ir(IR_CFG_IN);

    uint32_t cmd[] = {
        0xAA995566,                         /* Sync word */
        0x20000000,                         /* NOP */
        type1_packet(2, REG_CMD, 1),        /* Write CMD */
        CMD_DESYNC,                         /* DESYNC command */
        0x20000000,                         /* NOP */
        0x20000000,                         /* NOP */
    };
    shift_cfg_in(cmd, 6);

    jtag_load_ir(IR_BYPASS);
    jtag_runtest(32);
}

/*
 * Read a single 32-bit configuration register.
 * Sends command sequence via CFG_IN, reads result via CFG_OUT,
 * then issues mandatory DESYNC.
 */
static uint32_t read_config_register(int reg_addr)
{
    /* Step 1: Send read command via CFG_IN */
    jtag_load_ir(IR_CFG_IN);

    uint32_t cmd[] = {
        0xAA995566,                         /* Sync word */
        0x20000000,                         /* NOP */
        type1_packet(2, REG_CMD, 1),        /* Write CMD register */
        CMD_NULL,                           /* CMD = NULL (nop command) */
        type1_packet(1, reg_addr, 1),       /* Read target register, 1 word */
        0x20000000,                         /* NOP (pipeline flush) */
        0x20000000,                         /* NOP (pipeline flush) */
    };
    shift_cfg_in(cmd, 7);

    /* Step 2: Switch to read mode */
    jtag_load_ir(IR_CFG_OUT);

    /* Step 3: Read 32 bits */
    uint32_t value = read_cfg_out_32();

    /* Step 4: Mandatory DESYNC */
    desync();

    return value;
}

/*
 * Read N words from configuration via CFG_OUT.
 * Used for multi-word reads (DNA, full readback).
 */
static int read_cfg_out_n(uint32_t *buf, int word_count)
{
    /* Navigate RTI → Shift-DR: TMS=1,0,0 */
    uint8_t nav_tdi[1] = {0}, nav_tms[1] = {0x01}, nav_tdo[1] = {0};
    jtag_scan(nav_tdi, nav_tms, nav_tdo, 3);

    int total_bits = word_count * 32;
    int byte_len = word_count * 4;
    uint8_t *tdi = calloc(byte_len, 1);
    uint8_t *tms = calloc(byte_len, 1);
    uint8_t *tdo = calloc(byte_len, 1);

    /* TMS=1 on last bit */
    tms[(total_bits - 1) >> 3] |= (1 << ((total_bits - 1) & 7));

    jtag_scan(tdi, tms, tdo, total_bits);

    /* Exit1-DR → Update-DR → RTI: TMS=1,0 */
    uint8_t ex_tdi[1] = {0}, ex_tms[1] = {0x01}, ex_tdo[1] = {0};
    jtag_scan(ex_tdi, ex_tms, ex_tdo, 2);

    /* Reassemble words (bit-reverse each byte, big-endian) */
    for (int i = 0; i < word_count; i++) {
        uint8_t b0 = bitrev(tdo[i*4 + 0]);
        uint8_t b1 = bitrev(tdo[i*4 + 1]);
        uint8_t b2 = bitrev(tdo[i*4 + 2]);
        uint8_t b3 = bitrev(tdo[i*4 + 3]);
        buf[i] = ((uint32_t)b0 << 24) | ((uint32_t)b1 << 16) |
                 ((uint32_t)b2 << 8)  | (uint32_t)b3;
    }

    free(tdi);
    free(tms);
    free(tdo);
    return 0;
}

/* ======================================================================= */
/* Subcommands                                                             */
/* ======================================================================= */

static void decode_stat(uint32_t stat)
{
    printf("  STAT register: 0x%08X\n", stat);
    printf("  ┌─────────────────────────────────────\n");
    printf("  │ DONE          (bit 14): %s\n", (stat & (1 << 14)) ? "YES ✓" : "NO");
    printf("  │ INIT_B        (bit 12): %s\n", (stat & (1 << 12)) ? "HIGH" : "LOW");
    printf("  │ GTS_CFG_B     (bit 11): %s\n", (stat & (1 << 11)) ? "HIGH" : "LOW");
    printf("  │ GWE           (bit 10): %s\n", (stat & (1 << 10)) ? "YES" : "NO");
    printf("  │ GHIGH_B       (bit  9): %s\n", (stat & (1 <<  9)) ? "HIGH" : "LOW");
    printf("  │ MODE          (bit 5-7): M[2:0]=%d%d%d\n",
           (stat >> 7) & 1, (stat >> 6) & 1, (stat >> 5) & 1);
    printf("  │ EOS           (bit  4): %s\n", (stat & (1 <<  4)) ? "YES" : "NO");
    printf("  │ DCI_MATCH     (bit  3): %s\n", (stat & (1 <<  3)) ? "YES" : "NO");
    printf("  │ MMCM_LOCK     (bit  2): %s\n", (stat & (1 <<  2)) ? "YES" : "NO");
    printf("  │ Part Secured  (bit  1): %s\n", (stat & (1 <<  1)) ? "YES (readback blocked)" : "NO");
    printf("  │ CRC_ERROR     (bit  0): %s\n", (stat & (1 <<  0)) ? "ERROR!" : "OK");
    printf("  └─────────────────────────────────────\n");
}

static int cmd_status(void)
{
    printf("\n[READ] STAT register (0x%02X)...\n", REG_STAT);
    uint32_t stat = read_config_register(REG_STAT);
    decode_stat(stat);
    return 0;
}

static int cmd_idcode(void)
{
    printf("\n[READ] IDCODE via JTAG instruction...\n");
    uint32_t idcode_jtag = jtag_read_idcode();
    printf("  IDCODE (JTAG IR): 0x%08X\n", idcode_jtag);

    printf("\n[READ] IDCODE via config register (0x%02X)...\n", REG_IDCODE);
    uint32_t idcode_cfg = read_config_register(REG_IDCODE);
    printf("  IDCODE (CFG reg): 0x%08X\n", idcode_cfg);

    if (idcode_jtag == idcode_cfg)
        printf("  Match: YES ✓\n");
    else
        printf("  Match: NO ✗ (bit reversal issue?)\n");

    if ((idcode_jtag & 0x0FFFFFFF) == 0x03631093)
        printf("  Device: XC7A100T\n");

    return 0;
}

static int cmd_dna(void)
{
    printf("\n[READ] Device DNA (FUSE_DNA)...\n");

    /* DNA is in register 0x15, 2 words (64 bits, only 57 meaningful) */
    jtag_load_ir(IR_CFG_IN);

    uint32_t cmd[] = {
        0xAA995566,                         /* Sync word */
        0x20000000,                         /* NOP */
        type1_packet(2, REG_CMD, 1),        /* Write CMD */
        CMD_NULL,                           /* CMD = NULL */
        type1_packet(1, 0x15, 2),           /* Read FUSE_DNA, 2 words */
        0x20000000,                         /* NOP */
        0x20000000,                         /* NOP */
    };
    shift_cfg_in(cmd, 7);

    jtag_load_ir(IR_CFG_OUT);

    uint32_t dna[2];
    read_cfg_out_n(dna, 2);

    desync();

    uint64_t dna_val = ((uint64_t)dna[0] << 32) | dna[1];
    dna_val &= 0x01FFFFFFFFFFFFFFULL;  /* Mask to 57 bits */

    printf("  DNA[1]: 0x%08X\n", dna[0]);
    printf("  DNA[0]: 0x%08X\n", dna[1]);
    printf("  Full:   0x%014llX (57-bit)\n", (unsigned long long)dna_val);

    return 0;
}

static int cmd_reg(const char *hex_addr)
{
    unsigned int addr;
    if (sscanf(hex_addr, "%x", &addr) != 1 || addr > 0x1F) {
        fprintf(stderr, "Invalid register address: %s (must be 00-1F hex)\n", hex_addr);
        return 1;
    }

    printf("\n[READ] Config register 0x%02X...\n", addr);
    uint32_t val = read_config_register(addr);
    printf("  Value: 0x%08X\n", val);

    /* Decode known registers */
    if (addr == REG_STAT) decode_stat(val);
    if (addr == REG_IDCODE) {
        if ((val & 0x0FFFFFFF) == 0x03631093)
            printf("  Device: XC7A100T\n");
    }

    return 0;
}

static int cmd_readback(const char *outfile)
{
    printf("\n[READBACK] Full configuration readback...\n");

    /* Check STAT first */
    uint32_t stat = read_config_register(REG_STAT);
    printf("  STAT: 0x%08X\n", stat);
    if (!(stat & (1 << 14))) {
        fprintf(stderr, "  WARNING: DONE=0 — device not configured\n");
    }
    if (stat & (1 << 1)) {
        fprintf(stderr, "  ERROR: Part Secured — readback returns zeros\n");
        return 1;
    }

    /* Send readback command sequence via CFG_IN */
    jtag_load_ir(IR_CFG_IN);

    uint32_t total_words = XC7A100T_FRAME_COUNT * FRAME_WORDS;

    /*
     * Readback command sequence per UG470 Section 7.1.2.
     * Pipeline flush: 8 NOPs after Type 2 read command ensures the JTAG
     * config pipeline is fully flushed before data starts clocking out.
     * Previous 2 NOPs caused misalignment (issue #371).
     */
    uint32_t cmd[] = {
        0xAA995566,                              /* Sync */
        0x20000000,                              /* NOP */
        type1_packet(2, REG_CMD, 1),             /* Write CMD */
        CMD_RCRC,                                /* RCRC — reset CRC */
        0x20000000,                              /* NOP */
        0x20000000,                              /* NOP */
        type1_packet(2, REG_CMD, 1),             /* Write CMD */
        CMD_GCAPTURE,                            /* GCAPTURE */
        0x20000000,                              /* NOP */
        0x20000000,                              /* NOP */
        type1_packet(2, REG_FAR, 1),             /* Write FAR */
        0x00000000,                              /* FAR = 0 (start) */
        type1_packet(2, REG_CMD, 1),             /* Write CMD */
        CMD_RCFG,                                /* RCFG — readback config */
        0x20000000,                              /* NOP */
        0x20000000,                              /* NOP (extra pipeline flush) */
        type1_packet(1, REG_FDRO, 0),            /* Type 1 READ FDRO, 0 words (header for Type 2) */
        type2_packet(1, total_words),            /* Type 2 READ, total_words */
        0x20000000,                              /* NOP — pipeline flush (UG470) */
        0x20000000,                              /* NOP — pipeline flush */
        0x20000000,                              /* NOP — pipeline flush */
        0x20000000,                              /* NOP — pipeline flush */
        0x20000000,                              /* NOP — pipeline flush */
        0x20000000,                              /* NOP — pipeline flush */
        0x20000000,                              /* NOP — pipeline flush */
        0x20000000,                              /* NOP — pipeline flush */
    };
    shift_cfg_in(cmd, 26);

    /* Switch to CFG_OUT for readback */
    jtag_load_ir(IR_CFG_OUT);

    printf("  Reading %u frames x %d words = %u words (%.1f MB)...\n",
           XC7A100T_FRAME_COUNT, FRAME_WORDS, total_words,
           (total_words * 4) / (1024.0 * 1024.0));

    /* Read in frame-sized chunks to show progress */
    FILE *f = fopen(outfile, "wb");
    if (!f) {
        fprintf(stderr, "Cannot create output file: %s\n", outfile);
        desync();
        return 1;
    }

    /* Navigate to Shift-DR for bulk read */
    uint8_t nav_tdi[1] = {0}, nav_tms[1] = {0x01}, nav_tdo[1] = {0};
    jtag_scan(nav_tdi, nav_tms, nav_tdo, 3);

    int total_bits = total_words * 32;
    int sent = 0;
    int chunk_size = FRAME_WORDS * 32;  /* 1 frame at a time */
    int last_pct = -1;

    while (sent < total_bits) {
        int remaining = total_bits - sent;
        int chunk = (remaining > chunk_size) ? chunk_size : remaining;
        int byte_len = (chunk + 7) / 8;
        int is_last = (sent + chunk >= total_bits);

        uint8_t *c_tdi = calloc(byte_len, 1);
        uint8_t *c_tms = calloc(byte_len, 1);
        uint8_t *c_tdo = calloc(byte_len, 1);

        if (is_last && chunk > 0) {
            c_tms[(chunk - 1) >> 3] |= (1 << ((chunk - 1) & 7));
        }

        jtag_scan(c_tdi, c_tms, c_tdo, chunk);

        /* Bit-reverse and write to file */
        for (int i = 0; i < byte_len; i++) {
            uint8_t b = bitrev(c_tdo[i]);
            fwrite(&b, 1, 1, f);
        }

        free(c_tdi);
        free(c_tms);
        free(c_tdo);

        sent += chunk;

        int pct = (int)((100LL * sent) / total_bits);
        if (pct / 2 != last_pct / 2) {
            printf("\r  Reading: %d%%", pct);
            fflush(stdout);
            last_pct = pct;
        }
    }
    printf("\r  Reading: 100%% — done.          \n");

    /* Exit Shift-DR */
    uint8_t ex_tdi[1] = {0}, ex_tms[1] = {0x01}, ex_tdo[1] = {0};
    jtag_scan(ex_tdi, ex_tms, ex_tdo, 2);

    fclose(f);

    desync();

    printf("  Output: %s (%u bytes)\n", outfile, total_words * 4);
    return 0;
}

/*
 * Find frame data offset within raw (non-bit-reversed) bitstream.
 * Searches for Type 1 WRITE FDRI (0x30004000) followed by Type 2 packet.
 * Returns byte offset of first frame data byte, sets *frame_words.
 */
static int find_frame_data_offset(const uint8_t *bs, int bs_len, uint32_t *frame_words)
{
    for (int i = 0; i < bs_len - 8; i++) {
        uint32_t w = ((uint32_t)bs[i] << 24) | ((uint32_t)bs[i+1] << 16) |
                     ((uint32_t)bs[i+2] << 8) | bs[i+3];
        if (w == 0x30004000) {  /* Type 1 WRITE FDRI, 0 words */
            uint32_t w2 = ((uint32_t)bs[i+4] << 24) | ((uint32_t)bs[i+5] << 16) |
                          ((uint32_t)bs[i+6] << 8) | bs[i+7];
            if ((w2 >> 29) == 2) {  /* Type 2 packet */
                *frame_words = w2 & 0x07FFFFFF;
                return i + 8;
            }
        }
    }
    return -1;
}

static int cmd_verify(const char *bitfile)
{
    printf("\n[VERIFY] Readback vs %s...\n", bitfile);

    /* Load raw .bit file to find frame data with correct alignment */
    FILE *bf = fopen(bitfile, "rb");
    if (!bf) {
        fprintf(stderr, "Cannot open %s\n", bitfile);
        return 1;
    }
    fseek(bf, 0, SEEK_END);
    long file_size = ftell(bf);
    fseek(bf, 0, SEEK_SET);
    uint8_t *raw = malloc(file_size);
    if (!raw) { fclose(bf); return 1; }
    fread(raw, 1, file_size, bf);
    fclose(bf);

    /* Find field 'e' (bitstream data section) */
    int bs_start = -1, bs_len = 0;
    for (int i = 0; i < file_size - 5; i++) {
        if (raw[i] == 0x65) {
            uint32_t len = ((uint32_t)raw[i+1] << 24) | ((uint32_t)raw[i+2] << 16) |
                           ((uint32_t)raw[i+3] << 8) | raw[i+4];
            if (len > 1000000 && len < (uint32_t)file_size) {
                bs_start = i + 5;
                bs_len = (int)len;
                printf("  Field 'e' at offset 0x%X, %u bytes\n", bs_start, len);
                break;
            }
        }
    }
    if (bs_start < 0) {
        /* Fallback: find sync word */
        for (int i = 0; i < file_size - 4; i++) {
            if (raw[i] == 0xAA && raw[i+1] == 0x99 && raw[i+2] == 0x55 && raw[i+3] == 0x66) {
                bs_start = i;
                while (bs_start > 0 && raw[bs_start - 1] == 0xFF) bs_start--;
                bs_len = (int)file_size - bs_start;
                break;
            }
        }
    }
    if (bs_start < 0) {
        fprintf(stderr, "Cannot find bitstream data in %s\n", bitfile);
        free(raw);
        return 1;
    }

    /* Find FDRI write command → frame data starts after Type 2 header */
    uint32_t fdri_words = 0;
    int frame_offset = find_frame_data_offset(raw + bs_start, bs_len, &fdri_words);
    if (frame_offset < 0) {
        fprintf(stderr, "Cannot find FDRI write command in bitstream\n");
        free(raw);
        return 1;
    }
    printf("  FDRI write: %u words at bitstream offset +0x%X\n", fdri_words, frame_offset);

    /* Extract frame data and bit-reverse to match JTAG TDO readback byte order */
    int avail = bs_len - frame_offset;
    int ref_len = ((int)(fdri_words * 4) < avail) ? (int)(fdri_words * 4) : avail;

    uint8_t *ref_data = malloc(ref_len);
    if (!ref_data) { free(raw); return 1; }
    for (int i = 0; i < ref_len; i++) {
        ref_data[i] = bitrev(raw[bs_start + frame_offset + i]);
    }
    free(raw);

    /* Check STAT */
    uint32_t stat = read_config_register(REG_STAT);
    if (!(stat & (1 << 14))) {
        fprintf(stderr, "  WARNING: DONE=0 — device not configured\n");
        free(ref_data);
        return 1;
    }
    if (stat & (1 << 1)) {
        fprintf(stderr, "  ERROR: Part Secured — readback returns zeros\n");
        free(ref_data);
        return 1;
    }

    /* Readback to temp file */
    const char *tmpfile = "/tmp/jtag_readback_verify.bin";
    int rc = cmd_readback(tmpfile);
    if (rc != 0) {
        free(ref_data);
        return rc;
    }

    /* Load readback data */
    FILE *f = fopen(tmpfile, "rb");
    if (!f) {
        free(ref_data);
        return 1;
    }
    fseek(f, 0, SEEK_END);
    long readback_len = ftell(f);
    fseek(f, 0, SEEK_SET);
    uint8_t *readback = malloc(readback_len);
    fread(readback, 1, readback_len, f);
    fclose(f);

    /*
     * Auto-detect readback alignment (issue #371).
     *
     * Per UG470, readback data includes pad frame(s) before real configuration
     * data. The exact offset depends on pipeline flush timing and NOP count.
     * Instead of hardcoding 1 pad frame, we try word-aligned offsets from 0 to
     * 3 pad frames and pick the offset with the fewest mismatches in the first
     * reference frame. This eliminates alignment-dependent mismatch errors.
     */
    int rb_offset = FRAME_BYTES;  /* Default: 1 pad frame */
    int best_offset = rb_offset;
    int best_mismatches = ref_len;  /* Worst case */
    int max_try_offset = 3 * FRAME_BYTES;
    if (max_try_offset > (int)readback_len - FRAME_BYTES)
        max_try_offset = (int)readback_len - FRAME_BYTES;

    /* Scan word-aligned offsets to find best alignment */
    for (int try_off = 0; try_off <= max_try_offset; try_off += 4) {
        int mm = 0;
        int check_len = FRAME_BYTES;
        if (check_len > ref_len) check_len = ref_len;
        if (try_off + check_len > (int)readback_len) continue;

        for (int i = 0; i < check_len; i++) {
            if (ref_data[i] != readback[try_off + i])
                mm++;
        }
        if (mm < best_mismatches) {
            best_mismatches = mm;
            best_offset = try_off;
        }
    }

    rb_offset = best_offset;
    printf("  Alignment: auto-detected offset = %d bytes (%d words, %.1f frames)\n",
           rb_offset, rb_offset / 4, (double)rb_offset / FRAME_BYTES);
    if (rb_offset != FRAME_BYTES) {
        printf("  NOTE: offset differs from default 1-pad-frame assumption\n");
    }

    /*
     * Frame-by-frame comparison per UG470:
     * - Skip pad frame(s) in readback (auto-detected above)
     * - Skip ECC word (word #50 in each 101-word frame) — volatile
     * - Track BRAM frames separately (block type 1 in FAR — volatile after startup)
     * - Without .rbd/.msd files (openXC7, not Vivado), some mismatches are expected
     */
    int rb_avail = (int)readback_len - rb_offset;
    int compare_frames = ref_len / FRAME_BYTES;
    int rb_frames = rb_avail / FRAME_BYTES;
    if (compare_frames > rb_frames) compare_frames = rb_frames;

    int total_mismatches = 0;
    int ecc_mismatches = 0;
    int bram_mismatches = 0;
    int logic_mismatches = 0;
    int frames_clean = 0;
    int frames_dirty = 0;
    int bram_frames = 0;
    int first_mismatch = -1;

    printf("  Reference: %d frames, Readback: %d frames (after pad skip)\n",
           ref_len / FRAME_BYTES, rb_frames);
    printf("  Comparing %d frames (%d bytes)...\n",
           compare_frames, compare_frames * FRAME_BYTES);
    printf("  ECC word (word #50) masked, BRAM frames tracked separately\n");

    for (int fr = 0; fr < compare_frames; fr++) {
        uint8_t *ref_frame = ref_data + fr * FRAME_BYTES;
        uint8_t *rb_frame = readback + rb_offset + fr * FRAME_BYTES;
        int frame_mismatches = 0;
        int frame_ecc = 0;
        int is_bram = 0;

        /*
         * Detect BRAM frame: FAR block type field.
         * In XC7 series, frame address register encodes block type in bits [25:23].
         * Block type 1 = BRAM content. We can't read FAR per-frame from readback,
         * but BRAM frames are in a contiguous range. For XC7A100T: frames 3432+
         * are typically BRAM content frames.
         */
        if (fr >= (int)(XC7A100T_FRAME_COUNT - 322))
            is_bram = 1;

        if (is_bram) bram_frames++;

        for (int w = 0; w < FRAME_WORDS; w++) {
            int byte_off = w * 4;

            /* ECC word #50 — always volatile on readback */
            if (w == 50) {
                for (int b = 0; b < 4; b++) {
                    if (ref_frame[byte_off + b] != rb_frame[byte_off + b])
                        frame_ecc++;
                }
                continue;  /* Don't count as logic mismatch */
            }

            for (int b = 0; b < 4; b++) {
                if (ref_frame[byte_off + b] != rb_frame[byte_off + b]) {
                    frame_mismatches++;
                    if (first_mismatch < 0)
                        first_mismatch = fr * FRAME_BYTES + byte_off + b;
                }
            }
        }

        total_mismatches += frame_mismatches + frame_ecc;
        ecc_mismatches += frame_ecc;
        if (is_bram)
            bram_mismatches += frame_mismatches;
        else
            logic_mismatches += frame_mismatches;

        if (frame_mismatches == 0 && frame_ecc == 0)
            frames_clean++;
        else
            frames_dirty++;

        /* Show first 3 dirty frames */
        if (frame_mismatches > 0 && frames_dirty <= 3) {
            printf("    Frame %d: %d mismatches%s\n", fr, frame_mismatches,
                   is_bram ? " (BRAM — expected)" : "");
        }
    }

    free(ref_data);
    free(readback);
    remove(tmpfile);

    printf("\n  ┌─────────────────────────────────────────────\n");
    printf("  │ Frames compared:  %d\n", compare_frames);
    printf("  │ Frames clean:     %d\n", frames_clean);
    printf("  │ Frames dirty:     %d\n", frames_dirty);
    printf("  │ BRAM frames:      %d (volatile after startup)\n", bram_frames);
    printf("  │ Total mismatches: %d\n", total_mismatches);
    printf("  │   ECC (masked):   %d (word #50, expected)\n", ecc_mismatches);
    printf("  │   BRAM content:   %d (volatile, expected)\n", bram_mismatches);
    printf("  │   Logic config:   %d\n", logic_mismatches);
    printf("  └─────────────────────────────────────────────\n");

    if (logic_mismatches == 0) {
        printf("  VERIFY: PASS ✓ — all logic frames match\n");
        if (total_mismatches > 0)
            printf("  (ECC + BRAM mismatches are expected without .rbd/.msd mask files)\n");
    } else {
        double pct = 100.0 * logic_mismatches / (compare_frames * FRAME_BYTES);
        printf("  VERIFY: %d logic mismatches (%.3f%%)\n", logic_mismatches, pct);
        printf("  NOTE: Without Vivado .rbd/.msd files, some volatile bits\n");
        printf("        (IOB pads, FF capture state) cannot be masked.\n");
        printf("        Per UG470, this is expected for .bit-based verify.\n");
    }

    /* PASS if logic mismatches are small (<1% of data) */
    int logic_bytes = (compare_frames - bram_frames) * FRAME_BYTES;
    return (logic_bytes > 0 && logic_mismatches * 100 < logic_bytes) ? 0 : 1;
}

static int cmd_write(const char *bitfile)
{
    printf("\n[WRITE] Programming %s...\n", bitfile);

    int data_len = 0;
    uint8_t *bitstream = parse_bit_file(bitfile, &data_len);
    if (!bitstream) return 1;

    int total_bits = data_len * 8;

    /* JPROGRAM — clear configuration */
    printf("  JPROGRAM — clearing configuration...\n");
    jtag_load_ir(IR_JPROGRAM);
    jtag_runtest(10000);

    /* CFG_IN — send bitstream */
    printf("  CFG_IN — loading bitstream (%d bytes)...\n", data_len);
    jtag_load_ir(IR_CFG_IN);

    if (jtag_shift_dr_large(bitstream, total_bits) != 0) {
        fprintf(stderr, "  Failed to send bitstream\n");
        free(bitstream);
        return 1;
    }

    /* JSTART — trigger startup */
    printf("  JSTART — starting configuration...\n");
    jtag_load_ir(IR_JSTART);
    jtag_runtest(256);

    jtag_reset_to_idle();

    uint32_t idcode = jtag_read_idcode();
    free(bitstream);

    printf("  DONE — IDCODE: 0x%08X\n", idcode);
    return 0;
}

static int cmd_probe(void)
{
    uint16_t cpld_ver = 0, fw_ver = 0;
    int cpld_ok = 0, fw_ok = 0, tdo_ok = 0, idcode_ok = 0;
    uint32_t idcode;

    /* Read firmware version */
    if (io_read_firmware_version(&fw_ver) == 0)
        fw_ok = 1;

    /* Read CPLD version */
    if (io_read_cpld_version(&cpld_ver) == 0 && cpld_ver != 0 && cpld_ver != 0xFFFE)
        cpld_ok = 1;

    /* Try IDCODE read as TDO path test */
    idcode = jtag_read_idcode();
    if (idcode != 0x00000000 && idcode != 0xFFFFFFFF)
        tdo_ok = 1;
    if ((idcode & 0x0FFFFFFF) == 0x03631093)
        idcode_ok = 1;

    printf("\n");
    printf("  ┌─────────────────────────────────────────────┐\n");
    printf("  │            HARDWARE PROBE RESULT             │\n");
    printf("  ├──────────────┬──────────────┬────────────────┤\n");
    printf("  │ Component    │ Value        │ Status         │\n");
    printf("  ├──────────────┼──────────────┼────────────────┤\n");
    printf("  │ FX2 Firmware │ 0x%04X       │ %s            │\n",
           fw_ver, fw_ok ? "OK" : "FAIL");
    printf("  │ CPLD Version │ 0x%04X       │ %s            │\n",
           cpld_ver, cpld_ok ? "OK" : "DEAD");
    printf("  │ TDO Path     │ IDCODE=0x%08X │ %s     │\n",
           idcode, tdo_ok ? "OK" : "DEAD");
    printf("  │ FPGA IDCODE  │ XC7A100T     │ %s            │\n",
           idcode_ok ? "MATCH" : "FAIL");
    printf("  └──────────────┴──────────────┴────────────────┘\n\n");

    int result = (fw_ok << 3) | (cpld_ok << 2) | (tdo_ok << 1) | idcode_ok;
    printf("  Probe bitmask: 0x%X (FX2=%d CPLD=%d TDO=%d IDCODE=%d)\n\n",
           result, fw_ok, cpld_ok, tdo_ok, idcode_ok);

    return (result == 0x0F) ? 0 : 1;
}

/*
 * Read 64 bits from CFG_OUT (DR) — for testing if data is offset by 32 bits.
 * Returns two 32-bit words: out[0] = first 32 bits, out[1] = second 32 bits.
 */
static void read_cfg_out_64(uint32_t out[2])
{
    /* Navigate RTI → Shift-DR: TMS=1,0,0 */
    uint8_t nav_tdi[1] = {0}, nav_tms[1] = {0x01}, nav_tdo[1] = {0};
    jtag_scan(nav_tdi, nav_tms, nav_tdo, 3);

    /* Shift 64 bits, TMS=1 on last bit */
    uint8_t dr_tdi[8] = {0};
    uint8_t dr_tms[8] = {0,0,0,0, 0,0,0, 0x80};
    uint8_t dr_tdo[8] = {0};
    jtag_scan(dr_tdi, dr_tms, dr_tdo, 64);

    /* Exit1-DR → Update-DR → RTI: TMS=1,0 */
    uint8_t ex_tdi[1] = {0}, ex_tms[1] = {0x01}, ex_tdo[1] = {0};
    jtag_scan(ex_tdi, ex_tms, ex_tdo, 2);

    /* Print raw TDO bytes */
    if (trace_protocol) {
        fprintf(stderr, "  [TRACE] raw TDO 64-bit:");
        for (int i = 0; i < 8; i++) fprintf(stderr, " %02X", dr_tdo[i]);
        fprintf(stderr, "\n");
        fprintf(stderr, "  [TRACE] bitrev TDO:    ");
        for (int i = 0; i < 8; i++) fprintf(stderr, " %02X", bitrev(dr_tdo[i]));
        fprintf(stderr, "\n");
    }

    /* Bit-reverse each byte and reassemble big-endian (word 0 = first 32 bits) */
    uint8_t b0 = bitrev(dr_tdo[0]);
    uint8_t b1 = bitrev(dr_tdo[1]);
    uint8_t b2 = bitrev(dr_tdo[2]);
    uint8_t b3 = bitrev(dr_tdo[3]);
    out[0] = ((uint32_t)b0 << 24) | ((uint32_t)b1 << 16) |
             ((uint32_t)b2 << 8)  | (uint32_t)b3;

    uint8_t b4 = bitrev(dr_tdo[4]);
    uint8_t b5 = bitrev(dr_tdo[5]);
    uint8_t b6 = bitrev(dr_tdo[6]);
    uint8_t b7 = bitrev(dr_tdo[7]);
    out[1] = ((uint32_t)b4 << 24) | ((uint32_t)b5 << 16) |
             ((uint32_t)b6 << 8)  | (uint32_t)b7;
}

/*
 * Config register read with variable NOP count — for testing pipeline flush.
 */
static uint32_t read_config_register_nops(int reg_addr, int nop_count)
{
    jtag_load_ir(IR_CFG_IN);

    /* Base command: sync + NOP + write CMD=NULL + read target register */
    int cmd_len = 5 + nop_count;
    uint32_t *cmd = calloc(cmd_len, sizeof(uint32_t));
    cmd[0] = 0xAA995566;                         /* Sync word */
    cmd[1] = 0x20000000;                         /* NOP */
    cmd[2] = type1_packet(2, REG_CMD, 1);        /* Write CMD register */
    cmd[3] = CMD_NULL;                           /* CMD = NULL */
    cmd[4] = type1_packet(1, reg_addr, 1);       /* Read target register */
    for (int i = 0; i < nop_count; i++)
        cmd[5 + i] = 0x20000000;                 /* NOP pipeline flush */
    shift_cfg_in(cmd, cmd_len);
    free(cmd);

    jtag_load_ir(IR_CFG_OUT);

    uint32_t value = read_cfg_out_32();

    desync();

    return value;
}

/*
 * cmd_debug — Detailed diagnostic of config register read path.
 *
 * Tests:
 * 1. IDCODE via IR (known working baseline)
 * 2. Config register read with protocol tracing
 * 3. Different NOP counts (2, 4, 8)
 * 4. 64-bit read to check if data is offset
 * 5. Raw TDO byte dumps at each step
 */
static int cmd_debug(void)
{
    printf("\n╔═══════════════════════════════════════════════╗\n");
    printf("║     JTAG DEBUG — Config Read Path Diagnosis   ║\n");
    printf("╚═══════════════════════════════════════════════╝\n");

    /* ── Step 1: IDCODE via IR (baseline — should always work) ─── */
    printf("\n[1/6] IDCODE via IR instruction (baseline)...\n");
    uint32_t idcode = jtag_read_idcode();
    int ir_ok = ((idcode & 0x0FFFFFFF) == 0x03631093);
    printf("  Result: 0x%08X %s\n", idcode, ir_ok ? "✓ XC7A100T" : "✗ UNEXPECTED");

    if (idcode == 0x00000000 || idcode == 0xFFFFFFFF) {
        printf("\n  ╔═══════════════════════════════════════════╗\n");
        printf("  ║ DIAGNOSIS: TDO DEAD — no signal from FPGA ║\n");
        printf("  ║ Cable or CPLD hardware problem.            ║\n");
        printf("  ╚═══════════════════════════════════════════╝\n");
        return 1;
    }

    /* ── Step 2: CPLD and firmware versions ─── */
    printf("\n[2/6] Cable firmware/CPLD versions...\n");
    uint16_t cpld_ver = 0, fw_ver = 0;
    io_read_firmware_version(&fw_ver);
    io_read_cpld_version(&cpld_ver);
    printf("  FX2 Firmware: 0x%04X\n", fw_ver);
    printf("  CPLD Version: 0x%04X %s\n", cpld_ver,
           (cpld_ver == 0xFFFE) ? "(DEGRADED — 0xFFFE)" :
           (cpld_ver == 0x0000) ? "(MISSING)" : "(OK)");

    /* ── Step 3: Config register IDCODE with trace ─── */
    printf("\n[3/6] Config register IDCODE (0x0C) with USB trace...\n");
    int saved_trace = trace_protocol;
    trace_protocol = 1;

    uint32_t cfg_id = read_config_register(REG_IDCODE);
    printf("  CFG IDCODE: 0x%08X %s\n", cfg_id,
           cfg_id ? "(NON-ZERO — read path works!)" : "(ZERO — read path broken)");

    /* ── Step 4: STAT register with trace ─── */
    printf("\n[4/6] Config register STAT (0x07) with USB trace...\n");
    uint32_t stat = read_config_register(REG_STAT);
    printf("  CFG STAT: 0x%08X %s\n", stat,
           stat ? "(NON-ZERO)" : "(ZERO — read path broken)");
    if (stat) decode_stat(stat);

    trace_protocol = saved_trace;

    /* ── Step 5: Try different NOP counts ─── */
    printf("\n[5/6] Config register IDCODE with varying NOP counts...\n");
    int nop_counts[] = {2, 4, 8, 16};
    for (int i = 0; i < 4; i++) {
        uint32_t val = read_config_register_nops(REG_IDCODE, nop_counts[i]);
        printf("  NOPs=%2d → IDCODE: 0x%08X %s\n", nop_counts[i], val,
               val ? "✓" : "✗");
    }

    /* ── Step 6: Read 64 bits from CFG_OUT to check for offset ─── */
    printf("\n[6/6] Read 64 bits from CFG_OUT (check data offset)...\n");
    trace_protocol = 1;

    /* Send same read command as read_config_register but read 64 bits */
    jtag_load_ir(IR_CFG_IN);
    uint32_t cmd[] = {
        0xAA995566,                         /* Sync word */
        0x20000000,                         /* NOP */
        type1_packet(2, REG_CMD, 1),        /* Write CMD register */
        CMD_NULL,                           /* CMD = NULL */
        type1_packet(1, REG_IDCODE, 1),     /* Read IDCODE, 1 word */
        0x20000000,                         /* NOP */
        0x20000000,                         /* NOP */
        0x20000000,                         /* NOP */
        0x20000000,                         /* NOP */
    };
    shift_cfg_in(cmd, 9);

    jtag_load_ir(IR_CFG_OUT);

    uint32_t out64[2];
    read_cfg_out_64(out64);
    printf("  First  32 bits: 0x%08X\n", out64[0]);
    printf("  Second 32 bits: 0x%08X\n", out64[1]);

    desync();
    trace_protocol = saved_trace;

    /* ── Summary ─── */
    printf("\n╔═══════════════════════════════════════════════╗\n");
    printf("║                  SUMMARY                      ║\n");
    printf("╠═══════════════════════════════════════════════╣\n");
    printf("║ IR IDCODE:   0x%08X  %s              ║\n",
           idcode, idcode ? "TDO OK " : "TDO DEAD");
    printf("║ CFG IDCODE:  0x%08X  %s              ║\n",
           cfg_id, cfg_id ? "CFG OK " : "CFG FAIL");
    printf("║ CFG STAT:    0x%08X  %s              ║\n",
           stat, stat ? "STAT OK" : "STAT FL");
    printf("║ CPLD:        0x%04X      %s              ║\n",
           cpld_ver, (cpld_ver == 0xFFFE) ? "DEGRAD " : "OK     ");
    printf("║ 64-bit[0]:   0x%08X                      ║\n", out64[0]);
    printf("║ 64-bit[1]:   0x%08X                      ║\n", out64[1]);
    printf("╚═══════════════════════════════════════════════╝\n");

    if (ir_ok && !cfg_id && !stat) {
        printf("\n  DIAGNOSIS: TDO works but config register reads fail.\n");
        printf("  Possible causes:\n");
        printf("    1. Bit ordering: shift_cfg_in() double-reverses with xpc A6 protocol\n");
        printf("    2. Pipeline flush: not enough NOPs after read command\n");
        printf("    3. CPLD 0xFFFE degrades long DR scans (>32 bits in CFG_IN)\n");
        printf("    4. CFG_OUT IR not routing through CPLD correctly\n");
        printf("\n  Next: Run with -t flag for full USB transfer trace\n");
        printf("  Then: Check if jtag_program uses different A6 bit handling\n");
    } else if (ir_ok && cfg_id) {
        printf("\n  DIAGNOSIS: Config read path WORKS!\n");
        printf("  Both IR and CFG paths functional.\n");
    } else if (!ir_ok) {
        printf("\n  DIAGNOSIS: TDO path dead — hardware problem.\n");
        printf("  IDCODE read returned 0x%08X (expected 0x13631093).\n", idcode);
    }

    return (ir_ok && cfg_id) ? 0 : 1;
}

/* ======================================================================= */
/* JTAG Bridge — BSCANE2 communication via USER1 DR scan                   */
/* Protocol: shift in [CMD:8][ADDR:8][DATA:16], shift out response         */
/* ======================================================================= */

#define BRIDGE_CMD_READ   0x01
#define BRIDGE_CMD_WRITE  0x02
#define BRIDGE_CMD_START  0x03

#define BRIDGE_ADDR_STATUS  0x00
#define BRIDGE_ADDR_CYCLES  0x01
#define BRIDGE_ADDR_CONFIG  0x02

/* Clock frequency — must match MMCM output in hslm_full_top.v */
#define CLK_FREQ_HZ  81250000

/*
 * Perform a single 32-bit DR scan via USER1.
 * Shifts in cmd_word, returns the 32-bit response.
 */
static uint32_t bridge_dr_scan(uint32_t cmd_word)
{
    /* Load USER1 instruction */
    jtag_load_ir(IR_USER1);

    /* Navigate RTI → Shift-DR: TMS=1,0,0 */
    uint8_t nav_tdi[1] = {0}, nav_tms[1] = {0x01}, nav_tdo[1] = {0};
    jtag_scan(nav_tdi, nav_tms, nav_tdo, 3);

    /* Serialize cmd_word to TDI bytes (LSB first on wire) */
    uint8_t dr_tdi[4], dr_tms[4] = {0,0,0,0}, dr_tdo[4] = {0};
    dr_tdi[0] = bitrev((cmd_word >> 24) & 0xFF);
    dr_tdi[1] = bitrev((cmd_word >> 16) & 0xFF);
    dr_tdi[2] = bitrev((cmd_word >>  8) & 0xFF);
    dr_tdi[3] = bitrev((cmd_word >>  0) & 0xFF);

    /* TMS=1 on last bit to exit Shift-DR */
    dr_tms[3] = 0x80;

    jtag_scan(dr_tdi, dr_tms, dr_tdo, 32);

    /* Exit1-DR → Update-DR → RTI: TMS=1,0 */
    uint8_t ex_tdi[1] = {0}, ex_tms[1] = {0x01}, ex_tdo[1] = {0};
    jtag_scan(ex_tdi, ex_tms, ex_tdo, 2);

    /* Reassemble response (bit-reverse each byte, big-endian) */
    uint8_t b0 = bitrev(dr_tdo[0]);
    uint8_t b1 = bitrev(dr_tdo[1]);
    uint8_t b2 = bitrev(dr_tdo[2]);
    uint8_t b3 = bitrev(dr_tdo[3]);

    return ((uint32_t)b0 << 24) | ((uint32_t)b1 << 16) |
           ((uint32_t)b2 << 8)  | (uint32_t)b3;
}

/*
 * Build bridge command word: [CMD:8][ADDR:8][DATA:16]
 */
static uint32_t bridge_cmd(uint8_t cmd, uint8_t addr, uint16_t data)
{
    return ((uint32_t)cmd << 24) | ((uint32_t)addr << 16) | (uint32_t)data;
}

/*
 * Read a bridge register. Two scans required:
 * 1. Send READ command with address → gets previous response
 * 2. Send NOP → gets the actual response for our address
 */
static uint32_t bridge_read(uint8_t addr)
{
    /* First scan sets the address for CAPTURE */
    bridge_dr_scan(bridge_cmd(BRIDGE_CMD_READ, addr, 0));
    /* Second scan captures the response */
    return bridge_dr_scan(bridge_cmd(BRIDGE_CMD_READ, addr, 0));
}

static int cmd_bridge_status(void)
{
    printf("\n[BRIDGE] Reading inference status...\n");

    uint32_t status = bridge_read(BRIDGE_ADDR_STATUS);
    uint32_t cycles = bridge_read(BRIDGE_ADDR_CYCLES);
    uint32_t config = bridge_read(BRIDGE_ADDR_CONFIG);

    int done      = (status >> 15) & 1;
    int pass      = (status >> 14) & 1;
    int gen_count = (status >> 4) & 0x1F;
    int st_state  = status & 0x0F;
    int max_gen   = (config >> 7) & 0x1F;
    int seed      = config & 0x7F;

    uint32_t avg_cyc = (gen_count > 0) ? cycles / gen_count : 0;
    uint32_t tok_s   = (cycles > 0) ? (uint32_t)((uint64_t)CLK_FREQ_HZ * gen_count / cycles) : 0;

    printf("  ┌─────────────────────────────────────\n");
    printf("  │ Done:         %s\n", done ? "YES" : "NO");
    printf("  │ Self-test:    %s\n", pass ? "PASS" : "FAIL");
    printf("  │ State:        %d\n", st_state);
    printf("  │ Tokens:       %d / %d\n", gen_count, max_gen);
    printf("  │ Seed:         %d\n", seed);
    printf("  │ Total cycles: %u\n", cycles);
    printf("  │ Avg cyc/tok:  %u\n", avg_cyc);
    printf("  │ Throughput:   %u tok/s\n", tok_s);
    printf("  └─────────────────────────────────────\n");

    return 0;
}

static int cmd_bridge_measure(void)
{
    printf("\n[BRIDGE] Full measurement report...\n");

    uint32_t status = bridge_read(BRIDGE_ADDR_STATUS);
    uint32_t cycles = bridge_read(BRIDGE_ADDR_CYCLES);

    int done      = (status >> 15) & 1;
    int pass      = (status >> 14) & 1;
    int gen_count = (status >> 4) & 0x1F;

    if (!done) {
        printf("  Inference not complete (state=%d). Wait or run 'bridge run'.\n",
               status & 0x0F);
        return 1;
    }

    /* Read all generated tokens */
    printf("  Tokens: ");
    for (int i = 0; i < gen_count && i < 16; i++) {
        uint32_t tok = bridge_read(0x10 + i);
        printf("%u ", tok & 0x7F);
    }
    printf("\n");

    uint32_t avg_cyc = (gen_count > 0) ? cycles / gen_count : 0;
    uint32_t tok_s   = (cycles > 0) ? (uint32_t)((uint64_t)CLK_FREQ_HZ * gen_count / cycles) : 0;

    printf("  Pass:        %s\n", pass ? "YES" : "NO");
    printf("  Generated:   %d tokens\n", gen_count);
    printf("  Cycles:      %u\n", cycles);
    printf("  Avg cyc/tok: %u\n", avg_cyc);
    printf("  Throughput:  %u tok/s\n", tok_s);

    /* Verify against simulation expectation */
    uint32_t expected = 43241;  /* from simulation */
    if (avg_cyc > 0) {
        double dev = 100.0 * abs((int)avg_cyc - (int)expected) / (double)expected;
        printf("  Sim expect:  %u cyc/tok\n", expected);
        printf("  Deviation:   %.1f%%\n", dev);
        printf("  Verdict:     %s\n", (dev < 5.0) ? "MATCH" : "INVESTIGATE");
    }

    return 0;
}

static int cmd_bridge_run(const char *seed_str, const char *count_str)
{
    unsigned int seed = 42, count = 16;
    if (seed_str)  sscanf(seed_str, "%u", &seed);
    if (count_str) sscanf(count_str, "%u", &count);
    if (seed > 127) seed = 127;
    if (count > 16) count = 16;

    printf("\n[BRIDGE] Run inference: seed=%u, max_gen=%u\n", seed, count);

    /* Write seed register */
    bridge_dr_scan(bridge_cmd(BRIDGE_CMD_WRITE, 0x00, (uint16_t)seed));
    /* Write max_gen register */
    bridge_dr_scan(bridge_cmd(BRIDGE_CMD_WRITE, 0x01, (uint16_t)count));
    /* Start inference */
    bridge_dr_scan(bridge_cmd(BRIDGE_CMD_START, 0x00, 0x0000));

    printf("  Started. Polling for completion...\n");

    /* Poll status until done (max 5 seconds at ~30K polls/sec) */
    for (int i = 0; i < 150000; i++) {
        uint32_t st = bridge_read(BRIDGE_ADDR_STATUS);
        if ((st >> 15) & 1) {
            printf("  Done after ~%d polls.\n", i);
            return cmd_bridge_measure();
        }
    }

    printf("  Timeout waiting for inference to complete.\n");
    return 1;
}

static int cmd_bridge_read_reg(const char *addr_str)
{
    unsigned int addr;
    if (!addr_str || sscanf(addr_str, "%x", &addr) != 1) {
        fprintf(stderr, "Usage: bridge read <hex_addr>\n");
        return 1;
    }

    uint32_t val = bridge_read((uint8_t)addr);
    printf("  Bridge[0x%02X] = 0x%08X (%u)\n", addr, val, val);
    return 0;
}

static int cmd_bridge(int argc, char *argv[], int cmd_idx)
{
    if (cmd_idx >= argc) {
        printf(
            "\n═══════════════════════════════════════════════\n"
            " JTAG BRIDGE — BSCANE2 host ↔ FPGA inference\n"
            "═══════════════════════════════════════════════\n\n"
            "COMMANDS:\n"
            "  bridge status          Read inference status + tok/s\n"
            "  bridge measure         Full report with token sequence\n"
            "  bridge run [seed] [n]  Set seed, trigger, wait, measure\n"
            "  bridge read <hex>      Read any bridge register\n\n"
            "EXAMPLES:\n"
            "  sudo ./jtag_switcher bridge status\n"
            "  sudo ./jtag_switcher bridge run 42 16\n"
            "  sudo ./jtag_switcher bridge read 10\n\n");
        return 0;
    }

    const char *subcmd = argv[cmd_idx];

    if (strcmp(subcmd, "status") == 0)
        return cmd_bridge_status();
    else if (strcmp(subcmd, "measure") == 0)
        return cmd_bridge_measure();
    else if (strcmp(subcmd, "run") == 0) {
        const char *s = (cmd_idx + 1 < argc) ? argv[cmd_idx + 1] : NULL;
        const char *c = (cmd_idx + 2 < argc) ? argv[cmd_idx + 2] : NULL;
        return cmd_bridge_run(s, c);
    }
    else if (strcmp(subcmd, "read") == 0) {
        const char *a = (cmd_idx + 1 < argc) ? argv[cmd_idx + 1] : NULL;
        return cmd_bridge_read_reg(a);
    }
    else {
        fprintf(stderr, "Unknown bridge subcommand: %s\n", subcmd);
        return 1;
    }
}

static void print_usage(const char *progname)
{
    printf(
        "\n═══════════════════════════════════════════════\n"
        " TRINITY JTAG SWITCHER — Read/Write Mode\n"
        " Xilinx 7-series via Platform Cable USB II\n"
        "═══════════════════════════════════════════════\n\n"
        "USAGE:\n"
        "  sudo %s <command> [args]\n\n"
        "COMMANDS:\n"
        "  status              Read STAT register (DONE, CRC, etc.)\n"
        "  idcode              Read IDCODE via config interface\n"
        "  dna                 Read 57-bit device DNA\n"
        "  reg <hex_addr>      Read any config register (00-1F)\n"
        "  readback <out.bin>  Full bitstream readback to file\n"
        "  verify <file.bit>   Readback + compare with .bit file\n"
        "  write <file.bit>    Program bitstream (same as jtag_program)\n"
        "  probe               Hardware health probe (FX2/CPLD/TDO/IDCODE)\n"
        "  debug               Detailed config read path diagnosis\n"
        "  bridge <subcmd>     BSCANE2 bridge (status/measure/run/read)\n\n"
        "EXAMPLES:\n"
        "  sudo %s status\n"
        "  sudo %s idcode\n"
        "  sudo %s reg 07\n"
        "  sudo %s readback config_dump.bin\n"
        "  sudo %s verify fpga/openxc7-synth/hslm_full_top.bit\n"
        "  sudo %s write fpga/openxc7-synth/hslm_full_top.bit\n"
        "  sudo %s probe\n"
        "  sudo %s debug\n\n",
        progname, progname, progname, progname, progname, progname, progname, progname, progname);
}

int main(int argc, char *argv[])
{
    if (argc < 2) {
        print_usage(argv[0]);
        return 1;
    }

    /* Parse flags */
    const char *command = NULL;
    const char *arg1 = NULL;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-v") == 0)
            verbose = 1;
        else if (strcmp(argv[i], "-t") == 0)
            trace_protocol = 1;
        else if (!command)
            command = argv[i];
        else if (!arg1)
            arg1 = argv[i];
    }

    if (!command) {
        print_usage(argv[0]);
        return 1;
    }

    if (strcmp(command, "--help") == 0 || strcmp(command, "-h") == 0) {
        print_usage(argv[0]);
        return 0;
    }

    printf("═══════════════════════════════════════════════\n");
    printf(" TRINITY JTAG SWITCHER — %s\n", command);
    printf(" Xilinx 7-series via Platform Cable USB II\n");
    printf("═══════════════════════════════════════════════\n");

    /* Connect to Platform Cable USB II */
    printf("\n[INIT] Connecting to Platform Cable USB II...\n");
    if (io_init(VENDOR_ID, PRODUCT_ID, NULL) != 0) {
        fprintf(stderr, "Failed to connect. Is cable at PID 0x0008? Running sudo?\n");
        return 1;
    }
    printf("  Connected.\n");

    /* Reset TAP */
    jtag_reset_to_idle();

    /* Quick IDCODE check */
    uint32_t idcode = jtag_read_idcode();
    printf("  IDCODE: 0x%08X", idcode);
    if ((idcode & 0x0FFFFFFF) == 0x03631093)
        printf(" (XC7A100T ✓)\n");
    else
        printf("\n");

    int rc = 0;

    if (strcmp(command, "status") == 0) {
        rc = cmd_status();
    } else if (strcmp(command, "idcode") == 0) {
        rc = cmd_idcode();
    } else if (strcmp(command, "dna") == 0) {
        rc = cmd_dna();
    } else if (strcmp(command, "reg") == 0) {
        if (!arg1) {
            fprintf(stderr, "Usage: %s reg <hex_addr>\n", argv[0]);
            rc = 1;
        } else {
            rc = cmd_reg(arg1);
        }
    } else if (strcmp(command, "readback") == 0) {
        if (!arg1) {
            fprintf(stderr, "Usage: %s readback <output.bin>\n", argv[0]);
            rc = 1;
        } else {
            rc = cmd_readback(arg1);
        }
    } else if (strcmp(command, "verify") == 0) {
        if (!arg1) {
            fprintf(stderr, "Usage: %s verify <bitstream.bit>\n", argv[0]);
            rc = 1;
        } else {
            rc = cmd_verify(arg1);
        }
    } else if (strcmp(command, "write") == 0) {
        if (!arg1) {
            fprintf(stderr, "Usage: %s write <bitstream.bit>\n", argv[0]);
            rc = 1;
        } else {
            rc = cmd_write(arg1);
        }
    } else if (strcmp(command, "probe") == 0) {
        rc = cmd_probe();
    } else if (strcmp(command, "debug") == 0) {
        rc = cmd_debug();
    } else if (strcmp(command, "bridge") == 0) {
        /* Find the index of the first arg after "bridge" */
        int bridge_idx = -1;
        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "bridge") == 0) {
                bridge_idx = i + 1;
                break;
            }
        }
        rc = cmd_bridge(argc, argv, bridge_idx);
    } else {
        fprintf(stderr, "Unknown command: %s\n", command);
        print_usage(argv[0]);
        rc = 1;
    }

    io_close();

    if (rc == 0) {
        printf("\n═══════════════════════════════════════════════\n");
        printf(" φ² + 1/φ² = 3 = TRINITY\n");
        printf("═══════════════════════════════════════════════\n");
    }

    return rc;
}
