`include "definitions.svh"

module branch_ctrl(
    input wire          id_a_branch_mistaken,
    input wire          id_a_branch_taken,
    input wire [31:0]   id_a_branch_target,
    input wire [31:0]   id_a_pc,
    input wire          id_b_branch_mistaken,
    input wire          id_b_branch_taken,
    input wire [31:0]   id_b_branch_target,
    input wire [31:0]   id_b_pc,
    input wire          ex_a_branch_mistaken,
    input wire          ex_a_branch_taken,
    input wire [31:0]   ex_a_branch_target,
    input wire [31:0]   ex_a_pc,
    input wire          ex_b_branch_mistaken,
    input wire          ex_b_branch_taken,
    input wire [31:0]   ex_b_branch_target,
    input wire [31:0]   ex_b_pc,

    output logic        branch_mistaken,
    output logic [31:0] correct_target,
    output logic        flush_ibuf,
    output logic        flush_ro,
    output logic        flush_ex
);

always_comb begin
    if (ex_a_branch_mistaken) begin
        branch_mistaken = 1'b1;
        correct_target = ex_a_branch_taken ? ex_a_branch_target : ex_a_pc + 32'h4;
        flush_ibuf = 1'b1;
        flush_ro = 1'b1;
        flush_ex = 1'b1;
    end
    else if (ex_b_branch_mistaken) begin
        branch_mistaken = 1'b1;
        correct_target = ex_b_branch_taken ? ex_b_branch_target : ex_b_pc + 32'h4;
        flush_ibuf = 1'b1;
        flush_ro = 1'b1;
        flush_ex = 1'b1;
    end
    else if (id_a_branch_mistaken) begin
        branch_mistaken = 1'b1;
        correct_target = id_a_branch_taken ? id_a_branch_target : id_a_pc + 32'h4;
        flush_ibuf = 1'b1;
        flush_ro = 1'b0;
        flush_ex = 1'b0;
    end
    else if (id_b_branch_mistaken) begin
        branch_mistaken = 1'b1;
        correct_target = id_b_branch_taken ? id_b_branch_target : id_b_pc + 32'h4;
        flush_ibuf = 1'b1;
        flush_ro = 1'b0;
        flush_ex = 1'b0;
    end
    else begin
        branch_mistaken = 1'b0;
        correct_target = 32'h0;
        flush_ibuf = 1'b0;
        flush_ro = 1'b0;
        flush_ex = 1'b0;
    end
end


endmodule