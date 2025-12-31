read_db nangate_mvt.odb

read_verilog fir.v
read_verilog tkeo.v
read_verilog noise_estimator.v
read_verilog fir_tkeo_chain.v

synthesize

read_sdc constrain.sdc

report_timing > report_timing_v0_0.txt
report_area > report_area_v0_0.txt
report_power > report_power_v0_0.txt
report_hierarchy > report_hierarchy_v0_0.txt
report_scan_chains > report_scan_chains_v0_0.txt

