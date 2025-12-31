// ============================================================
// Parameterized FIR (Q15 in/out)
// LibreLane / Yosys / Verilator compatible
// ============================================================
module fir_filter #(
    parameter integer NTAPS      = 121,
    parameter integer N_TREE     = 128,
    parameter integer FRAC_BITS  = 15,
    parameter integer ACC_W      = 36,
    parameter integer LATENCY    = 9,
    parameter COEFF_FILE         = "fir_coeffs_q15.hex"
)(
    input  wire               clk,
    input  wire               rst,
    input  wire signed [15:0] s_axis_fir_tdata,
    input  wire               s_axis_fir_tvalid,
    input  wire               m_axis_fir_tready,
    output reg                m_axis_fir_tvalid,
    output reg  signed [31:0] m_axis_fir_tdata
);

    wire ce_data = s_axis_fir_tvalid && m_axis_fir_tready;
    wire ce_out  = m_axis_fir_tready;

    genvar g;

    // Buffered enables to reduce fanout
    reg ce_data_s1, ce_data_s2, ce_data_s3, ce_data_s4;
    reg ce_data_s5, ce_data_s6, ce_data_s7, ce_data_s8;

    // Reset tree to reduce fanout
    reg rst_s1, rst_s2, rst_s3, rst_s4;
    reg rst_s5, rst_s6, rst_s7, rst_s8;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ce_data_s1 <= 1'b0;
            ce_data_s2 <= 1'b0;
            ce_data_s3 <= 1'b0;
            ce_data_s4 <= 1'b0;
            ce_data_s5 <= 1'b0;
            ce_data_s6 <= 1'b0;
            ce_data_s7 <= 1'b0;
            ce_data_s8 <= 1'b0;
            rst_s1 <= 1'b1;
            rst_s2 <= 1'b1;
            rst_s3 <= 1'b1;
            rst_s4 <= 1'b1;
            rst_s5 <= 1'b1;
            rst_s6 <= 1'b1;
            rst_s7 <= 1'b1;
            rst_s8 <= 1'b1;
        end else begin
            ce_data_s1 <= ce_data;
            ce_data_s2 <= ce_data_s1;
            ce_data_s3 <= ce_data_s2;
            ce_data_s4 <= ce_data_s3;
            ce_data_s5 <= ce_data_s4;
            ce_data_s6 <= ce_data_s5;
            ce_data_s7 <= ce_data_s6;
            ce_data_s8 <= ce_data_s7;
            rst_s1 <= 1'b0;
            rst_s2 <= 1'b0;
            rst_s3 <= 1'b0;
            rst_s4 <= 1'b0;
            rst_s5 <= 1'b0;
            rst_s6 <= 1'b0;
            rst_s7 <= 1'b0;
            rst_s8 <= 1'b0;
        end
    end

    // Coefficients
    reg signed [15:0] taps [0:NTAPS-1];
    initial begin
        $readmemh(COEFF_FILE, taps);
        $display("FIR: Loaded coefficients from %s", COEFF_FILE);
        $display("FIR: taps[0] = %h (%d)", taps[0], taps[0]);
        $display("FIR: taps[60] = %h (%d)", taps[60], taps[60]);
    end

    // Shift register
    reg signed [15:0] buff [0:NTAPS-1];

    always @(posedge clk) begin
        if (rst) buff[0] <= 16'd0;
        else if (ce_data) buff[0] <= s_axis_fir_tdata;
    end

    generate
        for (g = 1; g < NTAPS; g = g + 1) begin : gen_sreg
            always @(posedge clk) begin
                if (rst) buff[g] <= 16'd0;
                else if (ce_data) buff[g] <= buff[g-1];
            end
        end
    endgenerate

    // Multipliers
    reg signed [31:0] mult_reg [0:NTAPS-1];

    generate
        for (g = 0; g < NTAPS; g = g + 1) begin : gen_mult
            always @(posedge clk) begin
                if (rst_s1) mult_reg[g] <= 32'd0;
                else if (ce_data_s1) mult_reg[g] <= buff[g] * taps[g];
            end
        end
    endgenerate

    // Extend to power-of-2
    wire signed [ACC_W-1:0] mult_ext [0:N_TREE-1];
    generate
        for (g = 0; g < NTAPS; g = g + 1)
            assign mult_ext[g] = {{(ACC_W-32){mult_reg[g][31]}}, mult_reg[g]};
        for (g = NTAPS; g < N_TREE; g = g + 1)
            assign mult_ext[g] = '0;
    endgenerate

    // ------------------------------------------------------------
    // Pipelined adder tree (8 stages - one per level)
    // Each level is a separate pipeline stage to minimize combinational depth
    // ------------------------------------------------------------
    
    // Level 0: 128 -> 64 (64 additions)
    reg signed [ACC_W-1:0] sum_l0 [0:(N_TREE/2)-1];
    
    generate
        for (g = 0; g < (N_TREE/2); g = g + 1) begin : gen_sum_l0
            always @(posedge clk) begin
                if (rst_s2) sum_l0[g] <= '0;
                else if (ce_data_s2) sum_l0[g] <= mult_ext[2*g] + mult_ext[2*g+1];
            end
        end
    endgenerate
    
    // Level 1: 64 -> 32 (32 additions)
    reg signed [ACC_W-1:0] sum_l1 [0:(N_TREE/4)-1];
    
    generate
        for (g = 0; g < (N_TREE/4); g = g + 1) begin : gen_sum_l1
            always @(posedge clk) begin
                if (rst_s3) sum_l1[g] <= '0;
                else if (ce_data_s3) sum_l1[g] <= sum_l0[2*g] + sum_l0[2*g+1];
            end
        end
    endgenerate
    
    // Level 2: 32 -> 16 (16 additions)
    reg signed [ACC_W-1:0] sum_l2 [0:(N_TREE/8)-1];
    
    generate
        for (g = 0; g < (N_TREE/8); g = g + 1) begin : gen_sum_l2
            always @(posedge clk) begin
                if (rst_s4) sum_l2[g] <= '0;
                else if (ce_data_s4) sum_l2[g] <= sum_l1[2*g] + sum_l1[2*g+1];
            end
        end
    endgenerate
    
    // Level 3: 16 -> 8 (8 additions)
    reg signed [ACC_W-1:0] sum_l3 [0:(N_TREE/16)-1];
    
    generate
        for (g = 0; g < (N_TREE/16); g = g + 1) begin : gen_sum_l3
            always @(posedge clk) begin
                if (rst_s5) sum_l3[g] <= '0;
                else if (ce_data_s5) sum_l3[g] <= sum_l2[2*g] + sum_l2[2*g+1];
            end
        end
    endgenerate
    
    // Level 4: 8 -> 4 (4 additions)
    reg signed [ACC_W-1:0] sum_l4 [0:(N_TREE/32)-1];
    
    generate
        for (g = 0; g < (N_TREE/32); g = g + 1) begin : gen_sum_l4
            always @(posedge clk) begin
                if (rst_s6) sum_l4[g] <= '0;
                else if (ce_data_s6) sum_l4[g] <= sum_l3[2*g] + sum_l3[2*g+1];
            end
        end
    endgenerate
    
    // Level 5: 4 -> 2 (2 additions)
    reg signed [ACC_W-1:0] sum_l5 [0:(N_TREE/64)-1];
    
    generate
        for (g = 0; g < (N_TREE/64); g = g + 1) begin : gen_sum_l5
            always @(posedge clk) begin
                if (rst_s7) sum_l5[g] <= '0;
                else if (ce_data_s7) sum_l5[g] <= sum_l4[2*g] + sum_l4[2*g+1];
            end
        end
    endgenerate
    
    // Level 6: 2 -> 1 (1 addition)
    reg signed [ACC_W-1:0] sum_l6;
    
    always @(posedge clk) begin
        if (rst_s8) begin
            sum_l6 <= '0;
        end else if (ce_data_s8) begin
            sum_l6 <= sum_l5[0] + sum_l5[1];
        end
    end

    wire signed [ACC_W-1:0] acc_shifted = sum_l6 >>> FRAC_BITS;
    reg  [LATENCY-1:0]      vld_pipe;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            vld_pipe          <= '0;
            m_axis_fir_tvalid <= 1'b0;
            m_axis_fir_tdata  <= 32'd0;
        end else if (ce_out) begin
            vld_pipe <= {vld_pipe[LATENCY-2:0], s_axis_fir_tvalid};
            m_axis_fir_tvalid <= vld_pipe[LATENCY-1];
            if (vld_pipe[LATENCY-1])
                m_axis_fir_tdata <= acc_shifted[31:0];
        end
    end
endmodule
