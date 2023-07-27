module btb
#(
	parameter BTBNUM = 32,
	parameter BTBIDLEN = $clog2(BTBNUM),
	parameter BTBTAGLEN = 6,
	parameter BTBGROUP = 2
)
(
	input             clk           ,
    input             reset         ,

    //from/to if
    input  	[31:0]    fetch_pc_0     	,
    input  	[31:0]    fetch_pc_1    	,
    output	[31:0]	  target_pc_0		,
    output	[31:0]	  target_pc_1		,
    output 	[2:0]	  ins_type_0		,
    output 	[2:0]	  ins_type_1		,

    //update btb
    input             branch_mistaken  ,
    input	[2:0]		  ins_type_w	   ,
    input  	[31:0]    wrong_pc         ,
    input  	[31:0]    right_target     
);

logic 	[BTBIDLEN-1:0]	index_0  ;	
logic 	[BTBIDLEN-1:0]	index_1  ;
logic  	[BTBIDLEN-1:0]  index_w  ;
logic  	[BTBIDLEN-1:0]  index_inv;
logic  	[BTBIDLEN-1:0]  index_replace;
logic            		hit_0    ;
logic            	 	hit_1    ;
logic             		hit_w    ;
logic             		hit_inv  ;
logic 	[31:0]     		target_0 ;
logic 	[31:0]     		target_1 ;

//storage
reg     [BTBNUM-1:0]    btb_valid;
reg     [BTBTAGLEN-1:0] btb_tag     [BTBNUM-1:0];
reg     [31:0]          btb_target  [BTBNUM-1:0];
reg     [2:0]			btb_ins_type[BTBNUM-1:0];
reg   	[$clog2(BTBGROUP)-1:0]	btb_replace_counter	[BTBNUM/BTBGROUP -1:0] ;   

//search
logic   [29:0]          pc_0_32to2;
logic   [29:0]          pc_1_32to2;
logic   [29:0]          pc_w_32to2;
logic   [BTBGROUP-1:0]  btb_hit_0;
logic   [BTBGROUP-1:0]  btb_hit_1;
logic   [BTBGROUP-1:0]  btb_hit_w; 
logic   [BTBGROUP-1:0]  btb_hit_inv;  
logic   [$clog2(BTBNUM/BTBGROUP)-1:0]  btb_group_num_0;
logic   [$clog2(BTBNUM/BTBGROUP)-1:0]  btb_group_num_1;
logic   [$clog2(BTBNUM/BTBGROUP)-1:0]  btb_group_num_w;
logic   [BTBTAGLEN-1:0] btb_fetch_tag_0;
logic   [BTBTAGLEN-1:0] btb_fetch_tag_1;
logic   [BTBTAGLEN-1:0] btb_fetch_tag_w;
logic   [$clog2(BTBGROUP)-1:0]  btb_index_in_group_0;
logic   [$clog2(BTBGROUP)-1:0]  btb_index_in_group_1;
logic   [$clog2(BTBGROUP)-1:0]  btb_index_in_group_w;
logic   [$clog2(BTBGROUP)-1:0]  btb_index_in_group_inv;


assign pc_0_32to2 = fetch_pc_0[31:2];
assign pc_1_32to2 = fetch_pc_1[31:2];
assign pc_w_32to2 = wrong_pc[31:2];

assign btb_group_num_0 = pc_0_32to2[$clog2(BTBNUM/BTBGROUP)-1:0];
assign btb_group_num_1 = pc_1_32to2[$clog2(BTBNUM/BTBGROUP)-1:0];
assign btb_group_num_w = pc_w_32to2[$clog2(BTBNUM/BTBGROUP)-1:0];

assign btb_fetch_tag_0 = pc_0_32to2[29:24]^pc_0_32to2[23:18]^pc_0_32to2[17:12]^pc_0_32to2[11:6]^pc_0_32to2[5:0];
assign btb_fetch_tag_1 = pc_1_32to2[29:24]^pc_1_32to2[23:18]^pc_1_32to2[17:12]^pc_1_32to2[11:6]^pc_1_32to2[5:0];
assign btb_fetch_tag_w = pc_w_32to2[29:24]^pc_w_32to2[23:18]^pc_w_32to2[17:12]^pc_w_32to2[11:6]^pc_w_32to2[5:0];

genvar i;
generate
    for(i = 0; i < BTBGROUP; i = i + 1)
    begin: BTB_match
        assign btb_hit_0[i] = btb_valid[btb_group_num_0 * BTBGROUP + i] && btb_tag[btb_group_num_0 * BTBGROUP + i] == btb_fetch_tag_0;
        assign btb_hit_1[i] = btb_valid[btb_group_num_1 * BTBGROUP + i] && btb_tag[btb_group_num_1 * BTBGROUP + i] == btb_fetch_tag_1;
        assign btb_hit_w[i] = btb_valid[btb_group_num_w * BTBGROUP + i] && btb_tag[btb_group_num_w * BTBGROUP + i] == btb_fetch_tag_w;
        assign btb_hit_inv[i] = ~btb_valid[btb_group_num_w * BTBGROUP + i];
    end
endgenerate
//calc index
integer j;
always_comb begin
    btb_index_in_group_0 = 0;
	btb_index_in_group_1 = 0;
	btb_index_in_group_inv = 0;
	btb_index_in_group_w = 0;
    for(j = 0; j < BTBGROUP; j = j + 1) begin
        if(btb_hit_0[j]) begin
            btb_index_in_group_0 = j;
        end
        if(btb_hit_1[j]) begin
            btb_index_in_group_1 = j;
        end
        if(btb_hit_w[j]) begin
            btb_index_in_group_w = j;
        end
        if(btb_hit_inv[j]) begin
            btb_index_in_group_inv = j;
        end
    end
end
assign index_0 = {btb_group_num_0,btb_index_in_group_0};
assign index_1 = {btb_group_num_1,btb_index_in_group_1};
assign index_w = {btb_group_num_w,btb_index_in_group_w};
assign index_inv = {btb_group_num_w,btb_index_in_group_inv};
assign index_replace = {btb_group_num_w,btb_replace_counter[btb_group_num_w]};

assign hit_0 = |btb_hit_0;
assign hit_1 = |btb_hit_1;
assign hit_w = |btb_hit_w;
assign hit_inv = |btb_hit_inv;

assign target_0 = btb_target[index_0];
assign target_1 = btb_target[index_1];

assign target_pc_0 = hit_0 ?target_0 : 32'b0;
assign target_pc_1 = hit_1 ?target_1 : 32'b0;

assign ins_type_0 = hit_0 ? btb_ins_type[index_0] : 3'b000;
assign ins_type_1 = hit_1 ? btb_ins_type[index_1] : 3'b000;
integer k;
always @(posedge clk) begin
    if(reset) begin
        btb_valid <= 0;
        for(k = 0; k < BTBNUM/BTBGROUP; k = k + 1) begin
            btb_replace_counter[k] <= 0;
        end
    end
    else begin
        if(branch_mistaken) begin
            //replace the same tag
            btb_replace_counter[btb_group_num_w] <= ~btb_replace_counter[btb_group_num_w];
            if(hit_w) begin
                btb_tag[index_w] <= btb_fetch_tag_w;
                btb_target[index_w] <= right_target;
                btb_ins_type[index_w] <= ins_type_w;
            end
            //fill empty line
            else if(hit_inv) begin
                btb_tag[index_inv] <= btb_fetch_tag_w;
                btb_target[index_inv] <= right_target;
                btb_ins_type[index_inv] <= ins_type_w;
                btb_valid[index_inv] <= 1'b1;
            end
            //random replace
            else begin
            	btb_tag[index_replace] <= btb_fetch_tag_w;
                btb_target[index_replace] <= right_target;
                btb_ins_type[index_replace] <= ins_type_w;
                btb_valid[index_replace] <= 1'b1;
            end
        end
    end
end
endmodule