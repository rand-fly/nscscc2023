`include "definitions.svh"

module mmu (
    input               clk,
    input               reset,
    // from csr
    input               da,
    input        [ 1:0] datf,
    input        [ 1:0] datm,
    input        [ 1:0] plv,
    input        [ 9:0] asid,
    input  dmw_t        dmw0,
    input  dmw_t        dmw1,
    // from ifu
    input               i_req,
    input        [31:0] i_va,
    // to ifu
    output              i_addr_ok,
    output              i_double,
    output              i_data_ok,
    output       [63:0] i_rdata,
    output              i_tlbr,
    output              i_pif,
    output              i_ppi,
    // from lsu a
    input               d1_req,
    input        [31:0] d1_va,
    input               d1_we,
    input        [ 1:0] d1_size,
    input        [ 3:0] d1_wstrb,
    input        [31:0] d1_wdata,
    // to lsu a
    output              d1_addr_ok,
    output              d1_data_ok,
    output       [31:0] d1_rdata,
    output              d1_tlbr,
    output              d1_pil,
    output              d1_pis,
    output              d1_ppi,
    output              d1_pme,
    // from lsu b
    input               d2_req,
    input        [31:0] d2_va,
    input               d2_we,
    input        [ 1:0] d2_size,
    input        [ 3:0] d2_wstrb,
    input        [31:0] d2_wdata,
    // to lsu b
    output              d2_addr_ok,
    output              d2_data_ok,
    output       [31:0] d2_rdata,
    output              d2_tlbr,
    output              d2_pil,
    output              d2_pis,
    output              d2_ppi,
    output              d2_pme,
    // from ex1
    input               invtlb_valid,
    input        [ 4:0] invtlb_op,
    input        [ 9:0] invtlb_asid,
    input        [31:0] invtlb_va,
    input               tlb_we,

    // from csr
    input              [TLBIDLEN-1:0] tlb_w_index,
    input  tlb_entry_t                tlb_w_entry,
    input              [TLBIDLEN-1:0] tlb_r_index,
    output tlb_entry_t                tlb_r_entry,

    input                 tlbsrch_valid,
    input  [        18:0] tlbsrch_vppn,
    output                tlbsrch_found,
    output [TLBIDLEN-1:0] tlbsrch_index,

    // to icache
    output        icache_req,
    output [31:0] icache_addr,
    output        icache_uncached,
    input         icache_addr_ok,
    input         icache_data_ok,
    input  [63:0] icache_rdata,
    // to dcache
    output        dcache_req,
    output        dcache_wr,
    output [ 1:0] dcache_size,
    output [ 3:0] dcache_wstrb,
    output [31:0] dcache_addr,
    output [31:0] dcache_wdata,
    output        dcache_uncached,
    input         dcache_addr_ok,
    input         dcache_data_ok,
    input  [31:0] dcache_rdata
);

  logic        [31:0] i_pa;
  logic        [ 1:0] i_mat;
  logic               i_page_fault;
  logic               i_page_invalid;
  logic               i_page_dirty;
  logic               i_plv_fault;

  logic        [31:0] d1_pa;
  logic        [ 1:0] d1_mat;
  logic               d1_page_fault;
  logic               d1_page_invalid;
  logic               d1_page_dirty;
  logic               d1_plv_fault;

  logic        [31:0] d2_pa;
  logic        [ 1:0] d2_mat;
  logic               d2_page_fault;
  logic               d2_page_invalid;
  logic               d2_page_dirty;
  logic               d2_plv_fault;

  logic        [18:0] tlb_s0_vppn;
  logic               tlb_s0_va_bit12;
  logic        [ 9:0] tlb_s0_asid;
  tlb_result_t        tlb_s0_result;

  logic        [18:0] tlb_s1_vppn;
  logic               tlb_s1_va_bit12;
  logic        [ 9:0] tlb_s1_asid;
  tlb_result_t        tlb_s1_result;

  logic        [18:0] tlb_s2_vppn;
  logic               tlb_s2_va_bit12;
  logic        [ 9:0] tlb_s2_asid;
  tlb_result_t        tlb_s2_result;

  addr_trans addr_trans_i (
      .direct_access    (da),
      .direct_access_mat(datf),
      .plv              (plv),
      .asid             (asid),
      .dmw0             (dmw0),
      .dmw1             (dmw1),
      .tlb_s_vppn       (tlb_s0_vppn),
      .tlb_s_va_bit12   (tlb_s0_va_bit12),
      .tlb_s_asid       (tlb_s0_asid),
      .tlb_s_result     (tlb_s0_result),

      .va          (i_va),
      .pa          (i_pa),
      .mat         (i_mat),
      .page_fault  (i_page_fault),
      .page_invalid(i_page_invalid),
      .page_dirty  (i_page_dirty),
      .plv_fault   (i_plv_fault)
  );

  assign i_tlbr = i_page_fault;
  assign i_pif  = i_page_invalid;
  assign i_ppi  = i_plv_fault;

  addr_trans addr_trans_d1 (
      .direct_access    (da),
      .direct_access_mat(datm),
      .plv              (plv),
      .asid             (asid),
      .dmw0             (dmw0),
      .dmw1             (dmw1),
      .tlb_s_vppn       (tlb_s1_vppn),
      .tlb_s_va_bit12   (tlb_s1_va_bit12),
      .tlb_s_asid       (tlb_s1_asid),
      .tlb_s_result     (tlb_s1_result),

      .va          (d1_va),
      .pa          (d1_pa),
      .mat         (d1_mat),
      .page_fault  (d1_page_fault),
      .page_invalid(d1_page_invalid),
      .page_dirty  (d1_page_dirty),
      .plv_fault   (d1_plv_fault)
  );

  assign d1_tlbr = d1_page_fault;
  assign d1_pil  = d1_page_invalid && !d1_we;
  assign d1_pis  = d1_page_invalid && d1_we;
  assign d1_ppi  = d1_plv_fault;
  assign d1_pme  = d1_page_dirty && d1_we;

  addr_trans addr_trans_d2 (
      .direct_access    (da),
      .direct_access_mat(datm),
      .plv              (plv),
      .asid             (asid),
      .dmw0             (dmw0),
      .dmw1             (dmw1),
      .tlb_s_vppn       (tlb_s2_vppn),
      .tlb_s_va_bit12   (tlb_s2_va_bit12),
      .tlb_s_asid       (tlb_s2_asid),
      .tlb_s_result     (tlb_s2_result),

      .va          (d2_va),
      .pa          (d2_pa),
      .mat         (d2_mat),
      .page_fault  (d2_page_fault),
      .page_invalid(d2_page_invalid),
      .page_dirty  (d2_page_dirty),
      .plv_fault   (d2_plv_fault)
  );

  assign d2_tlbr = d2_page_fault;
  assign d2_pil = d2_page_invalid && !d2_we;
  assign d2_pis = d2_page_invalid && d2_we;
  assign d2_ppi = d2_plv_fault;
  assign d2_pme = d2_page_dirty && d2_we;

  assign tlbsrch_found = tlbsrch_valid && tlb_s1_result.found;
  assign tlbsrch_index = !d1_req ? tlb_s1_result.index : tlb_s2_result.index;

//   tlb tlb_0 (
//       .clk  (clk),
//       .reset(reset),

//       .s0_vppn    (tlb_s0_vppn),
//       .s0_va_bit12(tlb_s0_va_bit12),
//       .s0_asid    (tlb_s0_asid),
//       .s0_result  (tlb_s0_result),

//       .s1_vppn    (tlbsrch_valid ? tlbsrch_vppn : tlb_s1_vppn),
//       .s1_va_bit12(tlb_s1_va_bit12),
//       .s1_asid    (tlb_s1_asid),
//       .s1_result  (tlb_s1_result),

//       .s2_vppn    (tlb_s2_vppn),
//       .s2_va_bit12(tlb_s2_va_bit12),
//       .s2_asid    (tlb_s2_asid),
//       .s2_result  (tlb_s2_result),

//       .invtlb_valid(invtlb_valid),
//       .invtlb_op   (invtlb_op),
//       .invtlb_asid (invtlb_asid),
//       .invtlb_va   (invtlb_va),

//       .we     (tlb_we),
//       .w_index(tlb_w_index),
//       .w_entry(tlb_w_entry),
//       .r_index(tlb_r_index),
//       .r_entry(tlb_r_entry)
//   );

  assign icache_req = i_req;
  assign icache_addr = i_pa;
  assign icache_uncached = i_mat == 2'd0;
  assign i_addr_ok = icache_addr_ok;
  assign i_double = i_mat == 2'd1 && i_va[`OFFSET_WIDTH-1:2] != {(`OFFSET_WIDTH - 2) {1'b1}};
  assign i_data_ok = icache_data_ok;
  assign i_rdata = icache_rdata;

  assign dcache_req = d1_req;
  assign dcache_wr = d1_we;
  assign dcache_size = d1_size;
  assign dcache_wstrb = d1_wstrb;
  assign dcache_addr = d1_pa;
  assign dcache_wdata = d1_wdata;
  assign dcache_uncached = d1_mat == 2'd0;
  assign d1_addr_ok = dcache_addr_ok;
  assign d1_data_ok = dcache_data_ok;
  assign d1_rdata = dcache_rdata;

  assign d2_addr_ok = 1'b0;
  assign d2_data_ok = 1'b0;
  assign d2_rdata = 32'h0;

endmodule
