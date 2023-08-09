`include "definitions.svh"

module ibuf (
    input                    clk,
    input                    reset,
    input                    flush,
    // input
    input             [ 1:0] i_size,
    output                   i_ready,
    // input port 0
    input             [31:0] i_a_pc,
    input  optype_t          i_a_optype,
    input  opcode_t          i_a_opcode,
    input             [ 4:0] i_a_dest,
    input             [31:0] i_a_imm,
    input                    i_a_pred_br_taken,
    input             [31:0] i_a_pred_br_target,
    input  br_type_t         i_a_br_type,
    input                    i_a_br_condition,
    input             [31:0] i_a_br_target,
    input                    i_a_br_taken,
    input                    i_a_have_excp,
    input  excp_t            i_a_excp_type,
    input  csr_addr_t        i_a_csr_addr,
    input                    i_a_csr_wr,
    input                    i_a_is_spec_op,
    input                    i_a_is_idle,
    input             [ 4:0] i_a_r1,
    input             [ 4:0] i_a_r2,
    input                    i_a_src2_is_imm,
    // input port 1
    input             [31:0] i_b_pc,
    input  optype_t          i_b_optype,
    input  opcode_t          i_b_opcode,
    input             [ 4:0] i_b_dest,
    input             [31:0] i_b_imm,
    input                    i_b_pred_br_taken,
    input             [31:0] i_b_pred_br_target,
    input  br_type_t         i_b_br_type,
    input                    i_b_br_condition,
    input                    i_b_br_taken,
    input             [31:0] i_b_br_target,
    input                    i_b_have_excp,
    input  excp_t            i_b_excp_type,
    input  csr_addr_t        i_b_csr_addr,
    input                    i_b_csr_wr,
    input                    i_b_is_spec_op,
    input                    i_b_is_idle,
    input             [ 4:0] i_b_r1,
    input             [ 4:0] i_b_r2,
    input                    i_b_src2_is_imm,

`ifdef DIFFTEST_EN
    input  difftest_t i_a_difftest,
    input  difftest_t i_b_difftest,
    output difftest_t o_a_difftest,
    output difftest_t o_b_difftest,
`endif

    //output
    input             [ 1:0] o_size,
    // output port 0
    output            [31:0] o_a_pc,
    output                   o_a_valid,
    output optype_t          o_a_optype,
    output opcode_t          o_a_opcode,
    output            [ 4:0] o_a_dest,
    output            [31:0] o_a_imm,
    output                   o_a_pred_br_taken,
    output            [31:0] o_a_pred_br_target,
    output br_type_t         o_a_br_type,
    output                   o_a_br_condition,
    output            [31:0] o_a_br_target,
    output                   o_a_br_taken,
    output                   o_a_have_excp,
    output excp_t            o_a_excp_type,
    output csr_addr_t        o_a_csr_addr,
    output                   o_a_csr_wr,
    output                   o_a_is_spec_op,
    output                   o_a_is_idle,
    output            [ 4:0] o_a_r1,
    output            [ 4:0] o_a_r2,
    output                   o_a_src2_is_imm,
    // output port 1
    output            [31:0] o_b_pc,
    output                   o_b_valid,
    output optype_t          o_b_optype,
    output opcode_t          o_b_opcode,
    output            [ 4:0] o_b_dest,
    output            [31:0] o_b_imm,
    output                   o_b_pred_br_taken,
    output            [31:0] o_b_pred_br_target,
    output br_type_t         o_b_br_type,
    output                   o_b_br_condition,
    output            [31:0] o_b_br_target,
    output                   o_b_br_taken,
    output                   o_b_have_excp,
    output excp_t            o_b_excp_type,
    output csr_addr_t        o_b_csr_addr,
    output                   o_b_csr_wr,
    output                   o_b_is_spec_op,
    output                   o_b_is_idle,
    output            [ 4:0] o_b_r1,
    output            [ 4:0] o_b_r2,
    output                   o_b_src2_is_imm
);

  logic [191:0] data_way0[8];
  logic [191:0] data_way1[8];

`ifdef DIFFTEST_EN
  difftest_t difftest_way0[8];
  difftest_t difftest_way1[8];
`endif

  logic [  2:0] head_way0;
  logic [  2:0] head_way1;
  logic         head_way;
  logic [  2:0] tail_way0;
  logic [  2:0] tail_way1;
  logic         tail_way;
  logic [  4:0] length;

  logic [191:0] input_data0;
  logic [191:0] input_data1;

  assign i_ready = length <= 5'd10; // 本周期最多可能进来两条，ID阶段可能有两条，同时最多可能发起两条请求，16-6=10

  assign o_a_valid = length >= 5'd1;
  assign{o_a_pc,
         o_a_optype,
         o_a_opcode,
         o_a_dest,
         o_a_imm,
         o_a_pred_br_taken,
         o_a_pred_br_target,
         o_a_br_type,
         o_a_br_condition,
         o_a_br_target,
         o_a_br_taken,
         o_a_have_excp,
         o_a_excp_type,
         o_a_csr_addr,
         o_a_csr_wr,
         o_a_is_spec_op,
         o_a_is_idle,
         o_a_r1,
         o_a_r2,
         o_a_src2_is_imm
  } = head_way ? data_way1[head_way1] : data_way0[head_way0];

  assign o_b_valid = length >= 5'd2;
  assign{o_b_pc,
         o_b_optype,
         o_b_opcode,
         o_b_dest,
         o_b_imm,
         o_b_pred_br_taken,
         o_b_pred_br_target,
         o_b_br_type,
         o_b_br_condition,
         o_b_br_target,
         o_b_br_taken,
         o_b_have_excp,
         o_b_excp_type,
         o_b_csr_addr,
         o_b_csr_wr,
         o_b_is_spec_op,
         o_b_is_idle,
         o_b_r1,
         o_b_r2,
         o_b_src2_is_imm
  } = head_way ? data_way0[head_way0] : data_way1[head_way1];


  assign input_data0 = {
    i_a_pc,
    i_a_optype,
    i_a_opcode,
    i_a_dest,
    i_a_imm,
    i_a_pred_br_taken,
    i_a_pred_br_target,
    i_a_br_type,
    i_a_br_condition,
    i_a_br_target,
    i_a_br_taken,
    i_a_have_excp,
    i_a_excp_type,
    i_a_csr_addr,
    i_a_csr_wr,
    i_a_is_spec_op,
    i_a_is_idle,
    i_a_r1,
    i_a_r2,
    i_a_src2_is_imm
  };

  assign input_data1 = {
    i_b_pc,
    i_b_optype,
    i_b_opcode,
    i_b_dest,
    i_b_imm,
    i_b_pred_br_taken,
    i_b_pred_br_target,
    i_b_br_type,
    i_b_br_condition,
    i_b_br_target,
    i_b_br_taken,
    i_b_have_excp,
    i_b_excp_type,
    i_b_csr_addr,
    i_b_csr_wr,
    i_b_is_spec_op,
    i_b_is_idle,
    i_b_r1,
    i_b_r2,
    i_b_src2_is_imm
  };

`ifdef DIFFTEST_EN
  assign o_a_difftest = head_way ? difftest_way1[head_way1] : difftest_way0[head_way0];
  assign o_b_difftest = head_way ? difftest_way0[head_way0] : difftest_way1[head_way1];
`endif

  always_ff @(posedge clk) begin
    if (reset || flush) begin
      head_way <= 1'd0;
      head_way0 <= 3'd0;
      head_way1 <= 3'd0;
      tail_way <= 1'd0;
      tail_way0 <= 3'd0;
      tail_way1 <= 3'd0;
      length <= 5'd0;
    end else begin
      if (tail_way == 1'b0 && i_size == 2'd1 || i_size == 2'd2) tail_way0 <= tail_way0 + 3'd1;
      if (tail_way == 1'b1 && i_size == 2'd1 || i_size == 2'd2) tail_way1 <= tail_way1 + 3'd1;
      if (head_way == 1'b0 && o_size == 2'd1 || o_size == 2'd2) head_way0 <= head_way0 + 3'd1;
      if (head_way == 1'b1 && o_size == 2'd1 || o_size == 2'd2) head_way1 <= head_way1 + 3'd1;
      tail_way <= tail_way ^ i_size[0];
      head_way <= head_way ^ o_size[0];
      length   <= length + {2'b0, i_size} - {2'b0, o_size};
      if (i_size == 2'd1 || i_size == 2'd2) begin
        if (tail_way == 1'b0) data_way0[tail_way0] <= input_data0;
        else data_way1[tail_way1] <= input_data0;
`ifdef DIFFTEST_EN
        if (tail_way == 1'b0) difftest_way0[tail_way0] <= i_a_difftest;
        else difftest_way1[tail_way1] <= i_a_difftest;
`endif
      end
      if (i_size == 2'd2) begin
        if (tail_way == 1'b0) data_way1[tail_way1] <= input_data1;
        else data_way0[tail_way0] <= input_data1;
`ifdef DIFFTEST_EN
        if (tail_way == 1'b0) difftest_way1[tail_way1] <= i_b_difftest;
        else difftest_way0[tail_way0] <= i_b_difftest;
`endif
      end
    end
  end

endmodule
