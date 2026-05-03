# ZC702 -> ADAR1000-EVALZ SPI Bring-Up (RX1 Max-Gain-45)

Self-contained Verilog SPI master that drives an ADAR1000-EVALZ from a ZC702
(Zynq-7000 XC7Z020) over the on-board Pmod headers and runs the
"max gain receive channel 1" test (`RX1_MaxG_45`) on power-up.

## Files

```
rtl/
  adar1000_spi_master.v   24-bit SPI master, mode 0
  adar1000_init_rom.v     register address/value table
  adar1000_seq_ctrl.v     sequencer FSM (walks ROM, pulses RX_LOAD)
  zc702_adar1000_top.v    top-level for ZC702
constraints/
  zc702_adar1000.xdc      pin / IO / clock constraints
sim/
  tb_adar1000_top.v       icarus-verilog testbench
```

## Wiring

ZC702 J63 (PMOD1) -> ADAR1000-EVALZ P3:

| ZC702 pin | FPGA | Signal   | P3 pin |
|-----------|------|----------|--------|
| J63.1     | E15  | CSB      | P3.1   |
| J63.3     | D15  | SDIO     | P3.2   |
| J63.5     | W17  | SDO      | P3.3   |
| J63.7     | W5   | SCLK     | P3.4   |

ZC702 J62 (PMOD2) -> ADAR1000-EVALZ P3:

| ZC702 pin | FPGA | Signal   | P3 pin |
|-----------|------|----------|--------|
| J62.1     | V7   | RX_LOAD  | P3.7   |
| J62.2     | W10  | TX_LOAD  | P3.8   (held low) |
| J62.3     | P18  | TR       | P3.9   (held low = RX) |
| J62.4     | P17  | PA_ON    | P3.10  (held low) |

Tie GND between the two boards. Leave EVALZ ADDR0/ADDR1 at their board straps
(chip address 00).

## Voltage caveat

ZC702 Pmod IO bank is **LVCMOS25 (2.5V)**; the ADAR1000-EVALZ P3 Pmod expects
**3.3V CMOS** (the eval board has on-board 3.3V->1.8V translators feeding the
chip). 2.5V VOH is below the typical 3.3V VIH threshold. If the ADAR1000 doesn't
respond, drop a TXS0108 (or equivalent) 2.5V<->3.3V level shifter inline.

## Build (Vivado)

1. Create project for `xc7z020clg484-1`.
2. Add the four files in `rtl/` as design sources, set `zc702_adar1000_top` as top.
3. Add `constraints/zc702_adar1000.xdc` as a constraints source.
4. Run synthesis + implementation, generate bitstream, program over JTAG.

## Simulate

```
iverilog -o sim.out -g2012 \
  rtl/adar1000_spi_master.v \
  rtl/adar1000_init_rom.v \
  rtl/adar1000_seq_ctrl.v \
  sim/tb_adar1000_top.v
vvp sim.out
```

Expected output: 11 frames decoded matching the ROM, then `PASS`.

## Init sequence (RX1 max-gain-45)

| # | Address | Data  | Purpose                             |
|---|---------|-------|-------------------------------------|
| 0 | 0x000   | 0x81  | soft reset                          |
| 1 | 0x000   | 0x18  | 4-wire SPI, SDO active              |
| 2 | 0x400   | 0x55  | LDO trim                            |
| 3 | 0x031   | 0x60  | RX_EN \| TX_EN subcircuit enables   |
| 4 | 0x02E   | 0x40  | RX channel 1 enable                 |
| 5 | 0x034   | 0x08  | bias default                        |
| 6 | 0x035   | 0x55  | bias default                        |
| 7 | 0x036   | 0x2D  | bias default                        |
| 8 | 0x037   | 0x06  | bias default                        |
| 9 | 0x010   | 0x7F  | CH1_RX_GAIN = 127 (max)             |
|10 | 0x028   | 0x01  | LD_WRK_REGS (RX side)               |
|11 | -       | -     | pulse RX_LOAD                       |

Composite from datasheet defaults plus the max gain code (0x7F). If you have
the exact `RX1_MaxG_45.txt` from the ADI eval-software install, replace the
ROM contents in `rtl/adar1000_init_rom.v` accordingly.

## Bench check

On a scope, after pressing the CPU reset button:
- 11 CSB low pulses on E15
- ~1 MHz SCLK on W5 inside each pulse
- `RX_LOAD` (V7) goes high after the last frame for ~16 sysclk cycles
- With an 8-16 GHz tone on RFIN1 and a power meter on RFIO, observe a gain step.
