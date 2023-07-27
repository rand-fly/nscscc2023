module pred
#(
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
    input  [31:0]     fetch_pc_0    ,
    input  [31:0]     fetch_pc_1    ,
    //not jump instruction  -> 000  while both not jmp, pc_1+0x4
    //direct jmp            -> 001, predicted in btb
    //call                  -> 010, predicted in btb, push pc+0x4 into RAS
    //ret:  jirl r0, r1, 0  -> 011, using RAS
    //indirect jmp          -> 100, using Target Cache
    //condional direct jmp  -> 101, using PHT
    input  [2:0]      ins_type_0    ,
    input  [2:0]      ins_type_1    ,

    output [31:0]     ret_pc        ,
    output [1:0]      hit_num       ,
    //valid while the first jump ins_type is 11(condional direct jmp)
    output            taken         ,

    //update
    input             branch_mistaken  ,
    input  [31:0]     wrong_pc         ,
    input  [31:0]     right_target     ,
    input  [1:0]      ins_type_w        ,
    
    input             update_orien_en  ,
    input  [31:0]     retire_pc        ,
    input             right_orien   

);


//BHT
reg [BHRLEN - 1:0]  bht [BHTNUM - 1:0] ;//6bit bhr
//search BHT
assign bht_index_0 = fetch_pc_0[BHRLEN + BHTIDLEN + 2:BHRLEN + 3];
assign bht_index_1 = fetch_pc_1[BHRLEN + BHTIDLEN + 2:BHRLEN + 3];
assign bht_val_0 = bht[bht_index_0];
assign bht_val_1 = bht[bht_index_1];



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

logic   [BHRLEN - 1:0]      hashed_index_0 ;
logic   [BHRLEN - 1:0]      hashed_index_1 ;

logic   [1:0]               pht_res_0   ;
logic   [1:0]               pht_res_1   ;

//search PHT 
assign pc_0 = fetch_pc_0[BHRLEN + 2 :3];
assign pc_1 = fetch_pc_1[BHRLEN + 2 :3];

assign hashed_index_0 = (fetch_pc_0[2] == 0) ? bht_val_0 ^ pc_0 : bht_val_1 ^ pc_1;
assign hashed_index_1 = (fetch_pc_1[2] == 1) ? bht_val_0 ^ pc_0 : bht_val_1 ^ pc_1;

assign pht_res_0 = (fetch_pc_0[2] == 0) ? pht_0[hashed_index_0] : pht_1[hashed_index_1];
assign pht_res_1 = (fetch_pc_1[2] == 1) ? pht_0[hashed_index_0] : pht_1[hashed_index_1];

assign taken_0 = pht_res_0[1];
assign taken_1 = pht_res_1[1];

assign taken = 
//


//update
logic   [BHTIDLEN - 1:0]    bht_index_o ;
logic   [BHRLEN - 1:0]      bht_val_o   ;

logic   [BHRLEN - 1:0]      fetch_pc_o        ;
logic   [BHRLEN - 1:0]      hashed_index_o ;

assign bht_index_o = retire_pc[BHRLEN + BHTIDLEN + 2:BHRLEN + 3];
assign bht_val_o = bht[bht_index_o];

assign fetch_pc_o = retire_pc[BHRLEN + 2 :3];
assign hashed_index_o = bht_val_o ^ fetch_pc_o;
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
    end
    else begin
        if(branch_mistaken) begin
            
        end
        if(update_orien_en) begin
            //update PHT
            if(retire_pc[2] == 0) begin
                if(right_orien) begin
                    if(pht_0[hashed_index_o] != 2'b11)begin    
                        pht_0[hashed_index_o] <= pht_0[hashed_index_o] + 1;
                    end
                end
                else begin
                    if(pht_0[hashed_index_o] != 2'b00)begin    
                        pht_0[hashed_index_o] <= pht_0[hashed_index_o] - 1;
                    end
                end
            end
            else begin
                if(right_orien) begin
                    if(pht_1[hashed_index_o] != 2'b11)begin    
                        pht_1[hashed_index_o] <= pht_1[hashed_index_o] + 1;
                    end
                end
                else begin
                    if(pht_1[hashed_index_o] != 2'b00)begin    
                        pht_1[hashed_index_o] <= pht_1[hashed_index_o] - 1;
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

