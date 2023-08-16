`include "../definitions.svh"

module mmu (
    input                         clk,
    input                         reset,
    // from csr
    input                         da,
    input        [           1:0] datf,
    input        [           1:0] datm,
    input        [           1:0] plv,
    input        [           9:0] asid,
    input  dmw_t                  dmw0,
    input  dmw_t                  dmw1,
    // from ifu
    input                         i_valid,
    input        [`TAG_WIDTH-1:0] i_vtag,
    // to ifu
    output                        i_ok,
    output       [`TAG_WIDTH-1:0] i_ptag,
    output       [           1:0] i_mat,
    output                        i_page_fault,
    output                        i_page_invalid,
    output                        i_plv_fault,
    // from lsu
    input                         d_valid,
    input        [`TAG_WIDTH-1:0] d_vtag,
    // to lsu
    output                        d_ok,
    output       [`TAG_WIDTH-1:0] d_ptag,
    output       [           1:0] d_mat,
    output                        d_page_fault,
    output                        d_page_invalid,
    output                        d_page_dirty,
    output                        d_plv_fault,

    // from csr
    input                             tlb_we,
    input              [TLBIDLEN-1:0] tlb_w_index,
    input  tlb_entry_t                tlb_w_entry,
    input              [TLBIDLEN-1:0] tlb_r_index,
    output tlb_entry_t                tlb_r_entry,

    input                 tlbsrch_valid,
    input  [        18:0] tlbsrch_vppn,
    output                tlbsrch_ok,
    output                tlbsrch_found,
    output [TLBIDLEN-1:0] tlbsrch_index,

    input        invtlb_valid,
    input [ 4:0] invtlb_op,
    input [ 9:0] invtlb_asid,
    input [31:0] invtlb_va
);

  logic               i_use_tlb;
  logic               d_use_tlb;

  logic        [18:0] tlb_s0_vppn;
  logic               tlb_s0_va_bit12;
  logic        [ 9:0] tlb_s0_asid;
  tlb_result_t        tlb_s0_result;

  logic        [18:0] tlb_s1_vppn;
  logic               tlb_s1_va_bit12;
  logic        [ 9:0] tlb_s1_asid;
  tlb_result_t        tlb_s1_result;

  assign i_ok = i_valid;
  assign d_ok = d_valid;
  assign tlbsrch_ok = tlbsrch_valid;

  addr_trans addr_trans_i (
      .direct_access    (da),
      .direct_access_mat(datf),
      .plv              (plv),
      .asid             (asid),
      .dmw0             (dmw0),
      .dmw1             (dmw1),
      .use_tlb          (i_use_tlb),
      .tlb_s_vppn       (tlb_s0_vppn),
      .tlb_s_va_bit12   (tlb_s0_va_bit12),
      .tlb_s_asid       (tlb_s0_asid),
      .tlb_s_result     (tlb_s0_result),

      .vtag        (i_vtag),
      .ptag        (i_ptag),
      .mat         (i_mat),
      .page_fault  (i_page_fault),
      .page_invalid(i_page_invalid),
      .page_dirty  (),
      .plv_fault   (i_plv_fault)
  );

  addr_trans addr_trans_d (
      .direct_access    (da),
      .direct_access_mat(datm),
      .plv              (plv),
      .asid             (asid),
      .dmw0             (dmw0),
      .dmw1             (dmw1),
      .use_tlb          (d_use_tlb),
      .tlb_s_vppn       (tlb_s1_vppn),
      .tlb_s_va_bit12   (tlb_s1_va_bit12),
      .tlb_s_asid       (tlb_s1_asid),
      .tlb_s_result     (tlb_s1_result),

      .vtag        (d_vtag),
      .ptag        (d_ptag),
      .mat         (d_mat),
      .page_fault  (d_page_fault),
      .page_invalid(d_page_invalid),
      .page_dirty  (d_page_dirty),
      .plv_fault   (d_plv_fault)
  );

  assign tlbsrch_found = tlbsrch_valid && tlb_s1_result.found;
  assign tlbsrch_index = tlb_s1_result.index;

  tlb u_tlb (
      .clk  (clk),
      .reset(reset),

      .s0_vppn    (tlb_s0_vppn),
      .s0_va_bit12(tlb_s0_va_bit12),
      .s0_asid    (tlb_s0_asid),
      .s0_result  (tlb_s0_result),

      .s1_vppn    (tlbsrch_valid ? tlbsrch_vppn : tlb_s1_vppn),
      .s1_va_bit12(tlb_s1_va_bit12),
      .s1_asid    (tlb_s1_asid),
      .s1_result  (tlb_s1_result),

      .invtlb_valid(invtlb_valid),
      .invtlb_op   (invtlb_op),
      .invtlb_asid (invtlb_asid),
      .invtlb_va   (invtlb_va),

      .we     (tlb_we),
      .w_index(tlb_w_index),
      .w_entry(tlb_w_entry),
      .r_index(tlb_r_index),
      .r_entry(tlb_r_entry)
  );

endmodule
