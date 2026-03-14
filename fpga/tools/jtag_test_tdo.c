/* Quick TDO test — read IDCODE with raw bit dump */
#include <stdio.h>
#include <stdint.h>
#include "xpc.h"

int verbose = 0;
int trace_usb = 0;
int trace_protocol = 0;

int main() {
    if (io_init(0x03FD, 0x0008, NULL) < 0) {
        printf("Cannot connect\n"); return 1;
    }
    printf("Connected.\n");

    /* TLR: 5x TMS=1 */
    uint8_t tdi[8]={0}, tms[8]={0x1F}, tdo[8]={0};
    io_scan(tdi, tms, tdo, 5);
    /* RTI: TMS=0 */
    tms[0]=0; io_scan(tdi, tms, tdo, 1);
    printf("TAP reset done.\n");

    /* IR = IDCODE (0x09): navigate to Shift-IR */
    tms[0]=0x03; io_scan(tdi, tms, tdo, 4);
    /* Shift 6 bits IR=0x09, TMS=1 on last */
    uint8_t ir_tdi[1]={0x09}, ir_tms[1]={0x20}, ir_tdo[1]={0};
    io_scan(ir_tdi, ir_tms, ir_tdo, 6);
    printf("IR shift TDO: 0x%02X\n", ir_tdo[0]);
    /* Exit → Update → RTI */
    tms[0]=0x01; io_scan(tdi, tms, tdo, 2);

    /* DR scan: navigate to Shift-DR */
    tms[0]=0x01; io_scan(tdi, tms, tdo, 3);
    /* Shift 32 bits, TMS=1 on last */
    uint8_t dr_tdi[4]={0}, dr_tms[4]={0,0,0,0x80}, dr_tdo[4]={0};
    io_scan(dr_tdi, dr_tms, dr_tdo, 32);
    printf("DR TDO raw: %02X %02X %02X %02X\n", dr_tdo[0], dr_tdo[1], dr_tdo[2], dr_tdo[3]);
    uint32_t id = dr_tdo[0] | (dr_tdo[1]<<8) | (dr_tdo[2]<<16) | ((uint32_t)dr_tdo[3]<<24);
    printf("IDCODE: 0x%08X\n", id);

    /* Exit → Update → RTI */
    tms[0]=0x01; io_scan(tdi, tms, tdo, 2);

    io_close();
    return 0;
}
