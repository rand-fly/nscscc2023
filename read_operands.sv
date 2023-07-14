`include "definitions.svh"

module read_operands (
    input wire             clk,
    input wire             reset,

    input wire             flush,
    input wire             allowout,

    input wire             id_ready,
    input wire [31:0]      id_pc,
    input wire             id_have_exception,
    input wire exception_t id_exception_type,
    input wire opcode_t    id_opcode,
    input wire [ 4:0]      id_rf_src1,
    input wire [ 4:0]      id_rf_src2,
    input wire             id_src2_is_imm,
    input wire [31:0]      id_imm,
    input wire [4 :0]      id_dest,
    input wire             id_is_branch,
    input wire             id_branch_taken,
    input wire             id_branch_condition,
    input wire [31:0]      id_branch_target,
    input wire             id_is_jirl,
    input wire             id_pred_branch_taken,
    input wire [31:0]      id_pred_branch_target,
    input wire mem_type_t  id_mem_type,
    input wire mem_size_t  id_mem_size,
    input wire             id_is_csr_op,
    input wire [13:0]      id_csr_addr,
    input wire [31:0]      id_csr_mask,

    output logic [4:0]     r1_addr,
    input wire             r1_valid,
    input wire [31:0]      r1_data,

    output logic [4:0]     r2_addr,
    input wire             r2_valid,
    input wire [31:0]      r2_data,

    output logic           ro_valid,
    output logic           ro_ready,
    output logic [31:0]    ro_pc,
    output logic           ro_have_exception,
    output exception_t     ro_exception_type,
    output opcode_t        ro_opcode,
    output logic [31:0]    ro_src1,
    output logic [31:0]    ro_src2,
    output logic [4 :0]    ro_dest,
    output logic           ro_is_branch,
    output logic           ro_branch_taken,
    output logic           ro_branch_condition,
    output logic [31:0]    ro_branch_target,
    output logic           ro_is_jirl,
    output logic           ro_pred_branch_taken,
    output logic [31:0]    ro_pred_branch_target,
    output mem_type_t      ro_mem_type,
    output mem_size_t      ro_mem_size,
    output logic [31:0]    ro_st_data,
    output logic           ro_is_csr_op,
    output logic [13:0]    ro_csr_addr,
    output logic [31:0]    ro_csr_mask
);

logic            RO_valid;
logic [31:0]     RO_pc;
logic            RO_have_exception;
exception_t      RO_exception_type;
opcode_t         RO_opcode;
logic [ 4:0]     RO_rf_src1;
logic [ 4:0]     RO_rf_src2;
logic            RO_src2_is_imm;
logic [31:0]     RO_imm;
logic [4 :0]     RO_dest;
logic            RO_is_branch;
logic            RO_branch_taken;
logic            RO_branch_condition;
logic [31:0]     RO_branch_target;
logic            RO_is_jirl;
logic            RO_pred_branch_taken;
logic [31:0]     RO_pred_branch_target;
mem_type_t       RO_mem_type;
mem_size_t       RO_mem_size;
logic            RO_is_csr_op;
logic [13:0]     RO_csr_addr;
logic [31:0]     RO_csr_mask;

always_ff @(posedge clk) begin
    if (reset || flush) begin
        RO_valid <= 1'b0;
    end
    else if (allowout) begin
        RO_valid <= id_ready;
        RO_pc <= id_pc;
        RO_have_exception <= id_have_exception;
        RO_exception_type <= id_exception_type;
        RO_opcode <= id_opcode;
        RO_rf_src1 <= id_rf_src1;
        RO_rf_src2 <= id_rf_src2;
        RO_src2_is_imm <= id_src2_is_imm;
        RO_imm <= id_imm;
        RO_dest <= id_dest;
        RO_is_branch <= id_is_branch;
        RO_branch_taken <= id_branch_taken;
        RO_branch_condition <= id_branch_condition;
        RO_branch_target <= id_branch_target;
        RO_is_jirl <= id_is_jirl;
        RO_pred_branch_taken <= id_pred_branch_taken;
        RO_pred_branch_target <= id_pred_branch_target;
        RO_mem_type <= id_mem_type;
        RO_mem_size <= id_mem_size;
        RO_is_csr_op <= id_is_csr_op;
        RO_csr_addr <= id_csr_addr;
        RO_csr_mask <= id_csr_mask;
    end
end


assign r1_addr = RO_rf_src1;
assign r2_addr = RO_rf_src2;

assign ro_valid = RO_valid;
assign ro_ready = RO_valid && (r1_valid && r2_valid || RO_have_exception);

assign ro_pc = RO_pc;
assign ro_have_exception = RO_have_exception;
assign ro_exception_type = RO_exception_type;
assign ro_opcode = RO_opcode;
assign ro_src1 = r1_data;
assign ro_src2 = RO_src2_is_imm ? RO_imm : r2_data;
assign ro_dest = RO_dest;
assign ro_is_branch = RO_is_branch;
assign ro_branch_condition = RO_branch_condition;
assign ro_branch_target = RO_branch_target;
assign ro_branch_taken = RO_branch_taken || RO_is_jirl;
assign ro_is_jirl = RO_is_jirl;
// assign ro_branch_mistaken = RO_valid && RO_is_jirl && (!RO_pred_branch_taken || RO_pred_branch_target != ro_branch_target);
assign ro_pred_branch_taken = RO_pred_branch_taken;
assign ro_pred_branch_target = RO_pred_branch_target;
assign ro_mem_type = RO_mem_type;
assign ro_mem_size = RO_mem_size;
assign ro_st_data = r2_data;
assign ro_is_csr_op = RO_is_csr_op;
assign ro_csr_addr = RO_csr_addr;
assign ro_csr_mask = r1_addr == 5'd1 ? 32'hffffffff : r1_data;

endmodule