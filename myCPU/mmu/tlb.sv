`include "../definitions.svh"

module tlb
(
    input  wire                clk,
    input  wire                reset,

    // search port 0 (for fetch)
    input  wire [        18:0] s0_vppn,
    input  wire                s0_va_bit12,
    input  wire [         9:0] s0_asid,
    output tlb_result_t        s0_result,

    // search port 1 (for load/store)
    input  wire [        18:0] s1_vppn,
    input  wire                s1_va_bit12,
    input  wire [         9:0] s1_asid,
    output tlb_result_t        s1_result,

    // search port 2
    input  wire [        18:0] s2_vppn,
    input  wire                s2_va_bit12,
    input  wire [         9:0] s2_asid,
    output tlb_result_t        s2_result,

    // invtlb opcode
    input  wire                invtlb_valid,
    input  wire [         4:0] invtlb_op,
    input  wire [         9:0] invtlb_asid,
    input  wire [        31:0] invtlb_va,

    // write port
    input  wire                we,     //w(rite) e(nable)
    input  wire [TLBIDLEN-1:0] w_index,
    input  tlb_entry_t         w_entry,

    // read port
    input  wire [TLBIDLEN-1:0] r_index,
    output tlb_entry_t         r_entry
);

reg  [TLBNUM-1:0] tlb_e;
reg  [TLBNUM-1:0] tlb_ps4MB; //pagesize 1:4MB, 0:4KB
reg  [      18:0] tlb_vppn     [TLBNUM-1:0];
reg  [       9:0] tlb_asid     [TLBNUM-1:0];
reg               tlb_g        [TLBNUM-1:0];
reg  [      19:0] tlb_ppn0     [TLBNUM-1:0];
reg  [       1:0] tlb_plv0     [TLBNUM-1:0];
reg  [       1:0] tlb_mat0     [TLBNUM-1:0];
reg               tlb_d0       [TLBNUM-1:0];
reg               tlb_v0       [TLBNUM-1:0];
reg  [      19:0] tlb_ppn1     [TLBNUM-1:0];
reg  [       1:0] tlb_plv1     [TLBNUM-1:0];
reg  [       1:0] tlb_mat1     [TLBNUM-1:0];
reg               tlb_d1       [TLBNUM-1:0];
reg               tlb_v1       [TLBNUM-1:0];


reg [TLBIDLEN-1:0] match_id0;
reg [TLBIDLEN-1:0] match_id1;
reg [TLBIDLEN-1:0] match_id2;

wire [TLBNUM-1:0] match0;
wire [TLBNUM-1:0] match_vppn0;
wire [TLBNUM-1:0] match_asid0;
wire [TLBNUM-1:0] match1;
wire [TLBNUM-1:0] match_vppn1;
wire [TLBNUM-1:0] match_asid1;
wire [TLBNUM-1:0] match2;
wire [TLBNUM-1:0] match_vppn2;
wire [TLBNUM-1:0] match_asid2;

logic [TLBIDLEN-1:0] match_id_sel0 [TLBNUM-1:0];
logic [TLBIDLEN-1:0] match_id_sel1 [TLBNUM-1:0];
logic [TLBIDLEN-1:0] match_id_sel2 [TLBNUM-1:0];

genvar i;

//select tlb
generate
    for(i = 0; i < TLBNUM; i = i + 1)
    begin: match
        assign match_vppn0[i] = tlb_ps4MB[i] ? s0_vppn[18:9] == tlb_vppn[i][18:9]: s0_vppn == tlb_vppn[i];
        assign match_asid0[i] = s0_asid == tlb_asid[i];
        assign match0[i] = tlb_e[i] && match_vppn0[i] && (match_asid0[i] || tlb_g[i]);
        assign match_id_sel0[i] = match0[i] ? i : 0;

        assign match_vppn1[i] = tlb_ps4MB[i] ? s1_vppn[18:9] == tlb_vppn[i][18:9]: s1_vppn == tlb_vppn[i];
        assign match_asid1[i] = s1_asid == tlb_asid[i];
        assign match1[i] = tlb_e[i] && match_vppn1[i] && (match_asid1[i] || tlb_g[i]);
        assign match_id_sel1[i] = match1[i] ? i : 0;

        assign match_vppn2[i] = tlb_ps4MB[i] ? s2_vppn[18:9] == tlb_vppn[i][18:9]: s2_vppn == tlb_vppn[i];
        assign match_asid2[i] = s2_asid == tlb_asid[i];
        assign match2[i] = tlb_e[i] && match_vppn2[i] && (match_asid2[i] || tlb_g[i]);
        assign match_id_sel2[i] = match2[i] ? i : 0;
    end
endgenerate

always_comb begin
    integer j;
    match_id0 = 0;
    match_id1 = 0;
    match_id2 = 0;
    for(j = 0; j < TLBNUM; j = j + 1) begin
        match_id0 |= match_id_sel0[j];
        match_id1 |= match_id_sel1[j];
        match_id2 |= match_id_sel2[j];
    end
end

assign s0_result.index = match_id0;
assign s1_result.index = match_id1;
assign s2_result.index = match_id2;

assign s0_result.found = match0 != 0;
assign s1_result.found = match1 != 0;
assign s2_result.found = match2 != 0;

always_comb begin
    logic [TLBIDLEN-1:0] j;
    j = match_id0;
    if((tlb_ps4MB[j] == 0 && s0_va_bit12 == 0) || (tlb_ps4MB[j] == 1 && s0_vppn[8] == 0))begin
        s0_result.ppn = tlb_ppn0[j];
        s0_result.ps = tlb_ps4MB[j] ? 21 : 12;
        s0_result.plv = tlb_plv0[j];
        s0_result.mat = tlb_mat0[j];
        s0_result.d = tlb_d0[j];
        s0_result.v = tlb_v0[j];
    end
    else begin
        s0_result.ppn = tlb_ppn1[j];
        s0_result.ps = tlb_ps4MB[j] ? 21 : 12;
        s0_result.plv = tlb_plv1[j];
        s0_result.mat = tlb_mat1[j];
        s0_result.d = tlb_d1[j];
        s0_result.v = tlb_v1[j];
    end
    
    j = match_id1;
    if((tlb_ps4MB[j] == 0 && s1_va_bit12 == 0) || (tlb_ps4MB[j] == 1 && s1_vppn[8] == 0))begin
        s1_result.ppn = tlb_ppn0[j];
        s1_result.ps = tlb_ps4MB[j] ? 21 : 12;
        s1_result.plv = tlb_plv0[j];
        s1_result.mat = tlb_mat0[j];
        s1_result.d = tlb_d0[j];
        s1_result.v = tlb_v0[j];
    end
    else begin
        s1_result.ppn = tlb_ppn1[j];
        s1_result.ps = tlb_ps4MB[j] ? 21 : 12;
        s1_result.plv = tlb_plv1[j];
        s1_result.mat = tlb_mat1[j];
        s1_result.d = tlb_d1[j];
        s1_result.v = tlb_v1[j];
    end

    j = match_id2;
    if((tlb_ps4MB[j] == 0 && s2_va_bit12 == 0) || (tlb_ps4MB[j] == 1 && s2_vppn[8] == 0))begin
        s2_result.ppn = tlb_ppn0[j];
        s2_result.ps = tlb_ps4MB[j] ? 21 : 12;
        s2_result.plv = tlb_plv0[j];
        s2_result.mat = tlb_mat0[j];
        s2_result.d = tlb_d0[j];
        s2_result.v = tlb_v0[j];
    end
    else begin
        s2_result.ppn = tlb_ppn1[j];
        s2_result.ps = tlb_ps4MB[j] ? 21 : 12;
        s2_result.plv = tlb_plv1[j];
        s2_result.mat = tlb_mat1[j];
        s2_result.d = tlb_d1[j];
        s2_result.v = tlb_v1[j];
    end
end
//end select tlb

//invtlb
wire tlb_clr = 				invtlb_op == 5'h0 || invtlb_op == 5'h1;
wire tlb_clr_g1 =			invtlb_op == 5'h2;
wire tlb_clr_g0 =			invtlb_op == 5'h3;
wire tlb_clr_g0_asid =		invtlb_op == 5'h4;
wire tlb_clr_g0_asid_vpn =	invtlb_op == 5'h5;
wire tlb_clr_g1_asid_vpn =	invtlb_op == 5'h6;

wire [18:0] invtlb_vppn;
assign invtlb_vppn = invtlb_va[31:13];

always @(posedge clk) begin
    integer j;
    if(reset) begin
        for(j = 0; j < TLBNUM; j = j + 1) begin
            tlb_e[j] <= 0;
        end
    end
    else if(invtlb_valid) begin
        for(j = 0; j < TLBNUM; j = j + 1) begin
             if(tlb_e[j]) begin
                //for both 0 and 1
                if(
                    (tlb_clr) ||
                    (tlb_clr_g1 && tlb_g[j] == 1)||
                    (tlb_clr_g0 && tlb_g[j] == 0)||
                    (tlb_clr_g0_asid && tlb_g[j] == 0 && tlb_asid[j] == invtlb_asid)||
                    (
                        tlb_clr_g0_asid_vpn && 
                        tlb_g[j] == 0 && tlb_asid[j] == invtlb_asid && 
                        (tlb_ps4MB[j] ? invtlb_vppn[18:9] == tlb_vppn[j][18:9]: invtlb_vppn == tlb_vppn[j])//vppn match
                    ) || 
                    (
                        tlb_clr_g1_asid_vpn && 
                        (tlb_g[j] == 1 || tlb_asid[j] == invtlb_asid) && 
                        (tlb_ps4MB[j] ? invtlb_vppn[18:9] == tlb_vppn[j][18:9]: invtlb_vppn == tlb_vppn[j])
                    )
                ) begin
                    tlb_e[j] <= 0;
                end
            end
        end	
    end
    else if(we) begin
        tlb_e[w_index] <= w_entry.e;
        tlb_vppn[w_index] <= w_entry.vppn;
        tlb_ps4MB[w_index] <= w_entry.ps == 12 ? 0 : 1;//21(else)->4MB, 12->4KB
        tlb_asid[w_index] <= w_entry.asid;
        tlb_g[w_index] <= w_entry.g;
        tlb_ppn0[w_index] <= w_entry.ppn0;
        tlb_plv0[w_index] <= w_entry.plv0;
        tlb_mat0[w_index] <= w_entry.mat0;
        tlb_d0[w_index] <= w_entry.d0;
        tlb_v0[w_index] <= w_entry.v0;
        tlb_ppn1[w_index] <= w_entry.ppn1;
        tlb_plv1[w_index] <= w_entry.plv1;
        tlb_mat1[w_index] <= w_entry.mat1;
        tlb_d1[w_index] <= w_entry.d1;
        tlb_v1[w_index] <= w_entry.v1;
    end
end
//end invtlb

//read tlb
assign r_entry.e = tlb_e[r_index];
assign r_entry.vppn = tlb_vppn[r_index];
assign r_entry.ps = tlb_ps4MB[r_index] ? 21 : 12;
assign r_entry.asid = tlb_asid[r_index];
assign r_entry.g = tlb_g[r_index];
assign r_entry.ppn0 = tlb_ppn0[r_index];
assign r_entry.plv0 = tlb_plv0[r_index];
assign r_entry.mat0 = tlb_mat0[r_index];
assign r_entry.d0 = tlb_d0[r_index];
assign r_entry.v0 = tlb_v0[r_index];
assign r_entry.ppn1 = tlb_ppn1[r_index];
assign r_entry.plv1 = tlb_plv1[r_index];
assign r_entry.mat1 = tlb_mat1[r_index];
assign r_entry.d1 = tlb_d1[r_index];
assign r_entry.v1 = tlb_v1[r_index];
//end read tlb
endmodule

