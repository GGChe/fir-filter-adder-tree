# GTKWave startup script
# Adds default signals for FIR filter with hierarchy detection

set hierarchies [list "tb_fir" "TOP" "fir_filter" "Vtop" "fir" "." ""]
set signal_names {
    "clk"
    "rst"
    "s_axis_fir_tvalid"
    "s_axis_fir_tdata"
    "m_axis_fir_tready"
    "m_axis_fir_tvalid"
    "m_axis_fir_tdata"
}

set added 0
foreach hier $hierarchies {
    set candidates [list]
    foreach sig $signal_names {
        if {$hier eq ""} {
            lappend candidates "$sig"
        } else {
            lappend candidates "$hier.$sig"
        }
    }
    
    # Attempt to add this batch
    set num_added [gtkwave::addSignalsFromList $candidates]
    
    if {$num_added > 0} {
        puts "Detected hierarchy '$hier', added $num_added signals."
        set added 1
        # If we found the correct hierarchy, stop looking
        break
    }
}

if {$added == 0} {
    puts "Warning: Could not detect valid hierarchy for default signals."
    puts "Attempting to list typical signals for debugging..."
}


