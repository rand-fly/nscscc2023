`include "definitions.svh"

module mem_ctrl(
    input wire             clk,
    input wire             reset,

    input wire             flush,
    input wire             ex_ready,
    input wire             allowout,
    input wire             cancel,
    output logic           mem_valid,
    output logic           mem_ready,
    output logic           mem_stall,

    input wire             ex_valid,
    input wire [31:0]      ex_pc,
    input wire             ex_have_exception,
    input wire exception_t ex_exception_type,
    input wire [31:0]      ex_result,
    input wire [ 4:0]      ex_dest,
    input wire mem_type_t  ex_mem_type,
    input wire mem_size_t  ex_mem_size,
    input wire [31:0]      ex_st_data,

    output logic           mem_forwardable,
    output logic [31:0]    mem_pc,
    output logic           mem_have_exception,
    output exception_t     mem_exception_type,
    output logic [31:0]    mem_result,
    output mem_type_t      mem_mem_type,
    output mem_size_t      mem_mem_size,
    output logic [ 4:0]    mem_dest,

    input wire             mem_csr_result_valid,
    input wire   [31:0]    mem_csr_result,

    output logic           mmu_valid,
    output logic [31:0]    mmu_addr,
    output logic           mmu_we,
    output logic [ 1:0]    mmu_size,
    output logic [ 3:0]    mmu_wstrb,
    output logic [31:0]    mmu_wdata,
    input wire             mmu_addr_ok,
    input wire             mmu_tlbr,
    input wire             mmu_pil,
    input wire             mmu_pis,
    input wire             mmu_ppi,
    input wire             mmu_pme

`ifdef DIFFTEST_EN
   ,input wire difftest_t  ex_difftest,
    output difftest_t      mem_difftest
`endif
);

logic        MEM_valid;
logic [31:0] MEM_pc;
logic        MEM_have_exception;
exception_t  MEM_exception_type;
logic [31:0] MEM_result;
logic [ 4:0] MEM_dest;
mem_type_t   MEM_mem_type;
mem_size_t   MEM_mem_size;
logic [31:0] MEM_st_data;

logic        waiting_for_out;

assign mem_valid = MEM_valid && !cancel;
assign mem_ready = MEM_valid && (!mmu_valid || mmu_addr_ok);
assign mem_stall = MEM_valid && (!mem_ready || !allowout);

always_ff @(posedge clk) begin
    if (reset || flush || (!mem_stall && !ex_ready)) begin
        MEM_valid     <= 1'b0;
    end
    else if (!mem_stall) begin
        MEM_valid          <= ex_valid;
        MEM_pc             <= ex_pc;
        MEM_have_exception <= ex_have_exception;
        MEM_exception_type <= ex_exception_type;
        MEM_result         <= ex_result;
        MEM_dest           <= ex_dest;
        MEM_mem_type       <= ex_mem_type;
        MEM_mem_size       <= ex_mem_size;
        MEM_st_data        <= ex_st_data;
    end
end

assign mem_pc      = MEM_pc;
assign mem_result  = mem_csr_result_valid ? mem_csr_result : MEM_result;
assign mem_dest    = MEM_dest;
assign mem_mem_type = MEM_mem_type;
assign mem_mem_size = MEM_mem_size;

assign mmu_addr = MEM_result;

assign mmu_valid = MEM_valid && !waiting_for_out && MEM_mem_type != MEM_NOP && !mem_have_exception;

always_ff @(posedge clk) begin
    if (reset || flush) begin
        waiting_for_out <= 1'b0;
    end
    else if (!allowout && mmu_valid && mmu_addr_ok) begin
        waiting_for_out <= 1'b1;
    end
    else if (allowout) begin
        waiting_for_out <= 1'b0;
    end
end

assign mem_forwardable = !MEM_have_exception && MEM_mem_type == MEM_NOP;

assign mmu_size = MEM_mem_size == MEM_BYTE ? 2'd0 :
                  MEM_mem_size == MEM_HALF ? 2'd1 :
                                             2'd2 ;

always_comb begin
    if (MEM_mem_type == MEM_STORE) begin
        mmu_we = 1'b1;
        unique case (MEM_mem_size)
            MEM_BYTE: begin
                unique case (MEM_result[1:0])
                    2'b00 : mmu_wstrb = 4'b0001;
                    2'b01 : mmu_wstrb = 4'b0010;
                    2'b10 : mmu_wstrb = 4'b0100;
                    2'b11 : mmu_wstrb = 4'b1000;
                endcase
                mmu_wdata = {4{MEM_st_data[ 7:0]}};
            end
            MEM_HALF: begin
                unique case (MEM_result[1])
                    1'b0 : mmu_wstrb = 4'b0011;
                    1'b1 : mmu_wstrb = 4'b1100;
                endcase
                mmu_wdata = {2{MEM_st_data[15:0]}};
            end
            MEM_WORD: begin
                mmu_wstrb    = 4'b1111;
                mmu_wdata = MEM_st_data;
            end
        endcase
    end
    else begin
        mmu_we = 1'b0;
        mmu_wstrb = 4'b0000;
        mmu_wdata = MEM_st_data;
    end
end

always_comb begin
    if (MEM_mem_type == MEM_NOP || MEM_have_exception) begin
        mem_have_exception = MEM_have_exception;
        mem_exception_type = MEM_exception_type;
    end
    else if (MEM_mem_size == MEM_HALF && MEM_result[0] || MEM_mem_size == MEM_WORD && MEM_result[1:0] != 2'h0) begin
        mem_have_exception = 1'b1;
        mem_exception_type = ALE;
    end
    else if(mmu_tlbr) begin
        mem_have_exception = 1'b1;
        mem_exception_type = TLBR;
    end
    else if(mmu_pil) begin
        mem_have_exception = 1'b1;
        mem_exception_type = PIL;
    end
    else if(mmu_pis) begin
        mem_have_exception = 1'b1;
        mem_exception_type = PIS;
    end
    else if(mmu_ppi) begin
        mem_have_exception = 1'b1;
        mem_exception_type = PPI;
    end
    else if(mmu_pme) begin
        mem_have_exception = 1'b1;
        mem_exception_type = PME;
    end
    else begin
        mem_have_exception = 1'b0;
        mem_exception_type = ALE;
    end
end

endmodule