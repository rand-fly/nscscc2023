`include "definitions.svh"

module mycpu_top(
    input wire          clk,
    input wire          resetn,

    output logic        inst_sram_req,
    output logic        inst_sram_wr,
    output logic [ 1:0] inst_sram_size,
    output logic [ 3:0] inst_sram_wstrb,
    output logic [31:0] inst_sram_addr,
    output logic [31:0] inst_sram_wdata,
    input wire          inst_sram_addr_ok,
    input wire          inst_sram_data_ok,
    input wire   [63:0] inst_sram_rdata,

    output logic        data_sram_req,
    output logic        data_sram_wr,
    output logic [ 1:0] data_sram_size,
    output logic [ 3:0] data_sram_wstrb,
    output logic [31:0] data_sram_addr,
    output logic [31:0] data_sram_wdata,
    input wire          data_sram_addr_ok,
    input wire          data_sram_data_ok,
    input wire   [31:0] data_sram_rdata,

    output logic [31:0] debug_wb_pc1,
    output logic [ 3:0] debug_wb_rf_we1,
    output logic [ 4:0] debug_wb_rf_wnum1,
    output logic [31:0] debug_wb_rf_wdata1,

    output logic [31:0] debug_wb_pc2,
    output logic [ 3:0] debug_wb_rf_we2,
    output logic [ 4:0] debug_wb_rf_wnum2,
    output logic [31:0] debug_wb_rf_wdata2
);

logic reset;
always_ff @(posedge clk) reset <= ~resetn;

logic        flush_all;

logic [31:0] if_pc1;
logic [31:0] if_inst1;
logic        if_pred_branch_taken1;
logic [31:0] if_pred_branch_target1;
logic [31:0] if_pc2;
logic [31:0] if_inst2;
logic        if_pred_branch_taken2;
logic [31:0] if_pred_branch_target2;
logic        if_have_exception;
exception_t  if_exception_type;


logic [1:0]  ibuf_input_size;
logic        ibuf_input_ready;
logic        ibuf_output_valid1;
logic [31:0] ibuf_output_pc1;
logic [31:0] ibuf_output_inst1;
logic        ibuf_output_pred_branch_taken1;
logic [31:0] ibuf_output_pred_branch_target1;
logic        ibuf_output_have_exception1;
exception_t  ibuf_output_exception_type1;

logic        ibuf_output_valid2;
logic [31:0] ibuf_output_pc2;
logic [31:0] ibuf_output_inst2;
logic        ibuf_output_pred_branch_taken2;
logic [31:0] ibuf_output_pred_branch_target2;

logic [ 1:0] id_consume_inst;

logic        id_a_ready;
logic [31:0] id_a_pc;
logic        id_a_have_exception;
exception_t  id_a_exception_type;
opcode_t     id_a_opcode;
logic [ 4:0] id_a_rf_src1;
logic [ 4:0] id_a_rf_src2;
logic        id_a_src2_is_imm;
logic [31:0] id_a_imm;
logic [4 :0] id_a_dest;
logic        id_a_is_branch;
logic        id_a_branch_taken;
logic        id_a_branch_condition;
logic [31:0] id_a_branch_target;
logic        id_a_is_jirl;
logic        id_a_pred_branch_taken;
logic [31:0] id_a_pred_branch_target;
logic        id_a_branch_mistaken;
mem_type_t   id_a_mem_type;
mem_size_t   id_a_mem_size;
logic        id_a_is_spec_op;
spec_opcode_t id_a_spec_opcode;

logic        id_b_ready;
logic [31:0] id_b_pc;
logic        id_b_have_exception;
exception_t  id_b_exception_type;
opcode_t     id_b_opcode;
logic [ 4:0] id_b_rf_src1;
logic [ 4:0] id_b_rf_src2;
logic        id_b_src2_is_imm;
logic [31:0] id_b_imm;
logic [4 :0] id_b_dest;
logic        id_b_is_branch;
logic        id_b_branch_taken;
logic        id_b_branch_condition;
logic [31:0] id_b_branch_target;
logic        id_b_is_jirl;
logic        id_b_pred_branch_taken;
logic [31:0] id_b_pred_branch_target;
logic        id_b_branch_mistaken;
mem_type_t   id_b_mem_type;
mem_size_t   id_b_mem_size;
logic        id_b_is_spec_op;
spec_opcode_t id_b_spec_opcode;

logic        ro_valid;
logic        ro_ready;
logic        ro_stall;

logic        ro_a_valid;
logic [31:0] ro_a_pc;
logic        ro_a_have_exception;
exception_t  ro_a_exception_type;
opcode_t     ro_a_opcode;
logic [31:0] ro_a_src1;
logic [31:0] ro_a_src2;
logic [4 :0] ro_a_dest;
logic        ro_a_is_branch;
logic        ro_a_branch_taken;
logic        ro_a_branch_condition;
logic [31:0] ro_a_branch_target;
logic        ro_a_is_jirl;
logic        ro_a_pred_branch_taken;
logic [31:0] ro_a_pred_branch_target;
mem_type_t   ro_a_mem_type;
mem_size_t   ro_a_mem_size;
logic [31:0] ro_a_st_data;
logic        ro_a_is_spec_op;
spec_op_t    ro_a_spec_op;

logic        ro_b_valid;
logic [31:0] ro_b_pc;
logic        ro_b_have_exception;
exception_t  ro_b_exception_type;
opcode_t     ro_b_opcode;
logic [31:0] ro_b_src1;
logic [31:0] ro_b_src2;
logic [4 :0] ro_b_dest;
logic        ro_b_is_branch;
logic        ro_b_branch_taken;
logic        ro_b_branch_condition;
logic [31:0] ro_b_branch_target;
logic        ro_b_is_jirl;
logic        ro_b_pred_branch_taken;
logic [31:0] ro_b_pred_branch_target;
mem_type_t   ro_b_mem_type;
mem_size_t   ro_b_mem_size;
logic [31:0] ro_b_st_data;
logic        ro_b_is_spec_op;
spec_op_t    ro_b_spec_op;


logic        ex_valid;
logic        ex_ready;
logic        ex_stall;
logic        ex_a_valid;
logic        ex_a_forwardable;
logic [31:0] ex_a_pc;
logic        ex_a_have_exception;
exception_t  ex_a_exception_type;
logic [31:0] ex_a_result;
logic [ 4:0] ex_a_dest;
logic        ex_a_branch_taken;
logic [31:0] ex_a_branch_target;
logic        ex_a_branch_mistaken;
mem_type_t   ex_a_mem_type;
mem_size_t   ex_a_mem_size;
logic [31:0] ex_a_st_data;
logic        ex_a_is_spec_op;
spec_op_t    ex_a_spec_op;

logic        ex_b_valid;
logic        ex_b_forwardable;
logic [31:0] ex_b_pc;
logic        ex_b_have_exception;
exception_t  ex_b_exception_type;
logic [31:0] ex_b_result;
logic [ 4:0] ex_b_dest;
logic        ex_b_branch_taken;
logic [31:0] ex_b_branch_target;
logic        ex_b_branch_mistaken;
mem_type_t   ex_b_mem_type;
mem_size_t   ex_b_mem_size;
logic [31:0] ex_b_st_data;
logic        ex_b_is_spec_op;
spec_op_t    ex_b_spec_op;


logic        mem_a_valid;
logic        mem_a_ready;
logic        mem_a_stall;
logic        mem_a_forwardable;
logic [31:0] mem_a_pc;
logic        mem_a_have_exception;
exception_t  mem_a_exception_type;
logic [31:0] mem_a_result;
mem_type_t   mem_a_mem_type;
mem_size_t   mem_a_mem_size;
logic [ 4:0] mem_a_dest;

logic        mem_b_valid;
logic        mem_b_ready;
logic        mem_b_stall;
logic        mem_b_forwardable;
logic [31:0] mem_b_pc;
logic        mem_b_have_exception;
exception_t  mem_b_exception_type;
logic [31:0] mem_b_result;
mem_type_t   mem_b_mem_type;
mem_size_t   mem_b_mem_size;
logic [ 4:0] mem_b_dest;

logic        MEM_a_is_spec_op;
logic        MEM_b_is_spec_op;
spec_op_t    MEM_spec_op;
spec_op_t    MEM_spec_op_pc;
logic [31:0] MEM_csr_wdata;
logic        mem_is_spec_op;
logic        mem_spec_valid;

logic        mem_a_csr_result_valid;
logic        mem_b_csr_result_valid;
logic [31:0] mem_csr_rdata;
exception_t  mem_exception_type;
logic [31:0] mem_exception_pc;
logic [31:0] mem_exception_address;

logic        csr_we;
logic        csr_badv_we;
logic [31:0] csr_badv_data;
logic        csr_vppn_we;
logic [18:0] csr_vppn_data;
logic        csr_tlbsrch_we;
logic        csr_tlbsrch_found;
logic[TLBIDLEN-1:0] csr_tlbsrch_index;
logic        csr_tlb_we;
tlb_entry_t  csr_tlb_wdata;
tlb_entry_t  csr_tlb_rdata;
logic [TLBIDLEN-1:0] csr_tlbidx;
logic [9:0]  csr_asid;
logic        csr_da;
logic [1:0]  csr_datf;
logic [1:0]  csr_datm;
logic [1:0]  csr_plv;
dmw_t        csr_dmw0;
dmw_t        csr_dmw1;

logic        wb_a_valid;
logic        wb_a_ready;
logic        wb_a_stall;
logic        wb_a_forwardable;
logic [31:0] wb_a_pc;
logic [ 4:0] wb_a_dest;
logic [31:0] wb_a_result;
logic        wb_b_valid;
logic        wb_b_ready;
logic        wb_b_stall;
logic        wb_b_forwardable;
logic [31:0] wb_b_pc;
logic [ 4:0] wb_b_dest;
logic [31:0] wb_b_result;


logic [ 4:0] rf_raddr1;
logic [31:0] rf_rdata1;
logic [ 4:0] rf_raddr2;
logic [31:0] rf_rdata2;
logic [ 4:0] rf_raddr3;
logic [31:0] rf_rdata3;
logic [ 4:0] rf_raddr4;
logic [31:0] rf_rdata4;
logic        rf_we1;
logic [ 4:0] rf_waddr1;
logic [31:0] rf_wdata1;
logic        rf_we2;
logic [ 4:0] rf_waddr2;
logic [31:0] rf_wdata2;


logic        mmu_direct_access;
logic [1:0]  mmu_direct_access_mat;
logic [1:0]  mmu_plv;
logic [9:0]  mmu_asid;
dmw_t        mmu_dmw0;
dmw_t        mmu_dmw1;
logic        mmu_i_valid;
logic [31:0] mmu_i_va;
logic        mmu_i_double;
logic        mmu_i_addr_ok;
logic        mmu_i_data_ok;
logic [63:0] mmu_i_rdata;
logic        mmu_i_tlbr;
logic        mmu_i_pif;
logic        mmu_i_ppi;
logic        mmu_d1_valid;
logic [31:0] mmu_d1_va;
logic        mmu_d1_we;
logic [1:0]  mmu_d1_size;
logic [3:0]  mmu_d1_wstrb;
logic [31:0] mmu_d1_wdata;
logic        mmu_d1_addr_ok;
logic        mmu_d1_data_ok;
logic [31:0] mmu_d1_rdata;
logic        mmu_d1_tlbr;
logic        mmu_d1_pil;
logic        mmu_d1_pis;
logic        mmu_d1_ppi;
logic        mmu_d1_pme;
logic        mmu_d2_valid;
logic [31:0] mmu_d2_va;
logic        mmu_d2_we;
logic [1:0]  mmu_d2_size;
logic [3:0]  mmu_d2_wstrb;
logic [31:0] mmu_d2_wdata;
logic        mmu_d2_addr_ok;
logic        mmu_d2_data_ok;
logic [31:0] mmu_d2_rdata;
logic        mmu_d2_tlbr;
logic        mmu_d2_pil;
logic        mmu_d2_pis;
logic        mmu_d2_ppi;
logic        mmu_d2_pme;
logic        mmu_invtlb_valid;
logic [4:0]  mmu_invtlb_op;
logic [9:0]  mmu_invtlb_asid;
logic [31:0] mmu_invtlb_va;
logic        mmu_tlb_we;
logic [TLBIDLEN-1:0] mmu_tlb_w_index;
tlb_entry_t  mmu_tlb_w_entry;
logic [TLBIDLEN-1:0] mmu_tlb_r_index;
tlb_entry_t  mmu_tlb_r_entry;
logic        mmu_tlbsrch_valid;
logic [18:0] mmu_tlbsrch_vppn;
logic        mmu_tlbsrch_found;
logic [TLBIDLEN-1:0] mmu_tlbsrch_index;

logic        branch_mistaken;
logic [31:0] correct_target;
logic        flush_ibuf;
logic        flush_ro;
logic        flush_ex;

logic        raise_exception;
logic [31:0] exception_target;
logic        rewind;
logic [31:0] rewind_target;
logic        interrupt;

ifu ifu_0(
    .clk(clk),
    .reset(reset),
    .ibuf_input_size(ibuf_input_size),
    .ibuf_ready(ibuf_input_ready),
    .pc1(if_pc1),
    .inst1(if_inst1),
    .pred_branch_taken1(if_pred_branch_taken1),
    .pred_branch_target1(if_pred_branch_target1),
    .pc2(if_pc2),
    .inst2(if_inst2),
    .pred_branch_taken2(if_pred_branch_taken2),
    .pred_branch_target2(if_pred_branch_target2),

    .have_exception(if_have_exception),
    .exception_type(if_exception_type),
    .rewind(rewind),
    .rewind_target(rewind_target),

    .branch_mistaken(branch_mistaken),
    .correct_target(correct_target),
    .raise_exception(raise_exception),
    .exception_target(exception_target),

    .mmu_i_valid(mmu_i_valid),
    .mmu_i_addr(mmu_i_va),
    .mmu_i_double(mmu_i_double),
    .mmu_i_addr_ok(mmu_i_addr_ok),
    .mmu_i_data_ok(mmu_i_data_ok),
    .mmu_i_rdata(mmu_i_rdata),
    .mmu_i_tlbr(mmu_i_tlbr),
    .mmu_i_pif(mmu_i_pif),
    .mmu_i_ppi(mmu_i_ppi)
);

ibuf ibuf_0(
    .clk(clk),
    .reset(reset),
    .flush(flush_ibuf || flush_all),

    .input_size(ibuf_input_size),
    .input_ready(ibuf_input_ready),
    .input_pc1(if_pc1),
    .input_inst1(if_inst1),
    .input_pred_branch_taken1(if_pred_branch_taken1),
    .input_pred_branch_target1(if_pred_branch_target1),
    .input_pc2(if_pc2),
    .input_inst2(if_inst2),
    .input_pred_branch_taken2(if_pred_branch_taken2),
    .input_pred_branch_target2(if_pred_branch_target2),

    .have_exception(if_have_exception),
    .exception_type(if_exception_type),

    .output_valid1(ibuf_output_valid1),
    .output_pc1(ibuf_output_pc1),
    .output_inst1(ibuf_output_inst1),
    .output_pred_branch_taken1(ibuf_output_pred_branch_taken1),
    .output_pred_branch_target1(ibuf_output_pred_branch_target1),
    .output_have_exception1(ibuf_output_have_exception1),
    .output_exception_type1(ibuf_output_exception_type1),

    .output_valid2(ibuf_output_valid2),
    .output_pc2(ibuf_output_pc2),
    .output_inst2(ibuf_output_inst2),
    .output_pred_branch_taken2(ibuf_output_pred_branch_taken2),
    .output_pred_branch_target2(ibuf_output_pred_branch_target2),

    .consume_inst(id_consume_inst)
);

logic [63:0] counter;

always_ff @(posedge clk) begin
    if (reset)
        counter <= 0;
    else
        counter <= counter + 64'd1;
end

id_stage id_stage_0 (
    .clk(clk),
    .reset(reset),
    .ro_stall(ro_stall),
    .counter(counter),
    .id_consume_inst(id_consume_inst),

    .a_valid(ibuf_output_valid1),
    .a_pc(ibuf_output_pc1),
    .a_inst(ibuf_output_inst1),
    .a_pred_branch_taken(ibuf_output_pred_branch_taken1),
    .a_pred_branch_target(ibuf_output_pred_branch_target1),
    .a_have_exception(ibuf_output_have_exception1),
    .a_exception_type(ibuf_output_exception_type1),

    .b_valid(ibuf_output_valid2),
    .b_pc(ibuf_output_pc2),
    .b_inst(ibuf_output_inst2),
    .b_pred_branch_taken(ibuf_output_pred_branch_taken2),
    .b_pred_branch_target(ibuf_output_pred_branch_target2),
    .b_have_exception(1'b0),
    .b_exception_type(INT),

    .id_a_ready(id_a_ready),
    .id_a_pc(id_a_pc),
    .id_a_have_exception(id_a_have_exception),
    .id_a_exception_type(id_a_exception_type),
    .id_a_opcode(id_a_opcode),
    .id_a_rf_src1(id_a_rf_src1),
    .id_a_rf_src2(id_a_rf_src2),
    .id_a_src2_is_imm(id_a_src2_is_imm),
    .id_a_imm(id_a_imm),
    .id_a_dest(id_a_dest),
    .id_a_is_branch(id_a_is_branch),
    .id_a_branch_taken(id_a_branch_taken),
    .id_a_branch_condition(id_a_branch_condition),
    .id_a_branch_target(id_a_branch_target),
    .id_a_is_jirl(id_a_is_jirl),
    .id_a_pred_branch_taken(id_a_pred_branch_taken),
    .id_a_pred_branch_target(id_a_pred_branch_target),
    .id_a_branch_mistaken(id_a_branch_mistaken),
    .id_a_mem_type(id_a_mem_type),
    .id_a_mem_size(id_a_mem_size),
    .id_a_is_spec_op(id_a_is_spec_op),
    .id_a_spec_opcode(id_a_spec_opcode),

    .id_b_ready(id_b_ready),
    .id_b_pc(id_b_pc),
    .id_b_have_exception(id_b_have_exception),
    .id_b_exception_type(id_b_exception_type),
    .id_b_opcode(id_b_opcode),
    .id_b_rf_src1(id_b_rf_src1),
    .id_b_rf_src2(id_b_rf_src2),
    .id_b_src2_is_imm(id_b_src2_is_imm),
    .id_b_imm(id_b_imm),
    .id_b_dest(id_b_dest),
    .id_b_is_branch(id_b_is_branch),
    .id_b_branch_taken(id_b_branch_taken),
    .id_b_branch_condition(id_b_branch_condition),
    .id_b_branch_target(id_b_branch_target),
    .id_b_is_jirl(id_b_is_jirl),
    .id_b_pred_branch_taken(id_b_pred_branch_taken),
    .id_b_pred_branch_target(id_b_pred_branch_target),
    .id_b_branch_mistaken(id_b_branch_mistaken),
    .id_b_mem_type(id_b_mem_type),
    .id_b_mem_size(id_b_mem_size),
    .id_b_is_spec_op(id_b_is_spec_op),
    .id_b_spec_opcode(id_b_spec_opcode)
);

ro_stage ro_stage_0(
    .clk(clk),
    .reset(reset),

    .flush(flush_ro || flush_all),
    .ex_stall(ex_stall),
    .ro_valid(ro_valid),
    .ro_ready(ro_ready),
    .ro_stall(ro_stall),

    .id_a_ready(id_a_ready),
    .id_a_pc(id_a_pc),
    .id_a_have_exception(id_a_have_exception),
    .id_a_exception_type(id_a_exception_type),
    .id_a_opcode(id_a_opcode),
    .id_a_rf_src1(id_a_rf_src1),
    .id_a_rf_src2(id_a_rf_src2),
    .id_a_src2_is_imm(id_a_src2_is_imm),
    .id_a_imm(id_a_imm),
    .id_a_dest(id_a_dest),
    .id_a_is_branch(id_a_is_branch),
    .id_a_branch_taken(id_a_branch_taken),
    .id_a_branch_condition(id_a_branch_condition),
    .id_a_branch_target(id_a_branch_target),
    .id_a_is_jirl(id_a_is_jirl),
    .id_a_pred_branch_taken(id_a_pred_branch_taken),
    .id_a_pred_branch_target(id_a_pred_branch_target),
    .id_a_branch_mistaken(id_a_branch_mistaken),
    .id_a_mem_type(id_a_mem_type),
    .id_a_mem_size(id_a_mem_size),
    .id_a_is_spec_op(id_a_is_spec_op),
    .id_a_spec_opcode(id_a_spec_opcode),

    .id_b_ready(id_b_ready),
    .id_b_pc(id_b_pc),
    .id_b_have_exception(id_b_have_exception),
    .id_b_exception_type(id_b_exception_type),
    .id_b_opcode(id_b_opcode),
    .id_b_rf_src1(id_b_rf_src1),
    .id_b_rf_src2(id_b_rf_src2),
    .id_b_src2_is_imm(id_b_src2_is_imm),
    .id_b_imm(id_b_imm),
    .id_b_dest(id_b_dest),
    .id_b_is_branch(id_b_is_branch),
    .id_b_branch_taken(id_b_branch_taken),
    .id_b_branch_condition(id_b_branch_condition),
    .id_b_branch_target(id_b_branch_target),
    .id_b_is_jirl(id_b_is_jirl),
    .id_b_pred_branch_taken(id_b_pred_branch_taken),
    .id_b_pred_branch_target(id_b_pred_branch_target),
    .id_b_mem_type(id_b_mem_type),
    .id_b_mem_size(id_b_mem_size),
    .id_b_is_spec_op(id_b_is_spec_op),
    .id_b_spec_opcode(id_b_spec_opcode),

    .r1_addr(rf_raddr1),
    .r1_data(rf_rdata1),
    .r2_addr(rf_raddr2),
    .r2_data(rf_rdata2),
    .r3_addr(rf_raddr3),
    .r3_data(rf_rdata3),
    .r4_addr(rf_raddr4),
    .r4_data(rf_rdata4),

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
    .wb_b_result(wb_b_result),

    .ro_a_valid(ro_a_valid),
    .ro_a_pc(ro_a_pc),
    .ro_a_have_exception(ro_a_have_exception),
    .ro_a_exception_type(ro_a_exception_type),
    .ro_a_opcode(ro_a_opcode),
    .ro_a_src1(ro_a_src1),
    .ro_a_src2(ro_a_src2),
    .ro_a_dest(ro_a_dest),
    .ro_a_is_branch(ro_a_is_branch),
    .ro_a_branch_taken(ro_a_branch_taken),
    .ro_a_branch_condition(ro_a_branch_condition),
    .ro_a_branch_target(ro_a_branch_target),
    .ro_a_is_jirl(ro_a_is_jirl),
    .ro_a_pred_branch_taken(ro_a_pred_branch_taken),
    .ro_a_pred_branch_target(ro_a_pred_branch_target),
    .ro_a_mem_type(ro_a_mem_type),
    .ro_a_mem_size(ro_a_mem_size),
    .ro_a_st_data(ro_a_st_data),
    .ro_a_is_spec_op(ro_a_is_spec_op),
    .ro_a_spec_op(ro_a_spec_op),

    .ro_b_valid(ro_b_valid),
    .ro_b_pc(ro_b_pc),
    .ro_b_have_exception(ro_b_have_exception),
    .ro_b_exception_type(ro_b_exception_type),
    .ro_b_opcode(ro_b_opcode),
    .ro_b_src1(ro_b_src1),
    .ro_b_src2(ro_b_src2),
    .ro_b_dest(ro_b_dest),
    .ro_b_is_branch(ro_b_is_branch),
    .ro_b_branch_taken(ro_b_branch_taken),
    .ro_b_branch_condition(ro_b_branch_condition),
    .ro_b_branch_target(ro_b_branch_target),
    .ro_b_is_jirl(ro_b_is_jirl),
    .ro_b_pred_branch_taken(ro_b_pred_branch_taken),
    .ro_b_pred_branch_target(ro_b_pred_branch_target),
    .ro_b_mem_type(ro_b_mem_type),
    .ro_b_mem_size(ro_b_mem_size),
    .ro_b_st_data(ro_b_st_data),
    .ro_b_is_spec_op(ro_b_is_spec_op),
    .ro_b_spec_op(ro_b_spec_op)
);

ex_stage ex_stage_0(
    .clk(clk),
    .reset(reset),
    .flush(flush_ex || flush_all),
    .allowout(!mem_a_stall && !mem_b_stall),
    .ro_ready(ro_ready),
    .ex_valid(ex_valid),
    .ex_ready(ex_ready),
    .ex_stall(ex_stall),

    .ro_a_valid(ro_a_valid),
    .ro_a_pc(ro_a_pc),
    .ro_a_have_exception(ro_a_have_exception),
    .ro_a_exception_type(ro_a_exception_type),
    .ro_a_opcode(ro_a_opcode),
    .ro_a_src1(ro_a_src1),
    .ro_a_src2(ro_a_src2),
    .ro_a_dest(ro_a_dest),
    .ro_a_is_branch(ro_a_is_branch),
    .ro_a_branch_condition(ro_a_branch_condition),
    .ro_a_branch_target(ro_a_branch_target),
    .ro_a_is_jirl(ro_a_is_jirl),
    .ro_a_pred_branch_taken(ro_a_pred_branch_taken),
    .ro_a_pred_branch_target(ro_a_pred_branch_target),
    .ro_a_mem_type(ro_a_mem_type),
    .ro_a_mem_size(ro_a_mem_size),
    .ro_a_st_data(ro_a_st_data),
    .ro_a_is_spec_op(ro_a_is_spec_op),
    .ro_a_spec_op(ro_a_spec_op),

    .ro_b_valid(ro_b_valid),
    .ro_b_pc(ro_b_pc),
    .ro_b_have_exception(ro_b_have_exception),
    .ro_b_exception_type(ro_b_exception_type),
    .ro_b_opcode(ro_b_opcode),
    .ro_b_src1(ro_b_src1),
    .ro_b_src2(ro_b_src2),
    .ro_b_dest(ro_b_dest),
    .ro_b_is_branch(ro_b_is_branch),
    .ro_b_branch_condition(ro_b_branch_condition),
    .ro_b_branch_target(ro_b_branch_target),
    .ro_b_is_jirl(ro_b_is_jirl),
    .ro_b_pred_branch_taken(ro_b_pred_branch_taken),
    .ro_b_pred_branch_target(ro_b_pred_branch_target),
    .ro_b_mem_type(ro_b_mem_type),
    .ro_b_mem_size(ro_b_mem_size),
    .ro_b_st_data(ro_b_st_data),
    .ro_b_is_spec_op(ro_b_is_spec_op),
    .ro_b_spec_op(ro_b_spec_op),

    .ex_a_valid(ex_a_valid),
    .ex_a_forwardable(ex_a_forwardable),
    .ex_a_pc(ex_a_pc),
    .ex_a_have_exception(ex_a_have_exception),
    .ex_a_exception_type(ex_a_exception_type),
    .ex_a_result(ex_a_result),
    .ex_a_dest(ex_a_dest),
    .ex_a_branch_taken(ex_a_branch_taken),
    .ex_a_branch_target(ex_a_branch_target),
    .ex_a_branch_mistaken(ex_a_branch_mistaken),
    .ex_a_mem_type(ex_a_mem_type),
    .ex_a_mem_size(ex_a_mem_size),
    .ex_a_st_data(ex_a_st_data),
    .ex_a_is_spec_op(ex_a_is_spec_op),
    .ex_a_spec_op(ex_a_spec_op),

    .ex_b_valid(ex_b_valid),
    .ex_b_forwardable(ex_b_forwardable),
    .ex_b_pc(ex_b_pc),
    .ex_b_have_exception(ex_b_have_exception),
    .ex_b_exception_type(ex_b_exception_type),
    .ex_b_result(ex_b_result),
    .ex_b_dest(ex_b_dest),
    .ex_b_branch_taken(ex_b_branch_taken),
    .ex_b_branch_target(ex_b_branch_target),
    .ex_b_branch_mistaken(ex_b_branch_mistaken),
    .ex_b_mem_type(ex_b_mem_type),
    .ex_b_mem_size(ex_b_mem_size),
    .ex_b_st_data(ex_b_st_data),
    .ex_b_is_spec_op(ex_b_is_spec_op),
    .ex_b_spec_op(ex_b_spec_op)
);

mem_ctrl mem_ctrl_a(
    .clk(clk),
    .reset(reset),
    .flush(flush_all && (mem_a_have_exception || !mem_a_stall)),
    .ex_ready(ex_ready && !mem_b_stall),
    .allowout(!wb_a_stall && !wb_b_stall && (!mem_b_valid || mem_b_ready)),
    .cancel(1'b0),
    .mem_valid(mem_a_valid),
    .mem_ready(mem_a_ready),
    .mem_stall(mem_a_stall),

    .ex_valid(ex_a_valid),
    .ex_pc(ex_a_pc),
    .ex_have_exception(ex_a_have_exception),
    .ex_exception_type(ex_a_exception_type),
    .ex_result(ex_a_result),
    .ex_dest(ex_a_dest),
    .ex_mem_type(ex_a_mem_type),
    .ex_mem_size(ex_a_mem_size),
    .ex_st_data(ex_a_st_data),

    .mem_forwardable(mem_a_forwardable),
    .mem_pc(mem_a_pc),
    .mem_have_exception(mem_a_have_exception),
    .mem_exception_type(mem_a_exception_type),
    .mem_result(mem_a_result),
    .mem_mem_type(mem_a_mem_type),
    .mem_mem_size(mem_a_mem_size),
    .mem_dest(mem_a_dest),

    .mem_csr_result_valid(mem_a_csr_result_valid),
    .mem_csr_result(mem_csr_rdata),

    .mmu_valid(mmu_d1_valid),
    .mmu_addr(mmu_d1_va),
    .mmu_we(mmu_d1_we),
    .mmu_size(mmu_d1_size),
    .mmu_wstrb(mmu_d1_wstrb),
    .mmu_wdata(mmu_d1_wdata),
    .mmu_addr_ok(mmu_d1_addr_ok),
    .mmu_tlbr(mmu_d1_tlbr),
    .mmu_pil(mmu_d1_pil),
    .mmu_pis(mmu_d1_pis),
    .mmu_ppi(mmu_d1_ppi),
    .mmu_pme(mmu_d1_pme)
);

mem_ctrl mem_ctrl_b(
    .clk(clk),
    .reset(reset),
    .flush(flush_all),
    .ex_ready(ex_ready && !mem_a_stall),
    .allowout(!wb_a_stall && !wb_b_stall && (!mem_a_valid || mem_a_ready)),
    .cancel(mem_a_have_exception),
    .mem_valid(mem_b_valid),
    .mem_ready(mem_b_ready),
    .mem_stall(mem_b_stall),

    .ex_valid(ex_b_valid && !ex_a_branch_mistaken),
    .ex_pc(ex_b_pc),
    .ex_have_exception(ex_b_have_exception),
    .ex_exception_type(ex_b_exception_type),
    .ex_result(ex_b_result),
    .ex_dest(ex_b_dest),
    .ex_mem_type(ex_b_mem_type),
    .ex_mem_size(ex_b_mem_size),
    .ex_st_data(ex_b_st_data),

    .mem_forwardable(mem_b_forwardable),
    .mem_pc(mem_b_pc),
    .mem_have_exception(mem_b_have_exception),
    .mem_exception_type(mem_b_exception_type),
    .mem_result(mem_b_result),
    .mem_mem_type(mem_b_mem_type),
    .mem_mem_size(mem_b_mem_size),
    .mem_dest(mem_b_dest),

    .mem_csr_result_valid(mem_b_csr_result_valid),
    .mem_csr_result(mem_csr_rdata),

    .mmu_valid(mmu_d2_valid),
    .mmu_addr(mmu_d2_va),
    .mmu_we(mmu_d2_we),
    .mmu_size(mmu_d2_size),
    .mmu_wstrb(mmu_d2_wstrb),
    .mmu_wdata(mmu_d2_wdata),
    .mmu_addr_ok(mmu_d2_addr_ok),
    .mmu_tlbr(mmu_d2_tlbr),
    .mmu_pil(mmu_d2_pil),
    .mmu_pis(mmu_d2_pis),
    .mmu_ppi(mmu_d2_ppi),
    .mmu_pme(mmu_d2_pme)
);

always_ff @(posedge clk) begin
    if (reset || flush_all) begin
        MEM_a_is_spec_op <= 1'b0;
        MEM_b_is_spec_op <= 1'b0;
    end
    else if (!mem_a_stall && !mem_b_stall) begin
        MEM_a_is_spec_op <= ex_a_is_spec_op;
        MEM_b_is_spec_op <= ex_b_is_spec_op;
        if (ex_a_is_spec_op) begin
            MEM_spec_op <= ex_a_spec_op;
            MEM_spec_op_pc <= ex_a_pc;
            MEM_csr_wdata <= ex_a_result;
        end
        else if (ex_b_is_spec_op) begin
            MEM_spec_op <= ex_b_spec_op;
            MEM_spec_op_pc <= ex_b_pc;
            MEM_csr_wdata <= ex_b_result;
        end
    end
end

assign mem_is_spec_op = MEM_a_is_spec_op || MEM_b_is_spec_op;
assign mem_a_csr_result_valid = MEM_a_is_spec_op && csr_we;
assign mem_b_csr_result_valid = MEM_b_is_spec_op && csr_we;

always_comb begin
    if (mem_a_valid && (mem_a_have_exception || interrupt)) begin
        raise_exception = 1'b1;
        mem_exception_type = interrupt ? INT : mem_a_exception_type;
        mem_exception_pc = mem_a_pc;
        mem_exception_address = mem_ctrl_a.MEM_result;
    end
    else if (mem_b_valid && mem_b_have_exception) begin
        raise_exception = 1'b1;
        mem_exception_type = mem_b_exception_type;
        mem_exception_pc = mem_b_pc;
        mem_exception_address = mem_ctrl_b.MEM_result;
    end
    else begin
        raise_exception = 1'b0;
        mem_exception_type = INT;
        mem_exception_pc = 32'd0;
        mem_exception_address = 32'd0;
    end
end

csr csr_0(
    .clk(clk),
    .reset(reset),
    .addr(MEM_spec_op.csr_addr),
    .rdata(mem_csr_rdata),
    .we(csr_we),
    .mask(MEM_spec_op.csr_mask),
    .wdata(MEM_csr_wdata),
    .have_exception(raise_exception),
    .exception_type(mem_exception_type),
    .pc_in(mem_exception_pc),
    .pc_out(exception_target),
    .interrupt(interrupt),
    .badv_we(csr_badv_we),
    .badv_data(csr_badv_data),
    .vppn_we(csr_vppn_we),
    .vppn_data(csr_vppn_data),
    .csr_tlbsrch_we(csr_tlbsrch_we),
    .csr_tlbsrch_found(csr_tlbsrch_found),
    .csr_tlbsrch_index(csr_tlbsrch_index),
    
    .csr_tlb_we(csr_tlb_we),
    .csr_tlb_wdata(csr_tlb_wdata),
    .csr_tlb_rdata(csr_tlb_rdata),

    .csr_tlbidx(csr_tlbidx),
    .csr_asid(csr_asid),
    .csr_da(csr_da),
    .csr_datf(csr_datf),
    .csr_datm(csr_datm),
    .csr_plv(csr_plv),
    .csr_dmw0(csr_dmw0),
    .csr_dmw1(csr_dmw1)
);

assign mem_spec_valid = mem_is_spec_op && !raise_exception && !mem_a_stall && !mem_b_stall;

assign csr_we = MEM_spec_op.opcode == SPEC_CSR && mem_spec_valid;
assign csr_badv_we = raise_exception && (
   mem_exception_type == TLBR
|| mem_exception_type == ADEF
|| mem_exception_type == ALE
|| mem_exception_type == PIL
|| mem_exception_type == PIS
|| mem_exception_type == PIF
|| mem_exception_type == PME
|| mem_exception_type == PPI);
assign csr_badv_data = (mem_exception_type == ADEF || mem_exception_type == PIF) ? mem_exception_pc : mem_exception_address;
assign csr_vppn_we = raise_exception && (
   mem_exception_type == TLBR
|| mem_exception_type == PIL
|| mem_exception_type == PIS
|| mem_exception_type == PIF
|| mem_exception_type == PME
|| mem_exception_type == PPI);
assign csr_vppn_data = mem_exception_type == PIF ? mem_exception_pc[31:13] : mem_exception_address[31:13];

assign csr_tlbsrch_we = MEM_spec_op.opcode == SPEC_TLBSRCH && mem_spec_valid;
assign csr_tlbsrch_found = mmu_tlbsrch_found;
assign csr_tlbsrch_index = mmu_tlbsrch_index;
assign csr_tlb_we = MEM_spec_op.opcode == SPEC_TLBRD && mem_spec_valid;
assign csr_tlb_wdata = mmu_tlb_r_entry;

assign mmu_tlbsrch_valid = csr_tlbsrch_we;
assign mmu_tlbsrch_vppn = csr_tlb_rdata.vppn;
assign mmu_tlb_r_index = csr_tlbidx;
assign mmu_tlb_we = (MEM_spec_op.opcode == SPEC_TLBWR || MEM_spec_op.opcode == SPEC_TLBFILL) && mem_spec_valid;
assign mmu_tlb_w_index = csr_tlbidx;
assign mmu_tlb_w_entry = csr_tlb_rdata;

assign mmu_invtlb_valid = MEM_spec_op.opcode == SPEC_INVTLB && mem_spec_valid;
assign mmu_invtlb_op = MEM_spec_op.invtlb_op;
assign mmu_invtlb_asid = MEM_spec_op.invtlb_asid;
assign mmu_invtlb_va = MEM_spec_op.invtlb_va;

assign flush_all = raise_exception || rewind;
assign rewind = mem_is_spec_op && mem_spec_valid;
assign rewind_target = MEM_spec_op_pc + 32'd4;

wb_ctrl wb_ctrl_a(
    .clk(clk),
    .reset(reset),

    .mem_ready((!mem_a_valid || mem_a_ready) && (!mem_b_valid || mem_b_ready) && !wb_b_stall),
    .allowout(!wb_b_valid || wb_b_ready),
    .wb_valid(wb_a_valid),
    .wb_ready(wb_a_ready),
    .wb_stall(wb_a_stall),

    .mem_valid(mem_a_valid && !mem_a_have_exception),
    .mem_pc(mem_a_pc),
    .mem_result(mem_a_result),
    .mem_mem_type(mem_a_mem_type),
    .mem_mem_size(mem_a_mem_size),
    .mem_dest(mem_a_dest),

    .mmu_data_ok(mmu_d1_data_ok),
    .mmu_rdata(mmu_d1_rdata),

    .rf_we(rf_we1),
    .rf_waddr(rf_waddr1),
    .rf_wdata(rf_wdata1),

    .wb_forwardable(wb_a_forwardable),
    .wb_pc(wb_a_pc),
    .wb_dest(wb_a_dest),
    .wb_result(wb_a_result)
);

wb_ctrl wb_ctrl_b(
    .clk(clk),
    .reset(reset),

    .mem_ready((!mem_a_valid || mem_a_ready) && (!mem_b_valid || mem_b_ready) && !wb_a_stall),
    .allowout(!wb_a_valid || wb_a_ready),
    .wb_valid(wb_b_valid),
    .wb_ready(wb_b_ready),
    .wb_stall(wb_b_stall),

    .mem_valid(mem_b_valid && !mem_b_have_exception),
    .mem_pc(mem_b_pc),
    .mem_result(mem_b_result),
    .mem_mem_type(mem_b_mem_type),
    .mem_mem_size(mem_b_mem_size),
    .mem_dest(mem_b_dest),

    .mmu_data_ok(mmu_d2_data_ok),
    .mmu_rdata(mmu_d2_rdata),

    .rf_we(rf_we2),
    .rf_waddr(rf_waddr2),
    .rf_wdata(rf_wdata2),

    .wb_forwardable(wb_b_forwardable),
    .wb_pc(wb_b_pc),
    .wb_dest(wb_b_dest),
    .wb_result(wb_b_result)
);

regfile regfile_0(
    .clk(clk),
    .raddr1(rf_raddr1),
    .rdata1(rf_rdata1),
    .raddr2(rf_raddr2),
    .rdata2(rf_rdata2),
    .raddr3(rf_raddr3),
    .rdata3(rf_rdata3),
    .raddr4(rf_raddr4),
    .rdata4(rf_rdata4),
    .we1(rf_we1),
    .waddr1(rf_waddr1),
    .wdata1(rf_wdata1),
    .we2(rf_we2),
    .waddr2(rf_waddr2),
    .wdata2(rf_wdata2)
);

branch_ctrl branch_ctrl_0(
    .id_a_branch_mistaken(id_a_branch_mistaken),
    .id_a_branch_taken(id_a_branch_taken),
    .id_a_branch_target(id_a_branch_target),
    .id_a_pc(id_a_pc),
    .id_b_branch_mistaken(id_b_branch_mistaken),
    .id_b_branch_taken(id_b_branch_taken),
    .id_b_branch_target(id_b_branch_target),
    .id_b_pc(id_b_pc),
    .ex_a_branch_mistaken(ex_a_branch_mistaken),
    .ex_a_branch_taken(ex_a_branch_taken),
    .ex_a_branch_target(ex_a_branch_target),
    .ex_a_pc(ex_a_pc),
    .ex_b_branch_mistaken(ex_b_branch_mistaken),
    .ex_b_branch_taken(ex_b_branch_taken),
    .ex_b_branch_target(ex_b_branch_target),
    .ex_b_pc(ex_b_pc),

    .branch_mistaken(branch_mistaken),
    .correct_target(correct_target),
    .flush_ibuf(flush_ibuf),
    .flush_ro(flush_ro),
    .flush_ex(flush_ex)
);

mmu mmu_0(
    .clk(clk),
    .reset(reset),

    .da(csr_da),
    .datf(csr_datf),
    .datm(csr_datm),
    .plv(csr_plv),
    .asid(csr_asid),
    .dmw0(csr_dmw0),
    .dmw1(csr_dmw1),

    .i_valid(mmu_i_valid),
    .i_va(mmu_i_va),
    .i_double(mmu_i_double),
    .i_addr_ok(mmu_i_addr_ok),
    .i_data_ok(mmu_i_data_ok),
    .i_rdata(mmu_i_rdata),
    .i_tlbr(mmu_i_tlbr),
    .i_pif(mmu_i_pif),
    .i_ppi(mmu_i_ppi),

    .d1_valid(mmu_d1_valid),
    .d1_va(mmu_d1_va),
    .d1_we(mmu_d1_we),
    .d1_size(mmu_d1_size),
    .d1_wstrb(mmu_d1_wstrb),
    .d1_wdata(mmu_d1_wdata),
    .d1_addr_ok(mmu_d1_addr_ok),
    .d1_data_ok(mmu_d1_data_ok),
    .d1_rdata(mmu_d1_rdata),
    .d1_tlbr(mmu_d1_tlbr),
    .d1_pil(mmu_d1_pil),
    .d1_pis(mmu_d1_pis),
    .d1_ppi(mmu_d1_ppi),
    .d1_pme(mmu_d1_pme),

    .d2_valid(mmu_d2_valid),
    .d2_va(mmu_d2_va),
    .d2_we(mmu_d2_we),
    .d2_size(mmu_d2_size),
    .d2_wstrb(mmu_d2_wstrb),
    .d2_wdata(mmu_d2_wdata),
    .d2_addr_ok(mmu_d2_addr_ok),
    .d2_data_ok(mmu_d2_data_ok),
    .d2_rdata(mmu_d2_rdata),
    .d2_tlbr(mmu_d2_tlbr),
    .d2_pil(mmu_d2_pil),
    .d2_pis(mmu_d2_pis),
    .d2_ppi(mmu_d2_ppi),
    .d2_pme(mmu_d2_pme),

    .invtlb_valid(mmu_invtlb_valid),
    .invtlb_op(mmu_invtlb_op),
    .invtlb_asid(mmu_invtlb_asid),
    .invtlb_va(mmu_invtlb_va),

    .tlb_we(mmu_tlb_we),
    .tlb_w_index(mmu_tlb_w_index),
    .tlb_w_entry(mmu_tlb_w_entry),
    .tlb_r_index(mmu_tlb_r_index),
    .tlb_r_entry(mmu_tlb_r_entry),

    .tlbsrch_valid(mmu_tlbsrch_valid),
    .tlbsrch_vppn(mmu_tlbsrch_vppn),
    .tlbsrch_found(mmu_tlbsrch_found),
    .tlbsrch_index(mmu_tlbsrch_index),

    .inst_sram_req(inst_sram_req),
    .inst_sram_wr(inst_sram_wr),
    .inst_sram_size(inst_sram_size),
    .inst_sram_wstrb(inst_sram_wstrb),
    .inst_sram_addr(inst_sram_addr),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_addr_ok(inst_sram_addr_ok),
    .inst_sram_data_ok(inst_sram_data_ok),
    .inst_sram_rdata(inst_sram_rdata),

    .data_sram_req(data_sram_req),
    .data_sram_wr(data_sram_wr),
    .data_sram_size(data_sram_size),
    .data_sram_wstrb(data_sram_wstrb),
    .data_sram_addr(data_sram_addr),
    .data_sram_wdata(data_sram_wdata),
    .data_sram_addr_ok(data_sram_addr_ok),
    .data_sram_data_ok(data_sram_data_ok),
    .data_sram_rdata(data_sram_rdata)
);

assign debug_wb_pc1 = wb_a_pc;
assign debug_wb_rf_wdata1 = rf_wdata1;
assign debug_wb_rf_wnum1 = wb_a_dest;
assign debug_wb_rf_we1 = {4{!wb_a_stall && wb_a_valid && wb_a_dest != 5'd0}};

assign debug_wb_pc2 = wb_b_pc;
assign debug_wb_rf_wdata2 = rf_wdata2;
assign debug_wb_rf_wnum2 = wb_b_dest;
assign debug_wb_rf_we2 = {4{!wb_b_stall && wb_b_valid && wb_b_dest != 5'd0}};

endmodule