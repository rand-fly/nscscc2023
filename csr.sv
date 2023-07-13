`include "definitions.svh"

module csr #(
    parameter TLBNUM = 16,
    parameter PALEN  = 32
)(
    input wire             clk,
    input wire             reset,
    input wire   [13:0]    addr,
    output logic [31:0]    rdata,
    input wire   [31:0]    we,
    input wire   [31:0]    wdata,
    input wire             have_exception,
    input wire exception_t exception_type,
    input wire             ertn,
    input wire   [31:0]    pc_in,
    output logic [31:0]    pc_out,
    output logic           interrupt,
    input wire             badv_we,
    input wire [31:0]      badv_data
);

parameter TLBIDLEN = $clog2(TLBNUM);

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
} TLBLO0, TLBLO1;

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

wire [31: 0] wdata_m = (rdata & ~we) | (wdata & we);

assign pc_out = ertn ? ERA : EENTRY;

wire [12: 0] int_vec = ESTAT.IS & ECFG.LIE;

assign interrupt = CRMD.IE && int_vec != 13'h0;

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
        14'h12: rdata = TLBLO0;
        14'h13: rdata = TLBLO1;
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
        default: rdata = 32'h0;
    endcase
end

always_ff @(posedge clk) begin
    if (reset) begin
        CRMD.PLV <= 2'h0;
        CRMD.IE <= 1'h0;
        CRMD.DA <= 1'h1;
        CRMD.PG <= 1'h0;
        CRMD.DATF <= 2'h0;
        CRMD.DATM <= 2'h0;
        CRMD.Z <= 23'h0;

        PRMD.Z <= 29'h0;

        ECFG <= 32'h0;

        ESTAT <= 32'h0;

        EENTRY.Z <= 6'h0;

        TCFG.En <= 1'h0;

        TVAL <= 32'h0;
    end
    else if (have_exception) begin
        if (!ertn) begin
            PRMD.PPLV <= CRMD.PLV;
            PRMD.PIE  <= CRMD.IE;
            CRMD.PLV  <= 2'h0;
            CRMD.IE   <= 1'h0;
            ERA.PC    <= pc_in;
            {ESTAT.Ecode,ESTAT.EsubCode} <= exception_type;
        end
        else begin
            CRMD.PLV <= PRMD.PPLV;
            CRMD.IE  <= PRMD.PIE;
        end
    end
    else if (we != 32'h0) begin
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
            14'h12: begin // TLBLO0
                TLBLO0 <= wdata_m;
                TLBLO0.Z1 <= 0;
                TLBLO0.Z2 <= 0;
            end
            14'h13: begin // TLBLO1
                TLBLO1 <= wdata_m;
                TLBLO1.Z1 <= 0;
                TLBLO1.Z2 <= 0;
            end
            14'h18: {ASID[23:16],ASID[9:0]}={wdata_m[23:16],wdata_m[9:0]};
            14'h30: SAVE0[31:0] <= wdata_m[31:0];
            14'h31: SAVE1[31:0] <= wdata_m[31:0];
            14'h32: SAVE2[31:0] <= wdata_m[31:0];
            14'h33: SAVE3[31:0] <= wdata_m[31:0];
            14'h40: TID[31:0] <= wdata_m[31:0];
            14'h41: begin
                TCFG[31:0] <= wdata_m[31:0];
                if (wdata_m[0]) TVAL.TimeVal <= {wdata_m[31:2], 2'b00};
            end
            14'h42: ; // TVAL
            14'h44: if (wdata_m[0]) ESTAT.IS[11] <= 1'h0; // TICLR
            14'h88: TLBRENTRY[31:6] <= wdata_m[31:6];
            default: ;
        endcase
    end

    // badv
    if (badv_we) BADV.VAddr <= badv_data;

    // timer
    if (TCFG.En) begin
        if (TVAL.TimeVal == 32'h0) begin
            if (TCFG.Periodic)
                TVAL.TimeVal <= {TCFG.InitVal, 2'b00};
            else
                TCFG.En <= 1'h0;
            ESTAT.IS[11] <= 1'h1;
        end
        else begin
            TVAL.TimeVal <= TVAL.TimeVal - 32'h1;
        end
    end
end

endmodule