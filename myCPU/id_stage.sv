`include "definitions.svh"

module id_stage (
    input wire             allowout,
    input wire [63:0]      counter,

    output logic [1:0]     id_consume_inst,

    input wire             a_valid,
    input wire [31:0]      a_pc,
    input wire [31:0]      a_inst,
    input wire             a_pred_branch_taken,
    input wire [31:0]      a_pred_branch_target,
    input wire             a_have_exception,
    input wire exception_t a_exception_type,

    input wire             b_valid,
    input wire [31:0]      b_pc,
    input wire [31:0]      b_inst,
    input wire             b_pred_branch_taken,
    input wire [31:0]      b_pred_branch_target,
    input wire             b_have_exception,
    input wire exception_t b_exception_type,

    output logic           id_a_ready,
    output logic [31:0]    id_a_pc,
    output logic           id_a_have_exception,
    output exception_t     id_a_exception_type,
    output opcode_t        id_a_opcode,
    output logic [ 4:0]    id_a_rf_src1,
    output logic [ 4:0]    id_a_rf_src2,
    output logic           id_a_src2_is_imm,
    output logic [31:0]    id_a_imm,
    output logic [4 :0]    id_a_dest,
    output logic           id_a_is_branch,
    output logic           id_a_branch_taken,
    output logic           id_a_branch_condition,
    output logic [31:0]    id_a_branch_target,
    output logic           id_a_is_jirl,
    output logic           id_a_pred_branch_taken,
    output logic [31:0]    id_a_pred_branch_target,
    output logic           id_a_branch_mistaken,
    output mem_type_t      id_a_mem_type,
    output mem_size_t      id_a_mem_size,
    output logic           id_a_is_spec_op,
    output spec_opcode_t   id_a_spec_opcode,

    output logic           id_b_ready,
    output logic [31:0]    id_b_pc,
    output logic           id_b_have_exception,
    output exception_t     id_b_exception_type,
    output opcode_t        id_b_opcode,
    output logic [ 4:0]    id_b_rf_src1,
    output logic [ 4:0]    id_b_rf_src2,
    output logic           id_b_src2_is_imm,
    output logic [31:0]    id_b_imm,
    output logic [4 :0]    id_b_dest,
    output logic           id_b_is_branch,
    output logic           id_b_branch_taken,
    output logic           id_b_branch_condition,
    output logic [31:0]    id_b_branch_target,
    output logic           id_b_is_jirl,
    output logic           id_b_pred_branch_taken,
    output logic [31:0]    id_b_pred_branch_target,
    output logic           id_b_branch_mistaken,
    output mem_type_t      id_b_mem_type,
    output mem_size_t      id_b_mem_size,
    output logic           id_b_is_spec_op,
    output spec_opcode_t   id_b_spec_opcode

`ifdef DIFFTEST_EN
   ,output difftest_t      id_a_difftest,
    output difftest_t      id_b_difftest
`endif
);

logic a_branch_mistaken;
logic b_branch_mistaken;

assign id_a_branch_mistaken = a_branch_mistaken && id_a_ready && !allowout;
assign id_b_branch_mistaken = b_branch_mistaken && id_b_ready && !allowout;

logic a_is_complex_op;
logic b_is_complex_op;
logic raw_hazard;
logic load_use_hazard;

assign a_is_complex_op = id_a_opcode[4];
assign b_is_complex_op = id_b_opcode[4];
assign raw_hazard      = a_valid && b_valid && id_a_dest != 5'd0 && (id_a_dest == id_b_rf_src1 || id_a_dest == id_b_rf_src2);
assign load_use_hazard = raw_hazard && (id_a_mem_type == MEM_LOAD_S || id_b_mem_type == MEM_LOAD_U);

assign id_a_ready = a_valid;
// assign ro_b_ready = ro_a_ready && r3_valid && r4_valid && !RO_a_is_csr_op && !(raw_hazard && (a_is_complex_op || b_is_complex_op || load_use_hazard));
// assign id_b_ready = b_valid && id_a_ready && !id_a_is_spec_op && !raw_hazard && id_b_mem_type == MEM_NOP;
assign id_b_ready = 1'b0;

assign id_a_pc = a_pc;
assign id_b_pc = b_pc;

assign id_consume_inst = allowout   ? 2'd0 :
                         id_b_ready ? 2'd2 :
                         id_a_ready ? 2'd1 :
                                      2'd0 ;

decoder decoder_a(
    .valid(a_valid),
    .pc(a_pc),
    .inst(a_inst),
    .if_have_exception(a_have_exception),
    .if_exception_type(a_exception_type),
    .if_pred_branch_taken(a_pred_branch_taken),
    .if_pred_branch_target(a_pred_branch_target),

    .counter(counter),

    .have_exception(id_a_have_exception),
    .exception_type(id_a_exception_type),
    .opcode(id_a_opcode),
    .rf_src1(id_a_rf_src1),
    .rf_src2(id_a_rf_src2),
    .src2_is_imm(id_a_src2_is_imm),
    .imm(id_a_imm),
    .dest(id_a_dest),
    .is_branch(id_a_is_branch),
    .branch_target(id_a_branch_target),
    .branch_mistaken(a_branch_mistaken),
    .branch_taken(id_a_branch_taken),
    .branch_condition(id_a_branch_condition),
    .is_jirl(id_a_is_jirl),
    .pred_branch_taken(id_a_pred_branch_taken),
    .pred_branch_target(id_a_pred_branch_target),
    .mem_type(id_a_mem_type),
    .mem_size(id_a_mem_size),
    .is_spec_op(id_a_is_spec_op),
    .spec_opcode(id_a_spec_opcode)
);

decoder decoder_b(
    .valid(b_valid),
    .pc(b_pc),
    .inst(b_inst),
    .if_have_exception(b_have_exception),
    .if_exception_type(b_exception_type),
    .if_pred_branch_taken(b_pred_branch_taken),
    .if_pred_branch_target(b_pred_branch_target),

    .counter(counter),

    .have_exception(id_b_have_exception),
    .exception_type(id_b_exception_type),
    .opcode(id_b_opcode),
    .rf_src1(id_b_rf_src1),
    .rf_src2(id_b_rf_src2),
    .src2_is_imm(id_b_src2_is_imm),
    .imm(id_b_imm),
    .dest(id_b_dest),
    .is_branch(id_b_is_branch),
    .branch_target(id_b_branch_target),
    .branch_mistaken(b_branch_mistaken),
    .branch_taken(id_b_branch_taken),
    .branch_condition(id_b_branch_condition),
    .is_jirl(id_b_is_jirl),
    .pred_branch_taken(id_b_pred_branch_taken),
    .pred_branch_target(id_b_pred_branch_target),
    .mem_type(id_b_mem_type),
    .mem_size(id_b_mem_size),
    .is_spec_op(id_b_is_spec_op),
    .spec_opcode(id_b_spec_opcode)
);

`ifdef DIFFTEST_EN
assign id_a_difftest.instr = a_inst;
assign id_a_difftest.is_CNTinst = decoder_a.inst_rdcntvl_w | decoder_a.inst_rdcntvh_w | decoder_a.inst_rdcntid_w;
assign id_a_difftest.timer_64_value = counter;
assign id_b_difftest.instr = b_inst;
assign id_b_difftest.is_CNTinst = decoder_b.inst_rdcntvl_w | decoder_b.inst_rdcntvh_w | decoder_b.inst_rdcntid_w;
assign id_b_difftest.timer_64_value = counter;
`endif

endmodule