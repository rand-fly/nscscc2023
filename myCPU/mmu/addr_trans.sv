`include "../definitions.svh"

module addr_trans (
    input             direct_access,
    input       [1:0] direct_access_mat,
    input       [1:0] plv,
    input       [9:0] asid,
    input dmw_t       dmw0,
    input dmw_t       dmw1,

    output logic               use_tlb,
    output              [18:0] tlb_s_vppn,
    output                     tlb_s_va_bit12,
    output              [ 9:0] tlb_s_asid,
    input  tlb_result_t        tlb_s_result,

    input        [19:0] vtag,
    output logic [19:0] ptag,
    output logic [ 1:0] mat,
    output              page_fault,
    output              page_invalid,
    output              page_dirty,
    output              plv_fault
);


  always_comb begin
    if (direct_access) begin
      ptag = vtag;
      mat = direct_access_mat;
      use_tlb = 1'b0;
    end else if (vtag[19:17] == dmw0.vseg && (plv == 2'd0 && dmw0.plv0 || plv == 2'd3 && dmw0.plv3)) begin
      ptag = {dmw0.pseg, vtag[16:0]};
      mat = dmw0.mat;
      use_tlb = 1'b0;
    end else if (vtag[19:17] == dmw1.vseg && (plv == 2'd0 && dmw1.plv0 || plv == 2'd3 && dmw1.plv3)) begin
      ptag = {dmw1.pseg, vtag[16:0]};
      mat = dmw1.mat;
      use_tlb = 1'b0;
    end else begin
      if (tlb_s_result.ps == 12) begin
        ptag = tlb_s_result.ppn;
      end else begin
        ptag = {tlb_s_result.ppn[19:9], vtag[8:0]};
      end
      mat = tlb_s_result.mat;
      use_tlb = 1'b1;
    end
  end

  assign tlb_s_vppn = vtag[19:1];
  assign tlb_s_va_bit12 = vtag[0];
  assign tlb_s_asid = asid;

  assign page_fault = use_tlb && !tlb_s_result.found;
  assign page_invalid = use_tlb && !tlb_s_result.v;
  assign page_dirty = use_tlb && tlb_s_result.d == 1'b0;
  assign plv_fault = use_tlb && plv > tlb_s_result.plv;

endmodule
