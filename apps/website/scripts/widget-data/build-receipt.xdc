# build-receipt.xdc -- QMTech Wukong V1 (XC7A200T-FGG676) LED pins for build_receipt_top.
# Pins and standards as in gHashTag/t27 fpga/vsa/gf16_heartbeat_top.xdc (R23 = D5, T23 = D6, J26).
set_property LOC R23 [get_ports led_d5]
set_property IOSTANDARD LVCMOS33 [get_ports led_d5]
set_property LOC T23 [get_ports led_d6]
set_property IOSTANDARD LVCMOS33 [get_ports led_d6]
set_property LOC J26 [get_ports led_j26]
set_property IOSTANDARD LVCMOS33 [get_ports led_j26]
