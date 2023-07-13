`include "../definitions.svh"

module mmu(
    input wire         direct_access,
    input wire [1:0]   direct_access_mat,
    input wire [1:0]   plv,
    input wire [9:0]   asid,
    input wire dmw_t   dmw0,
    input wire dmw_t   dmw1,

    input wire         i_valid,
    input wire [31:0]  i_va,
    input wire         i_double,
    output wire        i_addr_ok,
    output wire        i_data_ok,
    output wire [63:0] i_rdata,
    output wire        i_tlbr,
    output wire        i_pif,
    output wire        i_ppi,

    input wire         d1_valid,
    input wire [31:0]  d1_va,
    input wire         d1_we,
    input wire [1:0]   d1_size,
    input wire [3:0]   d1_wstrb,
    input wire [31:0]  d1_wdata,
    output wire        d1_addr_ok,
    output wire        d1_data_ok,
    output wire [31:0] d1_rdata,
    output wire        d1_tlbr,
    output wire        d1_pil,
    output wire        d1_pis,
    output wire        d1_ppi,
    output wire        d1_pme,

    input wire         d2_valid,
    input wire [31:0]  d2_va,
    input wire         d2_we,
    input wire [1:0]   d2_size,
    input wire [3:0]   d2_wstrb,
    input wire [31:0]  d2_wdata,
    output wire        d2_addr_ok,
    output wire        d2_data_ok,
    output wire [31:0] d2_rdata,
    output wire        d2_tlbr,
    output wire        d2_pil,
    output wire        d2_pis,
    output wire        d2_ppi,
    output wire        d2_pme,



    output logic        inst_sram_req,
    output logic        inst_sram_wr,
    output logic [ 1:0] inst_sram_size,
    output logic [ 3:0] inst_sram_wstrb,
    output logic [31:0] inst_sram_addr,
    output logic [31:0] inst_sram_wdata,
    input wire          inst_sram_addr_ok,
    input wire          inst_sram_data_ok,
    input wire   [63:0] inst_sram_rdata,

    output logic        data_sram_req,
    output logic        data_sram_wr,
    output logic [ 1:0] data_sram_size,
    output logic [ 3:0] data_sram_wstrb,
    output logic [31:0] data_sram_addr,
    output logic [31:0] data_sram_wdata,
    input wire          data_sram_addr_ok,
    input wire          data_sram_data_ok,
    input wire   [31:0] data_sram_rdata
);

logic [31:0] i_pa;
logic [1:0]  i_mat;
logic        i_page_fault;
logic        i_page_invalid;
logic        i_page_dirty;
logic        i_plv_fault;

logic [31:0] d1_pa;
logic [1:0]  d1_mat;
logic        d1_page_fault;
logic        d1_page_invalid;
logic        d1_page_dirty;
logic        d1_plv_fault;

logic [31:0] d2_pa;
logic [1:0]  d2_mat;
logic        d2_page_fault;
logic        d2_page_invalid;
logic        d2_page_dirty;
logic        d2_plv_fault;

logic [18:0] tlb_s0_vppn;
logic        tlb_s0_va_bit12;
logic [9:0]  tlb_s0_asid;
tlb_result_t tlb_s0_result;

logic [18:0] tlb_s1_vppn;
logic        tlb_s1_va_bit12;
logic [9:0]  tlb_s1_asid;
tlb_result_t tlb_s1_result;

logic [18:0] tlb_s2_vppn;
logic        tlb_s2_va_bit12;
logic [9:0]  tlb_s2_asid;
tlb_result_t tlb_s2_result;

addr_trans addr_trans_i(
    .direct_access     (direct_access),
    .direct_access_mat (direct_access_mat),
    .plv               (plv),
    .asid              (asid),
    .dmw0              (dmw0),
    .dmw1              (dmw1),
    .tlb_s_vppn        (tlb_s0_vppn),
    .tlb_s_va_bit12    (tlb_s0_va_bit12),
    .tlb_s_asid        (tlb_s0_asid),
    .tlb_s_result      (tlb_s0_result),

    .va                (i_va),
    .pa                (i_pa),
    .mat               (i_mat),
    .page_fault        (i_page_fault),
    .page_invalid      (i_page_invalid),
    .page_dirty        (i_page_dirty),
    .plv_fault         (i_plv_fault)
);

assign i_tlbr = i_valid && i_page_fault;
assign i_pif  = i_valid && i_page_invalid;
assign i_ppi  = i_valid && i_plv_fault;

addr_trans addr_trans_d1(
    .direct_access     (direct_access),
    .direct_access_mat (direct_access_mat),
    .plv               (plv),
    .asid              (asid),
    .dmw0              (dmw0),
    .dmw1              (dmw1),
    .tlb_s_vppn        (tlb_s1_vppn),
    .tlb_s_va_bit12    (tlb_s1_va_bit12),
    .tlb_s_asid        (tlb_s1_asid),
    .tlb_s_result      (tlb_s1_result),

    .va                (d1_va),
    .pa                (d1_pa),
    .mat               (d1_mat),
    .page_fault        (d1_page_fault),
    .page_invalid      (d1_page_invalid),
    .page_dirty        (d1_page_dirty),
    .plv_fault         (d1_plv_fault)
);

assign d1_tlbr = d1_valid && d1_page_fault;
assign d1_pil  = d1_valid && d1_page_invalid && !d1_we;
assign d1_pis  = d1_valid && d1_page_invalid && d1_we;
assign d1_ppi  = d1_valid && d1_plv_fault;
assign d1_pme  = d1_valid && d1_page_dirty && d1_we;

addr_trans addr_trans_d2(
    .direct_access     (direct_access),
    .direct_access_mat (direct_access_mat),
    .plv               (plv),
    .asid              (asid),
    .dmw0              (dmw0),
    .dmw1              (dmw1),
    .tlb_s_vppn        (tlb_s2_vppn),
    .tlb_s_va_bit12    (tlb_s2_va_bit12),
    .tlb_s_asid        (tlb_s2_asid),
    .tlb_s_result      (tlb_s2_result),

    .va                (d2_va),
    .pa                (d2_pa),
    .mat               (d2_mat),
    .page_fault        (d2_page_fault),
    .page_invalid      (d2_page_invalid),
    .page_dirty        (d2_page_dirty),
    .plv_fault         (d2_plv_fault)
);

assign d2_tlbr = d2_valid && d2_page_fault;
assign d2_pil  = d2_valid && d2_page_invalid && !d2_we;
assign d2_pis  = d2_valid && d2_page_invalid && d2_we;
assign d2_ppi  = d2_valid && d2_plv_fault;
assign d2_pme  = d2_valid && d2_page_dirty && d2_we;

assign inst_sram_req = i_valid;
assign inst_sram_wr  = 1'b0;
assign inst_sram_size = 2'd2;
assign inst_sram_wstrb = 4'b0000;
assign inst_sram_addr = i_va;
assign inst_sram_wdata = 32'h0;
assign i_addr_ok = inst_sram_addr_ok;
assign i_data_ok = inst_sram_data_ok;
assign i_rdata = inst_sram_rdata;

assign data_sram_req = d1_valid;
assign data_sram_wr  = d1_we;
assign data_sram_size = d1_size;
assign data_sram_wstrb = d1_wstrb;
assign data_sram_addr = d1_va;
assign data_sram_wdata = d1_wdata;
assign d1_addr_ok = data_sram_addr_ok;
assign d1_data_ok = data_sram_data_ok;
assign d1_rdata = data_sram_rdata;

assign d2_addr_ok = 1'b0;
assign d2_data_ok = 1'b0;
assign d2_rdata = 32'h0;

assign tlb_s0_result = 0;
assign tlb_s1_result = 0;
assign tlb_s2_result = 0;

endmodule