#!/usr/bin/env wish

# Test if GTKWave TCL scripting works
puts "TCL script is running!"

# Get all available signals
set all_facs [gtkwave::getFacilities]
puts "Total facilities found: [llength $all_facs]"

# Try finding specific signals
foreach sig {"tb_fir.clk" "tb_fir.s_axis_fir_tdata" "tb_fir.m_axis_fir_tdata"} {
    if {[lsearch $all_facs $sig] >= 0} {
        puts "Found signal: $sig"
    }
}

# Try to add signals
set sigs_to_add [list "tb_fir.clk" "tb_fir.rst" "tb_fir.s_axis_fir_tvalid" "tb_fir.s_axis_fir_tdata" "tb_fir.m_axis_fir_tready" "tb_fir.m_axis_fir_tvalid" "tb_fir.m_axis_fir_tdata"]

puts "Attempting to add [llength $sigs_to_add] signals..."
set num_added [gtkwave::addSignalsFromList $sigs_to_add]
puts "Successfully added $num_added signals"

gtkwave::zoomFull
