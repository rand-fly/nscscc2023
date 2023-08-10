`include "../definitions.svh"

module mmu (
    input                clk,
    input                reset,
    // from csr
    input                da,
    input         [ 1:0] datf,
    input         [ 1:0] datm,
    input         [ 1:0] plv,
    input         [ 9:0] asid,
    input  dmw_t         dmw0,
    input  dmw_t         dmw1,
    // from ifu
    input                i_req,
    input         [31:0] i_va,
    // to ifu
    output               i_addr_ok,
    output               i_double,
    output               i_data_ok,
    output        [63:0] i_rdata,
    output               i_tlbr,
    output               i_pif,
    output               i_ppi,
    input                d_cancel,
    input                d1_cancel,
    // from lsu a
    input                d0_req,
    input         [31:0] d0_va,            // 同时用于cacop
    input                d0_we,
    input         [ 1:0] d0_size,
    input         [ 3:0] d0_wstrb,
    input         [31:0] d0_wdata,
    // to lsu a
    output               d0_addr_ok,
    output               d0_data_ok,
    output        [31:0] d0_rdata,
    output               d0_tlbr,
    output               d0_pil,
    output               d0_pis,
    output               d0_ppi,
    output               d0_pme,
    // from lsu b
    input                d1_req,
    input         [31:0] d1_va,
    input                d1_we,
    input         [ 1:0] d1_size,
    input         [ 3:0] d1_wstrb,
    input         [31:0] d1_wdata,
    // to lsu b
    output               d1_addr_ok,
    output               d1_data_ok,
    output        [31:0] d1_rdata,
    output               d1_tlbr,
    output               d1_pil,
    output               d1_pis,
    output               d1_ppi,
    output               d1_pme,
    // from ex1
    input                invtlb_valid,
    input         [ 4:0] invtlb_op,
    input         [ 9:0] invtlb_asid,
    input         [31:0] invtlb_va,
    input                tlb_we,
    input                icacop_en,
    input                dcacop_en,
    input         [ 1:0] cacop_op,
    output               cacop_ok,
    output               cacop_have_excp,
    output excp_t        cacop_excp_type,

    // from csr
    input              [TLBIDLEN-1:0] tlb_w_index,
    input  tlb_entry_t                tlb_w_entry,
    input              [TLBIDLEN-1:0] tlb_r_index,
    output tlb_entry_t                tlb_r_entry,

    input                 tlbsrch_valid,
    input  [        18:0] tlbsrch_vppn,
    output                tlbsrch_found,
    output [TLBIDLEN-1:0] tlbsrch_index,

    // to and from icache
    output                     icache_req,
    output [              2:0] icache_op,
    output [             31:0] icache_addr,
    output                     icache_uncached,
    input                      icache_addr_ok,
    input                      icache_data_ok,
    input  [             63:0] icache_rdata,
    // to and from dcache
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
    input  [             31:0] dcache_p1_rdata
);

  logic        [`TAG_WIDTH-1:0] i_vtag;
  logic        [`TAG_WIDTH-1:0] i_ptag;
  logic        [          31:0] i_pa;
  logic        [           1:0] i_mat;
  logic                         i_page_fault;
  logic                         i_page_invalid;
  logic                         i_page_dirty;
  logic                         i_plv_fault;

  logic        [`TAG_WIDTH-1:0] d_vtag;
  logic        [`TAG_WIDTH-1:0] d_ptag;

  logic        [           1:0] d_mat;
  logic                         d_page_fault;
  logic                         d_page_invalid;
  logic                         d_page_dirty;
  logic                         d_plv_fault;

  logic        [          18:0] tlb_s0_vppn;
  logic                         tlb_s0_va_bit12;
  logic        [           9:0] tlb_s0_asid;
  tlb_result_t                  tlb_s0_result;

  logic        [          18:0] tlb_s1_vppn;
  logic                         tlb_s1_va_bit12;
  logic        [           9:0] tlb_s1_asid;
  tlb_result_t                  tlb_s1_result;

  logic                         d1_only;
  logic                         d1_only_reg;
  logic                         d0_req_reg;
  logic                         d1_req_reg;
  logic                         conflict;

  assign i_vtag = i_va[31:31-`TAG_WIDTH+1];
  assign i_pa   = {i_ptag, i_va[31-`TAG_WIDTH:0]};

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

      .vtag        (i_vtag),
      .ptag        (i_ptag),
      .mat         (i_mat),
      .page_fault  (i_page_fault),
      .page_invalid(i_page_invalid),
      .page_dirty  (i_page_dirty),
      .plv_fault   (i_plv_fault)
  );

  assign i_tlbr = i_page_fault;
  assign i_pif  = i_page_invalid;
  assign i_ppi  = i_plv_fault;


  assign d_vtag = d1_only ? d1_va[31:31-`TAG_WIDTH+1] : d0_va[31:31-`TAG_WIDTH+1];

  addr_trans addr_trans_d (
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

      .vtag        (d_vtag),
      .ptag        (d_ptag),
      .mat         (d_mat),
      .page_fault  (d_page_fault),
      .page_invalid(d_page_invalid),
      .page_dirty  (d_page_dirty),
      .plv_fault   (d_plv_fault)
  );

  assign d0_tlbr = d0_req && d_page_fault;
  assign d0_pil = d0_req && d_page_invalid && !d0_we;
  assign d0_pis = d0_req && d_page_invalid && d0_we;
  assign d0_ppi = d0_req && d_plv_fault;
  assign d0_pme = d0_req && d_page_dirty && d0_we;

  assign d1_tlbr = d1_req && d_page_fault;
  assign d1_pil = d1_req && d_page_invalid && !d1_we;
  assign d1_pis = d1_req && d_page_invalid && d1_we;
  assign d1_ppi = d1_req && d_plv_fault;
  assign d1_pme = d1_req && d_page_dirty && d1_we;


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

  assign icache_req = i_req || icacop_en && !cacop_have_excp;
  assign icache_op = icacop_en ? {1'b1, cacop_op} : 3'd0;
  assign icache_addr = icacop_en ? d0_va : i_pa;
  assign icache_uncached = i_mat == 2'd0;
  assign i_addr_ok = !icacop_en && icache_addr_ok;
  assign i_double = i_mat == 2'd1 && i_va[`OFFSET_WIDTH-1:2] != {(`OFFSET_WIDTH - 2) {1'b1}};
  assign i_data_ok = icache_data_ok;
  assign i_rdata = icache_rdata;

  assign d1_only = !d0_req && d1_req;
  assign conflict = d0_req && (dcache_uncached || d0_va[31:`OFFSET_WIDTH] != d1_va[31:`OFFSET_WIDTH]);

  always @(posedge clk) begin
    if (reset) begin
      d1_only_reg <= 1'b0;
      d0_req_reg  <= 1'b0;
      d1_req_reg  <= 1'b0;
    end else if (dcache_addr_ok) begin
      d1_only_reg <= d1_only;
      d0_req_reg  <= d0_req;
      d1_req_reg  <= d1_req && !conflict;
    end
  end

  assign dcache_p0_valid = (d1_only ? d1_req : d0_req) && !d_cancel || dcacop_en && !cacop_have_excp;
  assign dcache_p1_valid = (d1_req && !d1_only && !conflict) && !d_cancel && !d1_cancel;
  assign dcache_op = dcacop_en ? {1'b1, cacop_op} : d1_only ? {2'd0, d1_we} : {2'd0, d0_we};
  assign dcache_tag = d_ptag;
  assign dcache_index = d1_only ? d1_va[31-`TAG_WIDTH:31-`TAG_WIDTH-`INDEX_WIDTH+1] : d0_va[31-`TAG_WIDTH:31-`TAG_WIDTH-`INDEX_WIDTH+1];
  assign dcache_p0_offset = d1_only ? d1_va[`OFFSET_WIDTH-1:0] : d0_va[`OFFSET_WIDTH-1:0];
  assign dcache_p1_offset = d1_va[`OFFSET_WIDTH-1:0];
  assign dcache_p0_wstrb = d1_only ? d1_wstrb : d0_wstrb;
  assign dcache_p1_wstrb = d1_wstrb;
  assign dcache_p0_wdata = d1_only ? d1_wdata : d0_wdata;
  assign dcache_p1_wdata = d1_wdata;
  assign dcache_uncached = d_mat == 2'd0;
  assign dcache_p0_size = d1_only ? d1_size : d0_size;
  assign dcache_p1_size = d1_size;

  assign d0_addr_ok = d0_req && dcache_addr_ok;
  assign d0_data_ok = d0_req_reg && dcache_data_ok;
  assign d0_rdata = dcache_p0_rdata;

  assign d1_addr_ok = d1_req && !conflict && dcache_addr_ok;
  assign d1_data_ok = d1_req_reg && dcache_data_ok;
  assign d1_rdata = d1_only_reg ? dcache_p0_rdata : dcache_p0_rdata;

  assign cacop_ok = (icacop_en && icache_addr_ok) || (dcacop_en && dcache_addr_ok);
  assign cacop_have_excp = (icacop_en || dcacop_en) && cacop_op == 2 && (d_page_fault || d_page_invalid);
  assign cacop_excp_type = d_page_fault ? D_TLBR : PIL;

endmodule
