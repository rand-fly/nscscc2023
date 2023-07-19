`include "definitions.svh"

module ifu(
    input wire          clk,
    input wire          reset,
    output logic [ 1:0] ibuf_input_size,
    input wire          ibuf_ready,
    output logic [31:0] pc1,
    output logic [31:0] inst1,
    output logic        pred_branch_taken1,
    output logic [31:0] pred_branch_target1,
    output logic [31:0] pc2,
    output logic [31:0] inst2,
    output logic        pred_branch_taken2,
    output logic [31:0] pred_branch_target2,

    output logic        have_exception,
    output exception_t  exception_type,

    input wire          branch_mistaken,
    input wire   [31:0] correct_target,
    input wire          raise_exception,
    input wire   [31:0] exception_target,
    input wire          rewind,
    input wire   [31:0] rewind_target,

    output logic        mmu_i_valid,
    output logic [31:0] mmu_i_addr,
    input wire          mmu_i_addr_ok,
    input wire          mmu_i_double,
    input wire          mmu_i_data_ok,
    input wire [63:0]   mmu_i_rdata,
    input wire          mmu_i_tlbr,
    input wire          mmu_i_pif,
    input wire          mmu_i_ppi
);

logic [31:0] pc_start;
logic [31:0] pc_start_sent;
logic        is_sent_double;
logic        pending_data;
logic        cancel; 
logic [31:0] pred_pc_start;

assign pred_pc_start = pc_start + (mmu_i_double ? 32'd8 : 32'd4);
assign pred_branch_taken1 = 1'b0;
assign pred_branch_target1 = 32'd0;
assign pred_branch_taken2 = 1'b0;
assign pred_branch_target2 = 32'd0;

assign pc1 = have_exception ? pc_start : pc_start_sent;
assign pc2 = pc1 + 32'd4;

assign inst1 = mmu_i_rdata[31: 0];
assign inst2 = mmu_i_rdata[63:32];

always_ff @(posedge clk) begin
    if (reset) begin
        pc_start <= 32'h1c000000;
        pending_data <= 1'b0;
        cancel <= 1'b0;
    end
    else begin
        if (branch_mistaken || raise_exception || rewind) begin
            if ((mmu_i_valid && mmu_i_addr_ok) || (pending_data && !mmu_i_data_ok)) begin
                cancel <= 1'b1;
                pending_data <= 1'b1;
            end
            else if (mmu_i_data_ok) begin
                if (cancel) begin
                    cancel <= 1'b0;
                end
                pending_data <= 1'b0;
            end
            if (raise_exception) begin
                pc_start <= exception_target;
            end
            else if (rewind) begin
                pc_start <= rewind_target;
            end
            else begin
                pc_start <= correct_target;
            end
        end
        else begin
            if (mmu_i_data_ok) begin
                if (cancel) begin
                    cancel <= 1'b0;
                end
                pending_data <= 1'b0;
            end
            if (mmu_i_valid && mmu_i_addr_ok) begin
                pc_start_sent <= pc_start;
                is_sent_double <= mmu_i_double;
                pc_start <= pred_pc_start;
                pending_data <= 1'b1;
            end
        end
    end
end

assign mmu_i_valid = !reset && !have_exception && ibuf_ready && (!pending_data || mmu_i_data_ok);
assign mmu_i_addr = pc_start;
assign ibuf_input_size = have_exception           ? 2'd1 :
                         !mmu_i_data_ok || cancel ? 2'd0 :
                         is_sent_double           ? 2'd2 :
                                                    2'd1 ;

always_comb begin
    if (pc_start[1:0] != 2'h0) begin
        have_exception = 1'b1;
        exception_type = ADEF;
    end
    else if(mmu_i_tlbr) begin
        have_exception = 1'b1;
        exception_type = TLBR;
    end
    else if(mmu_i_pif) begin
        have_exception = 1'b1;
        exception_type = PIF;
    end
    else if(mmu_i_ppi) begin
        have_exception = 1'b1;
        exception_type = PPI;
    end
    else begin
        have_exception = 1'b0;
        exception_type = ADEF;
    end
end

endmodule