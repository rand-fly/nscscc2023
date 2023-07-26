`include "definitions.svh"

module mul (
    input clk,
    input valid,
    input mul_opcode_t opcode,
    input [31:0] src1,
    input [31:0] src2,
    output [31:0] result
);

  wire sign_ex = opcode == MUL_MULH;
  wire [32:0] src1_sign_ex = {sign_ex & src1[31], src1};
  wire [32:0] src2_sign_ex = {sign_ex & src2[31], src2};
  wire [63:0] mul_output;

  mul_opcode_t opcode_buf;

  always_ff @(posedge clk) begin
    opcode_buf <= opcode;
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
    input  wire         CLK,
    input  wire  [32:0] A,
    input  wire  [32:0] B,
    input  wire         CE,
    output logic [63:0] P
);

  always_ff @(posedge CLK) begin
    if (CE) P <= $signed(A) * $signed(B);
  end
endmodule
`endif
