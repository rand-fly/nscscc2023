`include "definitions.svh"

module ex_stage(
    input wire             clk,
    input wire             reset,

    input wire             flush,
    input wire             allowout,
    input wire             ro_ready,
    output logic           ex_valid,
    output logic           ex_ready,
    output logic           ex_stall,

    input wire             ro_a_valid,
    input wire [31:0]      ro_a_pc,
    input wire             ro_a_have_exception,
    input wire exception_t ro_a_exception_type,
    input wire opcode_t    ro_a_opcode,
    input wire [31:0]      ro_a_src1,
    input wire [31:0]      ro_a_src2,
    input wire [ 4:0]      ro_a_dest,
    input wire             ro_a_is_branch,
    input wire             ro_a_branch_condition,
    input wire [31:0]      ro_a_branch_target,
    input wire             ro_a_is_jirl,
    input wire             ro_a_pred_branch_taken,
    input wire [31:0]      ro_a_pred_branch_target,
    input wire mem_type_t  ro_a_mem_type,
    input wire mem_size_t  ro_a_mem_size,
    input wire [31:0]      ro_a_st_data,
    input wire             ro_a_is_spec_op,
    input wire spec_op_t   ro_a_spec_op,

    input wire             ro_b_valid,
    input wire [31:0]      ro_b_pc,
    input wire             ro_b_have_exception,
    input wire exception_t ro_b_exception_type,
    input wire opcode_t    ro_b_opcode,
    input wire [31:0]      ro_b_src1,
    input wire [31:0]      ro_b_src2,
    input wire [ 4:0]      ro_b_dest,
    input wire             ro_b_is_branch,
    input wire             ro_b_branch_condition,
    input wire [31:0]      ro_b_branch_target,
    input wire             ro_b_is_jirl,
    input wire             ro_b_pred_branch_taken,
    input wire [31:0]      ro_b_pred_branch_target,
    input wire mem_type_t  ro_b_mem_type,
    input wire mem_size_t  ro_b_mem_size,
    input wire [31:0]      ro_b_st_data,
    input wire             ro_b_is_spec_op,
    input wire spec_op_t   ro_b_spec_op,

    output logic           ex_a_valid,
    output logic           ex_a_forwardable,
    output logic [31:0]    ex_a_pc,
    output logic           ex_a_have_exception,
    output exception_t     ex_a_exception_type,
    output logic [31:0]    ex_a_result,
    output logic [ 4:0]    ex_a_dest,
    output logic           ex_a_branch_taken,
    output logic [31:0]    ex_a_branch_target,
    output logic           ex_a_branch_mistaken,
    output mem_type_t      ex_a_mem_type,
    output mem_size_t      ex_a_mem_size,
    output logic [31:0]    ex_a_st_data,
    output logic           ex_a_is_spec_op,
    output spec_op_t       ex_a_spec_op,

    output logic           ex_b_valid,
    output logic           ex_b_forwardable,
    output logic [31:0]    ex_b_pc,
    output logic           ex_b_have_exception,
    output exception_t     ex_b_exception_type,
    output logic [31:0]    ex_b_result,
    output logic [ 4:0]    ex_b_dest,
    output logic           ex_b_branch_taken,
    output logic [31:0]    ex_b_branch_target,
    output logic           ex_b_branch_mistaken,
    output mem_type_t      ex_b_mem_type,
    output mem_size_t      ex_b_mem_size,
    output logic [31:0]    ex_b_st_data,
    output logic           ex_b_is_spec_op,
    output spec_op_t       ex_b_spec_op
);

logic            EX_a_valid;
logic [31:0]     EX_a_pc;
logic            EX_a_have_exception;
exception_t      EX_a_exception_type;
opcode_t         EX_a_opcode;
logic [31:0]     EX_a_src1;
logic [31:0]     EX_a_src2;
logic [4 :0]     EX_a_dest;
logic            EX_a_is_branch;
logic            EX_a_branch_condition;
logic [31:0]     EX_a_branch_target;
logic            EX_a_is_jirl;
logic            EX_a_pred_branch_taken;
logic [31:0]     EX_a_pred_branch_target;
mem_type_t       EX_a_mem_type;
mem_size_t       EX_a_mem_size;
logic [31:0]     EX_a_st_data;
logic            EX_a_is_spec_op;
spec_op_t        EX_a_spec_op;

logic            EX_b_valid;
logic [31:0]     EX_b_pc;
logic            EX_b_have_exception;
exception_t      EX_b_exception_type;
opcode_t         EX_b_opcode;
logic [31:0]     EX_b_src1;
logic [31:0]     EX_b_src2;
logic [4 :0]     EX_b_dest;
logic            EX_b_is_branch;
logic            EX_b_branch_condition;
logic [31:0]     EX_b_branch_target;
logic            EX_b_is_jirl;
logic            EX_b_pred_branch_taken;
logic [31:0]     EX_b_pred_branch_target;
mem_type_t       EX_b_mem_type;
mem_size_t       EX_b_mem_size;
logic [31:0]     EX_b_st_data;
logic            EX_b_is_spec_op;
spec_op_t        EX_b_spec_op;

logic            a_is_alu_op;
logic            a_is_mul_op;
logic            a_is_div_op;
logic            a_coming_mul_op;
logic [31:0]     a_alu_result;
logic            a_mul_ready;
logic [32:0]     a_mul_src1;
logic [32:0]     a_mul_src2;
logic [63:0]     a_mul_result;
logic            a_mul_sign_ex;
logic            a_div_ready;
logic [63:0]     a_div_output;
logic            a_div_signed;
logic            a_div_start;
logic            a_div_sign;
logic            a_mod_sign;
logic [31:0]     a_div_result;
logic [31:0]     a_mod_result;

logic            b_is_alu_op;
logic            b_is_mul_op;
logic            b_is_div_op;
logic            b_coming_mul_op;
logic [31:0]     b_alu_result;
logic            b_mul_ready;
logic [32:0]     b_mul_src1;
logic [32:0]     b_mul_src2;
logic [63:0]     b_mul_result;
logic            b_mul_sign_ex;
logic            b_div_ready;
logic [63:0]     b_div_output;
logic            b_div_signed;
logic            b_div_start;
logic            b_div_sign;
logic            b_mod_sign;
logic [31:0]     b_div_result;
logic [31:0]     b_mod_result;

logic ex_a_ready;
logic ex_b_ready;

assign ex_valid = EX_a_valid || EX_b_valid;
assign ex_ready = ex_valid && (!EX_a_valid || ex_a_ready) && (!EX_b_valid || ex_b_ready);
assign ex_stall = ex_valid && (!ex_ready || !allowout);

always_ff @(posedge clk) begin
    if (reset || flush || (!ex_stall && !ro_ready)) begin
        EX_a_valid <= 1'b0;
        EX_b_valid <= 1'b0;
    end
    else if (!ex_stall) begin
        EX_a_valid              <= ro_a_valid;
        EX_a_pc                 <= ro_a_pc;
        EX_a_have_exception     <= ro_a_have_exception;
        EX_a_exception_type     <= ro_a_exception_type;
        EX_a_opcode             <= ro_a_opcode;
        EX_a_src1               <= ro_a_src1;
        EX_a_src2               <= ro_a_src2;
        EX_a_dest               <= ro_a_dest;
        EX_a_is_branch          <= ro_a_is_branch;
        EX_a_branch_condition   <= ro_a_branch_condition;
        EX_a_branch_target      <= ro_a_branch_target;
        EX_a_is_jirl            <= ro_a_is_jirl;
        EX_a_pred_branch_taken  <= ro_a_pred_branch_taken;
        EX_a_pred_branch_target <= ro_a_pred_branch_target;
        EX_a_mem_type           <= ro_a_mem_type;
        EX_a_mem_size           <= ro_a_mem_size;
        EX_a_st_data            <= ro_a_st_data;
        EX_a_is_spec_op         <= ro_a_is_spec_op;
        EX_a_spec_op            <= ro_a_spec_op;
        
        EX_b_valid              <= ro_b_valid;
        EX_b_pc                 <= ro_b_pc;
        EX_b_have_exception     <= ro_b_have_exception;
        EX_b_exception_type     <= ro_b_exception_type;
        EX_b_opcode             <= ro_b_opcode;
        EX_b_src1               <= ro_b_src1;
        EX_b_src2               <= ro_b_src2;
        EX_b_dest               <= ro_b_dest;
        EX_b_is_branch          <= ro_b_is_branch;
        EX_b_branch_condition   <= ro_b_branch_condition;
        EX_b_branch_target      <= ro_b_branch_target;
        EX_b_is_jirl            <= ro_b_is_jirl;
        EX_b_pred_branch_taken  <= ro_b_pred_branch_taken;
        EX_b_pred_branch_target <= ro_b_pred_branch_target;
        EX_b_mem_type           <= ro_b_mem_type;
        EX_b_mem_size           <= ro_b_mem_size;
        EX_b_st_data            <= ro_b_st_data;
        EX_b_is_spec_op         <= ro_b_is_spec_op;
        EX_b_spec_op            <= ro_b_spec_op;
    end
end

always_ff @(posedge clk) begin
    if (reset || flush) begin
        a_mul_ready <= 1'b0;
        a_div_start <= 1'b0;
        b_mul_ready <= 1'b0;
        b_div_start <= 1'b0;
    end
    else begin
        if (a_coming_mul_op) a_mul_ready <= 1'b0;
        if (b_coming_mul_op) b_mul_ready <= 1'b0;

        if (EX_a_valid && a_is_mul_op && !a_mul_ready) begin
            a_mul_ready <= 1'b1;
        end
        if (EX_b_valid && b_is_mul_op && !b_mul_ready) begin
            b_mul_ready <= 1'b1;
        end

        if (a_div_ready)
            a_div_start <= 1'b0;
        else if (EX_a_valid && a_is_div_op && !a_div_start)
            a_div_start <= 1'b1;

        if (b_div_ready)
            b_div_start <= 1'b0;
        else if (EX_b_valid && b_is_div_op && !b_div_start)
            b_div_start <= 1'b1;
    end
end

assign ex_a_valid          = EX_a_valid;
assign ex_a_ready          = EX_a_valid && !((a_is_mul_op && !a_mul_ready) || (a_is_div_op && !a_div_ready));
assign ex_a_forwardable    = ex_a_ready && !EX_a_have_exception && EX_a_mem_type == MEM_NOP && !EX_a_is_spec_op;
assign ex_a_pc             = EX_a_pc;
assign ex_a_have_exception = EX_a_have_exception;
assign ex_a_exception_type = EX_a_exception_type;
assign ex_a_dest           = EX_a_dest;
assign ex_a_mem_type       = EX_a_mem_type;
assign ex_a_mem_size       = EX_a_mem_size;
assign ex_a_st_data        = EX_a_st_data;
assign ex_a_is_spec_op     = EX_a_valid && EX_a_is_spec_op;
assign ex_a_spec_op        = EX_a_spec_op;

assign ex_b_valid          = EX_b_valid;
assign ex_b_ready          = EX_b_valid && !((b_is_mul_op && !b_mul_ready) || (b_is_div_op && !b_div_ready));
assign ex_b_forwardable    = ex_b_ready && !EX_b_have_exception && EX_b_mem_type == MEM_NOP && !EX_b_is_spec_op;
assign ex_b_pc             = EX_b_pc;
assign ex_b_have_exception = EX_b_have_exception;
assign ex_b_exception_type = EX_b_exception_type;
assign ex_b_dest           = EX_b_dest;
assign ex_b_mem_type       = EX_b_mem_type;
assign ex_b_mem_size       = EX_b_mem_size;
assign ex_b_st_data        = EX_b_st_data;
assign ex_b_is_spec_op     = EX_b_valid && EX_b_is_spec_op;
assign ex_b_spec_op        = EX_b_spec_op;

assign a_is_alu_op = EX_a_opcode[4] == 1'b0;
assign a_is_mul_op = EX_a_opcode[4:3] == 2'b10;
assign a_is_div_op = EX_a_opcode[4:3] == 2'b11;
assign a_coming_mul_op = ro_a_opcode[4:3] == 2'b10;
assign a_mul_sign_ex = EX_a_opcode == OP_MULH;
assign a_mul_src1 = {a_mul_sign_ex && EX_a_src1[31], EX_a_src1};
assign a_mul_src2 = {a_mul_sign_ex && EX_a_src2[31], EX_a_src2};
assign a_div_signed = EX_a_opcode == OP_DIV || EX_a_opcode == OP_MOD;
assign a_div_sign = a_div_signed && (EX_a_src1[31] ^ EX_a_src2[31]);
assign a_mod_sign = a_div_signed && EX_a_src1[31];
assign a_div_result = a_div_sign ? -a_div_output[63:32] : a_div_output[63:32];
assign a_mod_result = a_mod_sign ? -a_div_output[31: 0] : a_div_output[31: 0];

assign b_is_alu_op = EX_b_opcode[4] == 1'b0;
assign b_is_mul_op = EX_b_opcode[4:3] == 2'b10;
assign b_is_div_op = EX_b_opcode[4:3] == 2'b11;
assign b_coming_mul_op = ro_b_opcode[4:3] == 2'b10;
assign b_mul_sign_ex = EX_b_opcode == OP_MULH;
assign b_mul_src1 = {b_mul_sign_ex && EX_b_src1[31], EX_b_src1};
assign b_mul_src2 = {b_mul_sign_ex && EX_b_src2[31], EX_b_src2};
assign b_div_signed = EX_b_opcode == OP_DIV || EX_b_opcode == OP_MOD;
assign b_div_sign = b_div_signed && (EX_b_src1[31] ^ EX_b_src2[31]);
assign b_mod_sign = b_div_signed && EX_b_src1[31];
assign b_div_result = b_div_sign ? -b_div_output[63:32] : b_div_output[63:32];
assign b_mod_result = b_mod_sign ? -b_div_output[31: 0] : b_div_output[31: 0];

alu alu_a (
    .op(EX_a_opcode),
    .src1(EX_a_src1),
    .src2(EX_a_src2),
    .result(a_alu_result)
);

alu alu_b (
    .op(EX_b_opcode),
    .src1(EX_b_src1),
    .src2(EX_b_src2),
    .result(b_alu_result)
);

mult_gen_0 mul_a (
  .CLK(clk),
  .A(a_mul_src1),
  .B(a_mul_src2),
  .CE(a_is_mul_op),
  .P(a_mul_result)
);

mult_gen_0 mul_b (
  .CLK(clk),
  .A(b_mul_src1),
  .B(b_mul_src2),
  .CE(b_is_mul_op),
  .P(b_mul_result)
);


div_gen_0 div_a (
    .aclk(clk),
    .s_axis_divisor_tvalid(EX_a_valid && a_is_div_op && !a_div_start),
    .s_axis_divisor_tdata((a_div_signed && EX_a_src2[31]) ? -EX_a_src2 : EX_a_src2),
    .s_axis_dividend_tvalid(EX_a_valid && a_is_div_op && !a_div_start),
    .s_axis_dividend_tdata((a_div_signed && EX_a_src1[31]) ? -EX_a_src1 : EX_a_src1),
    .m_axis_dout_tvalid(a_div_ready),
    .m_axis_dout_tdata(a_div_output)
);

div_gen_0 div_b (
    .aclk(clk),
    .s_axis_divisor_tvalid(EX_b_valid && b_is_div_op && !b_div_start),
    .s_axis_divisor_tdata((b_div_signed && EX_b_src2[31]) ? -EX_b_src2 : EX_b_src2),
    .s_axis_dividend_tvalid(EX_b_valid &&b_is_div_op && !b_div_start),
    .s_axis_dividend_tdata((b_div_signed && EX_b_src1[31]) ? -EX_b_src1 : EX_b_src1),
    .m_axis_dout_tvalid(b_div_ready),
    .m_axis_dout_tdata(b_div_output)
);

assign ex_a_result = EX_a_is_jirl ? EX_a_pc + 32'd4 :
                     {32{a_is_alu_op}} & a_alu_result
                   | {32{EX_a_opcode == OP_MUL}} & a_mul_result[31:0]
                   | {32{EX_a_opcode == OP_MULH || EX_a_opcode == OP_MULHU}} & a_mul_result[63:32]
                   | {32{EX_a_opcode == OP_DIV || EX_a_opcode == OP_DIVU}} & a_div_result
                   | {32{EX_a_opcode == OP_MOD || EX_a_opcode == OP_MODU}} & a_mod_result;

assign ex_b_result = EX_b_is_jirl ? EX_b_pc + 32'd4 :
                     {32{b_is_alu_op}} & b_alu_result
                   | {32{EX_b_opcode == OP_MUL}} & b_mul_result[31:0]
                   | {32{EX_b_opcode == OP_MULH || EX_b_opcode == OP_MULHU}} & b_mul_result[63:32]
                   | {32{EX_b_opcode == OP_DIV || EX_b_opcode == OP_DIVU}} & b_div_result
                   | {32{EX_b_opcode == OP_MOD || EX_b_opcode == OP_MODU}} & b_mod_result;

assign ex_a_branch_taken = EX_a_is_branch && (EX_a_is_jirl || EX_a_branch_condition == a_alu_result[0]);

assign ex_a_branch_mistaken = ex_a_valid && !ex_stall && (ex_a_branch_taken != EX_a_pred_branch_taken
                                          || ex_a_branch_taken && ex_a_branch_target != EX_a_pred_branch_target);

assign ex_a_branch_target  = EX_a_is_jirl ? a_alu_result : EX_a_branch_target;


assign ex_b_branch_taken = EX_b_is_branch && (EX_b_is_jirl || EX_b_branch_condition == b_alu_result[0]);

assign ex_b_branch_mistaken = ex_b_valid && !ex_stall && (ex_b_branch_taken != EX_b_pred_branch_taken
                                          || ex_b_branch_taken && ex_b_branch_target != EX_b_pred_branch_target);

assign ex_b_branch_target  = EX_b_is_jirl ? b_alu_result : EX_b_branch_target;

endmodule