set_property -dict {PACKAGE_PIN R4 IOSTANDARD DIFF_SSTL15} [get_ports clk_p]
set_property -dict {PACKAGE_PIN T4 IOSTANDARD DIFF_SSTL15} [get_ports clk_n]
set_property -dict {PACKAGE_PIN B13 IOSTANDARD LVCMOS33} [get_ports led]
create_clock -period 5.000 -name sys_clk [get_ports clk_p]
