`include "definitions.svh"
module tlb
(
    input  wire                      clk,

    // search port 
    input  wire 					 s_valid,
    input  wire [              18:0] s_vppn,
    input  wire 					 s_va_bit12,
    input  wire [               9:0] s_asid,
    output tlb_result_t              s_result,
    // invtlb opcode
    input  wire                      invtlb_valid,
    input  wire [               4:0] invtlb_op,
    input  wire [              18:0] invtlb_vppn,
    input  wire [               9:0] invtlb_asid,

    // write port
    input  wire                      we,     //w(rite) e(nable)
    input  wire [$clog2(TLBNUM)-1:0] w_index,
    input  tlb_entry_t               w_entry,

    // read port
    input  wire [$clog2(TLBNUM)-1:0] r_index,
    output tlb_entry_t               r_entry
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
wire [TLBNUM-1:0] match_vppn			   ;
wire [TLBNUM-1:0] match_asid               ;
wire [TLBNUM-1:0] match                    ;




genvar i;

//select tlb
generate
    for(i = 0; i < TLBNUM; i = i + 1)
    begin
    	assign match_vppn[i] = tlb_ps4MB[i] ? s_vppn[18:9] == tlb_vppn[i][18:9]: s_vppn == tlb_vppn[i];
    	assign match_asid[i] = s_asid == tlb_asid[i];
        assign match[i] = tlb_e[i]?
        	 match_vppn[i] && (match_asid[i] || tlb_g[i]):
        	0;
    end
endgenerate


assign s_result.found = |match;
  
integer j;
always_comb begin
	for(j = 0; j < TLBNUM; j = j + 1) begin
	    if(match[j] == 1) begin
    		//decode to index
	    	s_result.index = j;
        end
    end
end
//s.x = is odd page(4M ? 8th bit: -1bit)? x1 : x0
assign s_result.ps =   tlb_ps4MB[s_result.index] ? 21 : 12;
assign s_result.ppn =  (tlb_ps4MB[s_result.index] ? s_vppn[8]: s_va_bit12)? tlb_ppn1[s_result.index]:  tlb_ppn0[s_result.index];
assign s_result.plv =  (tlb_ps4MB[s_result.index] ? s_vppn[8]: s_va_bit12)? tlb_plv1[s_result.index]:  tlb_plv0[s_result.index];
assign s_result.mat =  (tlb_ps4MB[s_result.index] ? s_vppn[8]: s_va_bit12)? tlb_mat1[s_result.index]:  tlb_mat0[s_result.index];
assign s_result.d =    (tlb_ps4MB[s_result.index] ? s_vppn[8]: s_va_bit12)? tlb_d1[s_result.index]:    tlb_d1[s_result.index];
assign s_result.v =    (tlb_ps4MB[s_result.index] ? s_vppn[8]: s_va_bit12)? tlb_v1[s_result.index]:    tlb_v1[s_result.index];

//end select tlb

//invtlb

wire tlb_clr = 				invtlb_op == 5'h0 || invtlb_op == 5'h1;
wire tlb_clr_g1 =			invtlb_op == 5'h2;
wire tlb_clr_g0 =			invtlb_op == 5'h3;
wire tlb_clr_g0_asid =		invtlb_op == 5'h4;
wire tlb_clr_g0_asid_vpn =	invtlb_op == 5'h5;
wire tlb_clr_g1_asid_vpn =	invtlb_op == 5'h6;


generate
	for(i = 0; i < TLBNUM; i = i + 1)
		begin:write_invtlb
			always @(posedge clk) begin
			    if(we && w_index == i) begin
					tlb_e[i] = w_entry.e;
					tlb_vppn[i] = w_entry.vppn;
					tlb_ps4MB[i] = w_entry.ps == 12 ? 0 : 1;//21(else)->4MB, 12->4KB
					tlb_asid[i] = w_entry.asid;
					tlb_g[i] = w_entry.g;
					tlb_ppn0[i] = w_entry.ppn0;
					tlb_plv0[i] = w_entry.plv0;
					tlb_mat0[i] = w_entry.mat0;
					tlb_d0[i] = w_entry.d0;
					tlb_v0[i] = w_entry.v0;
					tlb_ppn1[i] = w_entry.ppn1;
					tlb_plv1[i] = w_entry.plv1;
					tlb_mat1[i] = w_entry.mat1;
					tlb_d1[i] = w_entry.d1;
					tlb_v1[i] = w_entry.v1;
				end
				else if(invtlb_valid) begin
					if(
						(tlb_clr) ||
						(tlb_clr_g1 && tlb_g[i] == 1)||
						(tlb_clr_g0 && tlb_g[i] == 0)||
						(tlb_clr_g0_asid && tlb_g[i] == 0 && tlb_asid[i] == s_asid)||
						(
							tlb_clr_g0_asid_vpn && 
							tlb_g[i] == 0 && tlb_asid[i] == s_asid && 
							(tlb_ps4MB[i] ? s_vppn[18:9] == tlb_vppn[i][18:9]: s_vppn == tlb_vppn[i])//vppn match
						) || 
						(
							tlb_clr_g1_asid_vpn && 
							(tlb_g[i] == 1 || tlb_asid[i] == s_asid) && 
							(tlb_ps4MB[i] ? s_vppn[18:9] == tlb_vppn[i][18:9]: s_vppn == tlb_vppn[i])
						)
					) begin
						tlb_e[i] <= 0;
					end
				end
			end	
		end
endgenerate
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


