`include "definitions.svh"

`define R0 5'd0
`define R1 5'd1

module decoder(
    input wire             valid,
    input wire [31:0]      pc,
    input wire [31:0]      inst,
    input wire             if_have_exception,
    input wire exception_t if_exception_type,
    input wire             if_pred_branch_taken,
    input wire [31:0]      if_pred_branch_target,

    input wire [63:0]      counter,

    output logic           have_exception,
    output exception_t     exception_type,
    output opcode_t        opcode,
    output logic [4:0]     rf_src1,
    output logic [4:0]     rf_src2,
    output logic           src2_is_imm,
    output logic [31:0]    imm,
    output logic [4:0]     dest,
    output logic           is_branch,
    output logic [31:0]    branch_target,
    output logic           branch_mistaken,
    output logic           branch_taken,
    output logic           branch_condition,
    output logic           is_jirl,
    output logic           pred_branch_taken,
    output logic [31:0]    pred_branch_target,
    output mem_type_t      mem_type,
    output mem_size_t      mem_size,
    output logic           is_spec_op,
    output spec_opcode_t   spec_opcode
);

wire match;

wire [21:0] op_31_10 = inst[31:10];
wire [16:0] op_31_15 = inst[31:15];
wire [13:0] op_31_18 = inst[31:18];
wire [11:0] op_31_20 = inst[31:20];
wire [ 9:0] op_31_22 = inst[31:22];
wire [ 7:0] op_31_24 = inst[31:24];
wire [ 6:0] op_31_25 = inst[31:25];
wire [ 5:0] op_31_26 = inst[31:26];

wire [4:0] rd  = inst[ 4: 0];
wire [4:0] rj  = inst[ 9: 5];
wire [4:0] rk  = inst[14:10];
wire [4:0] ra  = inst[19:15];

wire [4: 0] i5  = inst[14:10];
wire [11:0] i12 = inst[21:10];
wire [15:0] i16 = inst[25:10];
wire [19:0] i20 = inst[24: 5];
wire [25:0] i26 = {inst[ 9: 0], inst[25:10]};

wire [31:0] ui5  = {27'd0, i5};
wire [31:0] si12 = {{20{i12[11]}}, i12};
wire [31:0] ui12 = {20'd0, i12};
wire [31:0] si16 = {{14{i16[15]}}, i16, 2'b0};
wire [31:0] si20 = {i20, 12'b0};
wire [31:0] si26 = {{ 4{i26[25]}}, i26, 2'b0};

wire [31:0] csr_addr = {18'd0, inst[23:10]};

wire inst_rdcntid_w = op_31_10 == 22'b0000000000000000011000 && rd == `R0 && rj != `R0;
wire inst_rdcntvl_w = op_31_10 == 22'b0000000000000000011000 && rd != `R0 && rj == `R0;
wire inst_rdcntvh_w = op_31_10 == 22'b0000000000000000011001;
wire inst_add_w     = op_31_15 == 17'b00000000000100000;
wire inst_sub_w     = op_31_15 == 17'b00000000000100010;
wire inst_slt       = op_31_15 == 17'b00000000000100100;
wire inst_sltu      = op_31_15 == 17'b00000000000100101;
wire inst_nor       = op_31_15 == 17'b00000000000101000;
wire inst_and       = op_31_15 == 17'b00000000000101001;
wire inst_or        = op_31_15 == 17'b00000000000101010;
wire inst_xor       = op_31_15 == 17'b00000000000101011;
wire inst_sll_w     = op_31_15 == 17'b00000000000101110;
wire inst_srl_w     = op_31_15 == 17'b00000000000101111;
wire inst_sra_w     = op_31_15 == 17'b00000000000110000;
wire inst_mul_w     = op_31_15 == 17'b00000000000111000;
wire inst_mulh_w    = op_31_15 == 17'b00000000000111001;
wire inst_mulh_wu   = op_31_15 == 17'b00000000000111010;
wire inst_div_w     = op_31_15 == 17'b00000000001000000;
wire inst_mod_w     = op_31_15 == 17'b00000000001000001;
wire inst_div_wu    = op_31_15 == 17'b00000000001000010;
wire inst_mod_wu    = op_31_15 == 17'b00000000001000011;
wire inst_break     = op_31_15 == 17'b00000000001010100;
wire inst_syscall   = op_31_15 == 17'b00000000001010110;
wire inst_slli_w    = op_31_15 == 17'b00000000010000001;
wire inst_srli_w    = op_31_15 == 17'b00000000010001001;
wire inst_srai_w    = op_31_15 == 17'b00000000010010001;
// FADD.S - FFINT.D.W
wire inst_slti      = op_31_22 == 10'b0000001000;
wire inst_sltui     = op_31_22 == 10'b0000001001;
wire inst_addi_w    = op_31_22 == 10'b0000001010;
wire inst_andi      = op_31_22 == 10'b0000001101;
wire inst_ori       = op_31_22 == 10'b0000001110;
wire inst_xori      = op_31_22 == 10'b0000001111;
wire inst_csrx      = op_31_24 == 8'b00000100; // CSRRD, CSRWR, CSRXCHG
// CACOP
wire inst_tlbsrch   = op_31_10 == 22'b0000011001001000001010;
wire inst_tlbrd     = op_31_10 == 22'b0000011001001000001011;
wire inst_tlbwr     = op_31_10 == 22'b0000011001001000001100;
wire inst_tlbfill   = op_31_10 == 22'b0000011001001000001101;
wire inst_ertn      = inst == 32'b00000110010010000011100000000000;
// IDLE
wire inst_invtlb    = op_31_15 == 17'b00000110010010011;
// FMADD.S - FSEL
wire inst_lu12i_w   = op_31_25 == 7'b0001010;
wire inst_pcaddu12i = op_31_25 == 7'b0001110;
// LL - SC
wire inst_ld_b      = op_31_22 == 10'b0010100000;
wire inst_ld_h      = op_31_22 == 10'b0010100001;
wire inst_ld_w      = op_31_22 == 10'b0010100010;
wire inst_st_b      = op_31_22 == 10'b0010100100;
wire inst_st_h      = op_31_22 == 10'b0010100101;
wire inst_st_w      = op_31_22 == 10'b0010100110;
wire inst_ld_bu     = op_31_22 == 10'b0010101000;
wire inst_ld_hu     = op_31_22 == 10'b0010101001;
// PRELD - BCNEZ
wire inst_jirl      = op_31_26 == 6'b010011;
wire inst_b         = op_31_26 == 6'b010100;
wire inst_bl        = op_31_26 == 6'b010101;
wire inst_beq       = op_31_26 == 6'b010110;
wire inst_bne       = op_31_26 == 6'b010111;
wire inst_blt       = op_31_26 == 6'b011000;
wire inst_bge       = op_31_26 == 6'b011001;
wire inst_bltu      = op_31_26 == 6'b011010;
wire inst_bgeu      = op_31_26 == 6'b011011;

// base table
assign                 {match, opcode,   rf_src1, rf_src2, src2_is_imm, imm,     dest} = 
{54{inst_add_w    }} & {1'b1,  OP_ADD,   rj,      rk,      1'b0,        32'd0,   rd  } |
{54{inst_sub_w    }} & {1'b1,  OP_SUB,   rj,      rk,      1'b0,        32'd0,   rd  } |
{54{inst_addi_w   }} & {1'b1,  OP_ADD,   rj,     `R0,      1'b1,        si12,    rd  } |
{54{inst_lu12i_w  }} & {1'b1,  OP_OUT2, `R0,     `R0,      1'b1,        si20,    rd  } |
{54{inst_slt      }} & {1'b1,  OP_SLT,   rj,      rk,      1'b0,        32'd0,   rd  } |
{54{inst_sltu     }} & {1'b1,  OP_SLTU,  rj,      rk,      1'b0,        32'd0,   rd  } |
{54{inst_slti     }} & {1'b1,  OP_SLT,   rj,     `R0,      1'b1,        si12,    rd  } |
{54{inst_sltui    }} & {1'b1,  OP_SLTU,  rj,     `R0,      1'b1,        si12,    rd  } |
{54{inst_pcaddu12i}} & {1'b1,  OP_OUT2, `R0,     `R0,      1'b1,        pc+si20, rd  } |
{54{inst_and      }} & {1'b1,  OP_AND,   rj,      rk,      1'b0,        32'd0,   rd  } |
{54{inst_or       }} & {1'b1,  OP_OR,    rj,      rk,      1'b0,        32'd0,   rd  } |
{54{inst_nor      }} & {1'b1,  OP_NOR,   rj,      rk,      1'b0,        32'd0,   rd  } |
{54{inst_xor      }} & {1'b1,  OP_XOR,   rj,      rk,      1'b0,        32'd0,   rd  } |
{54{inst_andi     }} & {1'b1,  OP_AND,   rj,     `R0,      1'b1,        ui12,    rd  } |
{54{inst_ori      }} & {1'b1,  OP_OR,    rj,     `R0,      1'b1,        ui12,    rd  } |
{54{inst_xori     }} & {1'b1,  OP_XOR,   rj,     `R0,      1'b1,        ui12,    rd  } |
{54{inst_mul_w    }} & {1'b1,  OP_MUL,   rj,      rk,      1'b0,        32'd0,   rd  } |
{54{inst_mulh_w   }} & {1'b1,  OP_MULH,  rj,      rk,      1'b0,        32'd0,   rd  } |
{54{inst_mulh_wu  }} & {1'b1,  OP_MULHU, rj,      rk,      1'b0,        32'd0,   rd  } |
{54{inst_div_w    }} & {1'b1,  OP_DIV,   rj,      rk,      1'b0,        32'd0,   rd  } |
{54{inst_div_wu   }} & {1'b1,  OP_DIVU,  rj,      rk,      1'b0,        32'd0,   rd  } |
{54{inst_mod_w    }} & {1'b1,  OP_MOD,   rj,      rk,      1'b0,        32'd0,   rd  } |
{54{inst_mod_wu   }} & {1'b1,  OP_MODU,  rj,      rk,      1'b0,        32'd0,   rd  } |
{54{inst_sll_w    }} & {1'b1,  OP_SLL,   rj,      rk,      1'b0,        32'd0,   rd  } |
{54{inst_srl_w    }} & {1'b1,  OP_SRL,   rj,      rk,      1'b0,        32'd0,   rd  } |
{54{inst_sra_w    }} & {1'b1,  OP_SRA,   rj,      rk,      1'b0,        32'd0,   rd  } |
{54{inst_slli_w   }} & {1'b1,  OP_SLL,   rj,     `R0,      1'b1,        ui5,     rd  } |
{54{inst_srli_w   }} & {1'b1,  OP_SRL,   rj,     `R0,      1'b1,        ui5,     rd  } |
{54{inst_srai_w   }} & {1'b1,  OP_SRA,   rj,     `R0,      1'b1,        ui5,     rd  } |
{54{inst_beq      }} & {1'b1,  OP_EQU,   rj,      rd,      1'b0,        32'd0,  `R0  } |
{54{inst_bne      }} & {1'b1,  OP_EQU,   rj,      rd,      1'b0,        32'd0,  `R0  } |
{54{inst_blt      }} & {1'b1,  OP_SLT,   rj,      rd,      1'b0,        32'd0,  `R0  } |
{54{inst_bltu     }} & {1'b1,  OP_SLTU,  rj,      rd,      1'b0,        32'd0,  `R0  } |
{54{inst_bge      }} & {1'b1,  OP_SLT,   rj,      rd,      1'b0,        32'd0,  `R0  } |
{54{inst_bgeu     }} & {1'b1,  OP_SLTU,  rj,      rd,      1'b0,        32'd0,  `R0  } |
{54{inst_b        }} & {1'b1,  OP_OUT2, `R0,     `R0,      1'b0,        32'd0,  `R0  } |
{54{inst_bl       }} & {1'b1,  OP_OUT2, `R0,     `R0,      1'b1,       pc+32'd4,`R1  } |
{54{inst_jirl     }} & {1'b1,  OP_ADD,   rj,     `R0,      1'b1,        si16,    rd  } | // special
{54{inst_ld_b     }} & {1'b1,  OP_ADD,   rj,     `R0,      1'b1,        si12,    rd  } |
{54{inst_ld_h     }} & {1'b1,  OP_ADD,   rj,     `R0,      1'b1,        si12,    rd  } |
{54{inst_ld_w     }} & {1'b1,  OP_ADD,   rj,     `R0,      1'b1,        si12,    rd  } |
{54{inst_ld_bu    }} & {1'b1,  OP_ADD,   rj,     `R0,      1'b1,        si12,    rd  } |
{54{inst_ld_hu    }} & {1'b1,  OP_ADD,   rj,     `R0,      1'b1,        si12,    rd  } |
{54{inst_st_b     }} & {1'b1,  OP_ADD,   rj,      rd,      1'b1,        si12,   `R0  } | // special use of src2
{54{inst_st_h     }} & {1'b1,  OP_ADD,   rj,      rd,      1'b1,        si12,   `R0  } | // special use of src2
{54{inst_st_w     }} & {1'b1,  OP_ADD,   rj,      rd,      1'b1,        si12,   `R0  } | // special use of src2
{54{inst_syscall  }} & {1'b1,  OP_OUT1, `R0,     `R0,      1'b0,        32'd0,  `R0  } |
{54{inst_break    }} & {1'b1,  OP_OUT1, `R0,     `R0,      1'b0,        32'd0,  `R0  } |
{54{inst_rdcntvl_w}} & {1'b1,  OP_OUT1, `R0,     `R0,      1'b0, counter[31: 0], rd  } |
{54{inst_rdcntvh_w}} & {1'b1,  OP_OUT1, `R0,     `R0,      1'b0, counter[63:32], rd  } |
{54{inst_rdcntid_w}} & {1'b1,  OP_OUT2, `R0,     `R0,      1'b0,        32'h40,  rj  } | // special use of src1 and imm
{54{inst_csrx     }} & {1'b1,  OP_OUT2,  rj,      rd,      1'b0,        csr_addr,rd  } | // special use of src1 and imm
{54{inst_tlbsrch  }} & {1'b1,  OP_OUT1, `R0,     `R0,      1'b0,        32'b0,  `R0  } |
{54{inst_tlbrd    }} & {1'b1,  OP_OUT1, `R0,     `R0,      1'b0,        32'b0,  `R0  } |
{54{inst_tlbwr    }} & {1'b1,  OP_OUT1, `R0,     `R0,      1'b0,        32'b0,  `R0  } |
{54{inst_tlbfill  }} & {1'b1,  OP_OUT1, `R0,     `R0,      1'b0,        32'b0,  `R0  } |
{54{inst_invtlb   }} & {1'b1,  OP_OUT1,  rj,      rk,      1'b0,     {27'd0,rd},`R0  } | // special
{54{inst_ertn     }} & {1'b1,  OP_OUT1, `R0,     `R0,      1'b0,        32'b0,  `R0  } ;


// branch table
assign                 {is_branch, branch_target, branch_condition} =
{34{inst_beq      }} & {1'b1,      pc+si16,       1'b1 /* EQU  */ } |
{34{inst_bne      }} & {1'b1,      pc+si16,       1'b0 /* EQU  */ } |
{34{inst_blt      }} & {1'b1,      pc+si16,       1'b1 /* SLT  */ } |
{34{inst_bltu     }} & {1'b1,      pc+si16,       1'b1 /* SLTU */ } |
{34{inst_bge      }} & {1'b1,      pc+si16,       1'b0 /* SLT  */ } |
{34{inst_bgeu     }} & {1'b1,      pc+si16,       1'b0 /* SLTU */ } |
{34{inst_b        }} & {1'b0,      pc+si26,       1'b0            } |
{34{inst_bl       }} & {1'b0,      pc+si26,       1'b0            } |
{34{inst_jirl     }} & {1'b1,      si16,          1'b0            } ;

assign branch_taken = inst_b || inst_bl;
assign is_jirl = inst_jirl;

assign branch_mistaken = valid && (!branch_taken && !is_branch && !is_jirl && pred_branch_taken
                                   || branch_taken && !pred_branch_taken
                                   || if_pred_branch_taken && branch_taken && if_pred_branch_target != branch_target);

assign pred_branch_taken = if_pred_branch_taken;

assign pred_branch_target = if_pred_branch_target;

// memory table
assign                {mem_type,   mem_size} =
{4{inst_ld_b     }} & {MEM_LOAD_S, MEM_BYTE} |
{4{inst_ld_h     }} & {MEM_LOAD_S, MEM_HALF} |
{4{inst_ld_w     }} & {MEM_LOAD_S, MEM_WORD} |
{4{inst_ld_bu    }} & {MEM_LOAD_U, MEM_BYTE} |
{4{inst_ld_hu    }} & {MEM_LOAD_U, MEM_HALF} |
{4{inst_st_b     }} & {MEM_STORE,  MEM_BYTE} |
{4{inst_st_h     }} & {MEM_STORE,  MEM_HALF} |
{4{inst_st_w     }} & {MEM_STORE,  MEM_WORD} ;

// special (csr & tlb)
assign                {is_spec_op, spec_opcode } =
{4{inst_csrx     }} & {1'b1,       SPEC_CSR    } |
{4{inst_rdcntid_w}} & {1'b1,       SPEC_CSR    } |
{4{inst_tlbsrch  }} & {1'b1,       SPEC_TLBSRCH} |
{4{inst_tlbrd    }} & {1'b1,       SPEC_TLBRD  } |
{4{inst_tlbwr    }} & {1'b1,       SPEC_TLBWR  } |
{4{inst_tlbfill  }} & {1'b1,       SPEC_TLBFILL} |
{4{inst_invtlb   }} & {rd <= 5'd6, SPEC_INVTLB } ;

always_comb begin
    if (if_have_exception) begin
        have_exception = if_have_exception;
        exception_type = if_exception_type;
    end
    else if (inst_ertn) begin
        have_exception = 1'b1;
        exception_type = ERTN;
    end
    else if (inst_syscall) begin
        have_exception = 1'b1;
        exception_type = SYS;
    end
    else if (inst_break) begin
        have_exception = 1'b1;
        exception_type = BRK;
    end
    else if (!match || inst_invtlb && rd > 5'd6) begin
        have_exception = 1'b1;
        exception_type = INE;
    end
    else begin
        have_exception = if_have_exception;
        exception_type = if_exception_type;
    end
end

endmodule