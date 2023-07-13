`include "definitions.svh"

module ro_stage (
    input wire             clk,
    input wire             reset,

    input wire             flush,
    input wire             ex_stall,
    output logic           ro_valid,
    output logic           ro_ready, // 工作完成了吗
    output logic           ro_stall, // 是否暂停（上一阶段可以进来吗）

    input wire             id_a_ready,
    input wire [31:0]      id_a_pc,
    input wire             id_a_have_exception,
    input wire exception_t id_a_exception_type,
    input wire opcode_t    id_a_opcode,
    input wire [ 4:0]      id_a_rf_src1,
    input wire [ 4:0]      id_a_rf_src2,
    input wire             id_a_src2_is_imm,
    input wire [31:0]      id_a_imm,
    input wire [4 :0]      id_a_dest,
    input wire             id_a_is_branch,
    input wire             id_a_branch_taken,
    input wire             id_a_branch_condition,
    input wire [31:0]      id_a_branch_target,
    input wire             id_a_is_jirl,
    input wire             id_a_pred_branch_taken,
    input wire [31:0]      id_a_pred_branch_target,
    input wire             id_a_branch_mistaken,
    input wire mem_type_t  id_a_mem_type,
    input wire mem_size_t  id_a_mem_size,
    input wire [31:0]      id_a_st_data,
    input wire             id_a_is_csr_op,
    input wire [13:0]      id_a_csr_addr,
    input wire [31:0]      id_a_csr_mask,

    input wire             id_b_ready,
    input wire [31:0]      id_b_pc,
    input wire             id_b_have_exception,
    input wire exception_t id_b_exception_type,
    input wire opcode_t    id_b_opcode,
    input wire [ 4:0]      id_b_rf_src1,
    input wire [ 4:0]      id_b_rf_src2,
    input wire             id_b_src2_is_imm,
    input wire [31:0]      id_b_imm,
    input wire [4 :0]      id_b_dest,
    input wire             id_b_is_branch,
    input wire             id_b_branch_taken,
    input wire             id_b_branch_condition,
    input wire [31:0]      id_b_branch_target,
    input wire             id_b_is_jirl,
    input wire             id_b_pred_branch_taken,
    input wire [31:0]      id_b_pred_branch_target,
    input wire             id_b_branch_mistaken,
    input wire mem_type_t  id_b_mem_type,
    input wire mem_size_t  id_b_mem_size,
    input wire [31:0]      id_b_st_data,
    input wire             id_b_is_csr_op,
    input wire [13:0]      id_b_csr_addr,
    input wire [31:0]      id_b_csr_mask,

    output logic [4:0]     r1_addr,
    input wire [31:0]      r1_data,
    output logic [4:0]     r2_addr,
    input wire [31:0]      r2_data,
    output logic [4:0]     r3_addr,
    input wire [31:0]      r3_data,
    output logic [4:0]     r4_addr,
    input wire [31:0]      r4_data,

    input wire             ex_a_valid,
    input wire             ex_a_forwardable,
    input wire    [ 4:0]   ex_a_dest,
    input wire    [31:0]   ex_a_result,
    input wire             ex_b_valid,
    input wire             ex_b_forwardable,
    input wire    [ 4:0]   ex_b_dest,
    input wire    [31:0]   ex_b_result,

    input wire             mem_a_valid,
    input wire             mem_a_forwardable,
    input wire    [ 4:0]   mem_a_dest,
    input wire    [31:0]   mem_a_result,
    input wire             mem_b_valid,
    input wire             mem_b_forwardable,
    input wire    [ 4:0]   mem_b_dest,
    input wire    [31:0]   mem_b_result,

    input wire             wb_a_valid,
    input wire             wb_a_forwardable,
    input wire    [ 4:0]   wb_a_dest,
    input wire    [31:0]   wb_a_result,
    input wire             wb_b_valid,
    input wire             wb_b_forwardable,
    input wire    [ 4:0]   wb_b_dest,
    input wire    [31:0]   wb_b_result,

    output logic           ro_a_valid,
    output logic [31:0]    ro_a_pc,
    output logic           ro_a_have_exception,
    output exception_t     ro_a_exception_type,
    output opcode_t        ro_a_opcode,
    output logic [31:0]    ro_a_src1,
    output logic [31:0]    ro_a_src2,
    output logic [4 :0]    ro_a_dest,
    output logic           ro_a_is_branch,
    output logic           ro_a_branch_taken,
    output logic           ro_a_branch_condition,
    output logic [31:0]    ro_a_branch_target,
    output logic           ro_a_pred_branch_taken,
    output logic [31:0]    ro_a_pred_branch_target,
    output logic           ro_a_branch_mistaken,
    output mem_type_t      ro_a_mem_type,
    output mem_size_t      ro_a_mem_size,
    output logic [31:0]    ro_a_st_data,
    output logic           ro_a_is_csr_op,
    output logic [13:0]    ro_a_csr_addr,
    output logic [31:0]    ro_a_csr_mask,

    output logic           ro_b_valid,
    output logic [31:0]    ro_b_pc,
    output logic           ro_b_have_exception,
    output exception_t     ro_b_exception_type,
    output opcode_t        ro_b_opcode,
    output logic [31:0]    ro_b_src1,
    output logic [31:0]    ro_b_src2,
    output logic [4 :0]    ro_b_dest,
    output logic           ro_b_is_branch,
    output logic           ro_b_branch_taken,
    output logic           ro_b_branch_condition,
    output logic [31:0]    ro_b_branch_target,
    output logic           ro_b_pred_branch_taken,
    output logic [31:0]    ro_b_pred_branch_target,
    output logic           ro_b_branch_mistaken,
    output mem_type_t      ro_b_mem_type,
    output mem_size_t      ro_b_mem_size,
    output logic [31:0]    ro_b_st_data,
    output logic           ro_b_is_csr_op,
    output logic [13:0]    ro_b_csr_addr,
    output logic [31:0]    ro_b_csr_mask
);

logic        a_branch_mistaken;
logic        b_branch_mistaken;

assign       ro_a_branch_mistaken = a_branch_mistaken && !ro_stall;
assign       ro_b_branch_mistaken = b_branch_mistaken && !ro_stall;

logic        forward_valid1;
logic [ 4:0] forward_addr1;
logic [31:0] forward_data1;
logic        forward_valid2;
logic [ 4:0] forward_addr2;
logic [31:0] forward_data2;
logic        forward_valid3;
logic [ 4:0] forward_addr3;
logic [31:0] forward_data3;
logic        forward_valid4;
logic [ 4:0] forward_addr4;
logic [31:0] forward_data4;

logic        ro_a_ready;
logic        ro_b_ready;

assign ro_valid = ro_a_valid || ro_b_valid;
assign ro_ready = ro_valid && (!ro_a_valid || ro_a_ready) && (!ro_b_valid || ro_b_ready);
assign ro_stall = ro_valid && (!ro_ready || ex_stall);

read_operands read_operands_a(
    .clk(clk),
    .reset(reset),

    .flush(flush),
    .allowout(!ro_stall),

    .id_ready(id_a_ready),
    .id_pc(id_a_pc),
    .id_have_exception(id_a_have_exception),
    .id_exception_type(id_a_exception_type),
    .id_opcode(id_a_opcode),
    .id_rf_src1(id_a_rf_src1),
    .id_rf_src2(id_a_rf_src2),
    .id_src2_is_imm(id_a_src2_is_imm),
    .id_imm(id_a_imm),
    .id_dest(id_a_dest),
    .id_is_branch(id_a_is_branch),
    .id_branch_taken(id_a_branch_taken),
    .id_branch_condition(id_a_branch_condition),
    .id_branch_target(id_a_branch_target),
    .id_is_jirl(id_a_is_jirl),
    .id_pred_branch_taken(id_a_pred_branch_taken),
    .id_pred_branch_target(id_a_pred_branch_target),
    .id_branch_mistaken(id_a_branch_mistaken),
    .id_mem_type(id_a_mem_type),
    .id_mem_size(id_a_mem_size),
    .id_st_data(id_a_st_data),
    .id_is_csr_op(id_a_is_csr_op),
    .id_csr_addr(id_a_csr_addr),
    .id_csr_mask(id_a_csr_mask),

    .r1_addr(forward_addr1),
    .r1_valid(forward_valid1),
    .r1_data(forward_data1),

    .r2_addr(forward_addr2),
    .r2_valid(forward_valid2),
    .r2_data(forward_data2),

    .ro_valid(ro_a_valid),
    .ro_ready(ro_a_ready),
    .ro_pc(ro_a_pc),
    .ro_have_exception(ro_a_have_exception),
    .ro_exception_type(ro_a_exception_type),
    .ro_opcode(ro_a_opcode),
    .ro_src1(ro_a_src1),
    .ro_src2(ro_a_src2),
    .ro_dest(ro_a_dest),
    .ro_is_branch(ro_a_is_branch),
    .ro_branch_taken(ro_a_branch_taken),
    .ro_branch_condition(ro_a_branch_condition),
    .ro_branch_target(ro_a_branch_target),
    .ro_pred_branch_taken(ro_a_pred_branch_taken),
    .ro_pred_branch_target(ro_a_pred_branch_target),
    .ro_branch_mistaken(a_branch_mistaken),
    .ro_mem_type(ro_a_mem_type),
    .ro_mem_size(ro_a_mem_size),
    .ro_st_data(ro_a_st_data),
    .ro_is_csr_op(ro_a_is_csr_op),
    .ro_csr_addr(ro_a_csr_addr),
    .ro_csr_mask(ro_a_csr_mask)
);

read_operands read_operands_b(
    .clk(clk),
    .reset(reset),

    .flush(flush),
    .allowout(!ro_stall),

    .id_ready(id_b_ready && !id_a_branch_mistaken),
    .id_pc(id_b_pc),
    .id_have_exception(id_b_have_exception),
    .id_exception_type(id_b_exception_type),
    .id_opcode(id_b_opcode),
    .id_rf_src1(id_b_rf_src1),
    .id_rf_src2(id_b_rf_src2),
    .id_src2_is_imm(id_b_src2_is_imm),
    .id_imm(id_b_imm),
    .id_dest(id_b_dest),
    .id_is_branch(id_b_is_branch),
    .id_branch_taken(id_b_branch_taken),
    .id_branch_condition(id_b_branch_condition),
    .id_branch_target(id_b_branch_target),
    .id_is_jirl(id_b_is_jirl),
    .id_pred_branch_taken(id_b_pred_branch_taken),
    .id_pred_branch_target(id_b_pred_branch_target),
    .id_branch_mistaken(id_b_branch_mistaken),
    .id_mem_type(id_b_mem_type),
    .id_mem_size(id_b_mem_size),
    .id_st_data(id_b_st_data),
    .id_is_csr_op(id_b_is_csr_op),
    .id_csr_addr(id_b_csr_addr),
    .id_csr_mask(id_b_csr_mask),

    .r1_addr(forward_addr3),
    .r1_valid(forward_valid3),
    .r1_data(forward_data3),

    .r2_addr(forward_addr4),
    .r2_valid(forward_valid4),
    .r2_data(forward_data4),

    .ro_valid(ro_b_valid),
    .ro_ready(ro_b_ready),
    .ro_pc(ro_b_pc),
    .ro_have_exception(ro_b_have_exception),
    .ro_exception_type(ro_b_exception_type),
    .ro_opcode(ro_b_opcode),
    .ro_src1(ro_b_src1),
    .ro_src2(ro_b_src2),
    .ro_dest(ro_b_dest),
    .ro_is_branch(ro_b_is_branch),
    .ro_branch_taken(ro_b_branch_taken),
    .ro_branch_condition(ro_b_branch_condition),
    .ro_branch_target(ro_b_branch_target),
    .ro_pred_branch_taken(ro_b_pred_branch_taken),
    .ro_pred_branch_target(ro_b_pred_branch_target),
    .ro_branch_mistaken(b_branch_mistaken),
    .ro_mem_type(ro_b_mem_type),
    .ro_mem_size(ro_b_mem_size),
    .ro_st_data(ro_b_st_data),
    .ro_is_csr_op(ro_b_is_csr_op),
    .ro_csr_addr(ro_b_csr_addr),
    .ro_csr_mask(ro_b_csr_mask)
);

forwarding_unit forwarding_unit1(
    .addr(forward_addr1),
    .valid(forward_valid1),
    .data(forward_data1),

    .rf_addr(r1_addr),
    .rf_data(r1_data),

    .ex_a_valid(ex_a_valid),
    .ex_a_forwardable(ex_a_forwardable),
    .ex_a_dest(ex_a_dest),
    .ex_a_result(ex_a_result),
    .ex_b_valid(ex_b_valid),
    .ex_b_forwardable(ex_b_forwardable),
    .ex_b_dest(ex_b_dest),
    .ex_b_result(ex_b_result),

    .mem_a_valid(mem_a_valid),
    .mem_a_forwardable(mem_a_forwardable),
    .mem_a_dest(mem_a_dest),
    .mem_a_result(mem_a_result),
    .mem_b_valid(mem_b_valid),
    .mem_b_forwardable(mem_b_forwardable),
    .mem_b_dest(mem_b_dest),
    .mem_b_result(mem_b_result),

    .wb_a_valid(wb_a_valid),
    .wb_a_forwardable(wb_a_forwardable),
    .wb_a_dest(wb_a_dest),
    .wb_a_result(wb_a_result),
    .wb_b_valid(wb_b_valid),
    .wb_b_forwardable(wb_b_forwardable),
    .wb_b_dest(wb_b_dest),
    .wb_b_result(wb_b_result)
);

forwarding_unit forwarding_unit2(
    .addr(forward_addr2),
    .valid(forward_valid2),
    .data(forward_data2),

    .rf_addr(r2_addr),
    .rf_data(r2_data),

    .ex_a_valid(ex_a_valid),
    .ex_a_forwardable(ex_a_forwardable),
    .ex_a_dest(ex_a_dest),
    .ex_a_result(ex_a_result),
    .ex_b_valid(ex_b_valid),
    .ex_b_forwardable(ex_b_forwardable),
    .ex_b_dest(ex_b_dest),
    .ex_b_result(ex_b_result),

    .mem_a_valid(mem_a_valid),
    .mem_a_forwardable(mem_a_forwardable),
    .mem_a_dest(mem_a_dest),
    .mem_a_result(mem_a_result),
    .mem_b_valid(mem_b_valid),
    .mem_b_forwardable(mem_b_forwardable),
    .mem_b_dest(mem_b_dest),
    .mem_b_result(mem_b_result),

    .wb_a_valid(wb_a_valid),
    .wb_a_forwardable(wb_a_forwardable),
    .wb_a_dest(wb_a_dest),
    .wb_a_result(wb_a_result),
    .wb_b_valid(wb_b_valid),
    .wb_b_forwardable(wb_b_forwardable),
    .wb_b_dest(wb_b_dest),
    .wb_b_result(wb_b_result)
);

forwarding_unit forwarding_unit3(
    .addr(forward_addr3),
    .valid(forward_valid3),
    .data(forward_data3),

    .rf_addr(r3_addr),
    .rf_data(r3_data),

    .ex_a_valid(ex_a_valid),
    .ex_a_forwardable(ex_a_forwardable),
    .ex_a_dest(ex_a_dest),
    .ex_a_result(ex_a_result),
    .ex_b_valid(ex_b_valid),
    .ex_b_forwardable(ex_b_forwardable),
    .ex_b_dest(ex_b_dest),
    .ex_b_result(ex_b_result),

    .mem_a_valid(mem_a_valid),
    .mem_a_forwardable(mem_a_forwardable),
    .mem_a_dest(mem_a_dest),
    .mem_a_result(mem_a_result),
    .mem_b_valid(mem_b_valid),
    .mem_b_forwardable(mem_b_forwardable),
    .mem_b_dest(mem_b_dest),
    .mem_b_result(mem_b_result),

    .wb_a_valid(wb_a_valid),
    .wb_a_forwardable(wb_a_forwardable),
    .wb_a_dest(wb_a_dest),
    .wb_a_result(wb_a_result),
    .wb_b_valid(wb_b_valid),
    .wb_b_forwardable(wb_b_forwardable),
    .wb_b_dest(wb_b_dest),
    .wb_b_result(wb_b_result)
);

forwarding_unit forwarding_unit4(
    .addr(forward_addr4),
    .valid(forward_valid4),
    .data(forward_data4),

    .rf_addr(r4_addr),
    .rf_data(r4_data),

    .ex_a_valid(ex_a_valid),
    .ex_a_forwardable(ex_a_forwardable),
    .ex_a_dest(ex_a_dest),
    .ex_a_result(ex_a_result),
    .ex_b_valid(ex_b_valid),
    .ex_b_forwardable(ex_b_forwardable),
    .ex_b_dest(ex_b_dest),
    .ex_b_result(ex_b_result),

    .mem_a_valid(mem_a_valid),
    .mem_a_forwardable(mem_a_forwardable),
    .mem_a_dest(mem_a_dest),
    .mem_a_result(mem_a_result),
    .mem_b_valid(mem_b_valid),
    .mem_b_forwardable(mem_b_forwardable),
    .mem_b_dest(mem_b_dest),
    .mem_b_result(mem_b_result),

    .wb_a_valid(wb_a_valid),
    .wb_a_forwardable(wb_a_forwardable),
    .wb_a_dest(wb_a_dest),
    .wb_a_result(wb_a_result),
    .wb_b_valid(wb_b_valid),
    .wb_b_forwardable(wb_b_forwardable),
    .wb_b_dest(wb_b_dest),
    .wb_b_result(wb_b_result)
);

endmodule