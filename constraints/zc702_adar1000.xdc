# ZC702 -> ADAR1000-EVALZ pin constraints.
# WARNING: ZC702 PMOD bank is LVCMOS25 (2.5V). The ADAR1000-EVALZ P3 PMOD
# expects 3.3V CMOS (it has on-board 3.3V->1.8V translators). 2.5V VOH may be
# below the EVALZ VIH threshold; user has accepted this risk for bench bring-up.
# If reads/writes are unreliable, insert a 2.5V<->3.3V level shifter inline.

# 200 MHz differential system clock (Y9/AB11)
set_property PACKAGE_PIN Y9   [get_ports sysclk_p]
set_property PACKAGE_PIN AB11 [get_ports sysclk_n]
set_property IOSTANDARD LVDS_25 [get_ports {sysclk_p sysclk_n}]
create_clock -period 5.000 -name sysclk [get_ports sysclk_p]

# CPU reset button
set_property PACKAGE_PIN G19 [get_ports cpu_resetn]
set_property IOSTANDARD LVCMOS25 [get_ports cpu_resetn]

# J63 (PMOD1) -- 4-wire SPI to ADAR1000-EVALZ P3
# J63.1 -> P3.1 CSB
set_property PACKAGE_PIN E15 [get_ports pmod1_csb]
# J63.3 -> P3.2 SDIO
set_property PACKAGE_PIN D15 [get_ports pmod1_sdio]
# J63.5 -> P3.3 SDO
set_property PACKAGE_PIN W17 [get_ports pmod1_sdo]
# J63.7 -> P3.4 SCLK
set_property PACKAGE_PIN W5  [get_ports pmod1_sclk]
set_property IOSTANDARD LVCMOS25 [get_ports {pmod1_csb pmod1_sdio pmod1_sdo pmod1_sclk}]

# J62 (PMOD2) -- only RX_LOAD used; tie TX_LOAD/TR/PA_ON to GND on the EVALZ.
# J62.1 -> P3.7  RX_LOAD
set_property PACKAGE_PIN V7 [get_ports pmod2_rx_load]
set_property IOSTANDARD LVCMOS25 [get_ports pmod2_rx_load]

# Unused-pin handling: drive pull-down on every unconstrained pin so floating
# Pmod traces don't toggle on the eval board.
set_property BITSTREAM.GENERAL.UNUSEDPIN PULLDOWN [current_design]
