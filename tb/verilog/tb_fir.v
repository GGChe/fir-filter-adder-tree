`timescale 1ns / 1ps

module tb_fir;

  // Parameters
  parameter integer MAX_SAMPLES = 200000;
  parameter integer FIR_LATENCY = 10; 

  // DUT signals
  reg  clk;
  reg  rst;

  reg  signed [15:0] s_axis_fir_tdata;
  reg                s_axis_fir_tvalid;
  reg                m_axis_fir_tready;

  wire               m_axis_fir_tvalid;
  wire signed [31:0] m_axis_fir_tdata;

  // DUT instantiation
  fir_filter dut (
    .clk               (clk),
    .rst               (rst),
    .s_axis_fir_tdata  (s_axis_fir_tdata),
    .s_axis_fir_tvalid (s_axis_fir_tvalid),
    .m_axis_fir_tready (m_axis_fir_tready),
    .m_axis_fir_tvalid (m_axis_fir_tvalid),
    .m_axis_fir_tdata  (m_axis_fir_tdata)
  );

  // Clock generation (100 MHz)
  initial clk = 1'b0;
  always #5 clk = ~clk;

  // Input sample storage
  integer sample_mem [0:MAX_SAMPLES-1];
  integer num_samples;
  integer i;
  integer fd;
  integer r;

  // Signal generation parameters
  real PI = 3.14159265358979;
  real FS = 2000.0;
  real AMP = 30000.0;
  real t;
  
  // Main stimulus
  initial begin
    // Generate synthetic samples FIRST
    num_samples = 0;
    
    $display("Generating synthetic test signals...");

    // 10 Hz (1000 samples)
    for (i = 0; i < 1000; i = i + 1) begin
       t = $itor(i) / FS;
       sample_mem[num_samples] = $rtoi(AMP * $sin(2.0 * PI * 10.0 * t));
       num_samples = num_samples + 1;
    end

    // 30 Hz (1000 samples)
    for (i = 0; i < 1000; i = i + 1) begin
       t = $itor(i) / FS;
       sample_mem[num_samples] = $rtoi(AMP * $sin(2.0 * PI * 30.0 * t));
       num_samples = num_samples + 1;
    end

    // 100 Hz (1000 samples)
    for (i = 0; i < 1000; i = i + 1) begin
       t = $itor(i) / FS;
       sample_mem[num_samples] = $rtoi(AMP * $sin(2.0 * PI * 100.0 * t));
       num_samples = num_samples + 1;
    end

    $display("Generated %0d samples (10Hz, 30Hz, 100Hz).", num_samples);
    
    // Debug: Show first 20 samples to verify sine wave
    $display("First 20 samples of 10Hz sine wave:");
    for (i = 0; i < 20; i = i + 1) begin
      $display("  sample[%2d] = %6d", i, sample_mem[i]);
    end
    $dumpfile("wave.vcd");
    $dumpvars(0, tb_fir);

    // Open CSV for logging
    fd = $fopen("fir_output.csv", "w");
    if (fd == 0) begin
        $display("Error opening fir_output.csv");
        $finish;
    end
    $fdisplay(fd, "time_ns,clk_cycle,input_val,output_val");

    // Defaults
    rst                 = 1'b1;
    s_axis_fir_tdata    = 16'sd0;
    s_axis_fir_tvalid   = 1'b0;
    m_axis_fir_tready   = 1'b1;

    // Reset
    repeat (10) @(posedge clk);
    rst = 1'b0;
    @(posedge clk);

    // Feed input samples & Log Output
    for (i = 0; i < num_samples; i = i + 1) begin
      s_axis_fir_tdata  = sample_mem[i][15:0];
      s_axis_fir_tvalid = 1'b1;
      
      // Log on rising edge when output is valid (or just every cycle)
      // To catch aligned data, we log just before the edge
      @(posedge clk);
      
      // Logging: Timestamp, Cycle, Input, Output
      // Note: Output corresponds to input from LATENCY cycles ago
      $fdisplay(fd, "%0d,%0d,%0d,%0d", $time, i, s_axis_fir_tdata, m_axis_fir_tdata);
    end

    // Stop sending data
    @(posedge clk);
    s_axis_fir_tvalid = 1'b0;
    s_axis_fir_tdata  = 16'sd0;

    // Flush FIR pipeline
    repeat (FIR_LATENCY + 10) @(posedge clk);

    $fclose(fd);
    $display("FIR simulation completed. Output written to fir_output.csv");
    $finish;
  end

endmodule