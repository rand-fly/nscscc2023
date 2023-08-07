// for verilator simulation
`ifdef SIMU
module mult_gen_0 (
    input             CLK,
    input      [32:0] A,
    input      [32:0] B,
    output reg [63:0] P
);
  logic [32:0] A_reg;
  logic [32:0] B_reg;

  always_ff @(posedge CLK) begin
    A_reg <= A;
    B_reg <= B;
  end

  always_ff @(posedge CLK) begin
    P <= $signed(A_reg) * $signed(B_reg);
  end
endmodule
`endif
