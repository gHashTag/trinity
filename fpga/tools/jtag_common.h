/*
 * jtag_common.h — Shared JTAG primitives for Xilinx 7-series
 *
 * Extracted from jtag_program.c for reuse by jtag_switcher.c
 */

#ifndef JTAG_COMMON_H
#define JTAG_COMMON_H

#include <stdint.h>

/* Xilinx 7-series JTAG IR instructions (6-bit) */
#define IR_LEN      6
#define IR_IDCODE   0x09
#define IR_JPROGRAM 0x0B
#define IR_CFG_IN   0x05
#define IR_CFG_OUT  0x04
#define IR_JSTART   0x0C
#define IR_BYPASS   0x3F
#define IR_USER1    0x02
#define IR_USER2    0x03

/* Bit-reverse a byte (MSB<->LSB, required for JTAG bit ordering) */
uint8_t bitrev(uint8_t b);

/* Send raw TMS/TDI bits through JTAG */
int jtag_scan(const uint8_t *tdi, const uint8_t *tms, uint8_t *tdo, int bits);

/* Move TAP to Test-Logic-Reset then Run-Test/Idle */
void jtag_reset_to_idle(void);

/* Run N TCK cycles in Run-Test/Idle */
void jtag_runtest(int clocks);

/* Load IR instruction from RTI, return to RTI */
void jtag_load_ir(uint8_t ir_value);

/* Read 32-bit IDCODE via JTAG IR_IDCODE */
uint32_t jtag_read_idcode(void);

/* Parse Xilinx .bit file, return bit-reversed data and length */
uint8_t *parse_bit_file(const char *filename, int *data_len);

/* Shift large data through DR (bitstream programming) */
int jtag_shift_dr_large(const uint8_t *data, int total_bits);

#endif /* JTAG_COMMON_H */
