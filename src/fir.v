// ============================================================
// Parameterized FIR (Q15 in/out)
// - Coefficients loaded from file (readmemh)
// - Balanced pipelined adder tree
// - 16x16 mult, 36-bit accumulate
// ============================================================
module fir #(
    parameter integer NTAPS      = 121,
    parameter integer N_TREE     = 128,          // power-of-2 >= NTAPS
    parameter integer FRAC_BITS  = 15,
    parameter integer ACC_W      = 36,
    parameter integer LATENCY    = 10,
    parameter string  COEFF_FILE = "fir_coeffs_q15.hex"
)(
    input  wire               clk,
    input  wire               rst,
    input  wire signed [15:0] s_axis_fir_tdata,
    input  wire               s_axis_fir_tvalid,
    input  wire               m_axis_fir_tready,
    output reg                m_axis_fir_tvalid,
    output reg  signed [31:0] m_axis_fir_tdata
);

    integer i, k;
    wire accept = s_axis_fir_tvalid && m_axis_fir_tready;

    // ------------------------------------------------------------
    // Coefficients (Q15) loaded from file
    // ------------------------------------------------------------
    reg signed [15:0] taps [0:NTAPS-1];
    initial begin
        $readmemh(COEFF_FILE, taps);
    end

    // ------------------------------------------------------------
    // Shift register buffer
    // ------------------------------------------------------------
    reg signed [15:0] buff [0:NTAPS-1];

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < NTAPS; i = i + 1)
                buff[i] <= 16'sd0;
        end else if (accept) begin
            buff[0] <= s_axis_fir_tdata;
            for (i = 1; i < NTAPS; i = i + 1)
                buff[i] <= buff[i-1];
        end
    end

    // ------------------------------------------------------------
    // Stage 1: registered multipliers
    // ------------------------------------------------------------
    reg signed [31:0] mult_reg [0:NTAPS-1];

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < NTAPS; i = i + 1)
                mult_reg[i] <= 32'sd0;
        end else if (accept) begin
            for (i = 0; i < NTAPS; i = i + 1)
                mult_reg[i] <= buff[i] * taps[i];
        end
    end

    // ------------------------------------------------------------
    // Extend + zero pad to N_TREE
    // ------------------------------------------------------------
    wire signed [ACC_W-1:0] mult_ext [0:N_TREE-1];
    genvar g;
    generate
        for (g = 0; g < NTAPS; g = g + 1)
            assign mult_ext[g] = {{(ACC_W-32){mult_reg[g][31]}}, mult_reg[g]};
        for (g = NTAPS; g < N_TREE; g = g + 1)
            assign mult_ext[g] = {ACC_W{1'b0}};
    endgenerate

    // ------------------------------------------------------------
    // Pipelined balanced adder tree
    // 128 -> 64 -> 32 -> 16 -> 8 -> 4 -> 2 -> 1
    // ------------------------------------------------------------
    reg signed [ACC_W-1:0] sum_l0 [0:(N_TREE/2)-1];
    reg signed [ACC_W-1:0] sum_l1 [0:(N_TREE/4)-1];
    reg signed [ACC_W-1:0] sum_l2 [0:(N_TREE/8)-1];
    reg signed [ACC_W-1:0] sum_l3 [0:(N_TREE/16)-1];
    reg signed [ACC_W-1:0] sum_l4 [0:(N_TREE/32)-1];
    reg signed [ACC_W-1:0] sum_l5 [0:(N_TREE/64)-1];
    reg signed [ACC_W-1:0] sum_l6;

    always @(posedge clk) begin
        if (rst) begin
            for (k = 0; k < (N_TREE/2);  k = k + 1) sum_l0[k] <= '0;
            for (k = 0; k < (N_TREE/4);  k = k + 1) sum_l1[k] <= '0;
            for (k = 0; k < (N_TREE/8);  k = k + 1) sum_l2[k] <= '0;
            for (k = 0; k < (N_TREE/16); k = k + 1) sum_l3[k] <= '0;
            for (k = 0; k < (N_TREE/32); k = k + 1) sum_l4[k] <= '0;
            for (k = 0; k < (N_TREE/64); k = k + 1) sum_l5[k] <= '0;
            sum_l6 <= '0;
        end else if (accept) begin
            for (k = 0; k < (N_TREE/2);  k = k + 1)
                sum_l0[k] <= mult_ext[2*k] + mult_ext[2*k+1];
            for (k = 0; k < (N_TREE/4);  k = k + 1)
                sum_l1[k] <= sum_l0[2*k] + sum_l0[2*k+1];
            for (k = 0; k < (N_TREE/8);  k = k + 1)
                sum_l2[k] <= sum_l1[2*k] + sum_l1[2*k+1];
            for (k = 0; k < (N_TREE/16); k = k + 1)
                sum_l3[k] <= sum_l2[2*k] + sum_l2[2*k+1];
            for (k = 0; k < (N_TREE/32); k = k + 1)
                sum_l4[k] <= sum_l3[2*k] + sum_l3[2*k+1];
            for (k = 0; k < (N_TREE/64); k = k + 1)
                sum_l5[k] <= sum_l4[2*k] + sum_l4[2*k+1];
            sum_l6 <= sum_l5[0] + sum_l5[1];
        end
    end

    // ------------------------------------------------------------
    // Output scaling + valid alignment
    // ------------------------------------------------------------
    wire signed [ACC_W-1:0] acc_shifted = sum_l6 >>> FRAC_BITS;
    reg [LATENCY-1:0] vld_pipe;

    always @(posedge clk) begin
        if (rst) begin
            vld_pipe         <= '0;
            m_axis_fir_tvalid <= 1'b0;
            m_axis_fir_tdata  <= 32'sd0;
        end else begin
            if (m_axis_fir_tready)
                vld_pipe <= {vld_pipe[LATENCY-2:0], s_axis_fir_tvalid};

            m_axis_fir_tvalid <= vld_pipe[LATENCY-1];

            if (vld_pipe[LATENCY-1] && m_axis_fir_tready)
                m_axis_fir_tdata <= acc_shifted[31:0];
        end
    end

endmodule
