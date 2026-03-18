#include <stdio.h>
#include <stdint.h>
#include "xpc.h"
int verbose=0, trace_usb=0, trace_protocol=0;

static void tap_reset(void) {
    uint8_t t[8]={0},m[8]={0x1F},o[8]={0};
    io_scan(t,m,o,5); m[0]=0; io_scan(t,m,o,1);
}
static void load_ir(uint8_t val) {
    uint8_t t[1]={0},m[1]={0x03},o[1]={0};
    io_scan(t,m,o,4);
    uint8_t it[1]={0},im[1]={0},io2[1]={0};
    for(int i=0;i<6;i++){if(val&(1<<i))it[0]|=(1<<i);if(i==5)im[0]|=(1<<i);}
    io_scan(it,im,io2,6);
    m[0]=0x01; io_scan(t,m,o,2);
}
static uint8_t dr_shift8(uint8_t tx) {
    uint8_t t[1]={0},m[1]={0x01},o[1]={0};
    io_scan(t,m,o,3);
    uint8_t dt[1]={0},dm[1]={0},dr[1]={0};
    for(int i=0;i<8;i++){if(tx&(1<<i))dt[0]|=(1<<i);if(i==7)dm[0]|=(1<<i);}
    io_scan(dt,dm,dr,8);
    m[0]=0x01; io_scan(t,m,o,2);
    return dr[0];
}
int main() {
    if(io_init(0x03FD,0x0008,NULL)<0){printf("No cable\n");return 1;}
    /* Test all USER instructions */
    uint8_t irs[]={0x02,0x03,0x22,0x23}; /* USER1-4 */
    char *names[]={"USER1","USER2","USER3","USER4"};
    for(int u=0;u<4;u++){
        tap_reset();
        load_ir(irs[u]);
        printf("%s (IR=0x%02X): ",names[u],irs[u]);
        uint8_t r1=dr_shift8(0x55);
        uint8_t r2=dr_shift8(0xAA);
        uint8_t r3=dr_shift8(0x00);
        printf("TX:55→%02X  TX:AA→%02X  TX:00→%02X",r1,r2,r3);
        if(r2==0x55&&r3==0xAA) printf("  ✓ ECHO!");
        printf("\n");
    }
    io_close();
    return 0;
}
