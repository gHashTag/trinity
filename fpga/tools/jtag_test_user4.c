#include <stdio.h>
#include <stdint.h>
#include "xpc.h"

int verbose = 0, trace_usb = 0, trace_protocol = 0;

static void tap_reset(void) {
    uint8_t t[8]={0}, m[8]={0x1F}, o[8]={0};
    io_scan(t, m, o, 5);
    m[0]=0; io_scan(t, m, o, 1);
}

static void load_ir(uint8_t val) {
    uint8_t t[1]={0}, m[1]={0x03}, o[1]={0};
    io_scan(t, m, o, 4);
    uint8_t it[1]={0}, im[1]={0}, io2[1]={0};
    for(int i=0;i<6;i++) { if(val&(1<<i)) it[0]|=(1<<i); if(i==5) im[0]|=(1<<i); }
    io_scan(it, im, io2, 6);
    printf("  IR shift TDO: 0x%02X\n", io2[0]);
    m[0]=0x01; io_scan(t, m, o, 2);
}

static uint8_t dr_shift8(uint8_t tx) {
    uint8_t t[1]={0}, m[1]={0x01}, o[1]={0};
    io_scan(t, m, o, 3);
    uint8_t dt[1]={0}, dm[1]={0}, dr[1]={0};
    for(int i=0;i<8;i++) { if(tx&(1<<i)) dt[0]|=(1<<i); if(i==7) dm[0]|=(1<<i); }
    io_scan(dt, dm, dr, 8);
    m[0]=0x01; io_scan(t, m, o, 2);
    return dr[0];
}

int main() {
    if(io_init(0x03FD,0x0008,NULL)<0) { printf("No cable\n"); return 1; }
    printf("Connected.\n");
    tap_reset();
    printf("Loading USER4 (0x23)...\n");
    load_ir(0x23);
    
    printf("\nShifting bytes through DR:\n");
    for(int i=0;i<6;i++) {
        uint8_t tx = 0x41+i;
        uint8_t rx = dr_shift8(tx);
        printf("  TX: 0x%02X '%c' → RX: 0x%02X", tx, tx, rx);
        if(rx>=0x20&&rx<0x7f) printf(" '%c'", rx);
        printf("\n");
    }
    io_close();
    return 0;
}
