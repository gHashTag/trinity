# Regression: a global buffer driven from FABRIC must place.
#
# Before openXC7/nextpnr-xilinx#111 this failed at placement with
#   ERROR: Unable to find legal placement for cell '$auto$clkbufmap.cc:...'
# because try_preplace() only handled buffers reachable by dedicated routing from
# a clock-capable pin, and aborted on the rest instead of falling back.
#
# The design is deliberately minimal: one differential input clock through an
# IBUFDS, and one clock produced by a flip-flop divider. Yosys' clkbufmap
# promotes BOTH to BUFG, so synthesis yields two global buffers whose only
# difference is how they are driven. That difference is the whole test.

FAMILY  = artix7
PART    = xc7a200tfbg484-2
BOARD   = ax7203
PROJECT = fabric_bufg
CHIPDB  = ${ARTIX7_CHIPDB}

include ../openXC7.mk
