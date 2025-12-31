# Clock definition
create_clock -name clk -period 20.0 [get_ports clk]

# Input delays (relative to clk)
set_input_delay  2.0 -clock clk [get_ports s_axis_fir_tdata*]
set_input_delay  2.0 -clock clk [get_ports s_axis_fir_tvalid]
set_input_delay  2.0 -clock clk [get_ports m_axis_fir_tready]

# Output delays
set_output_delay 2.0 -clock clk [get_ports m_axis_fir_tdata*]
set_output_delay 2.0 -clock clk [get_ports m_axis_fir_tvalid]

# Reset is asynchronous, ignore timing
set_false_path -from [get_ports rst]
