## QMTECH Artix-7 XC7A100T-1FGG676C
## VSA Coprocessor D6 LED constraints

## 50 MHz oscillator
set_property PACKAGE_PIN U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 20.000 -name sys_clk [get_ports clk]

## LED D6 (active high)
set_property PACKAGE_PIN T23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]
