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
  fir dut (
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

  // Load samples from file
  initial begin
    fd = $fopen("../../test_files/lfp/test_signal_20170224_16.txt", "r");


    if (fd == 0) begin
      $display("ERROR: Could not open input signal file.");
      $finish;
    end

    num_samples = 0;
    while (!$feof(fd) && num_samples < MAX_SAMPLES) begin
      r = $fscanf(fd, "%d\n", sample_mem[num_samples]);
      if (r == 1)
        num_samples = num_samples + 1;
    end

    $fclose(fd);
    $display("Loaded %0d samples.", num_samples);
  end

  // Main stimulus
  initial begin
    // Dump waves
    $dumpfile("wave.vcd");
    $dumpvars(0, tb_fir);

    // Defaults
    rst                 = 1'b1;
    s_axis_fir_tdata    = 16'sd0;
    s_axis_fir_tvalid   = 1'b0;
    m_axis_fir_tready   = 1'b1;

    // Reset
    repeat (10) @(posedge clk);
    rst = 1'b0;
    @(posedge clk);

    // Feed input samples
    s_axis_fir_tvalid = 1'b1;

    for (i = 0; i < num_samples; i = i + 1) begin
      @(posedge clk);
      s_axis_fir_tdata = sample_mem[i][15:0];
    end

    // Stop sending data
    @(posedge clk);
    s_axis_fir_tvalid = 1'b0;
    s_axis_fir_tdata  = 16'sd0;

    // Flush FIR pipeline
    repeat (FIR_LATENCY + 10) @(posedge clk);

    $display("FIR simulation completed.");
    $finish;
  end

endmodule
