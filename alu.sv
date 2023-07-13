`include "definitions.svh"

module alu(
  input  wire  opcode_t op,
  input  wire  [31:0] src1,
  input  wire  [31:0] src2,
  output logic [31:0] result
);

always_comb begin
    unique case(op)
        OP_OUT1: result = src1;
        OP_OUT2: result = src2;
        OP_ADD:  result = src1 + src2;
        OP_SUB:  result = src1 - src2;
        OP_EQU:  result = src1 == src2 ? 32'd1 : 32'd0;
        OP_SLT:  result = $signed(src1) < $signed(src2) ? 32'd1 : 32'd0;
        OP_SLTU: result = src1 < src2 ? 32'd1 : 32'd0;
        OP_AND:  result = src1 & src2;
        OP_NOR:  result = ~(src1 | src2);
        OP_OR:   result = src1 | src2;
        OP_XOR:  result = src1 ^ src2;
        OP_SLL:  result = src1 << src2[4:0];
        OP_SRL:  result = src1 >> src2[4:0];
        OP_SRA:  result = $signed(src1) >>> src2[4:0];
        default:  result = src1;
    endcase
end

endmodule
