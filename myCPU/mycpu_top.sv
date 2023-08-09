`include "definitions.svh"

`ifdef SIMU
module core_top(
`else
module mycpu_top (
`endif
    input wire       aclk,
    input wire       aresetn,
    input wire [7:0] ext_int,
    input wire [7:0] intrpt,

    //AXI interface
    //read reqest
    output logic [ 3:0] arid,
    output logic [31:0] araddr,
    output logic [ 7:0] arlen,
    output logic [ 2:0] arsize,
    output logic [ 1:0] arburst,
    output logic [ 1:0] arlock,
    output logic [ 3:0] arcache,
    output logic [ 2:0] arprot,
    output logic        arvalid,
    input  wire         arready,
    //read back
    input  wire  [ 3:0] rid,
    input  wire  [31:0] rdata,
    input  wire  [ 1:0] rresp,
    input  wire         rlast,
    input  wire         rvalid,
    output logic        rready,
    //write request
    output logic [ 3:0] awid,
    output logic [31:0] awaddr,
    output logic [ 7:0] awlen,
    output logic [ 2:0] awsize,
    output logic [ 1:0] awburst,
    output logic [ 1:0] awlock,
    output logic [ 3:0] awcache,
    output logic [ 2:0] awprot,
    output logic        awvalid,
    input  wire         awready,
    //write data
    output logic [ 3:0] wid,
    output logic [31:0] wdata,
    output logic [ 3:0] wstrb,
    output logic        wlast,
    output logic        wvalid,
    input  wire         wready,
    //write back
    input  wire  [ 3:0] bid,
    input  wire  [ 1:0] bresp,
    input  wire         bvalid,
    output logic        bready,

    //debug
    input  wire         break_point,
    input  wire         infor_flag,
    input  wire  [ 4:0] reg_num,
    output logic        ws_valid,
    output logic [31:0] rf_rdata,

    output logic [31:0] debug1_wb_pc,
    output logic [ 3:0] debug1_wb_rf_wen,
    output logic [ 4:0] debug1_wb_rf_wnum,
    output logic [31:0] debug1_wb_rf_wdata,

    output logic [31:0] debug0_wb_pc,
    output logic [ 3:0] debug0_wb_rf_wen,
    output logic [ 4:0] debug0_wb_rf_wnum,
    output logic [31:0] debug0_wb_rf_wdata,

    output logic [31:0] debug_wb_pc,
    output logic [ 3:0] debug_wb_rf_we,
    output logic [ 4:0] debug_wb_rf_wnum,
    output logic [31:0] debug_wb_rf_wdata
);

  logic                     icache_req;
  logic [              2:0] icache_op;
  logic [             31:0] icache_addr;
  logic                     icache_uncached;
  logic                     icache_addr_ok;
  logic                     icache_data_ok;
  logic [             63:0] icache_rdata;


  logic                     dcache_p0_valid;
  logic                     dcache_p1_valid;
  logic [              2:0] dcache_op;
  logic [   `TAG_WIDTH-1:0] dcache_tag;
  logic [ `INDEX_WIDTH-1:0] dcache_index;
  logic [`OFFSET_WIDTH-1:0] dcache_p0_offset;
  logic [`OFFSET_WIDTH-1:0] dcache_p1_offset;
  logic [              3:0] dcache_p0_wstrb;
  logic [              3:0] dcache_p1_wstrb;
  logic [             31:0] dcache_p0_wdata;
  logic [             31:0] dcache_p1_wdata;
  logic                     dcache_uncached;
  logic [              1:0] dcache_p0_size;
  logic [              1:0] dcache_p1_size;
  logic                     dcache_addr_ok;
  logic                     dcache_data_ok;
  logic [             31:0] dcache_p0_rdata;
  logic [             31:0] dcache_p1_rdata;


  logic                     inst_rd_req;
  logic [              2:0] inst_rd_type;
  logic [             31:0] inst_rd_addr;
  logic                     inst_rd_rdy;
  logic                     inst_ret_valid;
  logic                     inst_ret_last;
  logic [             31:0] inst_ret_data;
  logic                     inst_wr_req;
  logic [              2:0] inst_wr_type;
  logic [             31:0] inst_wr_addr;
  logic [              3:0] inst_wr_wstrb;
  logic [  `LINE_WIDTH-1:0] inst_wr_data;
  logic                     inst_wr_rdy;

  logic                     data_rd_req;
  logic [              2:0] data_rd_type;
  logic [             31:0] data_rd_addr;
  logic                     data_rd_rdy;
  logic                     data_ret_valid;
  logic                     data_ret_last;
  logic [             31:0] data_ret_data;
  logic                     data_wr_req;
  logic [              2:0] data_wr_type;
  logic [             31:0] data_wr_addr;
  logic [              3:0] data_wr_wstrb;
  logic [  `LINE_WIDTH-1:0] data_wr_data;
  logic                     data_wr_rdy;

`ifdef DIFFTEST_EN
  difftest_t a_difftest;
  difftest_t b_difftest;
  difftest_excp_t excp_difftest;
  difftest_csr_t csr_difftest;
`endif

  core core_0 (
      .clk(aclk),
      .resetn(aresetn),

      .icache_req(icache_req),
      .icache_op(icache_op),
      .icache_addr(icache_addr),
      .icache_uncached(icache_uncached),
      .icache_addr_ok(icache_addr_ok),
      .icache_data_ok(icache_data_ok),
      .icache_rdata(icache_rdata),

      .dcache_p0_valid(dcache_p0_valid),
      .dcache_p1_valid(dcache_p1_valid),
      .dcache_op(dcache_op),
      .dcache_tag(dcache_tag),
      .dcache_index(dcache_index),
      .dcache_p0_offset(dcache_p0_offset),
      .dcache_p1_offset(dcache_p1_offset),
      .dcache_p0_wstrb(dcache_p0_wstrb),
      .dcache_p1_wstrb(dcache_p1_wstrb),
      .dcache_p0_wdata(dcache_p0_wdata),
      .dcache_p1_wdata(dcache_p1_wdata),
      .dcache_uncached(dcache_uncached),
      .dcache_p0_size(dcache_p0_size),
      .dcache_p1_size(dcache_p1_size),
      .dcache_addr_ok(dcache_addr_ok),
      .dcache_data_ok(dcache_data_ok),
      .dcache_p0_rdata(dcache_p0_rdata),
      .dcache_p1_rdata(dcache_p1_rdata),

      .debug0_wb_pc(debug0_wb_pc),
      .debug0_wb_rf_wen(debug0_wb_rf_wen),
      .debug0_wb_rf_wnum(debug0_wb_rf_wnum),
      .debug0_wb_rf_wdata(debug0_wb_rf_wdata),

      .debug1_wb_pc(debug1_wb_pc),
      .debug1_wb_rf_wen(debug1_wb_rf_wen),
      .debug1_wb_rf_wnum(debug1_wb_rf_wnum),
      .debug1_wb_rf_wdata(debug1_wb_rf_wdata)

`ifdef DIFFTEST_EN,
      .a_difftest(a_difftest),
      .b_difftest(b_difftest),
      .excp_difftest(excp_difftest),
      .csr_difftest(csr_difftest)
`endif
  );

  logic [31:0] icache_rdata_l;
  logic [31:0] icache_rdata_h;

  assign icache_rdata = {icache_rdata_h, icache_rdata_l};

  icache icache (
      .clk(aclk),
      .resetn(aresetn),

      .valid(icache_req),
      .op(icache_op),
      .tag(icache_addr[31:12]),
      .index(icache_addr[11:`OFFSET_WIDTH]),
      .offset(icache_addr[`OFFSET_WIDTH-1:0]),
      .uncached(icache_uncached),
      .addr_ok(icache_addr_ok),
      .data_ok(icache_data_ok),
      .rdata_l(icache_rdata_l),
      .rdata_h(icache_rdata_h),

      .rd_req(inst_rd_req),
      .rd_type(inst_rd_type),
      .rd_addr(inst_rd_addr),
      .rd_rdy(inst_rd_rdy),
      .ret_valid(inst_ret_valid),
      .ret_last(inst_ret_last),
      .ret_data(inst_ret_data),
      .wr_req(inst_wr_req),
      .wr_type(inst_wr_type),
      .wr_addr(inst_wr_addr),
      .wr_wstrb(inst_wr_wstrb),
      .wr_data(inst_wr_data),
      .wr_rdy(inst_wr_rdy)
  );

  dcache dcache (
      .clk(aclk),
      .resetn(aresetn),

      .p0_valid(dcache_p0_valid),
      .p1_valid(dcache_p1_valid),

      .op       (dcache_op),
      .tag      (dcache_tag),
      .index    (dcache_index),
      .p0_offset(dcache_p0_offset),
      .p1_offset(dcache_p1_offset),

      .p0_wstrb(dcache_p0_wstrb),
      .p1_wstrb(dcache_p1_wstrb),


      .p0_wdata(dcache_p0_wdata),
      .p1_wdata(dcache_p1_wdata),

      .uncached(dcache_uncached),
      .p0_size (dcache_p0_size),
      .p1_size (dcache_p1_size),

      .addr_ok (dcache_addr_ok),
      .data_ok (dcache_data_ok),
      .p0_rdata(dcache_p0_rdata),
      .p1_rdata(dcache_p1_rdata),

      .rd_req(data_rd_req),
      .rd_type(data_rd_type),
      .rd_addr(data_rd_addr),
      .rd_rdy(data_rd_rdy),
      .ret_valid(data_ret_valid),
      .ret_last(data_ret_last),
      .ret_data(data_ret_data),
      .wr_req(data_wr_req),
      .wr_type(data_wr_type),
      .wr_addr(data_wr_addr),
      .wr_wstrb(data_wr_wstrb),
      .wr_data(data_wr_data),
      .wr_rdy(data_wr_rdy)
  );

  axi_bridge axi_bridge_0 (
      .clk  (aclk),
      .reset(~aresetn),

      .arid(arid),
      .araddr(araddr),
      .arlen(arlen),
      .arsize(arsize),
      .arburst(arburst),
      .arlock(arlock),
      .arcache(arcache),
      .arprot(arprot),
      .arvalid(arvalid),
      .arready(arready),

      .rid(rid),
      .rdata(rdata),
      .rresp(rresp),
      .rlast(rlast),
      .rvalid(rvalid),
      .rready(rready),

      .awid(awid),
      .awaddr(awaddr),
      .awlen(awlen),
      .awsize(awsize),
      .awburst(awburst),
      .awlock(awlock),
      .awcache(awcache),
      .awprot(awprot),
      .awvalid(awvalid),
      .awready(awready),

      .wid(wid),
      .wdata(wdata),
      .wstrb(wstrb),
      .wlast(wlast),
      .wvalid(wvalid),
      .wready(wready),

      .bid(bid),
      .bresp(bresp),
      .bvalid(bvalid),
      .bready(bready),

      .inst_rd_req(inst_rd_req),
      .inst_rd_type(inst_rd_type),
      .inst_rd_addr(inst_rd_addr),
      .inst_rd_rdy(inst_rd_rdy),
      .inst_ret_valid(inst_ret_valid),
      .inst_ret_last(inst_ret_last),
      .inst_ret_data(inst_ret_data),
      .inst_wr_req(inst_wr_req),
      .inst_wr_type(inst_wr_type),
      .inst_wr_addr(inst_wr_addr),
      .inst_wr_wstrb(inst_wr_wstrb),
      .inst_wr_data(inst_wr_data),
      .inst_wr_rdy(inst_wr_rdy),

      .data_rd_req(data_rd_req),
      .data_rd_type(data_rd_type),
      .data_rd_addr(data_rd_addr),
      .data_rd_rdy(data_rd_rdy),
      .data_ret_valid(data_ret_valid),
      .data_ret_last(data_ret_last),
      .data_ret_data(data_ret_data),
      .data_wr_req(data_wr_req),
      .data_wr_type(data_wr_type),
      .data_wr_addr(data_wr_addr),
      .data_wr_wstrb(data_wr_wstrb),
      .data_wr_data(data_wr_data),
      .data_wr_rdy(data_wr_rdy),
      .write_buffer_empty()
  );

`ifdef DIFFTEST_EN
  DifftestInstrCommit DifftestInstrCommit0 (
      .clock         (aclk),
      .coreid        (0),
      .index         (0),
      .valid         (a_difftest.valid),
      .pc            (debug0_wb_pc),
      .instr         (a_difftest.instr),
      .skip          (0),
      .is_TLBFILL    (a_difftest.is_TLBFILL),
      .TLBFILL_index (a_difftest.TLBFILL_index),
      .is_CNTinst    (a_difftest.is_CNTinst),
      .timer_64_value(a_difftest.timer_64_value),
      .wen           (debug0_wb_rf_wen),
      .wdest         (debug0_wb_rf_wnum),
      .wdata         (debug0_wb_rf_wdata),
      .csr_rstat     (a_difftest.csr_rstat),
      .csr_data      (a_difftest.csr_data)
  );

  DifftestStoreEvent DifftestStoreEvent0 (
      .clock     (aclk),
      .coreid    (0),
      .index     (0),
      .valid     (a_difftest.store_valid),
      .storePAddr(a_difftest.storePAddr),
      .storeVAddr(a_difftest.storeVAddr),
      .storeData (a_difftest.storeData)
  );

  DifftestLoadEvent DifftestLoadEvent0 (
      .clock (aclk),
      .coreid(0),
      .index (0),
      .valid (a_difftest.load_valid),
      .paddr (a_difftest.loadPAddr),
      .vaddr (a_difftest.loadVAddr)
  );

  DifftestInstrCommit DifftestInstrCommit1 (
      .clock         (aclk),
      .coreid        (0),
      .index         (1),
      .valid         (b_difftest.valid),
      .pc            (debug1_wb_pc),
      .instr         (b_difftest.instr),
      .skip          (0),
      .is_TLBFILL    (b_difftest.is_TLBFILL),
      .TLBFILL_index (b_difftest.TLBFILL_index),
      .is_CNTinst    (b_difftest.is_CNTinst),
      .timer_64_value(b_difftest.timer_64_value),
      .wen           (debug1_wb_rf_wen),
      .wdest         (debug1_wb_rf_wnum),
      .wdata         (debug1_wb_rf_wdata),
      .csr_rstat     (b_difftest.csr_rstat),
      .csr_data      (b_difftest.csr_data)
  );

  DifftestStoreEvent DifftestStoreEvent1 (
      .clock     (aclk),
      .coreid    (0),
      .index     (1),
      .valid     (b_difftest.store_valid),
      .storePAddr(b_difftest.storePAddr),
      .storeVAddr(b_difftest.storeVAddr),
      .storeData (b_difftest.storeData)
  );

  DifftestLoadEvent DifftestLoadEvent1 (
      .clock (aclk),
      .coreid(0),
      .index (1),
      .valid (b_difftest.load_valid),
      .paddr (b_difftest.loadPAddr),
      .vaddr (b_difftest.loadVAddr)
  );

  DifftestGRegState DifftestGRegState (
      .clock (aclk),
      .coreid(0),
      .gpr_0 (0),
      .gpr_1 (core_0.u_regfile.rf[1]),
      .gpr_2 (core_0.u_regfile.rf[2]),
      .gpr_3 (core_0.u_regfile.rf[3]),
      .gpr_4 (core_0.u_regfile.rf[4]),
      .gpr_5 (core_0.u_regfile.rf[5]),
      .gpr_6 (core_0.u_regfile.rf[6]),
      .gpr_7 (core_0.u_regfile.rf[7]),
      .gpr_8 (core_0.u_regfile.rf[8]),
      .gpr_9 (core_0.u_regfile.rf[9]),
      .gpr_10(core_0.u_regfile.rf[10]),
      .gpr_11(core_0.u_regfile.rf[11]),
      .gpr_12(core_0.u_regfile.rf[12]),
      .gpr_13(core_0.u_regfile.rf[13]),
      .gpr_14(core_0.u_regfile.rf[14]),
      .gpr_15(core_0.u_regfile.rf[15]),
      .gpr_16(core_0.u_regfile.rf[16]),
      .gpr_17(core_0.u_regfile.rf[17]),
      .gpr_18(core_0.u_regfile.rf[18]),
      .gpr_19(core_0.u_regfile.rf[19]),
      .gpr_20(core_0.u_regfile.rf[20]),
      .gpr_21(core_0.u_regfile.rf[21]),
      .gpr_22(core_0.u_regfile.rf[22]),
      .gpr_23(core_0.u_regfile.rf[23]),
      .gpr_24(core_0.u_regfile.rf[24]),
      .gpr_25(core_0.u_regfile.rf[25]),
      .gpr_26(core_0.u_regfile.rf[26]),
      .gpr_27(core_0.u_regfile.rf[27]),
      .gpr_28(core_0.u_regfile.rf[28]),
      .gpr_29(core_0.u_regfile.rf[29]),
      .gpr_30(core_0.u_regfile.rf[30]),
      .gpr_31(core_0.u_regfile.rf[31])
  );

  DifftestCSRRegState DifftestCSRRegState (
      .clock    (aclk),
      .coreid   (0),
      .crmd     (csr_difftest.CRMD),
      .prmd     (csr_difftest.PRMD),
      .euen     (0),
      .ecfg     (csr_difftest.ECFG),
      .estat    (csr_difftest.ESTAT),
      .era      (csr_difftest.ERA),
      .badv     (csr_difftest.BADV),
      .eentry   (csr_difftest.EENTRY),
      .tlbidx   (csr_difftest.TLBIDX),
      .tlbehi   (csr_difftest.TLBEHI),
      .tlbelo0  (csr_difftest.TLBELO0),
      .tlbelo1  (csr_difftest.TLBELO1),
      .asid     (csr_difftest.ASID),
      .pgdl     (0),
      .pgdh     (0),
      .save0    (csr_difftest.SAVE0),
      .save1    (csr_difftest.SAVE1),
      .save2    (csr_difftest.SAVE2),
      .save3    (csr_difftest.SAVE3),
      .tid      (csr_difftest.TID),
      .tcfg     (csr_difftest.TCFG),
      .tval     (csr_difftest.TVAL),
      .ticlr    (0),
      .llbctl   (csr_difftest.LLBCTL),
      .tlbrentry(csr_difftest.TLBRENTRY),
      .dmw0     (csr_difftest.DMW0),
      .dmw1     (csr_difftest.DMW1)
  );

  DifftestExcpEvent DifftestExcpEvent (
      .clock        (aclk),
      .coreid       (0),
      .excp_valid   (excp_difftest.excp_valid),
      .eret         (excp_difftest.eret),
      .intrNo       (excp_difftest.intrNo),
      .cause        (excp_difftest.cause),
      .exceptionPC  (excp_difftest.exceptionPC),
      .exceptionInst(excp_difftest.exceptionInst)
  );

`endif

endmodule
