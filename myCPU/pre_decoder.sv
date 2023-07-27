`include "definitions.svh"

module pre_decoder (
    input [31:0] pc,
    input [31:0] inst,
    output is_br,
    output is_imm_br,
    output is_jirl,
    output [31:0] br_target
);


  wire [ 5:0] op_31_26 = inst[31:26];

  wire [15:0] i16 = inst[25:10];
  wire [25:0] i26 = {inst[9:0], inst[25:10]};

  wire [31:0] si16 = {{14{i16[15]}}, i16, 2'b0};
  wire [31:0] si26 = {{4{i26[25]}}, i26, 2'b0};

  wire        inst_jirl = op_31_26 == 6'b010011;
  wire        inst_b = op_31_26 == 6'b010100;
  wire        inst_bl = op_31_26 == 6'b010101;
  wire        inst_beq = op_31_26 == 6'b010110;
  wire        inst_bne = op_31_26 == 6'b010111;
  wire        inst_blt = op_31_26 == 6'b011000;
  wire        inst_bge = op_31_26 == 6'b011001;
  wire        inst_bltu = op_31_26 == 6'b011010;
  wire        inst_bgeu = op_31_26 == 6'b011011;

  assign is_br = inst_jirl | inst_b | inst_bl | inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;
  assign is_imm_br = inst_b | inst_bl;
  assign is_jirl = inst_jirl;

  wire [31:0] pc_add_si16 = pc + si16;
  wire [31:0] pc_add_si26 = pc + si26;

  assign br_target = is_imm_br ? pc_add_si26 : pc_add_si16;

endmodule
