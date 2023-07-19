`include "definitions.svh"

module wb_ctrl(
    input wire            clk,
    input wire            reset,

    input wire            mem_ready,
    input wire            allowout,
    output logic          wb_valid,
    output logic          wb_ready,
    output logic          wb_stall,

    input wire            mem_valid,
    input wire [31:0]     mem_pc,
    input wire [31:0]     mem_result,
    input wire mem_type_t mem_mem_type,
    input wire mem_size_t mem_mem_size,
    input wire [ 4:0]     mem_dest,

    input wire            mmu_data_ok,
    input wire [31: 0]    mmu_rdata,

    output logic          rf_we,
    output logic [ 4:0]   rf_waddr,
    output logic [31:0]   rf_wdata,

    output logic          wb_forwardable,
    output logic [31:0]   wb_pc,
    output logic [ 4:0]   wb_dest,
    output logic [31:0]   wb_result

`ifdef DIFFTEST_EN
   ,input wire difftest_t  mem_difftest,
    output difftest_t      wb_difftest
`endif
);

logic          WB_valid;
logic [31:0]   WB_pc;
logic [31:0]   WB_result;
mem_type_t     WB_mem_type;
mem_size_t     WB_mem_size;
logic [ 4:0]   WB_dest;

logic [31:0]   load_result;

assign wb_valid = WB_valid;
assign wb_ready = WB_valid && (WB_mem_type == MEM_NOP || mmu_data_ok);
assign wb_stall = WB_valid && (!wb_ready || !allowout);

always_ff @(posedge clk) begin
    if (reset || (!wb_stall && !mem_ready)) begin
        WB_valid    <= 1'b0;
    end
    else if (!wb_stall) begin
        WB_valid   <= mem_valid;
        WB_pc      <= mem_pc;
        WB_result  <= mem_result;
        WB_mem_type<= mem_mem_type;
        WB_mem_size<= mem_mem_size;
        WB_dest    <= mem_dest;
    end
end

always_comb begin
    unique case (WB_mem_size)
        MEM_BYTE: begin
            logic [7:0] load_b;
            unique case (WB_result[1:0])
                2'b00 : load_b = mmu_rdata[ 7: 0];
                2'b01 : load_b = mmu_rdata[15: 8];
                2'b10 : load_b = mmu_rdata[23:16];
                2'b11 : load_b = mmu_rdata[31:24];
            endcase
            load_result = {{24{load_b[ 7] && WB_mem_type == MEM_LOAD_S}}, load_b};
        end
        MEM_HALF: begin
            logic [15:0] load_h;
            unique case (WB_result[1])
                1'b0 : load_h = mmu_rdata[15: 0];
                1'b1 : load_h = mmu_rdata[31:16];
            endcase
            load_result = {{16{load_h[15] && WB_mem_type == MEM_LOAD_S}}, load_h};
        end
        MEM_WORD: begin
            load_result = mmu_rdata;
        end
    endcase
end

// assign wb_forwardable = wb_ready;
assign wb_forwardable = WB_mem_type == MEM_NOP;
assign wb_dest        = WB_dest;
// assign wb_result      = (WB_mem_type == MEM_LOAD_S || WB_mem_type == MEM_LOAD_U) ? load_result : WB_result;
assign wb_result      = WB_result;
assign wb_pc          = WB_pc;

assign rf_we    = allowout && wb_valid;
assign rf_waddr = WB_dest;
assign rf_wdata = (WB_mem_type == MEM_LOAD_S || WB_mem_type == MEM_LOAD_U) ? load_result : WB_result;

endmodule