# JTAG scan script for openocd
# Using basic ftdi driver for FT232RL

adapter driver ftdi
adapter speed 1000
ftdi vid_pid 0x0403 0x6001
transport select jtag

# Initialize
jtag newtap xc7a100t tap -irlen 6

# Try to scan
init
scan_chain

shutdown
