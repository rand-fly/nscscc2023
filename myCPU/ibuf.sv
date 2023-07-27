`include "definitions.svh"

typedef struct packed {
  logic [31:0] pc;
  optype_t     optype;
  opcode_t     opcode;
  logic [4:0]  dest;
  logic [31:0] imm;
  logic        pred_br_taken;
  logic [31:0] pred_br_target;
  logic        is_br;
  logic        br_condition;
  logic [31:0] br_target;
  logic        is_jirl;
  logic        have_excp;
  excp_t       excp_type;
  csr_addr_t   csr_addr;
  logic        csr_wr;
  logic [4:0]  r1;
  logic [4:0]  r2;
  logic        src2_is_imm;
} ibuf_entry_t;

module ibuf (
    input                    clk,
    input                    reset,
    input                    flush,
    input                    interrupt,
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
    input                    i_a_is_br,
    input                    i_a_br_condition,
    input             [31:0] i_a_br_target,
    input                    i_a_is_jirl,
    input                    i_a_have_excp,
    input  excp_t            i_a_excp_type,
    input  csr_addr_t        i_a_csr_addr,
    input                    i_a_csr_wr,
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
    input                    i_b_is_br,
    input                    i_b_br_condition,
    input             [31:0] i_b_br_target,
    input                    i_b_is_jirl,
    input                    i_b_have_excp,
    input  excp_t            i_b_excp_type,
    input  csr_addr_t        i_b_csr_addr,
    input                    i_b_csr_wr,
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
    output                   o_a_is_br,
    output                   o_a_br_condition,
    output            [31:0] o_a_br_target,
    output                   o_a_is_jirl,
    output                   o_a_have_excp,
    output excp_t            o_a_excp_type,
    output csr_addr_t        o_a_csr_addr,
    output                   o_a_csr_wr,
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
    output                   o_b_is_br,
    output                   o_b_br_condition,
    output            [31:0] o_b_br_target,
    output                   o_b_is_jirl,
    output                   o_b_have_excp,
    output excp_t            o_b_excp_type,
    output csr_addr_t        o_b_csr_addr,
    output                   o_b_csr_wr,
    output            [ 4:0] o_b_r1,
    output            [ 4:0] o_b_r2,
    output                   o_b_src2_is_imm
);

  ibuf_entry_t data[8];

`ifdef DIFFTEST_EN
  difftest_t difftest[8];
`endif

  logic [2:0] head;
  logic [2:0] tail;
  logic [3:0] length;

  assign i_ready = length <= 4'd2; // 本周期最多可能进来两条，同时最多可能发起两条请求

  assign o_a_valid = length >= 4'd1;
  assign{o_a_pc,
         o_a_optype,
         o_a_opcode,
         o_a_dest,
         o_a_imm,
         o_a_pred_br_taken,
         o_a_pred_br_target,
         o_a_is_br,
         o_a_br_condition,
         o_a_br_target,
         o_a_is_jirl,
         o_a_have_excp,
         o_a_excp_type,
         o_a_csr_addr,
         o_a_csr_wr,
         o_a_r1,
         o_a_r2,
         o_a_src2_is_imm
        } = data[head];

  assign o_b_valid = length >= 4'd2;
  assign{o_b_pc,
         o_b_optype,
         o_b_opcode,
         o_b_dest,
         o_b_imm,
         o_b_pred_br_taken,
         o_b_pred_br_target,
         o_b_is_br,
         o_b_br_condition,
         o_b_br_target,
         o_b_is_jirl,
         o_b_have_excp,
         o_b_excp_type,
         o_b_csr_addr,
         o_b_csr_wr,
         o_b_r1,
         o_b_r2,
         o_b_src2_is_imm
        } = data[head + 1'b1];


`ifdef DIFFTEST_EN
  assign o_a_difftest = difftest[head];
  assign o_b_difftest = difftest[head+1'b1];
`endif

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
        data[tail] <= {
          i_a_pc,
          i_a_optype,
          i_a_opcode,
          i_a_dest,
          i_a_imm,
          i_a_pred_br_taken,
          i_a_pred_br_target,
          i_a_is_br,
          i_a_br_condition,
          i_a_br_target,
          i_a_is_jirl,
          i_a_have_excp || interrupt,
          interrupt ? INT : i_a_excp_type,
          i_a_csr_addr,
          i_a_csr_wr,
          i_a_r1,
          i_a_r2,
          i_a_src2_is_imm
        };
`ifdef DIFFTEST_EN
        difftest[tail] <= i_a_difftest;
`endif
      end
      if (i_size == 2'd2) begin
        data[tail+1'b1] <= {
          i_b_pc,
          i_b_optype,
          i_b_opcode,
          i_b_dest,
          i_b_imm,
          i_b_pred_br_taken,
          i_b_pred_br_target,
          i_b_is_br,
          i_b_br_condition,
          i_b_br_target,
          i_b_is_jirl,
          i_b_have_excp,
          i_b_excp_type,
          i_b_csr_addr,
          i_b_csr_wr,
          i_b_r1,
          i_b_r2,
          i_b_src2_is_imm
        };
`ifdef DIFFTEST_EN
        difftest[tail+2'd1] <= i_b_difftest;
`endif
      end
    end
  end

endmodule
