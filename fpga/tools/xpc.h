#include <stdint.h>

#define VENDOR_ID 0x03FD
#define PRODUCT_ID 0x0008

int io_init(unsigned vendor, unsigned product, const char *desc);

int io_scan(const unsigned char *tdi, const unsigned char *tms,
            unsigned char *tdo, unsigned len);
void io_close(void);

extern int verbose;
extern int trace_usb;
extern int trace_protocol;

/* Public wrappers for version reads (use global_xpcu) */
int io_read_cpld_version(uint16_t *ver);
int io_read_firmware_version(uint16_t *ver);
