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
    input        invtlb_valid,

    // write port
    input                            we,       //w(rite) e(nable)

    // read port
    // input              [`TCACHE_ID_LEN-1:0] r_index,
    // output tlb_entry_t                r_entry,
    // output                            r_hit,

    //refill port
    input                             refill_valid,
    input tlb_entry_t                 refill_data,
    input           [   TLBIDLEN-1:0] refill_index

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



  tlb_store_t                   data      [`TCACHE_NUM];
  reg                           valid     [`TCACHE_NUM];
  reg         [   TLBIDLEN-1:0] tlb_index [`TCACHE_NUM];
  reg         [            4:0] lru_cnt   [`TCACHE_NUM];


  `define write_data(index_, w_data_)\
    data[index_].e <= w_data_.e;\
    data[index_].vppn <= w_data_.vppn;\
    data[index_].ps4MB <= w_data_.ps == 12 ? 0 : 1;\
    data[index_].asid <= w_data_.asid;\
    data[index_].g <= w_data_.g;\
    data[index_].ppn0 <= w_data_.ppn0;\
    data[index_].plv0 <= w_data_.plv0;\
    data[index_].mat0 <= w_data_.mat0;\
    data[index_].d0 <= w_data_.d0;\
    data[index_].v0 <= w_data_.v0;\
    data[index_].ppn1 <= w_data_.ppn1;\
    data[index_].plv1 <= w_data_.plv1;\
    data[index_].mat1 <= w_data_.mat1;\
    data[index_].d1 <= w_data_.d1;\
    data[index_].v1 <= w_data_.v1\
  
  logic       [  `TCACHE_NUM-1:0] match;

  logic       [`TCACHE_ID_LEN-1:0] match_id_sel[`TCACHE_NUM];
  logic       [`TCACHE_ID_LEN-1:0] match_id;
  logic       [`TCACHE_ID_LEN-1:0] r_index;

  tlb_store_t                result_sel  [`TCACHE_NUM];

  //select tlb
  generate
    for (genvar i = 0; i < `TCACHE_NUM; i = i + 1) begin : gen_match0
      wire match_4m = s_vppn[18:9] == data[i].vppn[18:9];
      wire match_4k = s_vppn == data[i].vppn;
      wire match_vppn = data[i].ps4MB ? match_4m : match_4k;
      wire match_asid = s_asid == data[i].asid;
      assign match[i] = valid[i] && data[i].e && match_vppn && (match_asid || data[i].g);
      assign match_id_sel[i] = {`TCACHE_ID_LEN{match[i]}} & `TCACHE_ID_LEN'(i);
      assign result_sel[i] = {84{match[i]}} & data[i];
    end
  endgenerate

  `ifdef TCACHE_WAY_1
  assign r_index = 0;
  `endif
  `ifdef TCACHE_WAY_2
  assign r_index = lru_cnt[0] < lru_cnt[1];
  `endif
  `ifdef TCACHE_WAY_4
  always_comb begin
    if(lru_cnt[0] >= lru_cnt[1] && lru_cnt[0] >= lru_cnt[2] && lru_cnt[0] >= lru_cnt[3])
      r_index = 0;
    else if(lru_cnt[1] >= lru_cnt[0] && lru_cnt[1] >= lru_cnt[2] && lru_cnt[1] >= lru_cnt[3])
      r_index = 1;
    else if(lru_cnt[2] >= lru_cnt[0] && lru_cnt[2] >= lru_cnt[1] && lru_cnt[2] >= lru_cnt[3])
      r_index = 2;
    else if(lru_cnt[3] >= lru_cnt[0] && lru_cnt[3] >= lru_cnt[1] && lru_cnt[3] >= lru_cnt[2])
      r_index = 3;
    else
      r_index = 0;
  end
  `endif


  always_comb begin
    match_id = 0;
    for (int i = 0; i < `TCACHE_NUM; i = i + 1) begin
      match_id |= match_id_sel[i];
    end
  end

  assign s_result.index = tlb_index[match_id];
  assign s_result.found = |match;
  always_comb begin
    logic [`TCACHE_ID_LEN-1:0] i;
    i = match_id;
    if ((data[i].ps4MB == 0 && s_va_bit12 == 0) || (data[i].ps4MB == 1 && s_vppn[8] == 0)) begin
      s_result.ppn = data[i].ppn0;
      s_result.ps  = data[i].ps4MB ? 21 : 12;
      s_result.plv = data[i].plv0;
      s_result.mat = data[i].mat0;
      s_result.d   = data[i].d0;
      s_result.v   = data[i].v0;
    end else begin
      s_result.ppn = data[i].ppn1;
      s_result.ps  = data[i].ps4MB ? 21 : 12;
      s_result.plv = data[i].plv1;
      s_result.mat = data[i].mat1;
      s_result.d   = data[i].d1;
      s_result.v   = data[i].v1;
    end

  end
  //end select tlb

  always_ff @(posedge clk) begin
    //lru increase
    for(int i = 0; i < `TCACHE_NUM; i = i + 1) begin
      if (match[i] || (refill_valid && r_index == i)) begin
        lru_cnt[i] <= 0;
      end
      else begin
        lru_cnt[i] <= lru_cnt[i] + |(lru_cnt[i] ^ 5'b11111);
      end
    end
    if (reset || we || invtlb_valid) begin
      for (int i = 0; i < `TCACHE_NUM; i = i + 1) begin
        lru_cnt[i] <= 0;
        valid[i] <= 0;
      end
    end  else if (refill_valid) begin
      valid[r_index] <= 1;
      tlb_index[r_index] <= refill_index;
      `write_data(r_index, refill_data);
    end
  end
endmodule
