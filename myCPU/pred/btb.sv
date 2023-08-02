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
    input	[2:0]	  ins_type_w	   ,
    input  	[31:0]    wrong_pc         ,
    input  	[31:0]    right_target     
);

logic            		hit_0    ;
logic            	 	hit_1    ;
logic             		hit_w    ;
logic             		hit_inv  ;

//storage
reg     [BTBNUM/BTBGROUP -1:0]    btb_valid_way0;
reg     [BTBNUM/BTBGROUP -1:0]    btb_valid_way1;

`define get_valid(way_id_,index_) (\
        {1{way_id_==0}} & btb_valid_way0[index_]\
    |   {1{way_id_==1}} & btb_valid_way1[index_]\
)

reg     [BTBTAGLEN-1:0] btb_tag_way0     [BTBNUM/BTBGROUP -1:0];
reg     [BTBTAGLEN-1:0] btb_tag_way1     [BTBNUM/BTBGROUP -1:0];

`define get_tag(way_id_,index_) (\
        {BTBTAGLEN{way_id_==0}} & btb_tag_way0[index_]\
    |   {BTBTAGLEN{way_id_==1}} & btb_tag_way1[index_]\
)

reg     [31:0]          btb_target_way0  [BTBNUM/BTBGROUP -1:0];
reg     [31:0]          btb_target_way1  [BTBNUM/BTBGROUP -1:0];

`define get_target(way_id_,index_) (\
        {32{way_id_==0}} & btb_target_way0[index_]\
    |   {32{way_id_==1}} & btb_target_way1[index_]\
)

reg     [2:0]			btb_ins_type_way0[BTBNUM/BTBGROUP -1:0];
reg     [2:0]           btb_ins_type_way1[BTBNUM/BTBGROUP -1:0];

`define get_ins_type(way_id_,index_) (\
        {3{way_id_==0}} & btb_ins_type_way0[index_]\
    |   {3{way_id_==1}} & btb_ins_type_way1[index_]\
)

reg   	[$clog2(BTBGROUP)-1:0]	btb_replace_counter	[BTBNUM/BTBGROUP -1:0] ;

//search
logic   [29:0]          pc_0_32to2;
logic   [29:0]          pc_1_32to2;
logic   [29:0]          pc_w_32to2;
logic   [BTBGROUP-1:0]  btb_hit_way_0;
logic   [BTBGROUP-1:0]  btb_hit_way_1;
logic   [BTBGROUP-1:0]  btb_hit_way_w; 
logic   [BTBGROUP-1:0]  btb_hit_way_inv;  
logic   [$clog2(BTBNUM/BTBGROUP)-1:0]  btb_group_num_0;
logic   [$clog2(BTBNUM/BTBGROUP)-1:0]  btb_group_num_1;
logic   [$clog2(BTBNUM/BTBGROUP)-1:0]  btb_group_num_w;
logic   [BTBTAGLEN-1:0] btb_fetch_tag_0;
logic   [BTBTAGLEN-1:0] btb_fetch_tag_1;
logic   [BTBTAGLEN-1:0] btb_fetch_tag_w;
logic   [$clog2(BTBGROUP)-1:0]  btb_hit_way_id_0;
logic   [$clog2(BTBGROUP)-1:0]  btb_hit_way_id_1;
logic   [$clog2(BTBGROUP)-1:0]  btb_hit_way_id_w;
logic   [$clog2(BTBGROUP)-1:0]  btb_hit_way_id_inv;


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
        assign btb_hit_way_0[i] = `get_valid(i, btb_group_num_0) & (`get_tag(i, btb_group_num_0) == btb_fetch_tag_0);
        assign btb_hit_way_1[i] = `get_valid(i, btb_group_num_1) & (`get_tag(i, btb_group_num_1) == btb_fetch_tag_1);
        assign btb_hit_way_w[i] = `get_valid(i, btb_group_num_w) & (`get_tag(i, btb_group_num_w) == btb_fetch_tag_w);
        assign btb_hit_way_inv[i] = ~`get_valid(i, btb_group_num_w);
    end
endgenerate
//calc index

assign btb_hit_way_id_0 =   {1{btb_hit_way_0[0]}} & 0 |
                            {1{btb_hit_way_0[1]}} & 1;
assign btb_hit_way_id_1 =   {1{btb_hit_way_1[0]}} & 0 |
                            {1{btb_hit_way_1[1]}} & 1;
assign btb_hit_way_id_w =   {1{btb_hit_way_w[0]}} & 0 |
                            {1{btb_hit_way_w[1]}} & 1;
assign btb_hit_way_id_inv = {1{btb_hit_way_inv[0]}} & 0 |
                            {1{btb_hit_way_inv[1]}} & 1;



assign hit_0 = |btb_hit_way_0;
assign hit_1 = |btb_hit_way_1;
assign hit_w = |btb_hit_way_w;
assign hit_inv = |btb_hit_way_inv;



assign target_pc_0 = hit_0 ? `get_target(btb_hit_way_id_0, btb_group_num_0) : 32'b0;
assign target_pc_1 = hit_1 ? `get_target(btb_hit_way_id_1, btb_group_num_1) : 32'b0;

assign ins_type_0 = hit_0 ? `get_ins_type(btb_hit_way_id_0, btb_group_num_0) : 3'b000;
assign ins_type_1 = hit_1 ? `get_ins_type(btb_hit_way_id_1, btb_group_num_1) : 3'b000;
integer k;
always @(posedge clk) begin
    if(reset) begin
        btb_valid_way0 <= 0;
        btb_valid_way1 <= 0;
        for(k = 0; k < BTBNUM/BTBGROUP; k = k + 1) begin
            btb_replace_counter[k] <= 0;
        end
    end
    else begin
        if(branch_mistaken) begin
            //replace the same tag
            btb_replace_counter[btb_group_num_w] <= ~btb_replace_counter[btb_group_num_w];
            if(hit_w) begin
                case(btb_hit_way_id_w)
                    0 : begin
                        btb_tag_way0[btb_group_num_w] <= btb_fetch_tag_w;
                        btb_target_way0[btb_group_num_w] <= right_target;
                        btb_ins_type_way0[btb_group_num_w] <= ins_type_w;
                    end
                    1 : begin
                        btb_tag_way1[btb_group_num_w] <= btb_fetch_tag_w;
                        btb_target_way1[btb_group_num_w] <= right_target;
                        btb_ins_type_way1[btb_group_num_w] <= ins_type_w;
                    end
                endcase
            end
            //fill empty line
            else if(hit_inv) begin
                case(btb_hit_way_id_inv)
                    0 : begin
                        btb_tag_way0[btb_group_num_w] <= btb_fetch_tag_w;
                        btb_target_way0[btb_group_num_w] <= right_target;
                        btb_ins_type_way0[btb_group_num_w] <= ins_type_w;
                        btb_valid_way0[btb_group_num_w] <= 1'b1;
                    end
                    1 : begin
                        btb_tag_way1[btb_group_num_w] <= btb_fetch_tag_w;
                        btb_target_way1[btb_group_num_w] <= right_target;
                        btb_ins_type_way1[btb_group_num_w] <= ins_type_w;
                        btb_valid_way1[btb_group_num_w] <= 1'b1;
                    end
                endcase
            end
            //random replace
            else begin
            	case(btb_replace_counter[btb_group_num_w])
                    0 : begin
                        btb_tag_way0[btb_group_num_w] <= btb_fetch_tag_w;
                        btb_target_way0[btb_group_num_w] <= right_target;
                        btb_ins_type_way0[btb_group_num_w] <= ins_type_w;
                        btb_valid_way0[btb_group_num_w] <= 1'b1;
                    end
                    1 : begin
                        btb_tag_way1[btb_group_num_w] <= btb_fetch_tag_w;
                        btb_target_way1[btb_group_num_w] <= right_target;
                        btb_ins_type_way1[btb_group_num_w] <= ins_type_w;
                        btb_valid_way1[btb_group_num_w] <= 1'b1;
                    end
                endcase
            end
        end
    end
end
endmodule