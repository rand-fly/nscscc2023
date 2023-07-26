`include "definitions.svh"

module alu (
    input alu_opcode_t opcode,
    input [31:0] src1,
    input [31:0] src2,
    output logic [31:0] result
);

  always_comb begin
    unique case (opcode)
      ALU_OUT2: result = src2;
      ALU_ADD:  result = src1 + src2;
      ALU_SUB:  result = src1 - src2;
      ALU_EQU:  result = src1 == src2 ? 32'd1 : 32'd0;
      ALU_SLT:  result = $signed(src1) < $signed(src2) ? 32'd1 : 32'd0;
      ALU_SLTU: result = src1 < src2 ? 32'd1 : 32'd0;
      ALU_AND:  result = src1 & src2;
      ALU_NOR:  result = ~(src1 | src2);
      ALU_OR:   result = src1 | src2;
      ALU_XOR:  result = src1 ^ src2;
      ALU_SLL:  result = src1 << src2[4:0];
      ALU_SRL:  result = src1 >> src2[4:0];
      ALU_SRA:  result = $signed(src1) >>> src2[4:0];
      default:  result = src1;
    endcase
  end

endmodule
