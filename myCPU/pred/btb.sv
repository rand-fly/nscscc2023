module btb
#(
	parameter BTBNUM = 32,
	parameter BTBIDLEN = $clog2(BTBNUM),
	parameter BTBTAGLEN = 6,
	parameter BTBGROUP = 2,
	parameter RASNUM = 16,
	parameter RASIDLEN = $clog2(RASNUM)
)
(
	input             clk           ,
    input             reset         ,

    //from/to if
    input  	[31:0]     fetch_pc      ,
    output 	[31:0]     target_0      ,
    output 	[31:0]     target_1      ,
    output 	[BTBIDLEN-1:0]	index_0  ,	
    output 	[BTBIDLEN-1:0]	index_1  ,
    output             hit_0         ,
    output             hit_1         ,

    //update btb
    input             branch_mistaken  ,
    input	[BTBIDLEN-1:0]		  wrong_index	   ,
    input  	[31:0]     wrong_pc         ,
    input  	[31:0]     right_target     ,
    input             ins_type         ,
)
//storage
reg		[BTBNUM-1:0]	btb_valid	;
reg 	[BTBTAGLEN-1:0]	btb_tag		[BTBNUM-1:0];
reg 	[31:0]			btb_target	[BTBNUM-1:0];

//search
logic	[29:0]			pc_0_32to2;
logic	[29:0]			pc_1_32to2;
logic	[BTBGROUP-1:0]	btb_hit_0;
logic	[BTBGROUP-1:0]	btb_hit_1;		;
logic	[BTBIDLEN-1:0]	btb_group_num_0;
logic	[BTBIDLEN-1:0]	btb_group_num_1;
logic	[BTBTAGLEN-1:0]	btb_fetch_tag_0;
logic	[BTBTAGLEN-1:0]	btb_fetch_tag_1;
logic	[$clog2(BTBGROUP)-1,0]	btb_index_in_group_0;
logic	[$clog2(BTBGROUP)-1,0]	btb_index_in_group_1;


assign pc_0_32to2 = fetch_pc[31:2];
assign pc_1_32to2 = pc_0_32to2 + 1;

assign btb_group_num_0 = pc_0_32to2[$clog2(BTBNUM/BTBGROUP)-1:0];
assign btb_group_num_1 = pc_1_32to2[$clog2(BTBNUM/BTBGROUP)-1:0];

assign btb_fetch_tag_0 = pc_0_32to2[29:24]|pc_0_32to2[23:18]|pc_0_32to2[17:12]|pc_0_32to2[11:6]|pc_0_32to2[5:0];
assign btb_fetch_tag_1 = pc_1_32to2[29:24]|pc_1_32to2[23:18]|pc_1_32to2[17:12]|pc_1_32to2[11:6]|pc_1_32to2[5:0];

genvar i;
generate
	for(i = 0; i < BTBGROUP; i = i + 1)
	begin: BTB_match
		assign btb_hit_0[i] = btb_valid && btb_tag[btb_group_num_0 * BTBGROUP + i] == btb_fetch_tag_0;
		assign btb_hit_1[i] = btb_valid && btb_tag[btb_group_num_1 * BTBGROUP + i] == btb_fetch_tag_1;
	end
endgenerate
//calc index
integer j;
always_comb begin
	for(j = 0; j < BTBGROUP; j = j + 1) begin
		if(btb_hit_0[j]) begin
			btb_index_in_group_0 = j;
		end
		if(btb_hit_1[j]) begin
			btb_index_in_group_1 = j;
		end
	end
end
assign index_0 = {btb_group_num_0,btb_index_in_group_0};
assign index_1 = {btb_group_num_1,btb_index_in_group_1};


endmodule