`include "definitions.svh"

module mem_ctrl(
    input wire             clk,
    input wire             reset,

    input wire             valid,
    input wire [31:0]      addr,
    input wire mem_type_t  mem_type,
    input wire mem_size_t  mem_size,
    input wire [31:0]      st_data,
    input wire             allowout,

    output logic           ready,
    output logic           have_exception,
    output exception_t     exception_type,
    output logic           got_data_ok,
    output logic [31:0]    ld_data,


    output logic           mmu_valid,
    output logic [31:0]    mmu_addr,
    output logic           mmu_we,
    output logic [ 1:0]    mmu_size,
    output logic [ 3:0]    mmu_wstrb,
    output logic [31:0]    mmu_wdata,
    input wire             mmu_addr_ok,
    input wire             mmu_data_ok,
    input wire [31:0]      mmu_rdata,
    input wire             mmu_tlbr,
    input wire             mmu_pil,
    input wire             mmu_pis,
    input wire             mmu_ppi,
    input wire             mmu_pme
);

logic got_addr_ok;

assign mmu_addr = addr;
assign mmu_valid = valid && !got_addr_ok && mem_type != MEM_NOP && !have_exception;
assign ready = mmu_addr_ok || got_addr_ok;

always_ff @(posedge clk) begin
    if (reset || allowout) begin
        got_addr_ok <= 1'b0;
    end
    else if (mmu_valid && mmu_addr_ok) begin
        got_addr_ok <= 1'b1;
    end
end

always_ff @(posedge clk) begin
    if (reset || allowout) begin
        got_data_ok <= 1'b0;
    end
    else if (got_addr_ok && mmu_data_ok) begin
        got_data_ok <= 1'b1;
        ld_data <= mmu_rdata;
    end
end

assign mmu_size = mem_size == MEM_BYTE ? 2'd0 :
                  mem_size == MEM_HALF ? 2'd1 :
                                         2'd2 ;

always_comb begin
    if (mem_type == MEM_STORE) begin
        mmu_we = 1'b1;
        unique case (mem_size)
            MEM_BYTE: begin
                unique case (addr[1:0])
                    2'b00 : mmu_wstrb = 4'b0001;
                    2'b01 : mmu_wstrb = 4'b0010;
                    2'b10 : mmu_wstrb = 4'b0100;
                    2'b11 : mmu_wstrb = 4'b1000;
                endcase
                mmu_wdata = {4{st_data[ 7:0]}};
            end
            MEM_HALF: begin
                unique case (addr[1])
                    1'b0 : mmu_wstrb = 4'b0011;
                    1'b1 : mmu_wstrb = 4'b1100;
                endcase
                mmu_wdata = {2{st_data[15:0]}};
            end
            MEM_WORD: begin
                mmu_wstrb = 4'b1111;
                mmu_wdata = st_data;
            end
        endcase
    end
    else begin
        mmu_we = 1'b0;
        mmu_wstrb = 4'b0000;
        mmu_wdata = st_data;
    end
end

always_comb begin
    if (mem_type != MEM_NOP) begin
        if (mem_size == MEM_HALF && addr[0] || mem_size == MEM_WORD && addr[1:0] != 2'h0) begin
            have_exception = 1'b1;
            exception_type = ALE;
        end
        else if(mmu_tlbr) begin
            have_exception = 1'b1;
            exception_type = TLBR;
        end
        else if(mmu_pil) begin
            have_exception = 1'b1;
            exception_type = PIL;
        end
        else if(mmu_pis) begin
            have_exception = 1'b1;
            exception_type = PIS;
        end
        else if(mmu_ppi) begin
            have_exception = 1'b1;
            exception_type = PPI;
        end
        else if(mmu_pme) begin
            have_exception = 1'b1;
            exception_type = PME;
        end
        else begin
            have_exception = 1'b0;
            exception_type = ALE;
        end
    end
    else begin
        have_exception = 1'b0;
        exception_type = ALE;
    end
end

endmodule