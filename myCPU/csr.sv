`include "definitions.svh"

module csr(
    input wire             clk,
    input wire             reset,
    input wire   [13:0]    addr,
    output logic [31:0]    rdata,
    input wire             we,
    input wire   [31:0]    mask,
    input wire   [31:0]    wdata,
    input wire             have_exception,
    input wire exception_t exception_type,
    input wire   [31:0]    pc_in,
    output logic [31:0]    pc_out,
    output logic           interrupt,
    input wire             badv_we,
    input wire [31:0]      badv_data,
    input wire             vppn_we,
    input wire [18:0]      vppn_data,

    input wire             csr_tlbsrch_we,
    input wire             csr_tlbsrch_found,
    input wire [TLBIDLEN-1:0] csr_tlbsrch_index,

    input wire             csr_tlb_we,
    input wire tlb_entry_t csr_tlb_wdata,
    output tlb_entry_t     csr_tlb_rdata,

    output logic [TLBIDLEN-1:0] csr_tlbidx,
    output logic [9:0]     csr_asid,
    output logic           csr_da,
    output logic [1:0]     csr_datf,
    output logic [1:0]     csr_datm,
    output logic [1:0]     csr_plv,
    output dmw_t           csr_dmw0,
    output dmw_t           csr_dmw1
);

struct packed {
    logic [22: 0] Z;
    logic [ 1: 0] DATM;
    logic [ 1: 0] DATF;
    logic         PG;
    logic         DA;
    logic         IE;
    logic [ 1: 0] PLV;
} CRMD;

struct packed {
    logic [28: 0] Z;
    logic         PIE;
    logic [ 1: 0] PPLV;
} PRMD;

struct packed {
    logic [18: 0] Z0;
    logic [12: 0] LIE;
} ECFG;

struct packed {
    logic         Z0;
    logic [ 8: 0] EsubCode;
    logic [ 5: 0] Ecode;
    logic [ 2: 0] Z1;
    logic [12: 0] IS;
} ESTAT;

struct packed {
    logic [31: 0] PC;
} ERA;

struct packed {
    logic [31: 0] VAddr;
} BADV;

struct packed {
    logic [25: 0] VA;
    logic [ 5: 0] Z;
} EENTRY;

struct packed {
    logic         NE;
    logic         Z1;
    logic [ 5: 0] PS;
    logic [ 7: 0] Z2;
    logic [15-TLBIDLEN:0] Z3;
    logic [TLBIDLEN-1: 0] Index;
} TLBIDX;

struct packed {
    logic [18: 0] VPPN;
    logic [12: 0] Z0;
} TLBEHI;

struct packed {
    logic [35-PALEN:0] Z1;
    logic [PALEN-13:0] PPN;
    logic              Z2;
    logic              G;
    logic [1:0]        MAT;
    logic [1:0]        PLV;
    logic              D;
    logic              V;
} TLBELO0, TLBELO1;

struct packed {
    logic [ 7: 0] Z1;
    logic [ 7: 0] ASIDBITS;
    logic [ 5: 0] Z2;
    logic [ 9: 0] ASID;
} ASID;

struct packed {
    logic [31: 0] Data;
} SAVE0, SAVE1, SAVE2, SAVE3;

struct packed {
    logic [31: 0] TID;
} TID;

struct packed {
    logic [31: 2] InitVal;
    logic         Periodic;
    logic         En;
} TCFG;

struct packed {
    logic [31: 0] TimeVal;
} TVAL;

struct packed {
    logic [25: 0] PA;
    logic [ 5: 0] Z;
} TLBRENTRY;

struct packed {
    logic [ 2:0] VSEG;
    logic        Z3;
    logic [ 2:0] PSEG; 
    logic [18:0] Z2;
    logic [ 1:0] MAT;
    logic        PLV3;
    logic [ 1:0] Z1;
    logic        PLV0;
} DMW0, DMW1;

wire [31: 0] wdata_m = (rdata & ~mask) | (wdata & mask);

assign pc_out = exception_type == ERTN ? ERA : 
                exception_type == TLBR ? TLBRENTRY :
                                         EENTRY;

wire [12: 0] int_vec = ESTAT.IS & ECFG.LIE;

assign interrupt = CRMD.IE && int_vec != 13'h0;

logic timer_en;

always_comb begin
    unique case (addr)
        14'h00: rdata = CRMD;
        14'h01: rdata = PRMD;
        14'h04: rdata = ECFG;
        14'h05: rdata = ESTAT;
        14'h06: rdata = ERA;
        14'h07: rdata = BADV;
        14'h0c: rdata = EENTRY;
        14'h10: rdata = TLBIDX;
        14'h11: rdata = TLBEHI;
        14'h12: rdata = TLBELO0;
        14'h13: rdata = TLBELO1;
        14'h18: rdata = ASID;
        14'h30: rdata = SAVE0;
        14'h31: rdata = SAVE1;
        14'h32: rdata = SAVE2;
        14'h33: rdata = SAVE3;
        14'h40: rdata = TID;
        14'h41: rdata = TCFG;
        14'h42: rdata = TVAL;
        14'h44: rdata = 32'h0; // TICLR
        14'h88: rdata = TLBRENTRY;
        14'h180: rdata = DMW0;
        14'h181: rdata = DMW1;
        default: rdata = 32'h0;
    endcase
end

assign csr_tlb_rdata.vppn = TLBEHI.VPPN;
assign csr_tlb_rdata.ps   = TLBIDX.PS;
assign csr_tlb_rdata.g    = TLBELO0.G && TLBELO1.G;
assign csr_tlb_rdata.asid = ASID.ASID;
assign csr_tlb_rdata.e    = ESTAT.Ecode == 6'h3f ? 1'b1 : !TLBIDX.NE;
assign csr_tlb_rdata.ppn0 = TLBELO0.PPN;
assign csr_tlb_rdata.plv0 = TLBELO0.PLV;
assign csr_tlb_rdata.mat0 = TLBELO0.MAT;
assign csr_tlb_rdata.d0   = TLBELO0.D;
assign csr_tlb_rdata.v0   = TLBELO0.V;
assign csr_tlb_rdata.ppn1 = TLBELO1.PPN;
assign csr_tlb_rdata.plv1 = TLBELO1.PLV;
assign csr_tlb_rdata.mat1 = TLBELO1.MAT;
assign csr_tlb_rdata.d1   = TLBELO1.D;
assign csr_tlb_rdata.v1   = TLBELO1.V;

assign csr_tlbidx = TLBIDX.Index;
assign csr_asid   = ASID.ASID;
assign csr_da = CRMD.DA;
assign csr_datf = CRMD.DATF;
assign csr_datm = CRMD.DATM;
assign csr_plv = CRMD.PLV;
assign csr_dmw0.plv0 = DMW0.PLV0;
assign csr_dmw0.plv3 = DMW0.PLV3;
assign csr_dmw0.mat = DMW0.MAT;
assign csr_dmw0.pseg = DMW0.PSEG;
assign csr_dmw0.vseg = DMW0.VSEG;
assign csr_dmw1.plv0 = DMW1.PLV0;
assign csr_dmw1.plv3 = DMW1.PLV3;
assign csr_dmw1.mat = DMW1.MAT;
assign csr_dmw1.pseg = DMW1.PSEG;
assign csr_dmw1.vseg = DMW1.VSEG;


always_ff @(posedge clk) begin
    if (reset) begin
        CRMD.PLV <= 0;
        CRMD.IE <= 0;
        CRMD.DA <= 1;
        CRMD.PG <= 0;
        CRMD.DATF <= 0;
        CRMD.DATM <= 0;
        CRMD.Z <= 0;

        PRMD.Z <= 0;

        ECFG <= 0;

        ESTAT <= 0;

        EENTRY.Z <= 0;

        TLBIDX.Z1 <= 0;
        TLBIDX.Z2 <= 0;
        TLBIDX.Z3 <= 0;

        TLBEHI.Z0 <= 0;

        TLBELO0.Z1 <= 0;
        TLBELO0.Z2 <= 0;

        TLBELO1.Z1 <= 0;
        TLBELO1.Z2 <= 0;

        ASID.Z1 <= 0;
        ASID.ASIDBITS <= 10;
        ASID.Z2 <= 0;

        TCFG.En <= 0;

        TVAL <= 0;

        TLBRENTRY.Z <= 0;

        DMW0 <= 0;
        DMW1 <= 0;
    end
    else if (have_exception) begin
        if (exception_type != ERTN) begin
            PRMD.PPLV <= CRMD.PLV;
            PRMD.PIE  <= CRMD.IE;
            CRMD.PLV  <= 2'h0;
            CRMD.IE   <= 1'h0;
            ERA.PC    <= pc_in;
            {ESTAT.Ecode,ESTAT.EsubCode} <= exception_type;
            if (exception_type == TLBR) begin
                CRMD.DA <= 1'b1;
                CRMD.PG <= 1'b0;
            end
        end
        else begin
            CRMD.PLV <= PRMD.PPLV;
            CRMD.IE  <= PRMD.PIE;
            if (ESTAT.Ecode == 6'h3f) begin
                CRMD.DA <= 1'b0;
                CRMD.PG <= 1'b1;
            end
        end
    end
    else if (csr_tlbsrch_we) begin
        if (csr_tlbsrch_found) begin
            TLBIDX.Index <= csr_tlbsrch_index;
            TLBIDX.NE <= 1'b0;
        end
        else begin
            TLBIDX.NE <= 1'b1;
        end
    end
    else if (csr_tlb_we) begin
        if (csr_tlb_wdata.e) begin
            TLBEHI.VPPN <= csr_tlb_wdata.vppn;
            TLBIDX.PS   <= csr_tlb_wdata.ps;
            TLBELO0.G   <= csr_tlb_wdata.g;
            TLBELO1.G   <= csr_tlb_wdata.g;
            ASID.ASID   <= csr_tlb_wdata.asid;
            TLBELO0.PPN <= csr_tlb_wdata.ppn0;
            TLBELO0.PLV <= csr_tlb_wdata.plv0;
            TLBELO0.MAT <= csr_tlb_wdata.mat0;
            TLBELO0.D   <= csr_tlb_wdata.d0;
            TLBELO0.V   <= csr_tlb_wdata.v0;
            TLBELO1.PPN <= csr_tlb_wdata.ppn1;
            TLBELO1.PLV <= csr_tlb_wdata.plv1;
            TLBELO1.MAT <= csr_tlb_wdata.mat1;
            TLBELO1.D   <= csr_tlb_wdata.d1;
            TLBELO1.V   <= csr_tlb_wdata.v1;
        end
        else begin
            TLBIDX.NE <= 1'b1;
            ASID.ASID <= 10'h0;
            TLBEHI <= 32'h0;
            TLBELO0 <= 32'h0;
            TLBELO1 <= 32'h0;
            TLBIDX.PS <= 6'h0;
        end
    end
    else if (we) begin
        unique case (addr)
            14'h00: CRMD[8:0] <= wdata_m[8:0];
            14'h01: PRMD[2:0] <= wdata_m[2:0];
            14'h04: {ECFG[9:0],ECFG[12:11]} <= {wdata_m[9:0],wdata_m[12:11]};
            14'h05: ESTAT[1:0] <= wdata_m[1:0];
            14'h06: ERA[31:0] <= wdata_m[31:0];
            14'h07: BADV[31:0] <= wdata_m[31:0];
            14'h0c: EENTRY[31:6] <= wdata_m[31:6];
            14'h10: begin // TLBIDX
                TLBIDX <= wdata_m;
                TLBIDX.Z1 <= 0;
                TLBIDX.Z2 <= 0;
                TLBIDX.Z3 <= 0;
            end
            14'h11: TLBEHI[31:13] <= wdata_m[31:13];
            14'h12: begin // TLBELO0
                TLBELO0 <= wdata_m;
                TLBELO0.Z1 <= 0;
                TLBELO0.Z2 <= 0;
            end
            14'h13: begin // TLBELO1
                TLBELO1 <= wdata_m;
                TLBELO1.Z1 <= 0;
                TLBELO1.Z2 <= 0;
            end
            14'h18: ASID[9:0] <= wdata_m[9:0];
            14'h30: SAVE0[31:0] <= wdata_m[31:0];
            14'h31: SAVE1[31:0] <= wdata_m[31:0];
            14'h32: SAVE2[31:0] <= wdata_m[31:0];
            14'h33: SAVE3[31:0] <= wdata_m[31:0];
            14'h40: TID[31:0] <= wdata_m[31:0];
            14'h41: begin
                TCFG[31:0] <= wdata_m[31:0];
                timer_en <= wdata_m[0];
                if (wdata_m[0]) begin
                    TVAL.TimeVal <= {wdata_m[31:2], 2'b00};
                end
            end
            14'h42: ; // TVAL
            14'h44: if (wdata_m[0]) ESTAT.IS[11] <= 1'h0; // TICLR
            14'h88: TLBRENTRY[31:6] <= wdata_m[31:6];
            14'h180: {DMW0[0], DMW0[5:3], DMW0[27:25], DMW0[31:29]} <= {wdata_m[0], wdata_m[5:3], wdata_m[27:25], wdata_m[31:29]};
            14'h181: {DMW1[0], DMW1[5:3], DMW1[27:25], DMW1[31:29]} <= {wdata_m[0], wdata_m[5:3], wdata_m[27:25], wdata_m[31:29]};
            default: ;
        endcase
    end

    if (badv_we) BADV.VAddr <= badv_data;

    if (vppn_we) TLBEHI.VPPN <= vppn_data;

    // timer
    if (timer_en) begin
        if (TVAL.TimeVal == 32'h0) begin
            if (TCFG.Periodic)
                TVAL.TimeVal <= {TCFG.InitVal, 2'b00};
            else
                timer_en <= 1'h0;
            ESTAT.IS[11] <= 1'h1;
        end
        else begin
            TVAL.TimeVal <= TVAL.TimeVal - 32'h1;
        end
    end
end

endmodule