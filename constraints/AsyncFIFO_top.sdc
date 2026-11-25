# Timing constraints for AsyncFIFO_top (DE2-115)
create_clock -name CLOCK_50  -period 20.000 [get_ports CLOCK_50]
create_clock -name CLOCK2_50 -period 20.000 [get_ports CLOCK2_50]
create_generated_clock -name rd_clk -source [get_ports CLOCK2_50] -divide_by 4 [get_registers {div[1]}]
derive_clock_uncertainty
# Write and read domains are asynchronous: only the 2-FF synchronizers cross them
set_clock_groups -asynchronous -group {CLOCK_50} -group {CLOCK2_50 rd_clk}
set_false_path -from [get_ports {KEY[*] SW[*]}]
set_false_path -to   [get_ports {LEDR[*] LEDG[*] HEX*}]
