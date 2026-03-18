<<<<<<< Updated upstream
# QMTECH Artix-7 XC7A100T-1FGG676C
# D6 (R23) blink test
=======
# LED D6 (R23) + Clock (U22 = 50 MHz oscillator) for QMTECH xc7a100t
>>>>>>> Stashed changes
set_property LOC U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property LOC R23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]
