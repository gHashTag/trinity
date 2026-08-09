# RGMII / Gigabit Ethernet 0 on ALINX AX7203 (XC7A200T, xc7a200tfbg484-2)
# PHY: Microchip KSZ9031RNX.  AX7203 and AX7103 share this pinout.
#
# Reconstructed 2026-08-10 from the verified pin assignment recorded in
# trinity-fpga/.claude/skills/fpga-synth, which was itself checked against
# video-ax7203/tx_board/tx_ov5640_eth.xdc.  Written for the open flow:
# Yosys -> nextpnr-xilinx -> prjxray -> openFPGALoader.  No vendor tools.
#
# ---------------------------------------------------------------------------
# THREE TRAPS THIS FILE EXISTS TO AVOID
#
# 1. nextpnr's XDC parser matches port names EXACTLY and does not expand [*].
#    A line like  set_property SLEW FAST [get_ports {rgmii_txd[*]}]  silently
#    does nothing -- no warning, no error, and your SLEW is simply absent.
#    Every constraint below is therefore written one pin per line.  Do not
#    "tidy" this file into bus form.
#
# 2. SLEW FAST belongs on every TX pin.  The verified reference sets it and it
#    is easy to drop, because the design still builds and partly works without.
#
# 3. phy_rst_n is driven BY THE FPGA and is active low.  Whatever releases it
#    also gates the PHY, so a retry interval must come from the settling time
#    of what you are configuring -- not from "as often as possible".  The
#    failure looks like mdio_passes ticking while the link never comes up.
# ---------------------------------------------------------------------------

# --- Receive clock.  B17 is an SRCC pin, and that is the whole reason
# --- openXC7/nextpnr-xilinx#110 exists: the clock-buffer preplace BFS gave up
# --- before reaching a legal BUFG site and reported "Unable to find legal
# --- placement".  Without that patch merged, this pin does not route.
set_property LOC B17 [get_ports rgmii_rxc]
create_clock -period 8.000 -name rgmii_rxc [get_ports rgmii_rxc]

set_property LOC A15 [get_ports rgmii_rxctl]
set_property LOC A16 [get_ports {rgmii_rxd[0]}]
set_property LOC B18 [get_ports {rgmii_rxd[1]}]
set_property LOC C18 [get_ports {rgmii_rxd[2]}]
set_property LOC C19 [get_ports {rgmii_rxd[3]}]

# --- Transmit.  SLEW FAST on every one of these, per trap 2.
set_property LOC E18 [get_ports rgmii_txc]
set_property SLEW FAST [get_ports rgmii_txc]
set_property LOC F18 [get_ports rgmii_txctl]
set_property SLEW FAST [get_ports rgmii_txctl]
set_property LOC C20 [get_ports {rgmii_txd[0]}]
set_property SLEW FAST [get_ports {rgmii_txd[0]}]
set_property LOC D20 [get_ports {rgmii_txd[1]}]
set_property SLEW FAST [get_ports {rgmii_txd[1]}]
set_property LOC A19 [get_ports {rgmii_txd[2]}]
set_property SLEW FAST [get_ports {rgmii_txd[2]}]
set_property LOC A18 [get_ports {rgmii_txd[3]}]
set_property SLEW FAST [get_ports {rgmii_txd[3]}]

# --- Management interface
set_property LOC B16 [get_ports mdc]
set_property LOC B15 [get_ports mdio]

# --- PHY reset: driven by the FPGA, ACTIVE LOW.  See trap 3.
set_property LOC D16 [get_ports phy_rst_n]

# ---------------------------------------------------------------------------
# IOSTANDARD IS DELIBERATELY ABSENT.
#
# It depends on the bank supply for this PHY, and that voltage is not recorded
# anywhere in the corpus -- KSZ9031RNX RGMII is commonly 2.5 V (LVCMOS25) but
# runs at 1.8 V in some designs, and the AX7203 bank rail was never written
# down.  A guess here would build cleanly and drive the PHY at the wrong level.
#
# Measure VCCO on the bank, or read it off the AX7203 schematic, then add one
# line per port -- again per pin, never [*]:
#
#   set_property IOSTANDARD LVCMOS25 [get_ports rgmii_rxc]
#   ... and so on for each port named above.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# AND THE ONE THAT NEARLY PRODUCED A FALSE POSITIVE
#
# RXC is NOT a link indicator.  A KSZ9031 in RGMII drives the receive clock
# continuously whether or not a link exists, so measuring "RXC ~ 125 MHz on all
# three boards" looked like three gigabit links and was not.
#
# The honest test is RGMII in-band status: sample RXD[3:0] while RX_CTL is LOW
# (the inter-frame gap).
#     RXD[0]   = link up
#     RXD[2:1] = speed   00 = 10M, 01 = 100M, 10 = 1000M
#     RXD[3]   = full duplex
# So RXD = 0xD reads as LINK UP, 1000M, FULL DUPLEX.  About ten lines of RTL,
# and short of MDIO it is the only answer that does not flatter you.
#
# Measured 2026-08-08, reproduced 4x.  Actual RXC on the three boards was
# 118 / 120 / 115 MHz against one 125 MHz clock -- the spread is each board's
# own CFGMCLK, not the link.
# ---------------------------------------------------------------------------
