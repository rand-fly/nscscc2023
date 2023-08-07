`include "definitions.svh"

module div (
    input clk,
    input valid,
    input div_opcode_t opcode,
    input [31:0] src1,
    input [31:0] src2,
    output ok,
    output [31:0] result
);
  logic is_div_buf;
  logic div_sign_buf;
  logic mod_sign_buf;

  wire is_div = opcode == DIV_DIV || opcode == DIV_DIVU;
  wire is_signed = opcode == DIV_DIV || opcode == DIV_MOD;
  wire div_sign = is_signed && (src1[31] ^ src2[31]);
  wire mod_sign = is_signed && src1[31];

  wire [63:0] div_output;
  wire [31:0] div_result = div_sign_buf ? -div_output[63:32] : div_output[63:32];
  wire [31:0] mod_result = mod_sign_buf ? -div_output[31:0] : div_output[31:0];
  wire [31:0] src1_signed = (is_signed && src1[31]) ? -src1 : src1;
  wire [31:0] src2_signed = (is_signed && src2[31]) ? -src2 : src2;

  always_ff @(posedge clk) begin
    if (valid) begin
      is_div_buf   <= is_div;
      div_sign_buf <= div_sign;
      mod_sign_buf <= mod_sign;
    end
  end

  assign result = is_div_buf ? div_result : mod_result;

  div_gen_0 u_div_gen_0 (
      .aclk(clk),
      .s_axis_divisor_tvalid(valid),
      .s_axis_divisor_tdata(src2_signed),
      .s_axis_dividend_tvalid(valid),
      .s_axis_dividend_tdata(src1_signed),
      .m_axis_dout_tvalid(ok),
      .m_axis_dout_tdata(div_output)
  );

endmodule
