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
        type1_packet(1, REG_FDRO, 0),            /* Type 1 READ FDRO, 0 words (header for Type 2) */
        type2_packet(1, total_words),            /* Type 2 READ, total_words */
        0x20000000,                              /* NOP */
        0x20000000,                              /* NOP */
    };
    shift_cfg_in(cmd, 19);

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

static int cmd_verify(const char *bitfile)
{
    printf("\n[VERIFY] Readback vs %s...\n", bitfile);

    /* Parse the .bit file to get reference data */
    int ref_len = 0;
    uint8_t *ref_data = parse_bit_file(bitfile, &ref_len);
    if (!ref_data) return 1;

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

    /* Compare */
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

    /* Note: readback data is raw frames, ref_data is bit-reversed bitstream.
     * We need to bit-reverse ref_data back to compare with raw readback. */
    int compare_len = (ref_len < readback_len) ? ref_len : (int)readback_len;
    int mismatches = 0;
    int first_mismatch = -1;

    /* Un-bitreverse the reference (parse_bit_file already bit-reversed it) */
    for (int i = 0; i < ref_len; i++) {
        ref_data[i] = bitrev(ref_data[i]);
    }

    /* Skip header/sync in reference, find config data start */
    /* Readback frames start after sync+header, compare frame data only */
    printf("  Reference: %d bytes, Readback: %ld bytes\n", ref_len, readback_len);
    printf("  Comparing first %d bytes...\n", compare_len);

    for (int i = 0; i < compare_len; i++) {
        if (ref_data[i] != readback[i]) {
            mismatches++;
            if (first_mismatch < 0) first_mismatch = i;
        }
    }

    free(ref_data);
    free(readback);
    remove(tmpfile);

    if (mismatches == 0) {
        printf("  VERIFY: PASS ✓ — %d bytes match\n", compare_len);
    } else {
        printf("  VERIFY: FAIL ✗ — %d mismatches (first at offset 0x%X)\n",
               mismatches, first_mismatch);
    }

    return (mismatches == 0) ? 0 : 1;
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
        "  write <file.bit>    Program bitstream (same as jtag_program)\n\n"
        "EXAMPLES:\n"
        "  sudo %s status\n"
        "  sudo %s idcode\n"
        "  sudo %s reg 07\n"
        "  sudo %s readback config_dump.bin\n"
        "  sudo %s verify fpga/openxc7-synth/hslm_full_top.bit\n"
        "  sudo %s write fpga/openxc7-synth/hslm_full_top.bit\n\n",
        progname, progname, progname, progname, progname, progname, progname);
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
