`include "definitions.svh"

module csr (
    input                    clk,
    input                    reset,
    input             [ 7:0] ext_int,
    input  csr_addr_t        addr,
    output logic      [31:0] rdata,
    input                    we,
    input             [31:0] mask,
    input             [31:0] wdata,
    input                    raise_excp,
    input  excp_t            excp_type,
    input             [31:0] pc_in,
    output            [31:0] pc_out,
    output                   interrupt,
    input                    badv_we,
    input             [31:0] badv_data,
    input                    vppn_we,
    input             [18:0] vppn_data,

    input                csr_tlbsrch_we,
    input                csr_tlbsrch_found,
    input [TLBIDLEN-1:0] csr_tlbsrch_index,

    input              csr_tlb_we,
    input  tlb_entry_t csr_tlb_wdata,
    output tlb_entry_t csr_tlb_rdata,

    output       [TLBIDLEN-1:0] csr_tlbidx,
    output       [         9:0] csr_asid,
    output                      csr_da,
    output       [         1:0] csr_datf,
    output       [         1:0] csr_datm,
    output       [         1:0] csr_plv,
    output dmw_t                csr_dmw0,
    output dmw_t                csr_dmw1,

    input  csr_llbit_we,
    input  csr_llbit_wdata,
    output csr_llbit
);

  // verilog_lint: waive-start typedef-structs-unions
  struct packed {
    logic [22:0] Z;
    logic [1:0]  DATM;
    logic [1:0]  DATF;
    logic        PG;
    logic        DA;
    logic        IE;
    logic [1:0]  PLV;
  } CRMD;

  struct packed {
    logic [28:0] Z;
    logic        PIE;
    logic [1:0]  PPLV;
  } PRMD;

  struct packed {
    logic [18:0] Z0;
    logic [12:0] LIE;
  } ECFG;

  struct packed {
    logic        Z0;
    logic [8:0]  EsubCode;
    logic [5:0]  Ecode;
    logic [2:0]  Z1;
    logic [12:0] IS;
  } ESTAT;

  struct packed {logic [31:0] PC;} ERA;

  struct packed {logic [31:0] VAddr;} BADV;

  struct packed {
    logic [25:0] VA;
    logic [5:0]  Z;
  } EENTRY;

  struct packed {
    logic                 NE;
    logic                 Z1;
    logic [5:0]           PS;
    logic [7:0]           Z2;
    logic [15-TLBIDLEN:0] Z3;
    logic [TLBIDLEN-1:0]  Index;
  } TLBIDX;

  struct packed {
    logic [18:0] VPPN;
    logic [12:0] Z0;
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
  }
      TLBELO0, TLBELO1;

  struct packed {
    logic [7:0] Z1;
    logic [7:0] ASIDBITS;
    logic [5:0] Z2;
    logic [9:0] ASID;
  } ASID;

  struct packed {
    logic [19:0] Base;
    logic [11:0] Z;
  }
      PGDL, PGDH;

  struct packed {logic [31:0] Data;} SAVE0, SAVE1, SAVE2, SAVE3;

  struct packed {
    logic [28:0] Z;
    logic KLO;
    logic WBLLB;
    logic ROLLB;
  } LLBCTL;

  struct packed {logic [31:0] TID;} TID;

  struct packed {
    logic [31:2] InitVal;
    logic Periodic;
    logic En;
  } TCFG;

  struct packed {logic [31:0] TimeVal;} TVAL;

  struct packed {
    logic [25:0] PA;
    logic [5:0]  Z;
  } TLBRENTRY;

  struct packed {
    logic [2:0]  VSEG;
    logic        Z3;
    logic [2:0]  PSEG;
    logic [18:0] Z2;
    logic [1:0]  MAT;
    logic        PLV3;
    logic [1:0]  Z1;
    logic        PLV0;
  }
      DMW0, DMW1;

  // verilog_lint: waive-stop typedef-structs-unions

  wire [31:0] wdata_m = (rdata & ~mask) | (wdata & mask);

  assign pc_out = excp_type == ERTN ? ERA : (excp_type == I_TLBR || excp_type == D_TLBR) ? TLBRENTRY : EENTRY;

  wire [12:0] int_vec = ESTAT.IS & ECFG.LIE;

  assign interrupt = CRMD.IE && int_vec != 13'h0;

  logic timer_en;

  always_ff @(posedge clk) begin
    ESTAT.IS[9:2] <= ext_int;
  end

  always_comb begin
    unique case (addr)
      14'h00:  rdata = CRMD;
      14'h01:  rdata = PRMD;
      14'h04:  rdata = ECFG;
      14'h05:  rdata = ESTAT;
      14'h06:  rdata = ERA;
      14'h07:  rdata = BADV;
      14'h0c:  rdata = EENTRY;
      14'h10:  rdata = TLBIDX;
      14'h11:  rdata = TLBEHI;
      14'h12:  rdata = TLBELO0;
      14'h13:  rdata = TLBELO1;
      14'h18:  rdata = ASID;
      14'h19:  rdata = PGDL;
      14'h1a:  rdata = PGDH;
      14'h1b:  rdata = BADV[31] ? PGDH : PGDL;
      14'h30:  rdata = SAVE0;
      14'h31:  rdata = SAVE1;
      14'h32:  rdata = SAVE2;
      14'h33:  rdata = SAVE3;
      14'h40:  rdata = TID;
      14'h41:  rdata = TCFG;
      14'h42:  rdata = TVAL;
      14'h44:  rdata = 32'h0;  // TICLR
      14'h60:  rdata = LLBCTL;
      14'h88:  rdata = TLBRENTRY;
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
  assign csr_llbit = LLBCTL.ROLLB;

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

      ESTAT[31:10] <= 0;
      ESTAT[1:0] <= 0;


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

      PGDL.Z <= 0;
      PGDH.Z <= 0;

      TCFG.En <= 0;

      TVAL <= 0;

      LLBCTL.Z <= 0;
      LLBCTL.WBLLB <= 0;
      LLBCTL.KLO <= 0;

      TLBRENTRY.Z <= 0;

      DMW0 <= 0;
      DMW1 <= 0;

      timer_en <= 0;
    end else if (raise_excp) begin
      if (excp_type != ERTN) begin
        PRMD.PPLV <= CRMD.PLV;
        PRMD.PIE  <= CRMD.IE;
        CRMD.PLV  <= 2'h0;
        CRMD.IE   <= 1'h0;
        ERA.PC    <= pc_in;
        if (excp_type == I_TLBR || excp_type == D_TLBR) begin
          CRMD.DA <= 1'b1;
          CRMD.PG <= 1'b0;
          {ESTAT.Ecode, ESTAT.EsubCode} <= TLBR;
        end else begin
          {ESTAT.Ecode, ESTAT.EsubCode} <= excp_type;
        end
      end else begin
        CRMD.PLV <= PRMD.PPLV;
        CRMD.IE  <= PRMD.PIE;
        if (ESTAT.Ecode == 6'h3f) begin
          CRMD.DA <= 1'b0;
          CRMD.PG <= 1'b1;
        end
        if (!LLBCTL.KLO) LLBCTL.ROLLB <= 1'b0;
        else LLBCTL.KLO <= 1'b0;
      end
    end else if (csr_tlbsrch_we) begin
      if (csr_tlbsrch_found) begin
        TLBIDX.Index <= csr_tlbsrch_index;
        TLBIDX.NE <= 1'b0;
      end else begin
        TLBIDX.NE <= 1'b1;
      end
    end else if (csr_tlb_we) begin
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
      end else begin
        TLBIDX.NE <= 1'b1;
        ASID.ASID <= 10'h0;
        TLBEHI <= 32'h0;
        TLBELO0 <= 32'h0;
        TLBELO1 <= 32'h0;
        TLBIDX.PS <= 6'h0;
      end
    end else if (we) begin
      unique case (addr)
        14'h00: CRMD[8:0] <= wdata_m[8:0];
        14'h01: PRMD[2:0] <= wdata_m[2:0];
        14'h04: {ECFG[9:0], ECFG[12:11]} <= {wdata_m[9:0], wdata_m[12:11]};
        14'h05: ESTAT[1:0] <= wdata_m[1:0];
        14'h06: ERA[31:0] <= wdata_m[31:0];
        14'h07: BADV[31:0] <= wdata_m[31:0];
        14'h0c: EENTRY[31:6] <= wdata_m[31:6];
        14'h10: begin  // TLBIDX
          TLBIDX <= wdata_m;
          TLBIDX.Z1 <= 0;
          TLBIDX.Z2 <= 0;
          TLBIDX.Z3 <= 0;
        end
        14'h11: TLBEHI[31:13] <= wdata_m[31:13];
        14'h12: begin  // TLBELO0
          TLBELO0 <= wdata_m;
          TLBELO0.Z1 <= 0;
          TLBELO0.Z2 <= 0;
        end
        14'h13: begin  // TLBELO1
          TLBELO1 <= wdata_m;
          TLBELO1.Z1 <= 0;
          TLBELO1.Z2 <= 0;
        end
        14'h18: ASID[9:0] <= wdata_m[9:0];
        14'h19: PGDL[31:12] <= wdata_m[31:12];
        14'h1a: PGDH[31:12] <= wdata_m[31:12];
        14'h1b: ;  // PGD
        14'h30: SAVE0[31:0] <= wdata_m[31:0];
        14'h31: SAVE1[31:0] <= wdata_m[31:0];
        14'h32: SAVE2[31:0] <= wdata_m[31:0];
        14'h33: SAVE3[31:0] <= wdata_m[31:0];
        14'h40: TID[31:0] <= wdata_m[31:0];
        14'h41: begin
          TCFG[31:0] <= wdata_m[31:0];
          timer_en   <= wdata_m[0];
          if (wdata_m[0]) begin
            TVAL.TimeVal <= {wdata_m[31:2], 2'b00};
          end
        end
        14'h42: ;  // TVAL
        14'h44: if (wdata_m[0]) ESTAT.IS[11] <= 1'h0;  // TICLR
        14'h60: begin
          if (wdata_m[1]) LLBCTL.ROLLB <= 1'b0;
          LLBCTL.KLO <= wdata_m[2];
        end
        14'h88: TLBRENTRY[31:6] <= wdata_m[31:6];
        14'h180:
        {DMW0[0], DMW0[5:3], DMW0[27:25], DMW0[31:29]} <= {
          wdata_m[0], wdata_m[5:3], wdata_m[27:25], wdata_m[31:29]
        };
        14'h181:
        {DMW1[0], DMW1[5:3], DMW1[27:25], DMW1[31:29]} <= {
          wdata_m[0], wdata_m[5:3], wdata_m[27:25], wdata_m[31:29]
        };
        default: ;
      endcase
    end

    if (csr_llbit_we) LLBCTL.ROLLB <= csr_llbit_wdata;

    if (badv_we) BADV.VAddr <= badv_data;

    if (vppn_we) TLBEHI.VPPN <= vppn_data;

    // timer
    if (timer_en) begin
      if (TVAL.TimeVal == 32'h0) begin
        if (TCFG.Periodic) TVAL.TimeVal <= {TCFG.InitVal, 2'b00};
        else timer_en <= 1'h0;
        ESTAT.IS[11] <= 1'h1;
      end else begin
        TVAL.TimeVal <= TVAL.TimeVal - 32'h1;
      end
    end
  end

endmodule
