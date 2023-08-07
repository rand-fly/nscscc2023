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
