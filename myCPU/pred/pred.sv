module pred
#(
    parameter BTBNUM = 32,
    parameter BTBIDLEN = $clog2(BTBNUM),
    parameter BTBTAGLEN = 6,
    parameter BTBGROUP = 2,
    parameter RASNUM = 16,
    parameter RASIDLEN = $clog2(RASNUM),
    parameter BHTNUM = 32,
    parameter BHTIDLEN = 5,
    parameter BHRLEN = 6,
    parameter PHTNUM = 128
)
(
    input             clk           ,
    input             reset         ,
    //from/to if
    input  [31:0]     fetch_pc      ,
    output [31:0]     ret_pc        ,
    output            taken         ,
    output            ret_en        ,

    //update
    input             branch_mistaken  ,
    input  [31:0]     wrong_pc         ,
    input  [31:0]     right_target     ,
    input  [1:0]      ins_type_w         ,
    
    input             update_orien_en  ,
    input  [31:0]     retire_pc        ,
    input             right_orien   

);


//BTB 0\1\w: port0\port1\wrong Port
logic  [31:0]     target_0    ;
logic  [31:0]     target_1    ;
logic  [BTBIDLEN-1:0]  index_0;
logic  [BTBIDLEN-1:0]  index_1;
logic  [BTBIDLEN-1:0]  index_w;
logic  [BTBIDLEN-1:0]  index_inv;
logic             hit_0     ;  
logic             hit_1    ;
logic             hit_w    ;
logic             hit_inv;
logic   [1:0]       ins_type_0;
logic   [1:0]       ins_type_1;
logic taken_0;
logic taken_1;
//storage
reg     [BTBNUM-1:0]    btb_valid   ;
reg     [BTBTAGLEN-1:0] btb_tag     [BTBNUM-1:0];
reg     [31:0]          btb_target  [BTBNUM-1:0];
reg     [1:0]           btb_ins_type[BTBNUM-1:0];
reg   [BTBNUM/BTBGROUP -1:0] btb_fifo_counter;   

//search
logic   [29:0]          pc_0_32to2;
logic   [29:0]          pc_1_32to2;
logic   [29:0]          pc_w_32to2;
logic   [BTBGROUP-1:0]  btb_hit_0;
logic   [BTBGROUP-1:0]  btb_hit_1;
logic   [BTBGROUP-1:0]  btb_hit_w; 
logic   [BTBGROUP-1:0]  btb_invalid_w;  
logic   [BTBIDLEN-1:0]  btb_group_num_0;
logic   [BTBIDLEN-1:0]  btb_group_num_1;
logic   [BTBIDLEN-1:0]  btb_group_num_w;
logic   [BTBTAGLEN-1:0] btb_fetch_tag_0;
logic   [BTBTAGLEN-1:0] btb_fetch_tag_1;
logic   [BTBTAGLEN-1:0] btb_fetch_tag_w;
logic   [$clog2(BTBGROUP)-1,0]  btb_index_in_group_0;
logic   [$clog2(BTBGROUP)-1,0]  btb_index_in_group_1;
logic   [$clog2(BTBGROUP)-1,0]  btb_index_in_group_w;
logic   [$clog2(BTBGROUP)-1,0]  btb_index_in_group_inv;


assign pc_0_32to2 = fetch_pc[31:2];
assign pc_1_32to2 = pc_0_32to2 + 1;
assign pc_w_32to2 = wrong_pc[31:2];

assign btb_group_num_0 = pc_0_32to2[$clog2(BTBNUM/BTBGROUP)-1:0];
assign btb_group_num_1 = pc_1_32to2[$clog2(BTBNUM/BTBGROUP)-1:0];
assign btb_group_num_1 = pc_w_32to2[$clog2(BTBNUM/BTBGROUP)-1:0];

assign btb_fetch_tag_0 = pc_0_32to2[29:24]|pc_0_32to2[23:18]|pc_0_32to2[17:12]|pc_0_32to2[11:6]|pc_0_32to2[5:0];
assign btb_fetch_tag_1 = pc_1_32to2[29:24]|pc_1_32to2[23:18]|pc_1_32to2[17:12]|pc_1_32to2[11:6]|pc_1_32to2[5:0];
assign btb_fetch_tag_w = pc_w_32to2[29:24]|pc_w_32to2[23:18]|pc_w_32to2[17:12]|pc_w_32to2[11:6]|pc_w_32to2[5:0];

genvar i;
generate
    for(i = 0; i < BTBGROUP; i = i + 1)
    begin: BTB_match
        assign btb_hit_0[i] = btb_valid[i] && btb_tag[btb_group_num_0 * BTBGROUP + i] == btb_fetch_tag_0;
        assign btb_hit_1[i] = btb_valid[i] && btb_tag[btb_group_num_1 * BTBGROUP + i] == btb_fetch_tag_1;
        assign btb_hit_w[i] = btb_valid[i] && btb_tag[btb_group_num_w * BTBGROUP + i] == btb_fetch_tag_w;
        assign btb_invalid_w[i] = ~btb_valid[i];
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

assign hit_0 = |btb_hit_0;
assign hit_1 = |btb_hit_1;
assign hit_w = |btb_hit_w;
assign hit_inv = |btb_hit_inv;

assign target_0 = btb_target[index_0];
assign target_1 = btb_target[index_1];

assign ins_type_0 = btb_ins_type[index_0];
assign ins_type_1 = btb_ins_type[index_1];

//BHT
reg [BHRLEN - 1:0]  bht [BHTNUM - 1:0] ;//6bit bhr
//search BHT
assign bht_index = pc[BHRLEN + BHTIDLEN + 2:BHRLEN + 3];
assign bht_val = bht[bht_index];



//two ways PHT
// 00 01 10 11
//untaken -> taken
reg [1:0]   pht_0   [PHTNUM / 2 - 1:0]  ;
reg [1:0]   pht_1   [PHTNUM / 2 - 1:0]  ;

//search BHT
logic   [BHTIDLEN - 1:0]        bht_index   ;
logic   [BHRLEN - 1:0]      bht_val     ;

logic   [BHRLEN - 1:0]      pc_0        ;   
logic   [BHRLEN - 1:0]      pc_1        ;

logic   [BHRLEN - 1:0]      pht_index_0 ;
logic   [BHRLEN - 1:0]      pht_index_1 ;

logic   [1:0]               pht_res_0   ;
logic   [1:0]               pht_res_1   ;

//search PHT 
assign pc_0 = pc[BHRLEN + 2 :3];
assign pc_1 = pc_0 + 3'h4;

assign pht_index_0 = (pc[2] == 0) ? bht_val ^ pc_0 : bht_val ^ pc_1;
assign pht_index_1 = (pc[2] == 1) ? bht_val ^ pc_0 : bht_val ^ pc_1;

assign pht_res_0 = (pc[2] == 0) ? pht_0[pht_index_0] : pht_1[pht_index_1];
assign pht_res_1 = (pc[2] == 1) ? pht_0[pht_index_0] : pht_1[pht_index_1];

assign taken_0 = pht_res_0[1];
assign taken_1 = pht_res_1[1];





//update
logic   [BHTIDLEN - 1:0]        bht_index_o ;
logic   [BHRLEN - 1:0]      bht_val_o   ;

logic   [BHRLEN - 1:0]      pc_o        ;
logic   [BHRLEN - 1:0]      pht_index_o ;

assign bht_index_o = retire_pc[BHRLEN + BHTIDLEN + 2:BHRLEN + 3];
assign bht_val_o = bht[bht_index_o];

assign pc_o = retire_pc[BHRLEN + 2 :3];
assign pht_index_o = bht_val_o ^ pc_o;
integer i;
always @(posedge clk) begin
    if(reset) begin
        for(i = 0; i < BHTNUM; i = i + 1) begin
            bht[i] <= 0;
        end
        for(i = 0; i < PHTNUM/2; i = i + 1) begin
            pht_0[i] <= 0;
            pht_1[i] <= 0;
        end
        btb_v <= 0;
    end
    else begin

        if(branch_mistaken) begin
            //replace the same tag
            if(hit_w) begin
                btb_tag[index_w] <= btb_fetch_tag_w;
                btb_ins_type[index_w] <= ins_type_w;
                btb_target[index_w] <= right_target;
            end
            //fill empty line
            else if(hit_inv) begin
                btb_tag[index_inv] <= btb_fetch_tag_inv;
                btb_ins_type[index_inv] <= ins_type_inv;
                btb_target[index_inv] <= right_target;
            end
            //FIFO replace
            else begin
//to be countinue...................................................................................
            end
        end
        if(update_orien_en) begin
            //update PHT
            if(retire_pc[2] == 0) begin
                if(right_orien) begin
                    if(pht_0[pht_index_o] != 2'b11)begin    
                        pht_0[pht_index_o] <= pht_0[pht_index_o] + 1;
                    end
                end
                else begin
                    if(pht_0[pht_index_o] != 2'b00)begin    
                        pht_0[pht_index_o] <= pht_0[pht_index_o] - 1;
                    end
                end
            end
            else begin
                if(right_orien) begin
                    if(pht_1[pht_index_o] != 2'b11)begin    
                        pht_1[pht_index_o] <= pht_1[pht_index_o] + 1;
                    end
                end
                else begin
                    if(pht_1[pht_index_o] != 2'b00)begin    
                        pht_1[pht_index_o] <= pht_1[pht_index_o] - 1;
                    end
                end
            end

            //update BHT
            for(i = BHRLEN - 1; i >= 0; i = i - 1) begin
                bht[bht_index_o] <= bht[bht_index_o] << 1;
                bht[bht_index_o][0] <= right_orien;
            end
        end
    end
end




endmodule

