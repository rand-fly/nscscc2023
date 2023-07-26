`include "definitions.svh"

module ibuf (
    input                clk,
    input                reset,
    input                flush,
    input                interrupt,
    // input
    input         [ 1:0] i_size,
    output               i_ready,
    // input port 0
    input         [31:0] i0_pc,
    input         [31:0] i0_inst,
    input                i0_pred_br_taken,
    input         [31:0] i0_pred_br_target,
    input                i0_have_excp,
    input  excp_t        i0_excp_type,
    // input port 1
    input         [31:0] i1_pc,
    input         [31:0] i1_inst,
    input                i1_pred_br_taken,
    input         [31:0] i1_pred_br_target,

    //output
    input         [ 1:0] o_size,
    //output port 0
    output               o0_valid,
    output        [31:0] o0_pc,
    output        [31:0] o0_inst,
    output               o0_pred_br_taken,
    output        [31:0] o0_pred_br_target,
    output               o0_have_excp,
    output excp_t        o0_excp_type,
    //output port 1
    output               o1_valid,
    output        [31:0] o1_pc,
    output        [31:0] o1_inst,
    output               o1_pred_br_taken,
    output        [31:0] o1_pred_br_target,
    output               o1_have_excp,
    output excp_t        o1_excp_type
);

  logic  [31:0] pc            [7:0];
  logic  [31:0] inst          [7:0];
  logic         pred_br_taken [7:0];
  logic  [31:0] pred_br_target[7:0];
  logic         have_excp     [7:0];
  excp_t        excp_type     [7:0];

  logic  [ 2:0] head;
  logic  [ 2:0] tail;
  logic  [ 3:0] length;

  assign i_ready = length <= 4'd4; // 本周期最多可能进来两条，同时最多可能发起两条请求

  assign o0_valid = length >= 4'd1;
  assign o0_pc = pc[head];
  assign o0_inst = inst[head];
  assign o0_pred_br_taken = pred_br_taken[head];
  assign o0_pred_br_target = pred_br_target[head];
  assign o0_have_excp = interrupt || have_excp[head];
  assign o0_excp_type = interrupt ? INT : excp_type[head];

  assign o1_valid = length >= 4'd2;
  assign o1_pc = pc[head+3'd1];
  assign o1_inst = inst[head+3'd1];
  assign o1_pred_br_taken = pred_br_taken[head+3'd1];
  assign o1_pred_br_target = pred_br_target[head+3'd1];
  assign o1_have_excp = have_excp[head+3'd1];
  assign o1_excp_type = excp_type[head+3'd1];

  always_ff @(posedge clk) begin
    if (reset || flush) begin
      head   <= 3'd0;
      tail   <= 3'd0;
      length <= 4'd0;
    end else begin
      tail   <= tail + i_size;
      head   <= head + o_size;
      length <= length + {1'b0, i_size} - {1'b0, o_size};
      if (i_size == 2'd1 || i_size == 2'd2) begin
        pc[tail] <= i0_pc;
        inst[tail] <= i0_inst;
        pred_br_taken[tail] <= i0_pred_br_taken;
        pred_br_target[tail] <= i0_pred_br_target;
        have_excp[tail] <= i0_have_excp;
        excp_type[tail] <= i0_excp_type;
      end
      if (i_size == 2'd2) begin
        pc[tail+3'd1] <= i1_pc;
        inst[tail+3'd1] <= i1_inst;
        pred_br_taken[tail+3'd1] <= i1_pred_br_taken;
        pred_br_target[tail+3'd1] <= i1_pred_br_target;
        have_excp[tail+3'd1] <= 1'b0;
      end
    end
  end

endmodule
