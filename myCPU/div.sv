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

// for verilator simulation
`ifdef SIMU
// not pipelined
module div_gen_0 (
    input  wire         aclk,
    input  wire         s_axis_divisor_tvalid,
    input  wire  [31:0] s_axis_divisor_tdata,
    input  wire         s_axis_dividend_tvalid,
    input  wire  [31:0] s_axis_dividend_tdata,
    output logic        m_axis_dout_tvalid,
    output logic [63:0] m_axis_dout_tdata
);

  logic        valid;
  logic [ 4:0] counter;
  logic [31:0] divisor;
  logic [31:0] dividend;

  always_ff @(posedge aclk) begin
    if (valid) begin
      if (counter == 5'd0) begin
        valid <= 1'b0;
        m_axis_dout_tvalid <= 1'b1;
        m_axis_dout_tdata <= {dividend / divisor, dividend % divisor};
      end else begin
        counter <= counter - 5'd1;
      end
    end else begin
      m_axis_dout_tvalid <= 1'b0;
    end
    if (s_axis_divisor_tvalid && s_axis_dividend_tvalid) begin
      valid <= 1'd1;
      counter <= 5'd30;
      divisor <= s_axis_divisor_tdata;
      dividend <= s_axis_dividend_tdata;
    end
  end
endmodule
`endif
