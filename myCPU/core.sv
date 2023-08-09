`include "definitions.svh"

module core (
    input clk,
    input resetn,

    output        icache_req,
    output [ 2:0] icache_op,
    output [31:0] icache_addr,
    output        icache_uncached,
    input         icache_addr_ok,
    input         icache_data_ok,
    input  [63:0] icache_rdata,

    output                     dcache_p0_valid,
    output                     dcache_p1_valid,
    output [              2:0] dcache_op,
    output [   `TAG_WIDTH-1:0] dcache_tag,
    output [ `INDEX_WIDTH-1:0] dcache_index,
    output [`OFFSET_WIDTH-1:0] dcache_p0_offset,
    output [`OFFSET_WIDTH-1:0] dcache_p1_offset,
    output [              3:0] dcache_p0_wstrb,
    output [              3:0] dcache_p1_wstrb,
    output [             31:0] dcache_p0_wdata,
    output [             31:0] dcache_p1_wdata,
    output                     dcache_uncached,
    output [              1:0] dcache_p0_size,
    output [              1:0] dcache_p1_size,
    input                      dcache_addr_ok,
    input                      dcache_data_ok,
    input  [             31:0] dcache_p0_rdata,
    input  [             31:0] dcache_p1_rdata,

`ifdef DIFFTEST_EN
    output difftest_t a_difftest,
    output difftest_t b_difftest,
    output difftest_excp_t excp_difftest,
    output difftest_csr_t csr_difftest,
`endif

    output logic [31:0] debug0_wb_pc,
    output logic [ 3:0] debug0_wb_rf_wen,
    output logic [ 4:0] debug0_wb_rf_wnum,
    output logic [31:0] debug0_wb_rf_wdata,

    output logic [31:0] debug1_wb_pc,
    output logic [ 3:0] debug1_wb_rf_wen,
    output logic [ 4:0] debug1_wb_rf_wnum,
    output logic [31:0] debug1_wb_rf_wdata
);

  logic reset;
  always_ff @(posedge clk) reset <= ~resetn;

  // from ifu
  logic      [ 1:0] ifu_output_size;
  logic      [31:0] ifu_pc0;
  logic      [31:0] ifu_inst0;
  logic             ifu_pred_br_taken0;
  logic      [31:0] ifu_pred_br_target0;
  logic      [31:0] ifu_pc1;
  logic      [31:0] ifu_inst1;
  logic             ifu_pred_br_taken1;
  logic      [31:0] ifu_pred_br_target1;
  logic             ifu_have_excp;
  excp_t            ifu_excp_type;

  // decode stage reg
  logic             ID_a_valid;
  logic      [31:0] ID_a_pc;
  logic      [31:0] ID_a_inst;
  logic             ID_a_pred_br_taken;
  logic      [31:0] ID_a_pred_br_target;
  logic             ID_a_have_excp;
  excp_t            ID_a_excp_type;
  logic             ID_b_valid;
  logic      [31:0] ID_b_pc;
  logic      [31:0] ID_b_inst;
  logic             ID_b_pred_br_taken;
  logic      [31:0] ID_b_pred_br_target;
  logic             ID_b_have_excp;
  excp_t            ID_b_excp_type;
  // from decoder
  optype_t          id_a_optype;
  opcode_t          id_a_opcode;
  logic      [ 4:0] id_a_dest;
  logic      [31:0] id_a_imm;
  br_type_t         id_a_br_type;
  logic             id_a_br_condition;
  logic      [31:0] id_a_br_target;
  logic             id_a_have_excp;
  excp_t            id_a_excp_type;
  csr_addr_t        id_a_csr_addr;
  logic             id_a_csr_wr;
  logic             id_a_is_spec_op;
  logic             id_a_is_idle;
  logic             id_a_is_ll;
  logic             id_a_is_sc;
  logic      [ 4:0] id_a_r1;
  logic      [ 4:0] id_a_r2;
  logic             id_a_src2_is_imm;
  logic             id_a_br_mistaken;
  logic             id_a_br_taken;
  optype_t          id_b_optype;
  opcode_t          id_b_opcode;
  logic      [ 4:0] id_b_dest;
  logic      [31:0] id_b_imm;
  br_type_t         id_b_br_type;
  logic             id_b_br_condition;
  logic      [31:0] id_b_br_target;
  logic             id_b_have_excp;
  excp_t            id_b_excp_type;
  csr_addr_t        id_b_csr_addr;
  logic             id_b_csr_wr;
  logic             id_b_is_spec_op;
  logic             id_b_is_idle;
  logic             id_b_is_ll;
  logic             id_b_is_sc;
  logic      [ 4:0] id_b_r1;
  logic      [ 4:0] id_b_r2;
  logic             id_b_src2_is_imm;
  logic             id_b_br_mistaken;
  logic             id_b_br_taken;
`ifdef DIFFTEST_EN
  difftest_t id_a_difftest;
  difftest_t id_b_difftest;
`endif

  //from ibuf
  logic      [ 1:0] ibuf_i_size;
  logic             ibuf_i_ready;
  logic      [ 1:0] ibuf_o_size;

  // from issue
  logic             ro_a_valid;
  logic      [31:0] ro_a_pc;
  optype_t          ro_a_optype;
  opcode_t          ro_a_opcode;
  logic      [ 4:0] ro_a_dest;
  logic      [31:0] ro_a_imm;
  logic             ro_a_pred_br_taken;
  logic      [31:0] ro_a_pred_br_target;
  br_type_t         ro_a_br_type;
  logic             ro_a_br_condition;
  logic      [31:0] ro_a_br_target;
  logic             ro_a_br_taken;
  logic             ro_a_have_excp_no_int;
  excp_t            ro_a_excp_type_no_int;
  logic             ro_a_have_excp;
  excp_t            ro_a_excp_type;
  csr_addr_t        ro_a_csr_addr;
  logic             ro_a_csr_wr;
  logic             ro_a_is_spec_op;
  logic             ro_a_is_idle;
  logic             ro_a_is_ll;
  logic             ro_a_is_sc;
  logic      [ 4:0] ro_a_r1;
  logic      [ 4:0] ro_a_r2;
  logic             ro_a_src2_is_imm;

  logic             ro_b_valid;
  logic      [31:0] ro_b_pc;
  optype_t          ro_b_optype;
  opcode_t          ro_b_opcode;
  logic      [ 4:0] ro_b_dest;
  logic      [31:0] ro_b_imm;
  logic             ro_b_pred_br_taken;
  logic      [31:0] ro_b_pred_br_target;
  br_type_t         ro_b_br_type;
  logic             ro_b_br_condition;
  logic      [31:0] ro_b_br_target;
  logic             ro_b_br_taken;
  logic             ro_b_have_excp;
  excp_t            ro_b_excp_type;
  csr_addr_t        ro_b_csr_addr;
  logic             ro_b_csr_wr;
  logic             ro_b_is_spec_op;
  logic             ro_b_is_idle;
  logic             ro_b_is_ll;
  logic             ro_b_is_sc;
  logic      [ 4:0] ro_b_r1;
  logic      [ 4:0] ro_b_r2;
  logic             ro_b_src2_is_imm;
`ifdef DIFFTEST_EN
  difftest_t ro_a_difftest;
  difftest_t ro_b_difftest;
`endif
  // forward prediction
  source_t                   ro_a_src1_source;
  logic       [        31:0] ro_a_src1_passed;
  logic                      ro_a_src1_ok;
  source_t                   ro_a_src2_source;
  logic       [        31:0] ro_a_src2_passed;
  logic                      ro_a_src2_ok;
  source_t                   ro_b_src1_source;
  logic       [        31:0] ro_b_src1_passed;
  logic                      ro_b_src1_ok;
  source_t                   ro_b_src2_source;
  logic       [        31:0] ro_b_src2_passed;
  logic                      ro_b_src2_ok;
  logic                      ro_b_delayed;
  // from regfile
  logic       [        31:0] rf_rdata1;
  logic       [        31:0] rf_rdata2;
  logic       [        31:0] rf_rdata3;
  logic       [        31:0] rf_rdata4;
  // to regfile
  logic                      rf_we1;
  logic       [         4:0] rf_waddr1;
  logic       [        31:0] rf_wdata1;
  logic                      rf_we2;
  logic       [         4:0] rf_waddr2;
  logic       [        31:0] rf_wdata2;
  // issue logic
  logic                      allow_issue_a;
  logic                      allow_issue_b;
  // from and to csr
  logic       [        31:0] excp_target;
  logic                      interrupt;
  logic                      replay;
  logic       [        31:0] replay_target;
  logic       [        31:0] csr_rdata;
  logic                      csr_da;
  logic       [         1:0] csr_datf;
  logic       [         1:0] csr_datm;
  logic       [         1:0] csr_plv;
  logic       [         9:0] csr_asid;
  dmw_t                      csr_dmw0;
  dmw_t                      csr_dmw1;
  logic       [TLBIDLEN-1:0] csr_tlbidx;
  tlb_entry_t                csr_tlb_rdata;
  logic                      csr_tlb_we;
  tlb_entry_t                csr_tlb_wdata;
  logic                      csr_badv_we;
  logic       [        31:0] csr_badv_wdata;
  logic                      csr_vppn_we;
  logic       [        18:0] csr_vppn_wdata;
  logic                      csr_llbit;
  logic                      csr_llbit_we;
  logic                      csr_llbit_wdata;

  //from branch ctrl
  logic                      br_mistaken;
  br_type_t                  br_type;
  logic       [        31:0] wrong_pc;
  logic       [        31:0] right_target;
  logic       [        31:0] btb_target;
  logic                      update_orien_en;
  logic       [        31:0] retire_pc;
  logic                      right_orien;

  //between mmu and ifu/lsu
  logic                      mmu_i_req;
  logic       [        31:0] mmu_i_va;
  logic                      mmu_i_addr_ok;
  logic                      mmu_i_double;
  logic                      mmu_i_data_ok;
  logic       [        63:0] mmu_i_rdata;
  logic                      mmu_i_tlbr;
  logic                      mmu_i_pif;
  logic                      mmu_i_ppi;
  logic                      mmu_d0_req;
  logic       [        31:0] mmu_d0_va;
  logic                      mmu_d0_we;
  logic       [         1:0] mmu_d0_size;
  logic       [         3:0] mmu_d0_wstrb;
  logic       [        31:0] mmu_d0_wdata;
  logic                      mmu_d0_addr_ok;
  logic                      mmu_d0_data_ok;
  logic       [        31:0] mmu_d0_rdata;
  logic                      mmu_d0_tlbr;
  logic                      mmu_d0_pil;
  logic                      mmu_d0_pis;
  logic                      mmu_d0_ppi;
  logic                      mmu_d0_pme;
  logic                      mmu_d1_req;
  logic       [        31:0] mmu_d1_va;
  logic                      mmu_d1_we;
  logic       [         1:0] mmu_d1_size;
  logic       [         3:0] mmu_d1_wstrb;
  logic       [        31:0] mmu_d1_wdata;
  logic                      mmu_d1_addr_ok;
  logic                      mmu_d1_data_ok;
  logic       [        31:0] mmu_d1_rdata;
  logic                      mmu_d1_tlbr;
  logic                      mmu_d1_pil;
  logic                      mmu_d1_pis;
  logic                      mmu_d1_ppi;
  logic                      mmu_d1_pme;
  logic                      mem_cancel;
  logic                      mem_d1_cancel;


  // from and to mmu(tlb)
  logic                      invtlb_valid;
  logic       [         4:0] invtlb_op;
  logic       [         9:0] invtlb_asid;
  logic       [        31:0] invtlb_va;
  logic                      tlb_we;
  logic       [TLBIDLEN-1:0] tlb_w_index;
  tlb_entry_t                tlb_w_entry;
  logic       [TLBIDLEN-1:0] tlb_r_index;
  tlb_entry_t                tlb_r_entry;
  logic                      tlbsrch_valid;
  logic       [        18:0] tlbsrch_vppn;
  logic                      tlbsrch_found;
  logic       [TLBIDLEN-1:0] tlbsrch_index;

  // EX1 stage reg
  logic                      EX1_stalling;
  logic                      EX1_a_valid;
  logic       [        31:0] EX1_a_pc;
  optype_t                   EX1_a_optype;
  opcode_t                   EX1_a_opcode;
  logic       [         4:0] EX1_a_dest;
  source_t                   EX1_a_src1_source;
  logic       [        31:0] EX1_a_src1_passed;
  logic       [        31:0] EX1_a_src1_stalled;
  source_t                   EX1_a_src2_source;
  logic       [        31:0] EX1_a_src2_passed;
  logic       [        31:0] EX1_a_src2_stalled;
  logic       [        31:0] EX1_a_imm;
  br_type_t                  EX1_a_br_type;
  logic                      EX1_a_br_condition;
  logic       [        31:0] EX1_a_br_target;
  logic                      EX1_a_pred_br_taken;
  logic       [        31:0] EX1_a_pred_br_target;
  logic                      EX1_a_br_taken;
  logic                      EX1_a_have_excp;
  excp_t                     EX1_a_excp_type;
  csr_addr_t                 EX1_a_csr_addr;
  logic                      EX1_a_csr_wr;
  logic                      EX1_a_is_spec_op;
  logic                      EX1_a_is_idle;
  logic                      EX1_a_is_ll;
  logic                      EX1_a_is_sc;
  logic                      EX1_b_valid;
  logic       [        31:0] EX1_b_pc;
  logic                      EX1_b_delayed;
  optype_t                   EX1_b_optype;
  opcode_t                   EX1_b_opcode;
  logic       [         4:0] EX1_b_dest;
  source_t                   EX1_b_src1_source;
  logic       [        31:0] EX1_b_src1_passed;
  logic       [        31:0] EX1_b_src1_stalled;
  source_t                   EX1_b_src2_source;
  logic       [        31:0] EX1_b_src2_passed;
  logic       [        31:0] EX1_b_src2_stalled;
  logic       [        31:0] EX1_b_imm;
  br_type_t                  EX1_b_br_type;
  logic                      EX1_b_br_condition;
  logic       [        31:0] EX1_b_br_target;
  logic                      EX1_b_pred_br_taken;
  logic       [        31:0] EX1_b_pred_br_target;
  logic                      EX1_b_br_taken;
  logic                      EX1_b_have_excp;
  excp_t                     EX1_b_excp_type;
`ifdef DIFFTEST_EN
  difftest_t EX1_a_difftest;
  difftest_t EX1_b_difftest;
`endif
  // EX1 stage signal
  logic             ex1_ready;
  logic             ex1_stall;
  logic      [31:0] ex1_a_src1;
  logic      [31:0] ex1_a_src2;
  logic             ex1_a_br_taken;
  logic      [31:0] ex1_a_br_target;
  logic             ex1_a_br_mistaken;
  logic             ex1_a_br_mistaken_long;
  logic      [31:0] ex1_b_src1;
  logic      [31:0] ex1_b_src2;
  logic             ex1_b_br_taken;
  logic      [31:0] ex1_b_br_target;
  logic             ex1_b_br_mistaken;
  logic             have_excp;
  logic             icacop_en;
  logic             dcacop_en;
  logic             invalid_cacop;
  logic      [ 1:0] cacop_op;
  logic             cacop_ok;
  logic             cacop_have_excp;
  excp_t            cacop_excp_type;


  // EX2 stage reg
  logic             EX2_stalling;
  logic             EX2_a_valid;
  logic      [31:0] EX2_a_pc;
  optype_t          EX2_a_optype;
  logic      [ 4:0] EX2_a_dest;
  logic      [31:0] EX2_a_src1;
  logic      [31:0] EX2_a_src2;
  logic      [31:0] EX2_a_alu_result;
  br_type_t         EX2_a_br_type;
  logic             EX2_a_br_taken;
  logic             EX2_a_have_excp;
  excp_t            EX2_a_excp_type;
  logic      [31:0] EX2_a_excp_addr;
  csr_addr_t        EX2_a_csr_addr;
  logic             EX2_a_csr_wr;
  logic             EX2_a_is_spec_op;
  logic             EX2_a_is_idle;
  logic             EX2_a_is_ll;
  logic             EX2_a_is_sc;
  logic             EX2_b_valid;
  logic      [31:0] EX2_b_pc;
  logic             EX2_b_delayed;
  optype_t          EX2_b_optype;
  opcode_t          EX2_b_opcode;
  logic      [ 4:0] EX2_b_dest;
  logic      [31:0] EX2_b_src1;
  logic             EX2_b_src1_delayed;
  logic      [31:0] EX2_b_src2;
  logic             EX2_b_src2_delayed;
  logic      [31:0] EX2_b_alu_result;
  logic      [31:0] EX2_b_imm;
  br_type_t         EX2_b_br_type;
  logic             EX2_b_br_taken;
  logic             EX2_b_have_excp;
  excp_t            EX2_b_excp_type;
  logic      [31:0] EX2_b_excp_addr;
`ifdef DIFFTEST_EN
  difftest_t EX2_a_difftest;
  difftest_t EX2_b_difftest;
`endif
  // ex2 stage signal
  logic            ex2_a_ok;
  logic            ex2_b_ok;
  logic            ex2_stall;
  logic     [31:0] ex2_b_src1;
  logic     [31:0] ex2_b_src2;
  logic            ex2_have_excp;
  excp_t           ex2_excp_type;
  logic     [31:0] ex2_excp_pc;
  logic     [31:0] ex2_excp_addr;
  logic            idle;

  // WB stage reg
  logic            WB_a_valid;
  logic            WB_a_ok;
  logic     [31:0] WB_a_pc;
  logic     [ 4:0] WB_a_dest;
  logic     [31:0] WB_a_result;
  br_type_t        WB_a_br_type;
  logic            WB_a_br_taken;
  logic            WB_a_have_excp;
  excp_t           WB_a_excp_type;
  logic            WB_b_valid;
  logic            WB_b_ok;
  logic     [31:0] WB_b_pc;
  logic     [ 4:0] WB_b_dest;
  logic     [31:0] WB_b_result;
  br_type_t        WB_b_br_type;
  logic            WB_b_br_taken;
  logic            WB_b_have_excp;
  excp_t           WB_b_excp_type;
`ifdef DIFFTEST_EN
  difftest_t WB_a_difftest;
  difftest_t WB_b_difftest;
`endif

  // from exu/lsu
  logic  [31:0] alu_a_result;
  logic  [31:0] alu_b1_result;
  logic  [31:0] alu_b2_result;
  logic         mul_a_ok;
  logic  [31:0] mul_a_result;
  logic         mul_b_ok;
  logic  [31:0] mul_b_result;
  logic         div_ok;
  logic  [31:0] div_result;
  // from lsu a
  logic         lsu_a_ready;
  logic         lsu_a_ok;
  logic  [31:0] lsu_a_result;
  logic         lsu_a_have_excp;
  excp_t        lsu_a_excp_type;
  // from lsu b
  logic         lsu_b_ready;
  logic         lsu_b_ok;
  logic  [31:0] lsu_b_result;
  logic         lsu_b_have_excp;
  excp_t        lsu_b_excp_type;
  // pipeline control
  logic         raise_excp;
  logic         flush_id;
  logic         flush_ibuf;
  logic         flush_ex1;
  logic         ibuf_no_out;

  ifu u_ifu (
      .clk            (clk),
      .reset          (reset),
      .ibuf_i_ready   (ibuf_i_ready),
      .output_size    (ifu_output_size),
      .pc0            (ifu_pc0),
      .inst0          (ifu_inst0),
      .pred_br_taken0 (ifu_pred_br_taken0),
      .pred_br_target0(ifu_pred_br_target0),
      .pc1            (ifu_pc1),
      .inst1          (ifu_inst1),
      .pred_br_taken1 (ifu_pred_br_taken1),
      .pred_br_target1(ifu_pred_br_target1),
      .have_excp      (ifu_have_excp),
      .excp_type      (ifu_excp_type),
      .br_mistaken    (br_mistaken),
      .br_type        (br_type),
      .right_target   (right_target),
      .btb_target     (btb_target),
      .wrong_pc       (wrong_pc),
      .update_orien_en(update_orien_en),
      .retire_pc      (retire_pc),
      .right_orien    (right_orien),
      .raise_excp     (ex2_have_excp),
      .excp_target    (excp_target),
      .replay         (replay),
      .replay_target  (replay_target),
      .interrupt      (interrupt),
      .idle           (idle),
      .mmu_i_req      (mmu_i_req),
      .mmu_i_addr     (mmu_i_va),
      .mmu_i_addr_ok  (mmu_i_addr_ok),
      .mmu_i_double   (mmu_i_double),
      .mmu_i_data_ok  (mmu_i_data_ok),
      .mmu_i_rdata    (mmu_i_rdata),
      .mmu_i_tlbr     (mmu_i_tlbr),
      .mmu_i_pif      (mmu_i_pif),
      .mmu_i_ppi      (mmu_i_ppi)
  );

  always_ff @(posedge clk) begin
    if (reset || flush_id) begin
      ID_a_valid <= 1'b0;
      ID_b_valid <= 1'b0;
    end else begin
      ID_a_valid <= ifu_output_size >= 2'd1;
      ID_b_valid <= ifu_output_size >= 2'd2 && !ifu_have_excp;
    end
    if (ifu_output_size >= 2'd1) begin
      ID_a_pc <= ifu_pc0;
      ID_a_inst <= ifu_inst0;
      ID_a_pred_br_taken <= ifu_pred_br_taken0;
      ID_a_pred_br_target <= ifu_pred_br_target0;
      ID_a_have_excp <= ifu_have_excp;
      ID_a_excp_type <= ifu_excp_type;
    end
    if (ifu_output_size >= 2'd2 && !ifu_have_excp) begin
      ID_b_pc <= ifu_pc1;
      ID_b_inst <= ifu_inst1;
      ID_b_pred_br_taken <= ifu_pred_br_taken1;
      ID_b_pred_br_target <= ifu_pred_br_target1;
      ID_b_have_excp <= ifu_have_excp;
      ID_b_excp_type <= ifu_excp_type;
    end
  end

  logic [63:0] counter;
  always_ff @(posedge clk) begin
    if (reset) counter <= 0;
    else counter <= counter + 64'd1;
  end

  decoder u_decoder_a (
      .pc            (ID_a_pc),
      .inst          (ID_a_inst),
      .pred_br_taken (ID_a_pred_br_taken),
      .pred_br_target(ID_a_pred_br_target),
      .counter       (counter),
      .llbit         (csr_llbit),
      .optype        (id_a_optype),
      .opcode        (id_a_opcode),
      .dest          (id_a_dest),
      .imm           (id_a_imm),
      .br_type       (id_a_br_type),
      .br_condition  (id_a_br_condition),
      .br_target     (id_a_br_target),
      .have_excp     (id_a_have_excp),
      .excp_type     (id_a_excp_type),
      .csr_addr      (id_a_csr_addr),
      .csr_wr        (id_a_csr_wr),
      .is_spec_op    (id_a_is_spec_op),
      .is_idle       (id_a_is_idle),
      .is_ll         (id_a_is_ll),
      .is_sc         (id_a_is_sc),
      .r1            (id_a_r1),
      .r2            (id_a_r2),
      .src2_is_imm   (id_a_src2_is_imm),
      .br_mistaken   (id_a_br_mistaken),
      .br_taken      (id_a_br_taken)
  );

  decoder u_decoder_b (
      .pc            (ID_b_pc),
      .inst          (ID_b_inst),
      .pred_br_taken (ID_b_pred_br_taken),
      .pred_br_target(ID_b_pred_br_target),
      .counter       (counter),
      .llbit         (csr_llbit),
      .optype        (id_b_optype),
      .opcode        (id_b_opcode),
      .dest          (id_b_dest),
      .imm           (id_b_imm),
      .br_type       (id_b_br_type),
      .br_condition  (id_b_br_condition),
      .br_target     (id_b_br_target),
      .have_excp     (id_b_have_excp),
      .excp_type     (id_b_excp_type),
      .csr_addr      (id_b_csr_addr),
      .csr_wr        (id_b_csr_wr),
      .is_spec_op    (id_b_is_spec_op),
      .is_idle       (id_b_is_idle),
      .is_ll         (id_b_is_ll),
      .is_sc         (id_b_is_sc),
      .r1            (id_b_r1),
      .r2            (id_b_r2),
      .src2_is_imm   (id_b_src2_is_imm),
      .br_mistaken   (id_b_br_mistaken),
      .br_taken      (id_b_br_taken)
  );

  always_comb begin
    if (ex1_a_br_mistaken) begin
      br_mistaken  = 1'b1;
      br_type      = EX1_a_br_type;
      wrong_pc     = EX1_a_pc;
      right_target = ex1_a_br_taken ? ex1_a_br_target : EX1_a_pc + 32'd4;
      btb_target   = ex1_a_br_target;
    end else if (ex1_b_br_mistaken) begin
      br_mistaken  = 1'b1;
      br_type      = EX1_b_br_type;
      wrong_pc     = EX1_b_pc;
      right_target = ex1_b_br_taken ? ex1_b_br_target : EX1_b_pc + 32'd4;
      btb_target   = ex1_b_br_target;
    end else if (ID_a_valid && id_a_br_mistaken) begin
      br_mistaken = 1'b1;
      br_type = id_a_br_type;
      wrong_pc = ID_a_pc;
      right_target = (id_a_br_taken || id_a_br_type == BR_COND && ID_a_pred_br_taken) ? id_a_br_target : ID_a_pc + 32'd4;
      btb_target = id_a_br_target;
    end else if (ID_b_valid && id_b_br_mistaken) begin
      br_mistaken = 1'b1;
      br_type = id_b_br_type;
      wrong_pc = ID_b_pc;
      right_target = (id_b_br_taken || id_b_br_type == BR_COND && ID_b_pred_br_taken) ? id_b_br_target : ID_b_pc + 32'd4;
      btb_target = id_b_br_target;
    end else begin
      br_mistaken  = 1'b0;
      br_type      = BR_NOP;
      wrong_pc     = 32'd0;
      right_target = 32'd0;
      btb_target   = 32'd0;
    end
  end

  assign flush_id = raise_excp || replay || br_mistaken;
  assign flush_ibuf = raise_excp || replay || ex1_a_br_mistaken || ex1_b_br_mistaken;
  assign ibuf_no_out = ex1_a_br_mistaken || ex1_b_br_mistaken;
  assign flush_ex1 = raise_excp || replay;

  always_comb begin
    if (ID_b_valid) begin
      if (id_a_br_mistaken) ibuf_i_size = 2'd1;
      else ibuf_i_size = 2'd2;
    end else if (ID_a_valid) begin
      ibuf_i_size = 2'd1;
    end else begin
      ibuf_i_size = 2'd0;
    end
  end

`ifdef DIFFTEST_EN
  assign id_a_difftest.instr = ID_a_inst;
  assign id_a_difftest.store_valid = {
    4'b0,
    u_decoder_a.inst_sc_w & csr_llbit,
    u_decoder_a.inst_st_w,
    u_decoder_a.inst_st_h,
    u_decoder_a.inst_st_b
  };
  assign id_a_difftest.load_valid = {
    2'b0,
    u_decoder_a.inst_ll_w,
    u_decoder_a.inst_ld_w,
    u_decoder_a.inst_ld_hu,
    u_decoder_a.inst_ld_h,
    u_decoder_a.inst_ld_bu,
    u_decoder_a.inst_ld_b
  };
  assign id_a_difftest.is_CNTinst = u_decoder_a.inst_rdcntid_w|u_decoder_a.inst_rdcntvl_w|u_decoder_a.inst_rdcntvh_w;
  assign id_a_difftest.timer_64_value = counter;

  assign id_b_difftest.instr = ID_b_inst;
  assign id_b_difftest.store_valid = {
    4'b0,
    u_decoder_b.inst_sc_w & csr_llbit,
    u_decoder_b.inst_st_w,
    u_decoder_b.inst_st_h,
    u_decoder_b.inst_st_b
  };
  assign id_b_difftest.load_valid = {
    2'b0,
    u_decoder_b.inst_ll_w,
    u_decoder_b.inst_ld_w,
    u_decoder_b.inst_ld_hu,
    u_decoder_b.inst_ld_h,
    u_decoder_b.inst_ld_bu,
    u_decoder_b.inst_ld_b
  };
  assign id_b_difftest.is_CNTinst = u_decoder_b.inst_rdcntid_w|u_decoder_b.inst_rdcntvl_w|u_decoder_b.inst_rdcntvh_w;
  assign id_b_difftest.timer_64_value = counter;
`endif

  ibuf u_ibuf (
      .clk               (clk),
      .reset             (reset),
      .flush             (flush_ibuf),
      .i_size            (ibuf_i_size),
      .i_ready           (ibuf_i_ready),
      .i_a_pc            (ID_a_pc),
      .i_a_optype        (id_a_optype),
      .i_a_opcode        (id_a_opcode),
      .i_a_dest          (id_a_dest),
      .i_a_imm           (id_a_imm),
      .i_a_pred_br_taken (ID_a_pred_br_taken),
      .i_a_pred_br_target(ID_a_pred_br_target),
      .i_a_br_type       (id_a_br_type),
      .i_a_br_condition  (id_a_br_condition),
      .i_a_br_target     (id_a_br_target),
      .i_a_br_taken      (id_a_br_taken),
      .i_a_have_excp     (ID_a_have_excp || id_a_have_excp),
      .i_a_excp_type     (ID_a_have_excp ? ID_a_excp_type : id_a_excp_type),
      .i_a_csr_addr      (id_a_csr_addr),
      .i_a_csr_wr        (id_a_csr_wr),
      .i_a_is_spec_op    (id_a_is_spec_op),
      .i_a_is_idle       (id_a_is_idle),
      .i_a_is_ll         (id_a_is_ll),
      .i_a_is_sc         (id_a_is_sc),
      .i_a_r1            (id_a_r1),
      .i_a_r2            (id_a_r2),
      .i_a_src2_is_imm   (id_a_src2_is_imm),
      .i_b_pc            (ID_b_pc),
      .i_b_optype        (id_b_optype),
      .i_b_opcode        (id_b_opcode),
      .i_b_dest          (id_b_dest),
      .i_b_imm           (id_b_imm),
      .i_b_pred_br_taken (ID_b_pred_br_taken),
      .i_b_pred_br_target(ID_b_pred_br_target),
      .i_b_br_type       (id_b_br_type),
      .i_b_br_condition  (id_b_br_condition),
      .i_b_br_target     (id_b_br_target),
      .i_b_br_taken      (id_b_br_taken),
      .i_b_have_excp     (id_b_have_excp),
      .i_b_excp_type     (id_b_excp_type),
      .i_b_csr_addr      (id_b_csr_addr),
      .i_b_csr_wr        (id_b_csr_wr),
      .i_b_is_spec_op    (id_b_is_spec_op),
      .i_b_is_idle       (id_b_is_idle),
      .i_b_is_ll         (id_b_is_ll),
      .i_b_is_sc         (id_b_is_sc),
      .i_b_r1            (id_b_r1),
      .i_b_r2            (id_b_r2),
      .i_b_src2_is_imm   (id_b_src2_is_imm),

`ifdef DIFFTEST_EN
      .i_a_difftest(id_a_difftest),
      .i_b_difftest(id_b_difftest),
      .o_a_difftest(ro_a_difftest),
      .o_b_difftest(ro_b_difftest),
`endif

      .o_size            (ibuf_o_size),
      .o_a_pc            (ro_a_pc),
      .o_a_valid         (ro_a_valid),
      .o_a_optype        (ro_a_optype),
      .o_a_opcode        (ro_a_opcode),
      .o_a_dest          (ro_a_dest),
      .o_a_imm           (ro_a_imm),
      .o_a_pred_br_taken (ro_a_pred_br_taken),
      .o_a_pred_br_target(ro_a_pred_br_target),
      .o_a_br_type       (ro_a_br_type),
      .o_a_br_condition  (ro_a_br_condition),
      .o_a_br_target     (ro_a_br_target),
      .o_a_br_taken      (ro_a_br_taken),
      .o_a_have_excp     (ro_a_have_excp_no_int),
      .o_a_excp_type     (ro_a_excp_type_no_int),
      .o_a_csr_addr      (ro_a_csr_addr),
      .o_a_csr_wr        (ro_a_csr_wr),
      .o_a_is_spec_op    (ro_a_is_spec_op),
      .o_a_is_idle       (ro_a_is_idle),
      .o_a_is_ll         (ro_a_is_ll),
      .o_a_is_sc         (ro_a_is_sc),
      .o_a_r1            (ro_a_r1),
      .o_a_r2            (ro_a_r2),
      .o_a_src2_is_imm   (ro_a_src2_is_imm),
      .o_b_valid         (ro_b_valid),
      .o_b_pc            (ro_b_pc),
      .o_b_optype        (ro_b_optype),
      .o_b_opcode        (ro_b_opcode),
      .o_b_dest          (ro_b_dest),
      .o_b_imm           (ro_b_imm),
      .o_b_pred_br_taken (ro_b_pred_br_taken),
      .o_b_pred_br_target(ro_b_pred_br_target),
      .o_b_br_type       (ro_b_br_type),
      .o_b_br_condition  (ro_b_br_condition),
      .o_b_br_target     (ro_b_br_target),
      .o_b_br_taken      (ro_b_br_taken),
      .o_b_have_excp     (ro_b_have_excp),
      .o_b_excp_type     (ro_b_excp_type),
      .o_b_csr_addr      (ro_b_csr_addr),
      .o_b_csr_wr        (ro_b_csr_wr),
      .o_b_is_spec_op    (ro_b_is_spec_op),
      .o_b_is_idle       (ro_b_is_idle),
      .o_b_is_ll         (ro_b_is_ll),
      .o_b_is_sc         (ro_b_is_sc),
      .o_b_r1            (ro_b_r1),
      .o_b_r2            (ro_b_r2),
      .o_b_src2_is_imm   (ro_b_src2_is_imm)
  );

  assign ro_a_have_excp = ro_a_have_excp_no_int || interrupt;
  assign ro_a_excp_type = interrupt ? INT : ro_a_excp_type_no_int;

  regfile u_regfile (
      .clk   (clk),
      .raddr1(ro_a_r1),
      .rdata1(rf_rdata1),
      .raddr2(ro_a_r2),
      .rdata2(rf_rdata2),
      .raddr3(ro_b_r1),
      .rdata3(rf_rdata3),
      .raddr4(ro_b_r2),
      .rdata4(rf_rdata4),
      .we1   (rf_we1),
      .waddr1(rf_waddr1),
      .wdata1(rf_wdata1),
      .we2   (rf_we2),
      .waddr2(rf_waddr2),
      .wdata2(rf_wdata2)
  );

  // forward planning
  always_comb begin
    ro_a_src1_passed = 32'd0;
    if (ro_a_r1 == 5'd0) begin
      ro_a_src1_ok = 1'b1;
      ro_a_src1_source = SRC_ZERO;
    end else if (EX1_b_valid && EX1_b_dest == ro_a_r1) begin
      ro_a_src1_ok = EX1_b_optype == OP_ALU && !EX1_b_delayed;
      ro_a_src1_source = SRC_EX2_B;
    end else if (EX1_a_valid && EX1_a_dest == ro_a_r1) begin
      ro_a_src1_ok = EX1_a_optype == OP_ALU;
      ro_a_src1_source = SRC_EX2_A;
    end else if (EX2_b_valid && EX2_b_dest == ro_a_r1) begin
      ro_a_src1_ok = ex2_b_ok || WB_b_ok;
      ro_a_src1_source = SRC_WB_B;
    end else if (EX2_a_valid && EX2_a_dest == ro_a_r1) begin
      ro_a_src1_ok = ex2_a_ok || WB_a_ok;
      ro_a_src1_source = SRC_WB_A;
    end else if (WB_b_valid && WB_b_dest == ro_a_r1) begin
      ro_a_src1_ok = 1'b1;
      ro_a_src1_source = SRC_PASSED;
      ro_a_src1_passed = WB_b_result;
    end else if (WB_a_valid && WB_a_dest == ro_a_r1) begin
      ro_a_src1_ok = 1'b1;
      ro_a_src1_source = SRC_PASSED;
      ro_a_src1_passed = WB_a_result;
    end else begin
      ro_a_src1_ok = 1'b1;
      ro_a_src1_source = SRC_PASSED;
      ro_a_src1_passed = rf_rdata1;
    end
  end

  always_comb begin
    ro_a_src2_passed = 32'd0;
    if (ro_a_src2_is_imm) begin
      ro_a_src2_ok = 1'b1;
      ro_a_src2_source = SRC_IMM;
    end else if (ro_a_r2 == 5'd0) begin
      ro_a_src2_ok = 1'b1;
      ro_a_src2_source = SRC_ZERO;
    end else if (EX1_b_valid && EX1_b_dest == ro_a_r2) begin
      ro_a_src2_ok = EX1_b_optype == OP_ALU && !EX1_b_delayed;
      ro_a_src2_source = SRC_EX2_B;
    end else if (EX1_a_valid && EX1_a_dest == ro_a_r2) begin
      ro_a_src2_ok = EX1_a_optype == OP_ALU;
      ro_a_src2_source = SRC_EX2_A;
    end else if (EX2_b_valid && EX2_b_dest == ro_a_r2) begin
      ro_a_src2_ok = ex2_b_ok || WB_b_ok;
      ro_a_src2_source = SRC_WB_B;
    end else if (EX2_a_valid && EX2_a_dest == ro_a_r2) begin
      ro_a_src2_ok = ex2_a_ok || WB_a_ok;
      ro_a_src2_source = SRC_WB_A;
    end else if (WB_b_valid && WB_b_dest == ro_a_r2) begin
      ro_a_src2_ok = 1'b1;
      ro_a_src2_source = SRC_PASSED;
      ro_a_src2_passed = WB_b_result;
    end else if (WB_a_valid && WB_a_dest == ro_a_r2) begin
      ro_a_src2_ok = 1'b1;
      ro_a_src2_source = SRC_PASSED;
      ro_a_src2_passed = WB_a_result;
    end else begin
      ro_a_src2_ok = 1'b1;
      ro_a_src2_source = SRC_PASSED;
      ro_a_src2_passed = rf_rdata2;
    end
  end

  always_comb begin
    ro_b_src1_passed = 32'd0;
    if (ro_b_r1 == 5'd0) begin
      ro_b_src1_ok = 1'b1;
      ro_b_src1_source = SRC_ZERO;
    end else if (ro_a_dest == ro_b_r1) begin
      ro_b_src1_ok = ro_b_delayed;
      ro_b_src1_source = SRC_DELAYED;
    end else if (EX1_b_valid && EX1_b_dest == ro_b_r1) begin
      ro_b_src1_ok = EX1_b_optype == OP_ALU && !EX1_b_delayed;
      ro_b_src1_source = SRC_EX2_B;
    end else if (EX1_a_valid && EX1_a_dest == ro_b_r1) begin
      ro_b_src1_ok = EX1_a_optype == OP_ALU;
      ro_b_src1_source = SRC_EX2_A;
    end else if (EX2_b_valid && EX2_b_dest == ro_b_r1) begin
      ro_b_src1_ok = ex2_b_ok || WB_b_ok;
      ro_b_src1_source = SRC_WB_B;
    end else if (EX2_a_valid && EX2_a_dest == ro_b_r1) begin
      ro_b_src1_ok = ex2_a_ok || WB_a_ok;
      ro_b_src1_source = SRC_WB_A;
    end else if (WB_b_valid && WB_b_dest == ro_b_r1) begin
      ro_b_src1_ok = 1'b1;
      ro_b_src1_source = SRC_PASSED;
      ro_b_src1_passed = WB_b_result;
    end else if (WB_a_valid && WB_a_dest == ro_b_r1) begin
      ro_b_src1_ok = 1'b1;
      ro_b_src1_source = SRC_PASSED;
      ro_b_src1_passed = WB_a_result;
    end else begin
      ro_b_src1_ok = 1'b1;
      ro_b_src1_source = SRC_PASSED;
      ro_b_src1_passed = rf_rdata3;
    end
  end

  always_comb begin
    ro_b_src2_passed = 32'd0;
    if (ro_b_src2_is_imm) begin
      ro_b_src2_ok = 1'b1;
      ro_b_src2_source = SRC_IMM;
    end else if (ro_b_r2 == 5'd0) begin
      ro_b_src2_ok = 1'b1;
      ro_b_src2_source = SRC_ZERO;
    end else if (ro_a_dest == ro_b_r2) begin
      ro_b_src2_ok = ro_b_delayed;
      ro_b_src2_source = SRC_DELAYED;
    end else if (EX1_b_valid && EX1_b_dest == ro_b_r2) begin
      ro_b_src2_ok = EX1_b_optype == OP_ALU && !EX1_b_delayed;
      ro_b_src2_source = SRC_EX2_B;
    end else if (EX1_a_valid && EX1_a_dest == ro_b_r2) begin
      ro_b_src2_ok = EX1_a_optype == OP_ALU;
      ro_b_src2_source = SRC_EX2_A;
    end else if (EX2_b_valid && EX2_b_dest == ro_b_r2) begin
      ro_b_src2_ok = ex2_b_ok || WB_b_ok;
      ro_b_src2_source = SRC_WB_B;
    end else if (EX2_a_valid && EX2_a_dest == ro_b_r2) begin
      ro_b_src2_ok = ex2_a_ok || WB_a_ok;
      ro_b_src2_source = SRC_WB_A;
    end else if (WB_b_valid && WB_b_dest == ro_b_r2) begin
      ro_b_src2_ok = 1'b1;
      ro_b_src2_source = SRC_PASSED;
      ro_b_src2_passed = WB_b_result;
    end else if (WB_a_valid && WB_a_dest == ro_b_r2) begin
      ro_b_src2_ok = 1'b1;
      ro_b_src2_source = SRC_PASSED;
      ro_b_src2_passed = WB_a_result;
    end else begin
      ro_b_src2_ok = 1'b1;
      ro_b_src2_source = SRC_PASSED;
      ro_b_src2_passed = rf_rdata4;
    end
  end


  wire related = (ro_a_dest == ro_b_r1 || ro_a_dest == ro_b_r2) && ro_a_dest != 5'd0;
  wire b_will_br = ro_b_br_type == BR_COND || ro_b_br_type == BR_INDIR || ro_b_br_type == BR_RET;

  assign ro_b_delayed = ro_a_optype == OP_ALU && ro_b_optype == OP_ALU && related;

  assign allow_issue_a = !ibuf_no_out && ro_a_valid && ro_a_src1_ok && ro_a_src2_ok;
  assign allow_issue_b = !ibuf_no_out && allow_issue_a && !ro_a_have_excp
                      && ro_b_valid && ro_b_src1_ok && ro_b_src2_ok
                      && !ro_a_is_spec_op && !ro_b_is_spec_op
                      && !(ro_a_optype == OP_DIV && ro_b_optype == OP_DIV)
                      && !(related && (ro_a_optype != OP_ALU || ro_b_optype != OP_ALU || b_will_br))
                      && !(ro_a_optype == OP_MEM && ro_b_optype == OP_MEM && ro_a_opcode[5:4] != ro_b_opcode[5:4]);

  assign ibuf_o_size = ex1_stall ? 2'd0 : allow_issue_b ? 2'd2 : allow_issue_a ? 2'd1 : 2'd0;

  always_ff @(posedge clk) begin
    if (reset || flush_ex1) begin
      EX1_a_valid <= 1'b0;
      EX1_b_valid <= 1'b0;
    end else if (!ex1_stall) begin
      EX1_a_valid <= allow_issue_a;
      EX1_b_valid <= allow_issue_b;
    end

    if (!ex1_stall && allow_issue_a) begin
      EX1_a_pc             <= ro_a_pc;
      EX1_a_optype         <= ro_a_optype;
      EX1_a_opcode         <= ro_a_opcode;
      EX1_a_dest           <= ro_a_dest;
      EX1_a_src1_source    <= ro_a_src1_source;
      EX1_a_src1_passed    <= ro_a_src1_passed;
      EX1_a_src2_source    <= ro_a_src2_source;
      EX1_a_src2_passed    <= ro_a_src2_passed;
      EX1_a_imm            <= ro_a_imm;
      EX1_a_br_type        <= ro_a_br_type;
      EX1_a_br_condition   <= ro_a_br_condition;
      EX1_a_br_target      <= ro_a_br_target;
      EX1_a_pred_br_taken  <= ro_a_pred_br_taken;
      EX1_a_pred_br_target <= ro_a_pred_br_target;
      EX1_a_br_taken       <= ro_a_br_taken;
      EX1_a_have_excp      <= ro_a_have_excp;
      EX1_a_excp_type      <= ro_a_excp_type;
      EX1_a_csr_addr       <= ro_a_csr_addr;
      EX1_a_csr_wr         <= ro_a_csr_wr;
      EX1_a_is_spec_op     <= ro_a_is_spec_op;
      EX1_a_is_idle        <= ro_a_is_idle;
      EX1_a_is_ll          <= ro_a_is_ll;
      EX1_a_is_sc          <= ro_a_is_sc;
`ifdef DIFFTEST_EN
      EX1_a_difftest <= ro_a_difftest;
      EX1_a_difftest.is_TLBFILL <= ro_a_optype == OP_TLB || ro_a_opcode == TLB_TLBFILL;
      EX1_a_difftest.TLBFILL_index <= csr_tlbidx;
`endif
    end

    if (!ex1_stall && allow_issue_b) begin
      EX1_b_pc             <= ro_b_pc;
      EX1_b_delayed        <= ro_b_delayed;
      EX1_b_optype         <= ro_b_optype;
      EX1_b_opcode         <= ro_b_opcode;
      EX1_b_dest           <= ro_b_dest;
      EX1_b_src1_source    <= ro_b_src1_source;
      EX1_b_src1_passed    <= ro_b_src1_passed;
      EX1_b_src2_source    <= ro_b_src2_source;
      EX1_b_src2_passed    <= ro_b_src2_passed;
      EX1_b_imm            <= ro_b_imm;
      EX1_b_br_type        <= ro_b_br_type;
      EX1_b_br_condition   <= ro_b_br_condition;
      EX1_b_br_target      <= ro_b_br_target;
      EX1_b_pred_br_taken  <= ro_b_pred_br_taken;
      EX1_b_pred_br_target <= ro_b_pred_br_target;
      EX1_b_br_taken       <= ro_b_br_taken;
      EX1_b_have_excp      <= ro_b_have_excp;
      EX1_b_excp_type      <= ro_b_excp_type;
`ifdef DIFFTEST_EN
      EX1_b_difftest <= ro_b_difftest;
      EX1_b_difftest.is_TLBFILL <= id_b_optype == OP_TLB || id_b_opcode == TLB_TLBFILL;
      EX1_b_difftest.TLBFILL_index <= csr_tlbidx;
`endif
    end
`ifdef DIFFTEST_EN
    if (ex1_stall && mmu_d0_addr_ok) begin
      EX1_a_difftest.storePAddr  <= {u_mmu.d_ptag, u_lsu_a.addr[31-`TAG_WIDTH:0]};
      EX1_a_difftest.loadPAddr   <= {u_mmu.d_ptag, u_lsu_a.addr[31-`TAG_WIDTH:0]};
      EX1_a_difftest.added_paddr <= 1'b1;
    end
    if (ex1_stall && mmu_d1_addr_ok) begin
      EX1_b_difftest.storePAddr  <= {u_mmu.d_ptag, u_lsu_b.addr[31-`TAG_WIDTH:0]};
      EX1_b_difftest.loadPAddr   <= {u_mmu.d_ptag, u_lsu_b.addr[31-`TAG_WIDTH:0]};
      EX1_b_difftest.added_paddr <= 1'b1;
    end
`endif
  end

  always_ff @(posedge clk) begin
    EX1_stalling <= ex1_stall;
    if (ex1_stall) begin
      EX1_a_src1_stalled <= ex1_a_src1;
      EX1_a_src2_stalled <= ex1_a_src2;
      EX1_b_src1_stalled <= ex1_b_src1;
      EX1_b_src2_stalled <= ex1_b_src2;
    end
  end

  always_comb begin
    if (EX1_stalling) begin
      ex1_a_src1 = EX1_a_src1_stalled;
      ex1_a_src2 = EX1_a_src2_stalled;
      ex1_b_src1 = EX1_b_src1_stalled;
      ex1_b_src2 = EX1_b_src2_stalled;
    end else begin
      unique case (EX1_a_src1_source)
        SRC_PASSED: ex1_a_src1 = EX1_a_src1_passed;
        SRC_EX2_A:  ex1_a_src1 = EX2_a_alu_result;
        SRC_EX2_B:  ex1_a_src1 = EX2_b_alu_result;
        SRC_WB_A:   ex1_a_src1 = WB_a_result;
        SRC_WB_B:   ex1_a_src1 = WB_b_result;
        default:    ex1_a_src1 = 32'd0;
      endcase
      unique case (EX1_a_src2_source)
        SRC_PASSED: ex1_a_src2 = EX1_a_src2_passed;
        SRC_IMM:    ex1_a_src2 = EX1_a_imm;
        SRC_EX2_A:  ex1_a_src2 = EX2_a_alu_result;
        SRC_EX2_B:  ex1_a_src2 = EX2_b_alu_result;
        SRC_WB_A:   ex1_a_src2 = WB_a_result;
        SRC_WB_B:   ex1_a_src2 = WB_b_result;
        default:    ex1_a_src2 = 32'd0;
      endcase
      unique case (EX1_b_src1_source)
        SRC_PASSED: ex1_b_src1 = EX1_b_src1_passed;
        SRC_EX2_A:  ex1_b_src1 = EX2_a_alu_result;
        SRC_EX2_B:  ex1_b_src1 = EX2_b_alu_result;
        SRC_WB_A:   ex1_b_src1 = WB_a_result;
        SRC_WB_B:   ex1_b_src1 = WB_b_result;
        default:    ex1_b_src1 = 32'd0;
      endcase
      unique case (EX1_b_src2_source)
        SRC_PASSED: ex1_b_src2 = EX1_b_src2_passed;
        SRC_IMM:    ex1_b_src2 = EX1_b_imm;
        SRC_EX2_A:  ex1_b_src2 = EX2_a_alu_result;
        SRC_EX2_B:  ex1_b_src2 = EX2_b_alu_result;
        SRC_WB_A:   ex1_b_src2 = WB_a_result;
        SRC_WB_B:   ex1_b_src2 = WB_b_result;
        default:    ex1_b_src2 = 32'd0;
      endcase
    end
  end

  assign ex1_ready = lsu_a_ready && lsu_b_ready && !(EX1_a_valid && EX1_a_optype == OP_CACHE && !cacop_ok && !invalid_cacop);
  assign ex1_stall =  /*(EX1_a_valid || EX1_b_valid) &&*/ (!ex1_ready || ex2_stall);

  alu u_alu_a (
      .opcode(alu_opcode_t'(EX1_a_opcode)),
      .src1  (ex1_a_src1),
      .src2  (ex1_a_src2),
      .result(alu_a_result)
  );

  always_comb begin
    if (EX1_a_br_type == BR_COND) begin
      ex1_a_br_taken = EX1_a_br_condition == alu_a_result[0];
      ex1_a_br_target = EX1_a_br_target;
      ex1_a_br_mistaken_long = EX1_a_valid && ex1_a_br_taken != EX1_a_pred_br_taken;
    end else if (EX1_a_br_type == BR_INDIR || EX1_a_br_type == BR_RET) begin
      ex1_a_br_taken = 1'b1;
      ex1_a_br_target = ex1_a_src1 + EX1_a_br_target;
      ex1_a_br_mistaken_long = EX1_a_valid && (!EX1_a_pred_br_taken || ex1_a_br_target != EX1_a_pred_br_target);
    end else begin
      ex1_a_br_taken = 1'b0;
      ex1_a_br_target = 32'd0;
      ex1_a_br_mistaken_long = 1'b0;
    end
  end
  assign ex1_a_br_mistaken = ex1_a_br_mistaken_long && !EX1_stalling;

  alu u_alu_b1 (
      .opcode(alu_opcode_t'(EX1_b_opcode)),
      .src1  (ex1_b_src1),
      .src2  (ex1_b_src2),
      .result(alu_b1_result)
  );

  always_comb begin
    if (!EX1_b_delayed && EX1_b_br_type == BR_COND) begin
      ex1_b_br_taken = EX1_b_br_condition == alu_b1_result[0];
      ex1_b_br_target = EX1_b_br_target;
      ex1_b_br_mistaken = EX1_b_valid && !EX1_stalling && ex1_b_br_taken != EX1_b_pred_br_taken;
    end else if (!EX1_b_delayed && (EX1_b_br_type == BR_INDIR || EX1_b_br_type == BR_RET)) begin
      ex1_b_br_taken = 1'b1;
      ex1_b_br_target = ex1_b_src1 + EX1_b_br_target;
      ex1_b_br_mistaken = EX1_b_valid && !EX1_stalling && (!EX1_b_pred_br_taken || ex1_b_br_target != EX1_b_pred_br_target);
    end else begin
      ex1_b_br_taken = 1'b0;
      ex1_b_br_target = 32'd0;
      ex1_b_br_mistaken = 1'b0;
    end
  end

  mul u_mul_a (
      .clk   (clk),
      .valid (EX1_a_valid && EX1_a_optype == OP_MUL && !ex1_stall),
      .opcode(mul_opcode_t'(EX1_a_opcode)),
      .src1  (ex1_a_src1),
      .src2  (ex1_a_src2),
      .ok    (mul_a_ok),
      .result(mul_a_result)
  );

  mul u_mul_b (
      .clk(clk),
      .valid (EX1_b_valid && EX1_b_optype == OP_MUL && !ex1_stall && !ex1_a_br_mistaken && !lsu_a_have_excp),
      .opcode(mul_opcode_t'(EX1_b_opcode)),
      .src1(ex1_b_src1),
      .src2(ex1_b_src2),
      .ok(mul_b_ok),
      .result(mul_b_result)
  );

  div u_div (
      .clk(clk),
      .valid (EX1_a_valid && EX1_a_optype == OP_DIV && !ex1_stall || EX1_b_valid && EX1_b_optype == OP_DIV && !ex1_stall && !ex1_a_br_mistaken && !lsu_a_have_excp),
      .opcode(EX1_a_optype == OP_DIV ? div_opcode_t'(EX1_a_opcode) : div_opcode_t'(EX1_b_opcode)),
      .src1(EX1_a_optype == OP_DIV ? ex1_a_src1 : ex1_b_src1),
      .src2(EX1_a_optype == OP_DIV ? ex1_a_src2 : ex1_b_src2),
      .ok(div_ok),
      .result(div_result)
  );

  assign mem_cancel = raise_excp || replay
                 || lsu_a_have_excp || (lsu_b_have_excp && EX1_a_optype != OP_MEM)
                 || ex1_a_br_mistaken;

  assign mem_d1_cancel = lsu_b_have_excp;

  lsu u_lsu_a (
      .clk(clk),
      .reset(reset),
      .cancel(mem_cancel),
      .ready(lsu_a_ready),
      .valid(EX1_a_valid && EX1_a_optype == OP_MEM),
      .start(EX1_a_valid && EX1_a_optype == OP_MEM && !EX1_stalling),
      .addr(ex1_a_src1 + EX1_a_imm),
      .opcode(EX1_a_opcode),
      .st_data(ex1_a_src2),
      .have_excp(lsu_a_have_excp),
      .excp_type(lsu_a_excp_type),
      .ok(lsu_a_ok),
      .accept_ok(EX2_a_valid && EX2_a_optype == OP_MEM && !WB_a_ok && lsu_a_ok),
      .ld_data(lsu_a_result),
      .mmu_req(mmu_d0_req),
      .mmu_addr(mmu_d0_va),
      .mmu_we(mmu_d0_we),
      .mmu_size(mmu_d0_size),
      .mmu_wstrb(mmu_d0_wstrb),
      .mmu_wdata(mmu_d0_wdata),
      .mmu_addr_ok(mmu_d0_addr_ok),
      .mmu_data_ok(mmu_d0_data_ok),
      .mmu_rdata(mmu_d0_rdata),
      .mmu_tlbr(mmu_d0_tlbr),
      .mmu_pil(mmu_d0_pil),
      .mmu_pis(mmu_d0_pis),
      .mmu_ppi(mmu_d0_ppi),
      .mmu_pme(mmu_d0_pme)
  );

  lsu u_lsu_b (
      .clk(clk),
      .reset(reset),
      .cancel(mem_cancel || mem_d1_cancel),
      .ready(lsu_b_ready),
      .valid(EX1_b_valid && EX1_b_optype == OP_MEM),
      .start(EX1_b_valid && EX1_b_optype == OP_MEM && !EX1_stalling),
      .addr(ex1_b_src1 + EX1_b_imm),
      .opcode(EX1_b_opcode),
      .st_data(ex1_b_src2),
      .have_excp(lsu_b_have_excp),
      .excp_type(lsu_b_excp_type),
      .ok(lsu_b_ok),
      .accept_ok(EX2_b_valid && EX2_b_optype == OP_MEM && !WB_b_ok && lsu_b_ok),
      .ld_data(lsu_b_result),
      .mmu_req(mmu_d1_req),
      .mmu_addr(mmu_d1_va),
      .mmu_we(mmu_d1_we),
      .mmu_size(mmu_d1_size),
      .mmu_wstrb(mmu_d1_wstrb),
      .mmu_wdata(mmu_d1_wdata),
      .mmu_addr_ok(mmu_d1_addr_ok),
      .mmu_data_ok(mmu_d1_data_ok),
      .mmu_rdata(mmu_d1_rdata),
      .mmu_tlbr(mmu_d1_tlbr),
      .mmu_pil(mmu_d1_pil),
      .mmu_pis(mmu_d1_pis),
      .mmu_ppi(mmu_d1_ppi),
      .mmu_pme(mmu_d1_pme)
  );

  assign invtlb_valid = EX1_a_valid && !EX1_stalling && EX1_a_optype == OP_TLB && EX1_a_opcode == TLB_INVTLB && !flush_ex1;
  assign invtlb_op = EX1_a_imm[4:0];
  assign invtlb_asid = ex1_a_src1[9:0];
  assign invtlb_va = ex1_a_src2;
  assign tlb_we = EX1_a_valid && !EX1_stalling && EX1_a_optype == OP_TLB && (EX1_a_opcode == TLB_TLBWR || EX1_a_opcode == TLB_TLBFILL) && !flush_ex1;
  assign tlb_w_index = csr_tlbidx;
  assign tlb_w_entry = csr_tlb_rdata;
  assign tlb_r_index = csr_tlbidx;
  assign csr_tlb_wdata = tlb_r_entry;
  assign tlbsrch_valid = EX1_a_valid && !EX1_stalling && EX1_a_optype == OP_TLB && EX1_a_opcode == TLB_TLBSRCH && !flush_ex1;
  assign tlbsrch_vppn = csr_tlb_rdata.vppn;
  assign csr_tlb_we = EX1_a_valid && !EX1_stalling && EX1_a_optype == OP_TLB && EX1_a_opcode == TLB_TLBRD && !flush_ex1;

  assign icacop_en = EX1_a_valid && EX1_a_optype == OP_CACHE && EX1_a_opcode[2:0] == 0;
  assign dcacop_en = EX1_a_valid && EX1_a_optype == OP_CACHE && EX1_a_opcode[2:0] == 1;
  assign invalid_cacop = EX1_a_valid && EX1_a_optype == OP_CACHE && EX1_a_opcode[2:0] != 0 && EX1_a_opcode[2:0] != 1;
  assign cacop_op = EX1_a_opcode[4:3];

  always_ff @(posedge clk) begin
    if (reset) begin
      EX2_a_valid <= 1'b0;
      EX2_b_valid <= 1'b0;
    end else if (!ex2_stall) begin
      EX2_a_valid <= ex1_ready && EX1_a_valid && !flush_ex1;
      EX2_b_valid <= ex1_ready && EX1_b_valid && !ex1_a_br_mistaken_long && !lsu_a_have_excp && !flush_ex1;
    end

    EX2_stalling <= ex2_stall;

    if (!ex2_stall && ex1_ready && EX1_a_valid && !flush_ex1) begin
`ifdef DIFFTEST_EN
      mem_opcode_t opcode = EX1_a_opcode;
`endif
      EX2_a_pc <= EX1_a_pc;
      EX2_a_optype <= EX1_a_optype;
      EX2_a_dest <= EX1_a_dest;
      EX2_a_src1 <= ex1_a_src1;
      EX2_a_src2 <= ex1_a_src2;
      EX2_a_alu_result <= alu_a_result;
      EX2_a_br_type <= EX1_a_br_type;
      EX2_a_br_taken <= ex1_a_br_taken || EX1_a_br_taken;
      EX2_a_have_excp <= EX1_a_have_excp || lsu_a_have_excp || cacop_have_excp;
      EX2_a_excp_type <= lsu_a_have_excp ? lsu_a_excp_type :
                         cacop_have_excp ? cacop_excp_type :
                                           EX1_a_excp_type;
      EX2_a_excp_addr <= u_lsu_a.addr;
      EX2_a_csr_addr <= EX1_a_csr_addr;
      EX2_a_csr_wr <= EX1_a_csr_wr;
      EX2_a_is_spec_op <= EX1_a_is_spec_op;
      EX2_a_is_idle <= EX1_a_is_idle;
      EX2_a_is_ll <= EX1_a_is_ll;
      EX2_a_is_sc <= EX1_a_is_sc;
`ifdef DIFFTEST_EN
      EX2_a_difftest <= EX1_a_difftest;
      if (!EX1_a_difftest.added_paddr) begin
        EX2_a_difftest.storePAddr <= {u_mmu.d_ptag, u_lsu_a.addr[31-`TAG_WIDTH:0]};
      end
      EX2_a_difftest.storeVAddr <= u_lsu_a.addr;
      EX2_a_difftest.storeData <= opcode.size_byte ? ex1_a_src2[7:0] << (u_lsu_a.addr[1:0]*8) :
                                  opcode.size_half ? ex1_a_src2[15:0] << (u_lsu_a.addr[1]*16) :
                                  ex1_a_src2;
      if (!EX1_a_difftest.added_paddr) begin
        EX2_a_difftest.loadPAddr <= {u_mmu.d_ptag, u_lsu_a.addr[31-`TAG_WIDTH:0]};
      end
      EX2_a_difftest.loadVAddr <= u_lsu_a.addr;
      EX2_a_difftest.csr_rstat <= EX1_a_optype == OP_CSR && EX1_a_csr_addr == 14'h5;
      EX2_a_difftest.csr_data  <= u_csr.ESTAT;
`endif
    end

    if (!ex2_stall && ex1_ready && EX1_b_valid && !flush_ex1 && !ex1_a_br_mistaken) begin
`ifdef DIFFTEST_EN
      mem_opcode_t opcode = EX1_b_opcode;
`endif
      EX2_b_pc <= EX1_b_pc;
      EX2_b_delayed <= EX1_b_delayed;
      EX2_b_optype <= EX1_b_optype;
      EX2_b_opcode <= EX1_b_opcode;
      EX2_b_dest <= EX1_b_dest;
      EX2_b_src1 <= ex1_b_src1;
      EX2_b_src1_delayed <= EX1_b_src1_source == SRC_DELAYED;
      EX2_b_src2 <= ex1_b_src2;
      EX2_b_src2_delayed <= EX1_b_src2_source == SRC_DELAYED;
      EX2_b_alu_result <= alu_b1_result;
      EX2_b_imm <= EX1_b_imm;
      EX2_b_br_type <= EX1_b_br_type;
      EX2_b_br_taken <= ex1_b_br_taken || EX1_b_br_taken;
      EX2_b_have_excp <= EX1_b_have_excp || lsu_b_have_excp;
      EX2_b_excp_type <= lsu_b_have_excp ? lsu_b_excp_type : EX1_b_excp_type;
      EX2_b_excp_addr <= u_lsu_b.addr;
`ifdef DIFFTEST_EN
      EX2_b_difftest <= EX1_b_difftest;
      EX2_b_difftest.csr_rstat <= 1'b0;
      if (!EX1_b_difftest.added_paddr) begin
        EX2_b_difftest.storePAddr <= {u_mmu.d_ptag, u_lsu_b.addr[31-`TAG_WIDTH:0]};
      end
      EX2_b_difftest.storeVAddr <= u_lsu_b.addr;
      EX2_b_difftest.storeData <= opcode.size_byte ? ex1_b_src2[7:0] << (u_lsu_b.addr[1:0]*8) :
                                  opcode.size_half ? ex1_b_src2[15:0] << (u_lsu_b.addr[1]*16) :
                                  ex1_b_src2;
      if (!EX1_b_difftest.added_paddr) begin
        EX2_b_difftest.loadPAddr <= {u_mmu.d_ptag, u_lsu_b.addr[31-`TAG_WIDTH:0]};
      end
      EX2_b_difftest.loadVAddr <= u_lsu_b.addr;
`endif
    end
  end

  assign ex2_have_excp = (EX2_a_valid && EX2_a_have_excp) || (EX2_b_valid && EX2_b_have_excp);
  assign ex2_excp_type = EX2_a_have_excp ? EX2_a_excp_type : EX2_b_excp_type;
  assign ex2_excp_pc = EX2_a_have_excp ? EX2_a_pc : EX2_b_pc;
  assign ex2_excp_addr = EX2_a_have_excp ? EX2_a_excp_addr : EX2_b_excp_addr;

  assign raise_excp = ex2_have_excp && !EX2_stalling;
  assign csr_badv_we = raise_excp && (
         ex2_excp_type == TLBR
      || ex2_excp_type == ADEF
      || ex2_excp_type == ALE
      || ex2_excp_type == PIL
      || ex2_excp_type == PIS
      || ex2_excp_type == PIF
      || ex2_excp_type == PME
      || ex2_excp_type == PPI
    );

  //TODO: PPI?

  assign csr_badv_wdata = (ex2_excp_type == ADEF || ex2_excp_type == PIF)? ex2_excp_pc : ex2_excp_addr;

  assign csr_vppn_we = raise_excp && (
         ex2_excp_type == TLBR
      || ex2_excp_type == PIL
      || ex2_excp_type == PIS
      || ex2_excp_type == PIF
      || ex2_excp_type == PME
      || ex2_excp_type == PPI
    );
  assign csr_vppn_wdata = ex2_excp_type == PIF ? ex2_excp_pc[31:13] : ex2_excp_addr[31:13];

  assign idle = EX2_a_valid && EX2_a_is_idle;

  assign csr_llbit_we = EX2_a_is_ll || EX2_a_is_sc;
  assign csr_llbit_wdata = EX2_a_is_ll;

  assign ex2_a_ok = !(EX2_a_optype == OP_DIV && !div_ok || EX2_a_optype == OP_MUL && !mul_a_ok || EX2_a_optype == OP_MEM && !lsu_a_ok && !EX2_a_have_excp);
  assign ex2_b_ok = !(EX2_b_optype == OP_DIV && !div_ok || EX2_b_optype == OP_MUL && !mul_b_ok || EX2_b_optype == OP_MEM && !lsu_b_ok && !EX2_b_have_excp);
  assign ex2_stall  = /*(EX2_a_valid || EX2_b_valid) &&*/ (EX2_a_valid && !ex2_a_ok && !WB_a_ok || EX2_b_valid && !ex2_b_ok && !WB_b_ok);
  assign ex2_b_src1 = EX2_b_src1_delayed ? EX2_a_alu_result : EX2_b_src1;
  assign ex2_b_src2 = EX2_b_src2_delayed ? EX2_a_alu_result : EX2_b_src2;

  alu u_alu_b2 (
      .opcode(alu_opcode_t'(EX2_b_opcode)),
      .src1  (ex2_b_src1),
      .src2  (ex2_b_src2),
      .result(alu_b2_result)
  );

  assign replay = !EX2_stalling && EX2_a_valid && EX2_a_is_spec_op;
  assign replay_target = EX2_a_pc + 32'd4;

  always_ff @(posedge clk) begin
    if (reset) begin
      WB_a_valid <= 1'b0;
      WB_b_valid <= 1'b0;
    end else begin
      WB_a_valid <= !ex2_stall && EX2_a_valid;
      WB_b_valid <= !ex2_stall && EX2_b_valid;
    end
    if (!ex2_stall && EX2_a_valid) begin
      WB_a_pc <= EX2_a_pc;
      WB_a_dest <= EX2_a_dest;
      WB_a_br_type <= EX2_a_br_type;
      WB_a_br_taken <= EX2_a_br_taken;
      WB_a_have_excp <= EX2_a_have_excp;
      WB_a_excp_type <= EX2_a_excp_type;
`ifdef DIFFTEST_EN
      WB_a_difftest <= EX2_a_difftest;
`endif
    end
    if (!ex2_stall && EX2_b_valid) begin
      WB_b_pc <= EX2_b_pc;
      WB_b_dest <= EX2_b_dest;
      WB_b_br_type <= EX2_b_br_type;
      WB_b_br_taken <= EX2_b_br_taken;
      WB_b_have_excp <= EX2_b_have_excp;
      WB_b_excp_type <= EX2_b_excp_type;
`ifdef DIFFTEST_EN
      WB_b_difftest <= EX2_b_difftest;
`endif
    end
  end

  assign update_orien_en = WB_a_valid && WB_a_br_type == BR_COND || WB_b_valid && WB_b_br_type == BR_COND;
  assign retire_pc = (WB_a_valid && WB_a_br_type == BR_COND) ? WB_a_pc : WB_b_pc;
  assign right_orien = (WB_a_valid && WB_a_br_type == BR_COND) ? WB_a_br_taken : WB_b_br_taken;

  always_ff @(posedge clk) begin
    if (reset) begin
      WB_a_ok <= 1'b0;
    end else begin
      if (ex2_a_ok && !WB_a_ok) begin
        if (ex2_stall) WB_a_ok <= 1'b1;
        unique case (EX2_a_optype)
          OP_ALU:  WB_a_result <= EX2_a_is_sc ? 32'd0 : EX2_a_alu_result;
          OP_MUL:  WB_a_result <= mul_a_result;
          OP_DIV:  WB_a_result <= div_result;
          OP_MEM:  WB_a_result <= EX2_a_is_sc ? 32'd1 : lsu_a_result;
          OP_CSR:  WB_a_result <= csr_rdata;
          default: WB_a_result <= 32'd0;
        endcase
      end
      if (!ex2_stall) begin
        WB_a_ok <= 1'b0;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      WB_b_ok <= 1'b0;
    end else begin
      if (ex2_b_ok && !WB_b_ok) begin
        if (ex2_stall) WB_b_ok <= 1'b1;
        unique case (EX2_b_optype)
          OP_ALU:  WB_b_result <= EX2_b_delayed ? alu_b2_result : EX2_b_alu_result;
          OP_MUL:  WB_b_result <= mul_b_result;
          OP_DIV:  WB_b_result <= div_result;
          OP_MEM:  WB_b_result <= lsu_b_result;
          default: WB_b_result <= 32'd0;
        endcase
      end
      if (!ex2_stall) begin
        WB_b_ok <= 1'b0;
      end
    end
  end

  assign rf_we1 = WB_a_valid && !WB_a_have_excp;
  assign rf_waddr1 = WB_a_dest;
  assign rf_wdata1 = WB_a_result;
  assign rf_we2 = WB_b_valid && !WB_b_have_excp;
  assign rf_waddr2 = WB_b_dest;
  assign rf_wdata2 = WB_b_result;

  always_ff @(posedge clk) begin
    debug0_wb_pc <= WB_a_pc;
    debug0_wb_rf_wen <= {4{WB_a_valid && !WB_a_have_excp}};
    debug0_wb_rf_wnum <= WB_a_dest;
    debug0_wb_rf_wdata <= WB_a_result;
    debug1_wb_pc <= WB_b_pc;
    debug1_wb_rf_wen <= {4{WB_b_valid && !WB_b_have_excp}};
    debug1_wb_rf_wnum <= WB_b_dest;
    debug1_wb_rf_wdata <= WB_b_result;
`ifdef DIFFTEST_EN
    a_difftest <= WB_a_difftest;
    a_difftest.valid <= WB_a_valid && (!WB_a_have_excp || WB_a_excp_type == ERTN);
    b_difftest <= WB_b_difftest;
    b_difftest.valid <= WB_b_valid && (!WB_b_have_excp || WB_b_excp_type == ERTN);
    excp_difftest.excp_valid <= (WB_a_valid && WB_a_have_excp && WB_a_excp_type != ERTN || WB_b_valid && WB_b_have_excp && WB_b_excp_type != ERTN);
    excp_difftest.eret <= (WB_a_valid && WB_a_have_excp && WB_a_excp_type == ERTN || WB_b_valid && WB_b_have_excp && WB_b_excp_type == ERTN);
    excp_difftest.intrNo <= u_csr.ESTAT[12:2];
    excp_difftest.cause <= u_csr.ESTAT[21:16];
    excp_difftest.exceptionPC <= WB_a_have_excp ? WB_a_pc : WB_b_pc;
    excp_difftest.exceptionInst <= WB_a_have_excp ? WB_a_difftest.instr : WB_b_difftest.instr;

    csr_difftest.CRMD <= u_csr.CRMD;
    csr_difftest.PRMD <= u_csr.PRMD;
    csr_difftest.ECFG <= u_csr.ECFG;
    csr_difftest.ESTAT <= u_csr.ESTAT;
    csr_difftest.ERA <= u_csr.ERA;
    csr_difftest.BADV <= u_csr.BADV;
    csr_difftest.EENTRY <= u_csr.EENTRY;
    csr_difftest.TLBIDX <= u_csr.TLBIDX;
    csr_difftest.TLBEHI <= u_csr.TLBEHI;
    csr_difftest.TLBELO0 <= u_csr.TLBELO0;
    csr_difftest.TLBELO1 <= u_csr.TLBELO1;
    csr_difftest.ASID <= u_csr.ASID;
    csr_difftest.SAVE0 <= u_csr.SAVE0;
    csr_difftest.SAVE1 <= u_csr.SAVE1;
    csr_difftest.SAVE2 <= u_csr.SAVE2;
    csr_difftest.SAVE3 <= u_csr.SAVE3;
    csr_difftest.LLBCTL <= u_csr.LLBCTL;
    csr_difftest.TID <= u_csr.TID;
    csr_difftest.TCFG <= u_csr.TCFG;
    csr_difftest.TVAL <= u_csr.TVAL;
    csr_difftest.TLBRENTRY <= u_csr.TLBRENTRY;
    csr_difftest.DMW0 <= u_csr.DMW0;
    csr_difftest.DMW1 <= u_csr.DMW1;
`endif
  end

  csr u_csr (
      .clk(clk),
      .reset(reset),
      .addr(EX2_a_csr_addr),
      .rdata(csr_rdata),
      .we(EX2_a_valid && EX2_a_optype == OP_CSR),
      .mask(EX2_a_csr_wr ? 32'hffffffff : EX2_a_src1),
      .wdata(EX2_a_src2),
      .raise_excp(raise_excp),
      .excp_type(ex2_excp_type),
      .pc_in(ex2_excp_pc),
      .pc_out(excp_target),
      .interrupt(interrupt),
      .badv_we(csr_badv_we),
      .badv_data(csr_badv_wdata),
      .vppn_we(csr_vppn_we),
      .vppn_data(csr_vppn_wdata),
      .csr_tlbsrch_we(tlbsrch_valid),
      .csr_tlbsrch_found(tlbsrch_found),
      .csr_tlbsrch_index(tlbsrch_index),
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
      .csr_dmw1(csr_dmw1),
      .csr_llbit(csr_llbit),
      .csr_llbit_we(csr_llbit_we),
      .csr_llbit_wdata(csr_llbit_wdata)
  );


  mmu u_mmu (
      .clk             (clk),
      .reset           (reset),
      .da              (csr_da),
      .datf            (csr_datf),
      .datm            (csr_datm),
      .plv             (csr_plv),
      .asid            (csr_asid),
      .dmw0            (csr_dmw0),
      .dmw1            (csr_dmw1),
      .i_req           (mmu_i_req),
      .i_va            (mmu_i_va),
      .i_addr_ok       (mmu_i_addr_ok),
      .i_double        (mmu_i_double),
      .i_data_ok       (mmu_i_data_ok),
      .i_rdata         (mmu_i_rdata),
      .i_tlbr          (mmu_i_tlbr),
      .i_pif           (mmu_i_pif),
      .i_ppi           (mmu_i_ppi),
      .d_cancel        (mem_cancel),
      .d1_cancel       (mem_d1_cancel),
      .d0_req          (mmu_d0_req),
      .d0_va           (mmu_d0_va),
      .d0_we           (mmu_d0_we),
      .d0_size         (mmu_d0_size),
      .d0_wstrb        (mmu_d0_wstrb),
      .d0_wdata        (mmu_d0_wdata),
      .d0_addr_ok      (mmu_d0_addr_ok),
      .d0_data_ok      (mmu_d0_data_ok),
      .d0_rdata        (mmu_d0_rdata),
      .d0_tlbr         (mmu_d0_tlbr),
      .d0_pil          (mmu_d0_pil),
      .d0_pis          (mmu_d0_pis),
      .d0_ppi          (mmu_d0_ppi),
      .d0_pme          (mmu_d0_pme),
      .d1_req          (mmu_d1_req),
      .d1_va           (mmu_d1_va),
      .d1_we           (mmu_d1_we),
      .d1_size         (mmu_d1_size),
      .d1_wstrb        (mmu_d1_wstrb),
      .d1_wdata        (mmu_d1_wdata),
      .d1_addr_ok      (mmu_d1_addr_ok),
      .d1_data_ok      (mmu_d1_data_ok),
      .d1_rdata        (mmu_d1_rdata),
      .d1_tlbr         (mmu_d1_tlbr),
      .d1_pil          (mmu_d1_pil),
      .d1_pis          (mmu_d1_pis),
      .d1_ppi          (mmu_d1_ppi),
      .d1_pme          (mmu_d1_pme),
      .invtlb_valid    (invtlb_valid),
      .invtlb_op       (invtlb_op),
      .invtlb_asid     (invtlb_asid),
      .invtlb_va       (invtlb_va),
      .tlb_we          (tlb_we),
      .icacop_en       (icacop_en),
      .dcacop_en       (dcacop_en),
      .cacop_op        (cacop_op),
      .cacop_ok        (cacop_ok),
      .cacop_have_excp (cacop_have_excp),
      .cacop_excp_type (cacop_excp_type),
      .tlb_w_index     (tlb_w_index),
      .tlb_w_entry     (tlb_w_entry),
      .tlb_r_index     (tlb_r_index),
      .tlb_r_entry     (tlb_r_entry),
      .tlbsrch_valid   (tlbsrch_valid),
      .tlbsrch_vppn    (tlbsrch_vppn),
      .tlbsrch_found   (tlbsrch_found),
      .tlbsrch_index   (tlbsrch_index),
      .icache_req      (icache_req),
      .icache_op       (icache_op),
      .icache_addr     (icache_addr),
      .icache_uncached (icache_uncached),
      .icache_addr_ok  (icache_addr_ok),
      .icache_data_ok  (icache_data_ok),
      .icache_rdata    (icache_rdata),
      .dcache_p0_valid (dcache_p0_valid),
      .dcache_p1_valid (dcache_p1_valid),
      .dcache_op       (dcache_op),
      .dcache_tag      (dcache_tag),
      .dcache_index    (dcache_index),
      .dcache_p0_offset(dcache_p0_offset),
      .dcache_p1_offset(dcache_p1_offset),
      .dcache_p0_wstrb (dcache_p0_wstrb),
      .dcache_p1_wstrb (dcache_p1_wstrb),
      .dcache_p0_wdata (dcache_p0_wdata),
      .dcache_p1_wdata (dcache_p1_wdata),
      .dcache_uncached (dcache_uncached),
      .dcache_p0_size  (dcache_p0_size),
      .dcache_p1_size  (dcache_p1_size),
      .dcache_addr_ok  (dcache_addr_ok),
      .dcache_data_ok  (dcache_data_ok),
      .dcache_p0_rdata (dcache_p0_rdata),
      .dcache_p1_rdata (dcache_p1_rdata)
  );
  // int br_cnt = 0;
  // int imm_cnt = 0;
  // int con_cnt = 0;
  // int call_cnt = 0;
  // int ret_cnt = 0;
  // int indir_cnt = 0;
  // int imm_mis_cnt = 0;
  // int con_mis_cnt = 0;
  // int call_mis_cnt = 0;
  // int ret_mis_cnt = 0;
  // int indir_mis_cnt = 0;

  // always_ff @(posedge clk) begin
  //   if (ID_a_valid) begin
  //     br_cnt = br_cnt + 1;
  //     case (id_a_br_type)
  //       BR_IMM:   imm_cnt = imm_cnt + 1;
  //       BR_COND:  con_cnt = con_cnt + 1;
  //       BR_CALL:  call_cnt = call_cnt + 1;
  //       BR_RET:   ret_cnt = ret_cnt + 1;
  //       BR_INDIR: indir_cnt = indir_cnt + 1;
  //     endcase
  //   end
  //   if (ID_b_valid) begin
  //     br_cnt = br_cnt + 1;
  //     case (id_b_br_type)
  //       BR_IMM:   imm_cnt = imm_cnt + 1;
  //       BR_COND:  con_cnt = con_cnt + 1;
  //       BR_CALL:  call_cnt = call_cnt + 1;
  //       BR_RET:   ret_cnt = ret_cnt + 1;
  //       BR_INDIR: indir_cnt = indir_cnt + 1;
  //     endcase
  //   end
  //   if (br_mistaken) begin
  //     case (br_type)
  //       BR_IMM:   imm_mis_cnt = imm_mis_cnt + 1;
  //       BR_COND:  con_mis_cnt = con_mis_cnt + 1;
  //       BR_CALL:  call_mis_cnt = call_mis_cnt + 1;
  //       BR_RET:   ret_mis_cnt = ret_mis_cnt + 1;
  //       BR_INDIR: indir_mis_cnt = indir_mis_cnt + 1;
  //     endcase
  //   end
  //   if (br_cnt > 0 && br_cnt % 10000 == 0) begin
  //     $display("imm_cnt=%d, imm_mis_cnt=%d, rate=%f%%", imm_cnt, imm_mis_cnt,
  //              100.0 * imm_mis_cnt / imm_cnt);
  //     $display("con_cnt=%d, con_mis_cnt=%d, rate=%f%%", con_cnt, con_mis_cnt,
  //              100.0 * con_mis_cnt / con_cnt);
  //     $display("call_cnt=%d, call_mis_cnt=%d, rate=%f%%", call_cnt, call_mis_cnt,
  //              100.0 * call_mis_cnt / call_cnt);
  //     $display("ret_cnt=%d, ret_mis_cnt=%d, rate=%f%%", ret_cnt, ret_mis_cnt,
  //              100.0 * ret_mis_cnt / ret_cnt);
  //     $display("indir_cnt=%d, indir_mis_cnt=%d, rate=%f%%\n", indir_cnt, indir_mis_cnt,
  //              100.0 * indir_mis_cnt / indir_cnt);
  //   end
  // end

endmodule
