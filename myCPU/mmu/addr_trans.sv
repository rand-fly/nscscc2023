`include "definitions.svh"

module addr_trans(
    input wire               direct_access,
    input wire [1:0]         direct_access_mat,
    input wire [1:0]         plv,
    input wire [9:0]         asid,
    input wire dmw_t         dmw0,
    input wire dmw_t         dmw1,

    output logic [18:0]      tlb_s_vppn,
    output logic             tlb_s_va_bit12,
    output logic [9:0]       tlb_s_asid,
    input wire tlb_result_t  tlb_s_result,

    input wire [31:0]        va,
    output logic [31:0]      pa,
    output logic [1:0]       mat,
    output logic             page_fault,
    output logic             page_invalid,
    output logic             page_dirty,
    output logic             plv_fault
);

logic use_tlb;

always_comb begin
    if (direct_access) begin
        pa = va;
        mat = direct_access_mat;
        use_tlb = 1'b0;
    end
    else if (va[31:29] == dmw0.vseg && (plv == 2'd0 && dmw0.plv0 || plv == 2'd3 && dmw0.plv3)) begin
        pa = {dmw0.pseg, va[28:0]};
        mat = dmw0.mat;
        use_tlb = 1'b0;
    end
    else if (va[31:29] == dmw1.vseg && (plv == 2'd0 && dmw1.plv0 || plv == 2'd3 && dmw1.plv3)) begin
        pa = {dmw1.pseg, va[28:0]};
        mat = dmw1.mat;
        use_tlb = 1'b0;
    end
    else begin
        // only 4KB
        pa = {tlb_s_result.ppn, va[11:0]};
        mat = tlb_s_result.mat;
        use_tlb = 1'b1;
    end
end

assign tlb_s_vppn = va[31:13];
assign tlb_s_va_bit12 = va[12];
assign tlb_s_asid = asid;

assign page_fault = use_tlb && !tlb_s_result.found;
assign page_invalid = use_tlb && !tlb_s_result.v;
assign page_dirty = use_tlb && tlb_s_result.d == 1'b0;
assign plv_fault = use_tlb && plv > tlb_s_result.plv;

endmodule