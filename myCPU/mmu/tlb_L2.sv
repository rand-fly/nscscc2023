`include "../definitions.svh"

module tlb_L2 (
    input clk,
    input reset,

    // search port 0 (for fetch)
    input               [18:0] s0_vppn,
    input               [ 9:0] s0_asid,
    output tlb_entry_t         s0_result,
    output                     s0_found,
    output      [TLBIDLEN-1:0] s0_index,

    // search port 1 (for load/store)
    input               [18:0] s1_vppn,
    input               [ 9:0] s1_asid,
    output tlb_entry_t         s1_result,
    output                     s1_found,
    output      [TLBIDLEN-1:0] s1_index,

    // invtlb opcode
    input        invtlb_valid,
    input [ 4:0] invtlb_op,
    input [ 9:0] invtlb_asid,
    input [31:0] invtlb_va,

    // write port
    input                            we,       //w(rite) e(nable)
    input             [TLBIDLEN-1:0] w_index,
    input tlb_entry_t                w_entry,

    // read port
    input              [TLBIDLEN-1:0] r_index,
    output tlb_entry_t                r_entry
);

  typedef struct packed {
    logic        e;
    logic        ps4MB;  //pagesize 1:4MB, 0:4KB
    logic [18:0] vppn;
    logic [9:0]  asid;
    logic        g;
    logic [19:0] ppn0;
    logic [1:0]  plv0;
    logic [1:0]  mat0;
    logic        d0;
    logic        v0;
    logic [19:0] ppn1;
    logic [1:0]  plv1;
    logic [1:0]  mat1;
    logic        d1;
    logic        v1;
  } tlb_store_t;

  tlb_store_t                data         [TLBNUM];

  logic       [  TLBNUM-1:0] match0;
  logic       [  TLBNUM-1:0] match1;
  reg         [  TLBNUM-1:0] match0_reg;
  reg         [  TLBNUM-1:0] match1_reg;

  
  logic       [TLBIDLEN-1:0] match_id_sel0[TLBNUM];
  logic       [TLBIDLEN-1:0] match_id_sel1[TLBNUM];
  logic       [TLBIDLEN-1:0] match_id0;
  logic       [TLBIDLEN-1:0] match_id1;
  

  tlb_store_t                result_sel0  [TLBNUM];
  tlb_store_t                result_sel1  [TLBNUM];
  tlb_store_t                result0;
  tlb_store_t                result1;

  //select tlb
  generate
    for (genvar i = 0; i < TLBNUM; i = i + 1) begin : gen_match0
      wire match_4m = s0_vppn[18:9] == data[i].vppn[18:9];
      wire match_4k = s0_vppn == data[i].vppn;
      wire match_vppn = data[i].ps4MB ? match_4m : match_4k;
      wire match_asid = s0_asid == data[i].asid;
      assign match0[i] = data[i].e && match_vppn && (match_asid || data[i].g);
      assign match_id_sel0[i] = {TLBIDLEN{match0_reg[i]}} & TLBIDLEN'(i);
      assign result_sel0[i] = {84{match0_reg[i]}} & data[i];
    end
  endgenerate

  generate
    for (genvar i = 0; i < TLBNUM; i = i + 1) begin : gen_match1
      wire match_4m = s1_vppn[18:9] == data[i].vppn[18:9];
      wire match_4k = s1_vppn == data[i].vppn;
      wire match_vppn = data[i].ps4MB ? match_4m : match_4k;
      wire match_asid = s1_asid == data[i].asid;
      assign match1[i] = data[i].e && match_vppn && (match_asid || data[i].g);
      assign match_id_sel1[i] = {TLBIDLEN{match1_reg[i]}} & TLBIDLEN'(i);
      assign result_sel1[i] = {84{match1_reg[i]}} & data[i];
    end
  endgenerate

  always_comb begin
    match_id0 = 0;
    match_id1 = 0;
    result0   = 0;
    result1   = 0;
    for (int i = 0; i < TLBNUM; i = i + 1) begin
      match_id0 |= match_id_sel0[i];
      match_id1 |= match_id_sel1[i];
      result0 |= result_sel0[i];
      result1 |= result_sel1[i];
    end
  end

  assign s0_index = match_id0;
  assign s1_index = match_id1;

  assign s0_found = |match0;
  assign s1_found = |match1;

  `define tlb_store_to_tlb_entry(store_, entry_)\
  assign entry_.e    = store_.e;\
  assign entry_.ps = store_.ps4MB ? 21 : 12;\
  assign entry_.vppn = store_.vppn;\
  assign entry_.asid = store_.asid;\
  assign entry_.g    = store_.g;\
  assign entry_.ppn0 = store_.ppn0;\
  assign entry_.plv0 = store_.plv0;\
  assign entry_.mat0 = store_.mat0;\
  assign entry_.d0   = store_.d0;\
  assign entry_.v0   = store_.v0;\
  assign entry_.ppn1 = store_.ppn1;\
  assign entry_.plv1 = store_.plv1;\
  assign entry_.mat1 = store_.mat1;\
  assign entry_.d1   = store_.d1;\
  assign entry_.v1   = store_.v1
  
  `tlb_store_to_tlb_entry(result0, s0_result);
  `tlb_store_to_tlb_entry(result1, s1_result);

  
  //end select tlb

  //invtlb
  wire        tlb_clr = invtlb_op == 5'h0 || invtlb_op == 5'h1;
  wire        tlb_clr_g1 = invtlb_op == 5'h2;
  wire        tlb_clr_g0 = invtlb_op == 5'h3;
  wire        tlb_clr_g0_asid = invtlb_op == 5'h4;
  wire        tlb_clr_g0_asid_vpn = invtlb_op == 5'h5;
  wire        tlb_clr_g1_asid_vpn = invtlb_op == 5'h6;
  wire [18:0] invtlb_vppn = invtlb_va[31:13];

  always_ff @(posedge clk) begin
    match0_reg <= match0;
    match1_reg <= match1;
    if (reset) begin
      for (int i = 0; i < TLBNUM; i = i + 1) begin 
        data[i].e <= 0;
      end
    end else if (invtlb_valid) begin
      for (int i = 0; i < TLBNUM; i = i + 1) begin
        if (data[i].e) begin
          if(
                (tlb_clr) ||
                (tlb_clr_g1 && data[i].g == 1)||
                (tlb_clr_g0 && data[i].g == 0)||
                (tlb_clr_g0_asid && data[i].g == 0 && data[i].asid == invtlb_asid)||
                (
                    tlb_clr_g0_asid_vpn &&
                    data[i].g == 0 && data[i].asid == invtlb_asid &&
                    (data[i].ps4MB ? invtlb_vppn[18:9] == data[i].vppn[18:9]: invtlb_vppn == data[i].vppn)
                ) ||
                (
                    tlb_clr_g1_asid_vpn &&
                    (data[i].g == 1 || data[i].asid == invtlb_asid) &&
                    (data[i].ps4MB ? invtlb_vppn[18:9] == data[i].vppn[18:9]: invtlb_vppn == data[i].vppn)
                )
            ) begin
            data[i].e <= 0;
          end
        end
      end
    end else if (we) begin
      data[w_index].e <= w_entry.e;
      data[w_index].vppn <= w_entry.vppn;
      data[w_index].ps4MB <= w_entry.ps == 12 ? 0 : 1;  //21(else)->4MB, 12->4KB
      data[w_index].asid <= w_entry.asid;
      data[w_index].g <= w_entry.g;
      data[w_index].ppn0 <= w_entry.ppn0;
      data[w_index].plv0 <= w_entry.plv0;
      data[w_index].mat0 <= w_entry.mat0;
      data[w_index].d0 <= w_entry.d0;
      data[w_index].v0 <= w_entry.v0;
      data[w_index].ppn1 <= w_entry.ppn1;
      data[w_index].plv1 <= w_entry.plv1;
      data[w_index].mat1 <= w_entry.mat1;
      data[w_index].d1 <= w_entry.d1;
      data[w_index].v1 <= w_entry.v1;
    end
  end
  //end invtlb

  //read tlb
  assign r_entry.e = data[r_index].e;
  assign r_entry.vppn = data[r_index].vppn;
  assign r_entry.ps = data[r_index].ps4MB ? 21 : 12;
  assign r_entry.asid = data[r_index].asid;
  assign r_entry.g = data[r_index].g;
  assign r_entry.ppn0 = data[r_index].ppn0;
  assign r_entry.plv0 = data[r_index].plv0;
  assign r_entry.mat0 = data[r_index].mat0;
  assign r_entry.d0 = data[r_index].d0;
  assign r_entry.v0 = data[r_index].v0;
  assign r_entry.ppn1 = data[r_index].ppn1;
  assign r_entry.plv1 = data[r_index].plv1;
  assign r_entry.mat1 = data[r_index].mat1;
  assign r_entry.d1 = data[r_index].d1;
  assign r_entry.v1 = data[r_index].v1;
  //end read tlb
endmodule
