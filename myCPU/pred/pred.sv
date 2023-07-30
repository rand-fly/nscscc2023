`include "../definitions.svh"

module pred #(
    parameter RASNUM   = 16,
    parameter RASIDLEN = $clog2(RASNUM),
    parameter BHTNUM   = 32,
    parameter BHTIDLEN = $clog2(BHTNUM),
    parameter BHRLEN   = 7,
    parameter PHTNUM   = 2 ** BHRLEN
) (
    input        clk,
    input        reset,
    //from/to if
    input [31:0] fetch_pc_0,
    input [31:0] fetch_pc_1,

    input dual_issue,


    output logic [31:0] ret_pc_0,
    output logic [31:0] ret_pc_1,

    output taken_0,
    output taken_1,

    //update
    input        branch_mistaken,
    input [31:0] wrong_pc,
    input [31:0] right_target,
    input [ 2:0] ins_type_w,

    input        update_orien_en,
    input [31:0] retire_pc,
    input        right_orien
);

  //not jump instruction  -> 000  while both not jmp, pc_0+0x8
  //direct jmp            -> 001, predicted in btb
  //call                  -> 010, predicted in btb, push pc+0x4 into RAS
  //ret:  jirl r0, r1, 0  -> 011, using RAS
  //indirect jmp          -> 100, using Target Cache
  logic [           2:0] ins_type_0;
  logic [           2:0] ins_type_1;



  //BHT
  reg                    bht_v          [BHTNUM - 1:0];  //bhr_valid lazy_tag
  reg   [  BHRLEN - 1:0] bht            [BHTNUM - 1:0];  //8bit bhr
  //search BHT
  logic [BHTIDLEN - 1:0] bht_index_0;
  logic [BHTIDLEN - 1:0] bht_index_1;
  logic [BHTIDLEN - 1:0] bht_index_o;
  logic [BHTIDLEN - 1:0] bht_index_w;
  logic [  BHRLEN - 1:0] bht_val_0;
  logic [  BHRLEN - 1:0] bht_val_1;
  logic [  BHRLEN - 1:0] bht_val_o;
  logic [  BHRLEN - 1:0] bht_val_w;
  logic [  BHRLEN - 1:0] pc_frag_0;
  logic [  BHRLEN - 1:0] pc_frag_1;
  logic [  BHRLEN - 1:0] pc_frag_o;
  logic [  BHRLEN - 1:0] pc_frag_w;
  logic [  BHRLEN - 1:0] hashed_index_0;
  logic [  BHRLEN - 1:0] hashed_index_1;
  logic [  BHRLEN - 1:0] hashed_index_o;
  logic [  BHRLEN - 1:0] hashed_index_w;


  //adjust this hash while change BHTNUM/IDLEN
  assign bht_index_0 = fetch_pc_0[31:27]^fetch_pc_0[26:22]^fetch_pc_0[21:17]^fetch_pc_0[16:12]^fetch_pc_0[11:7]^fetch_pc_0[6:2];
  assign bht_index_1 = fetch_pc_1[31:27]^fetch_pc_1[26:22]^fetch_pc_1[21:17]^fetch_pc_1[16:12]^fetch_pc_1[11:7]^fetch_pc_1[6:2];
  assign bht_index_o = retire_pc[31:27]^retire_pc[26:22]^retire_pc[21:17]^retire_pc[16:12]^retire_pc[11:7]^retire_pc[6:2];
  assign bht_index_w = wrong_pc[31:27]^wrong_pc[26:22]^wrong_pc[21:17]^wrong_pc[16:12]^wrong_pc[11:7]^wrong_pc[6:2];

  assign bht_val_0 = {7{bht_v[bht_index_0]}} & bht[bht_index_0];
  assign bht_val_1 = {7{bht_v[bht_index_1]}} & bht[bht_index_1];
  assign bht_val_o = {7{bht_v[bht_index_o]}} & bht[bht_index_o];
  assign bht_val_w = {7{bht_v[bht_index_w]}} & bht[bht_index_w];

  assign pc_frag_0 = fetch_pc_0[BHRLEN+1 : 2];
  assign pc_frag_1 = fetch_pc_1[BHRLEN+1 : 2];
  assign pc_frag_o = retire_pc[BHRLEN+1 : 2];
  assign pc_frag_w = wrong_pc[BHRLEN+1 : 2];

  assign hashed_index_0 = bht_val_0 ^ pc_frag_0;
  assign hashed_index_1 = bht_val_1 ^ pc_frag_1;
  assign hashed_index_o = bht_val_o ^ pc_frag_o;
  assign hashed_index_w = bht_val_w ^ pc_frag_w;
  //reset & update BHT
  integer i;
  always @(posedge clk) begin
    if (reset) begin
      for (i = 0; i < BHTNUM; i = i + 1) begin
        bht_v[i] <= 0;
      end
    end else if (update_orien_en) begin
      if (bht_v[bht_index_o]) begin
        for (i = BHRLEN - 1; i >= 0; i = i - 1) begin
          bht[bht_index_o] <= bht[bht_index_o] << 1;
          bht[bht_index_o][0] <= right_orien;
        end
      end else begin  //need reset
        bht[bht_index_o]   <= right_orien;
        bht_v[bht_index_o] <= 1;
      end
    end
  end



  //PHT
  // 00 01 10 11
  //untaken -> taken
  reg         pht_v     [PHTNUM - 1:0];
  reg   [1:0] pht       [PHTNUM - 1:0];
  //search PHT
  logic [1:0] pht_res_0;
  logic [1:0] pht_res_1;

  assign pht_res_0 = {2{pht_v[hashed_index_0]}} & pht[hashed_index_0];
  assign pht_res_1 = {2{pht_v[hashed_index_1]}} & pht[hashed_index_1];
  assign taken_0   = ins_type_0 == BR_NOP ? 1'b0 : ins_type_0 == BR_COND ? pht_res_0[1] : 1'b1;
  assign taken_1   = ins_type_1 == BR_NOP ? 1'b0 : ins_type_1 == BR_COND ? pht_res_1[1] : 1'b1;
  //reset & update PHT
  integer j;
  always @(posedge clk) begin
    if (reset) begin
      for (j = 0; j < PHTNUM; j = j + 1) begin
        pht_v[j] = 0;  // make verilator happy
      end
    end else if (update_orien_en) begin
      if (pht_v[hashed_index_o]) begin
        if (right_orien) begin
          if (pht[hashed_index_o] != 2'b11) begin
            pht[hashed_index_o] <= pht[hashed_index_o] + 1;
          end
        end else begin
          if (pht[hashed_index_o] != 2'b00) begin
            pht[hashed_index_o] <= pht[hashed_index_o] - 1;
          end
        end
      end else begin  //need reset, always 00 or 01
        pht_v[hashed_index_o] <= 1;
        pht[hashed_index_o]   <= {1'b0, right_orien};
      end
    end
  end



  //RAS
  reg   [              31:0] ras_pc       [RASNUM - 1:0];
  reg   [$clog2(RASNUM)-1:0] ras_top;
  //search RAS
  reg   [              31:0] ras_res;
  logic [              31:0] ras_top_val;
  logic [              31:0] ras_ret_pc;
  logic [              31:0] ras_ret_pc_0;
  logic [              31:0] ras_ret_pc_1;
  logic [               2:0] ras_ins_type;


  assign ras_top_val = ras_pc[ras_top];
  assign ras_ins_type = (ins_type_0 == BR_CALL || ins_type_0 == BR_RET) ? ins_type_0 : ins_type_1 & {3{dual_issue}};
  assign ras_ret_pc = (ins_type_0 == BR_CALL || ins_type_0 == BR_RET) ? ras_ret_pc_0 : ras_ret_pc_1;
  assign ras_ret_pc_0 = {fetch_pc_0[31:2] + 1'b1, fetch_pc_0[1:0]};
  assign ras_ret_pc_1 = {fetch_pc_1[31:2] + 1'b1, fetch_pc_1[1:0]};

  //reset & push & pop RAS
  integer k;
  always @(posedge clk) begin
    if (reset) begin
      for (k = 0; k < RASNUM; k = k + 1) begin
        ras_pc[k] <= 0;
      end
      ras_top <= 0;
    end else begin
      //call->push
      if (ras_ins_type == BR_CALL) begin
        ras_top <= ras_top + 1;
        ras_pc[ras_top+1] <= ras_ret_pc;
      end  //ret->pop
      else if (ras_ins_type == BR_RET) begin
        ras_top <= ras_top - 1;
      end
    end
  end

  assign ras_res = ras_top_val;


  //BTB
  logic [31:0] btb_res_0;
  logic [31:0] btb_res_1;
  btb btb (
      .clk  (clk),
      .reset(reset),

      .fetch_pc_0 (fetch_pc_0),
      .fetch_pc_1 (fetch_pc_1),
      .target_pc_0(btb_res_0),
      .target_pc_1(btb_res_1),
      .ins_type_0 (ins_type_0),
      .ins_type_1 (ins_type_1),

      .branch_mistaken(branch_mistaken),
      .ins_type_w(ins_type_w),
      .wrong_pc(wrong_pc),
      .right_target(right_target)
  );

  //final select
  always_comb begin
    unique case (ins_type_0)
      BR_NOP:  ret_pc_0 = {fetch_pc_0[31:2] + 1'b1, 2'b0};
      BR_RET:  ret_pc_0 = ras_res;
      default: ret_pc_0 = btb_res_0;
    endcase
  end

  always_comb begin
    unique case (ins_type_1)
      BR_NOP:  ret_pc_1 = {fetch_pc_1[31:2] + 1'b1, 2'b0};
      BR_RET:  ret_pc_1 = ras_res;
      default: ret_pc_1 = btb_res_1;
    endcase
  end

endmodule

