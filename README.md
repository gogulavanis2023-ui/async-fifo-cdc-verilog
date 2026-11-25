# Asynchronous FIFO with Gray-Code Clock-Domain Crossing (Verilog, DE2-115)

A dual-clock FIFO that passes data safely between two **unrelated clock domains**: a 50 MHz write side and a 12.5 MHz read side. It uses Gray-coded pointers, 2-flop synchronisers and correct full/empty generation. Implemented in Intel Quartus on the Terasic DE2-115 (Cyclone IV E), with SDC timing constraints that declare the domains asynchronous.

## Problem statement
Passing multi-bit pointers directly between asynchronous clocks causes metastability and incoherent values. Several bits can change at once and be sampled half-updated. The standard fix is to Gray-code the pointers, so only one bit changes per increment, and to synchronise them through two flip-flops before comparing them in the other domain.

## Architecture
```
 wr_clk domain                                          rd_clk domain
 ─────────────                                          ─────────────
 w_ptr (6b bin) ─► bin2gray ─► double_sync ──────────►  gray2bin ─► compare with r_ptr ─► empty
                                                   ┌──  r_ptr (6b bin) ─► bin2gray
 full ◄─ compare with w_ptr ◄─ gray2bin ◄─ double_sync ◄┘
            │                                               │
            ▼                                               ▼
     wraddress[4:0], wren  ───────►  dpram (32 × 8, dual clock)  ───► rdaddress[4:0], rden → data_out
```
| Module | Function |
|---|---|
| `asynchronous_fifo.v` | Pointer logic and full/empty flags. Parameters: `DEPTH=32`, `DATA_WIDTH=8`, `PTR_WIDTH=6` (one extra wrap bit). |
| `bin2gray.v` / `gray2bin.v` | Pointer encoding and decoding |
| `double_sync.v` | 2-FF synchroniser with asynchronous reset |
| `dpram.v` | 32×8 true dual-clock RAM, a Quartus `altsyncram` IP wrapper |
| `AsyncFIFO_top.v` | DE2-115 board wrapper: debounced write and read keys, switches, LEDs, hex displays |

**Flags:** `full` is set when the MSBs differ and the lower bits match (write pointer vs. synchronised read pointer). `empty` is set when the synchronised write pointer equals the read pointer. Writes are blocked when full and reads when empty, so data can never be overwritten or read twice.

## Board interface (DE2-115)
| I/O | Function |
|---|---|
| `CLOCK_50` | Write clock (50 MHz) |
| `CLOCK2_50 / 4` | Read clock (12.5 MHz) |
| `SW[7:0]` | Data to write (echoed on `LEDR[7:0]` and HEX5–HEX4) |
| `KEY[0]` / `KEY[1]` | Write / read one word (debounced, one-cycle pulse in its own domain) |
| `KEY[3]` | Active-low reset |
| HEX1–HEX0 | Data read from the FIFO |
| `LEDG[0]` / `LEDG[1]` | empty / full |

## Timing constraints (`constraints/AsyncFIFO_top.sdc`)
```tcl
create_clock -name CLOCK_50  -period 20.000 [get_ports CLOCK_50]
create_clock -name CLOCK2_50 -period 20.000 [get_ports CLOCK2_50]
create_generated_clock -name rd_clk -source [get_ports CLOCK2_50] -divide_by 4 [get_registers {div[1]}]
set_clock_groups -asynchronous -group {CLOCK_50} -group {CLOCK2_50 rd_clk}
```
The two domains are declared asynchronous, so the timing analyser does not time the synchroniser crossings as ordinary paths.

## Verification
`sim/AsyncFIFO_tb.v` is a self-checking testbench with a scoreboard:
- Write and read clocks are independent, with 10 and 14 time-unit periods, a non-integer ratio.
- It makes **40 write attempts into the 32-deep FIFO**. The last 8 must be blocked by `full`.
- It then makes **45 read attempts**. The surplus reads must be blocked by `empty`.
- Every accepted write is pushed into an expected-data queue, and every read is compared in order.
- It prints `*** TEST PASSED ***` only if there are 0 data errors and exactly 32 words were written and 32 read.

Simulation needs the Intel `altera_mf` library because of the `altsyncram` RAM.

## Setup
1. In Quartus Prime (Lite), create a project for the DE2-115 (`EP4CE115F29C7`) and add `rtl/*.v` and `constraints/AsyncFIFO_top.sdc`. Set `AsyncFIFO_top` as top.
2. Import the Terasic DE2-115 pin assignments (from the board's System CD), then compile and program.
3. Simulate in ModelSim/Questa with `altera_mf` compiled.

## Limitations and future improvements
- The RAM is a vendor IP wrapper. Replacing it with inferred RTL would make the design portable to Vivado or ASIC flows.
- Add SystemVerilog assertions (no write when full, no read when empty) and a randomised scoreboard testbench across many clock ratios.
- Add almost-full and almost-empty thresholds, and parameterise the depth with `$clog2`.

## Technologies
`Verilog` `Clock-domain crossing` `Gray code` `Synchronizers` `Dual-port RAM` `Quartus Prime` `SDC / TimeQuest` `Cyclone IV` `DE2-115` `ModelSim`
