`include "definitions.svh"

module forwarding_unit (
    input wire   [ 4:0]  addr,
    output logic         valid,
    output logic [31:0]  data,

    output logic  [ 4:0] rf_addr,
    input wire    [31:0] rf_data,

    input wire           ex_a_valid,
    input wire           ex_a_forwardable,
    input wire    [ 4:0] ex_a_dest,
    input wire    [31:0] ex_a_result,
    input wire           ex_b_valid,
    input wire           ex_b_forwardable,
    input wire    [ 4:0] ex_b_dest,
    input wire    [31:0] ex_b_result,

    input wire           mem_a_valid,
    input wire           mem_a_forwardable,
    input wire    [ 4:0] mem_a_dest,
    input wire    [31:0] mem_a_result,
    input wire           mem_b_valid,
    input wire           mem_b_forwardable,
    input wire    [ 4:0] mem_b_dest,
    input wire    [31:0] mem_b_result,

    input wire           wb_a_valid,
    input wire           wb_a_forwardable,
    input wire    [ 4:0] wb_a_dest,
    input wire    [31:0] wb_a_result,
    input wire           wb_b_valid,
    input wire           wb_b_forwardable,
    input wire    [ 4:0] wb_b_dest,
    input wire    [31:0] wb_b_result
);

assign rf_addr = addr;

always_comb begin
    if (addr == 5'd0) begin
        valid = 1'b1;
        data = 32'h0;
    end
    else if (ex_b_valid && addr == ex_b_dest) begin
        valid = ex_b_forwardable;
        data = ex_b_result;
    end
    else if (ex_a_valid && addr == ex_a_dest) begin
        valid = ex_a_forwardable;
        data = ex_a_result;
    end
    else if (mem_b_valid && addr == mem_b_dest) begin
        valid = mem_b_forwardable;
        data = mem_b_result;
    end
    else if (mem_a_valid && addr == mem_a_dest) begin
        valid = mem_a_forwardable;
        data = mem_a_result;
    end
    else if (wb_b_valid && addr == wb_b_dest) begin
        valid = wb_b_forwardable;
        data = wb_b_result;
    end
    else if (wb_a_valid && addr == wb_a_dest) begin
        valid = wb_a_forwardable;
        data = wb_a_result;
    end
    else begin
        valid = 1'b1;
        data = rf_data;
    end
end

endmodule