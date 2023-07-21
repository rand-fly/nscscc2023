`include "definitions.svh"

module mem_stage(
    input wire            clk,
    input wire            reset,
    input wire            flush,

    input wire            ex_both_ready,
    output wire           mem_ready,
    output wire           mem_stall,
    input wire            allowout,

    input wire            ex_valid,
    input wire [31:0]     ex_pc,
    input wire [31:0]     ex_result,
    input wire [ 4:0]     ex_dest,
    input wire [31:0]     ex_addr,
    input wire mem_type_t ex_mem_type,
    input wire mem_size_t ex_mem_size,
    input wire            ex_got_data_ok,
    input wire [31:0]     ex_ld_data,

    output logic          mem_valid,
    output logic [31:0]   mem_pc,
    output logic [31:0]   mem_result,
    output logic [ 4:0]   mem_dest,
    output logic          mem_forwardable,

    input wire            mmu_data_ok,
    input wire [31:0]     mmu_rdata
);

logic        MEM_valid;
logic [31:0] MEM_pc;
logic [31:0] MEM_result;
logic [ 4:0] MEM_dest;
logic [31:0] MEM_addr;
mem_type_t   MEM_mem_type;
mem_size_t   MEM_mem_size;
logic        MEM_got_data_ok;
logic [31:0] MEM_ld_data;

logic [31:0] load_data;
logic [31:0] load_result;

assign load_data = MEM_got_data_ok ? MEM_ld_data : mmu_rdata;

assign mem_ready = MEM_mem_type == MEM_NOP || MEM_got_data_ok;
assign mem_stall = MEM_valid && !mem_ready || !allowout;

always_ff @(posedge clk) begin
    if (reset || flush) begin
        MEM_valid    <= 1'b0;
    end
    else if (!mem_stall) begin
        MEM_valid <= ex_both_ready && ex_valid;
    end

    if (!mem_stall && ex_both_ready && ex_valid) begin
        MEM_pc          <= ex_pc;
        MEM_result      <= ex_result;
        MEM_dest        <= ex_dest;
        MEM_addr        <= ex_addr;
        MEM_mem_type    <= ex_mem_type;
        MEM_mem_size    <= ex_mem_size;
        MEM_got_data_ok <= ex_got_data_ok;
        MEM_ld_data     <= ex_ld_data;
    end

    if (mmu_data_ok) begin
        MEM_got_data_ok <= 1'b1;
        MEM_ld_data <= mmu_rdata;
    end
end

assign mem_valid = MEM_valid;
assign mem_pc = MEM_pc;
assign mem_result = (MEM_mem_type == MEM_LOAD_S || MEM_mem_type == MEM_LOAD_U) ? load_result : MEM_result;
assign mem_dest = MEM_dest;
assign mem_forwardable = MEM_mem_type == MEM_NOP;

always_comb begin
    unique case (MEM_mem_size)
        MEM_BYTE: begin
            logic [7:0] load_b;
            unique case (MEM_addr[1:0])
                2'b00 : load_b = load_data[ 7: 0];
                2'b01 : load_b = load_data[15: 8];
                2'b10 : load_b = load_data[23:16];
                2'b11 : load_b = load_data[31:24];
            endcase
            load_result = {{24{load_b[ 7] && MEM_mem_type == MEM_LOAD_S}}, load_b};
        end
        MEM_HALF: begin
            logic [15:0] load_h;
            unique case (MEM_addr[1])
                1'b0 : load_h = load_data[15: 0];
                1'b1 : load_h = load_data[31:16];
            endcase
            load_result = {{16{load_h[15] && MEM_mem_type == MEM_LOAD_S}}, load_h};
        end
        MEM_WORD: begin
            load_result = load_data;
        end
    endcase
end

endmodule