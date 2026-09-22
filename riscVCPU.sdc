create_clock -name clk -period 20.000 [get_ports {clk}]
set_clock_uncertainty -setup -from [get_clocks {clk}] -to [get_clocks {clk}] 0.200
set_clock_uncertainty -hold -from [get_clocks {clk}] -to [get_clocks {clk}] 0.100
