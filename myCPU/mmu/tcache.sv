`include "../definitions.svh"

module tcache (
    input clk,
    input reset,

    // search port 0 (for fetch)
    input               [18:0] s_vppn,
    input                      s_va_bit12,
    input               [ 9:0] s_asid,
    output tlb_result_t        s_result,

    // invtlb opcode
    input invalid,

    //refill port
    input                            refill_valid,
    input tlb_entry_t                refill_data,
    input             [TLBIDLEN-1:0] refill_index

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
  //length of tlb_store_t = 84

  tlb_store_t data;
  logic [TLBIDLEN-1:0] index;

  wire match_4m = s_vppn[18:9] == data.vppn[18:9];
  wire match_4k = s_vppn == data.vppn;
  wire match_vppn = data.ps4MB ? match_4m : match_4k;
  wire match_asid = s_asid == data.asid;
  wire match = data.e && match_vppn && (match_asid || data.g);

  assign s_result.index = index;
  assign s_result.found = match;

  always_comb begin
    if ((data.ps4MB == 0 && s_va_bit12 == 0) || (data.ps4MB == 1 && s_vppn[8] == 0)) begin
      s_result.ppn = data.ppn0;
      s_result.ps  = data.ps4MB ? 21 : 12;
      s_result.plv = data.plv0;
      s_result.mat = data.mat0;
      s_result.d   = data.d0;
      s_result.v   = data.v0;
    end else begin
      s_result.ppn = data.ppn1;
      s_result.ps  = data.ps4MB ? 21 : 12;
      s_result.plv = data.plv1;
      s_result.mat = data.mat1;
      s_result.d   = data.d1;
      s_result.v   = data.v1;
    end

  end
  //end select tlb

  always_ff @(posedge clk) begin
    if (reset || invalid) begin
      data.e <= 0;
    end else if (refill_valid) begin
      index <= refill_index;
      data.e <= refill_data.e;
      data.vppn <= refill_data.vppn;
      data.ps4MB <= refill_data.ps == 12 ? 0 : 1;
      data.asid <= refill_data.asid;
      data.g <= refill_data.g;
      data.ppn0 <= refill_data.ppn0;
      data.plv0 <= refill_data.plv0;
      data.mat0 <= refill_data.mat0;
      data.d0 <= refill_data.d0;
      data.v0 <= refill_data.v0;
      data.ppn1 <= refill_data.ppn1;
      data.plv1 <= refill_data.plv1;
      data.mat1 <= refill_data.mat1;
      data.d1 <= refill_data.d1;
      data.v1 <= refill_data.v1;
    end
  end
endmodule
