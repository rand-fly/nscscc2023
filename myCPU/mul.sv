`include "definitions.svh"

module mul (
    input clk,
    input valid,
    input mul_opcode_t opcode,
    input [31:0] src1,
    input [31:0] src2,
    output reg ok,
    output [31:0] result
);

  wire sign_ex = opcode == MUL_MULH;
  wire [32:0] src1_sign_ex = {sign_ex & src1[31], src1};
  wire [32:0] src2_sign_ex = {sign_ex & src2[31], src2};
  wire [63:0] mul_output;

  mul_opcode_t opcode_buf;

  logic valid_buf;

  always_ff @(posedge clk) begin
    if (valid) opcode_buf <= opcode;
  end

  always_ff @(posedge clk) begin
    valid_buf <= valid;
    ok <= valid_buf;
  end

  assign result = opcode_buf == MUL_MUL ? mul_output[31:0] : mul_output[63:32];

  mult_gen_0 u_mult_gen_0 (
      .CLK(clk),
      .A  (src1_sign_ex),
      .B  (src2_sign_ex),
      .CE (valid),
      .P  (mul_output)
  );

endmodule

// for verilator simulation
`ifdef SIMU
module mult_gen_0 (
    input             CLK,
    input      [32:0] A,
    input      [32:0] B,
    input             CE,
    output reg [63:0] P
);
  logic [32:0] A_reg;
  logic [32:0] B_reg;
  logic [32:0] CE_reg;

  always_ff @(posedge CLK) begin
    A_reg  <= A;
    B_reg  <= B;
    CE_reg <= CE;
  end

  always_ff @(posedge CLK) begin
    if (CE_reg) P <= $signed(A_reg) * $signed(B_reg);
  end
endmodule
`endif
