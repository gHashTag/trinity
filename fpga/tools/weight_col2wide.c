// weight_col2wide — Pack K column .mem files into one wide .mem file
// Usage: weight_col2wide <prefix> <K>
// Reads: {prefix}_b00.mem .. {prefix}_b{K-1}.mem (2-bit binary per line)
// Writes: {prefix}_wide.mem (2*K-bit binary per line)
//
// Wide word layout matches tmu.v: bank_word[2*b +: 2] = bank b's code
// So bank0 at bits [1:0], bank1 at bits [3:2], etc.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_K 32
#define MAX_DEPTH 16384
#define MAX_LINE 128

int main(int argc, char *argv[]) {
    if (argc != 3) {
        fprintf(stderr, "Usage: %s <prefix> <K>\n", argv[0]);
        fprintf(stderr, "  Reads {prefix}_b00.mem .. {prefix}_b{K-1}.mem\n");
        fprintf(stderr, "  Writes {prefix}_wide.mem\n");
        return 1;
    }

    const char *prefix = argv[1];
    int K = atoi(argv[2]);
    if (K != 16 && K != 32) {
        fprintf(stderr, "Error: K must be 16 or 32, got %d\n", K);
        return 1;
    }

    int wide_bits = 2 * K;
    FILE *banks[MAX_K];
    char fname[256];
    int depth = 0;

    // Open all bank files
    for (int b = 0; b < K; b++) {
        snprintf(fname, sizeof(fname), "%s_b%02d.mem", prefix, b);
        banks[b] = fopen(fname, "r");
        if (!banks[b]) {
            fprintf(stderr, "Error: cannot open %s\n", fname);
            return 1;
        }
    }

    // Count lines in bank 0
    char line[MAX_LINE];
    while (fgets(line, sizeof(line), banks[0])) depth++;
    rewind(banks[0]);

    fprintf(stderr, "Packing %s: K=%d, depth=%d, wide_bits=%d\n", prefix, K, depth, wide_bits);

    // Open output
    snprintf(fname, sizeof(fname), "%s_wide.mem", prefix);
    FILE *out = fopen(fname, "w");
    if (!out) {
        fprintf(stderr, "Error: cannot create %s\n", fname);
        return 1;
    }

    // Pack line by line
    for (int addr = 0; addr < depth; addr++) {
        unsigned long long wide_word = 0;

        for (int b = 0; b < K; b++) {
            if (!fgets(line, sizeof(line), banks[b])) {
                fprintf(stderr, "Error: unexpected EOF in bank %d at line %d\n", b, addr);
                return 1;
            }
            // Parse 2-bit binary value
            int code = 0;
            if (line[0] == '0' && line[1] == '0') code = 0;
            else if (line[0] == '0' && line[1] == '1') code = 1;
            else if (line[0] == '1' && line[1] == '0') code = 2;
            else if (line[0] == '1' && line[1] == '1') code = 3;
            else {
                fprintf(stderr, "Error: invalid code '%c%c' in bank %d line %d\n",
                        line[0], line[1], b, addr);
                return 1;
            }

            wide_word |= ((unsigned long long)code) << (2 * b);
        }

        // Write as binary string
        for (int bit = wide_bits - 1; bit >= 0; bit--)
            fputc(((wide_word >> bit) & 1) ? '1' : '0', out);
        fputc('\n', out);
    }

    fclose(out);
    for (int b = 0; b < K; b++) fclose(banks[b]);

    fprintf(stderr, "Wrote %s: %d lines x %d bits\n", fname, depth, wide_bits);
    return 0;
}
