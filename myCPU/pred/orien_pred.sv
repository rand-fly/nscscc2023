module orien_pred
#(
	parameter BHTNUM = 32,
	parameter BHTIDLEN = 5,
	parameter BHRLEN = 6,
	parameter PHTNUM = 128
)

//18		5			6			1 				2
//other 	BHT_index	pc_hash		pht_port_sel	other
//[31:14]	[13:9]		[8:3]		[2]				[1:0]
(	
	input 			clk			,
	input [31:0]	pc 			,
	output			taken_0		,
	output			taken_1		,

	//update port
	input			operate_en	,
	input [31:0]	operate_pc	,
	input 			right_orien	
);




reg	[BHRLEN - 1:0]	bht	[BHTNUM - 1:0] ;//6bit bhr

//two ways PHT
// 00 01 10 11
//untaken -> taken
reg [1:0]	pht_0	[PHTNUM / 2 - 1:0]	;
reg [1:0]	pht_1	[PHTNUM / 2 - 1:0]	;

//search BHT
logic	[BHTIDLEN - 1:0]		bht_index	;
logic	[BHRLEN - 1:0]		bht_val		;

logic	[BHRLEN - 1:0]		pc_0		;	
logic	[BHRLEN - 1:0]		pc_1		;

logic	[BHRLEN - 1:0]		pht_index_0	;
logic	[BHRLEN - 1:0]		pht_index_1	;

logic 	[1:0]				pht_res_0	;
logic 	[1:0]				pht_res_1	;



//search BHT
assign bht_index = pc[BHRLEN + BHTIDLEN + 2:BHRLEN + 3];
assign bht_val = bht[bht_index];

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
logic	[BHTIDLEN - 1:0]		bht_index_o	;
logic	[BHRLEN - 1:0]		bht_val_o	;

logic	[BHRLEN - 1:0]		pc_o		;
logic	[BHRLEN - 1:0]		pht_index_o	;

assign bht_index_o = operate_pc[BHRLEN + BHTIDLEN + 2:BHRLEN + 3];
assign bht_val_o = bht[bht_index_o];

assign pc_o = operate_pc[BHRLEN + 2 :3];
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
	end
	else if(operate_en) begin
		//update PHT
		if(operate_pc[2] == 0) begin
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

endmodule