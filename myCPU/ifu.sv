`include "definitions.svh"

module ifu (
    input                   clk,
    input                   reset,
    // from ibuf
    input                   ibuf_i_ready,
    // to ibuf
    output           [ 1:0] output_size,
    output           [31:0] pc0,
    output           [31:0] inst0,
    output reg              pred_br_taken0,
    output reg       [31:0] pred_br_target0,
    output           [31:0] pc1,
    output           [31:0] inst1,
    output reg              pred_br_taken1,
    output reg       [31:0] pred_br_target1,
    output reg              have_excp,
    output excp_t           excp_type,
    // from branch ctrl
    input                   br_mistaken,
    input  br_type_t        br_type,
    input            [31:0] right_target,
    input            [31:0] btb_target,
    input            [31:0] wrong_pc,
    input                   update_orien_en,
    input            [31:0] retire_pc,
    input                   right_orien,
    // from csr
    input                   raise_excp,
    input            [31:0] excp_target,
    input                   replay,
    input            [31:0] replay_target,
    // from mmu
    output                  mmu_i_req,
    output           [31:0] mmu_i_addr,
    input                   mmu_i_addr_ok,
    input                   mmu_i_double,
    input                   mmu_i_data_ok,
    input            [63:0] mmu_i_rdata,
    input                   mmu_i_tlbr,
    input                   mmu_i_pif,
    input                   mmu_i_ppi
);

  logic     [31:0] pc_start;
  logic     [31:0] pc_start_sent;
  logic            have_excp_inner;
  excp_t           excp_type_inner;

  logic            pred_br_taken0_inner;
  logic     [31:0] pred_br_target0_inner;
  logic            pred_br_taken1_inner;
  logic     [31:0] pred_br_target1_inner;


  logic            is_sent_double;
  logic            pending_data;
  logic            cancel;
  logic     [31:0] pred_pc_start;

  logic            br_mistaken_buf;
  br_type_t        br_type_buf;
  logic     [31:0] btb_target_buf;
  logic     [31:0] wrong_pc_buf;

  logic            ras_en;

  always_ff @(posedge clk) begin
    br_mistaken_buf <= br_mistaken;
    br_type_buf <= br_type;
    btb_target_buf <= btb_target;
    wrong_pc_buf <= wrong_pc;
  end

  always_ff @(posedge clk) begin
    ras_en <= mmu_i_req && mmu_i_addr_ok;
  end

  always_comb begin
    if (pred_br_taken0_inner) pred_pc_start = pred_br_target0_inner;
    else if (pred_br_taken1_inner && mmu_i_double) pred_pc_start = pred_br_target1_inner;
    else if (mmu_i_double) pred_pc_start = pc_start + 32'd8;
    else pred_pc_start = pc_start + 32'd4;
  end

  assign pc0   = pc_start_sent;
  assign pc1   = pc0 + 32'd4;

  assign inst0 = have_excp ? 32'h03400000  /* NOP */ : mmu_i_rdata[31:0];
  assign inst1 = mmu_i_rdata[63:32];

  always_ff @(posedge clk) begin
    if (reset) begin
      pc_start <= 32'h1c000000;
      pending_data <= 1'b0;
      cancel <= 1'b0;
      have_excp <= 1'b0;
    end else begin
      if (br_mistaken || raise_excp || replay) begin
        if ((mmu_i_req && mmu_i_addr_ok) || (pending_data && !mmu_i_data_ok)) begin
          cancel <= 1'b1;
          pending_data <= 1'b1;
        end else if (mmu_i_data_ok) begin
          if (cancel) begin
            cancel <= 1'b0;
          end
          pending_data <= 1'b0;
        end
        if (raise_excp) begin
          pc_start <= excp_target;
        end else if (replay) begin
          pc_start <= replay_target;
        end else begin
          pc_start <= right_target;
        end
        have_excp <= 1'b0;
      end else begin
        if (mmu_i_data_ok) begin
          if (cancel) begin
            cancel <= 1'b0;
          end
          pending_data <= 1'b0;
        end
        if (mmu_i_req && mmu_i_addr_ok || have_excp_inner && (!pending_data || mmu_i_data_ok)) begin
          pc_start_sent <= pc_start;
          pred_br_taken0 <= pred_br_taken0_inner;
          pred_br_target0 <= pred_br_target0_inner;
          pred_br_taken1 <= pred_br_taken1_inner;
          pred_br_target1 <= pred_br_target1_inner;
          is_sent_double <= mmu_i_double;
          have_excp <= have_excp_inner;
          excp_type <= excp_type_inner;
        end
        if (mmu_i_req && mmu_i_addr_ok) begin
          pc_start <= pred_pc_start;
          pending_data <= 1'b1;
        end
      end
    end
  end

  assign mmu_i_req = !reset && !have_excp_inner && ibuf_i_ready && (!pending_data || mmu_i_data_ok);
  assign mmu_i_addr = pc_start;
  assign output_size = have_excp                        ? 2'd1 :
                      !mmu_i_data_ok || cancel          ? 2'd0 :
                      is_sent_double && !pred_br_taken0 ? 2'd2 :
                                                          2'd1 ;

  always_comb begin
    if (pc_start[1:0] != 2'h0) begin
      have_excp_inner = 1'b1;
      excp_type_inner = ADEF;
    end else if (mmu_i_tlbr) begin
      have_excp_inner = 1'b1;
      excp_type_inner = TLBR;
    end else if (mmu_i_pif) begin
      have_excp_inner = 1'b1;
      excp_type_inner = PIF;
    end else if (mmu_i_ppi) begin
      have_excp_inner = 1'b1;
      excp_type_inner = PPI;
    end else begin
      have_excp_inner = 1'b0;
      excp_type_inner = ADEF;
    end
  end

  pred u_pred (
      .clk            (clk),
      .reset          (reset),
      .fetch_pc_0     (pc_start),
      .fetch_pc_1     (pc_start + 32'd4),
      .dual_issue     (mmu_i_double),
      .ras_en         (ras_en),
      .ret_pc_0       (pred_br_target0_inner),
      .ret_pc_1       (pred_br_target1_inner),
      .taken_0        (pred_br_taken0_inner),
      .taken_1        (pred_br_taken1_inner),
      .branch_mistaken(br_mistaken_buf),
      .wrong_pc       (wrong_pc_buf),
      .right_target   (btb_target_buf),
      .ins_type_w     (br_type_buf),
      .update_orien_en(update_orien_en),
      .retire_pc      (retire_pc),
      .right_orien    (right_orien)
  );


endmodule
