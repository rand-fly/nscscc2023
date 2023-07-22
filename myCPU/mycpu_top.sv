`include "definitions.svh"

`ifdef SIMU
module core_top(
`else
module mycpu_top(
`endif
    input wire          aclk,
    input wire          aresetn,
    input wire   [ 7:0] intrpt, 

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
    input wire          arready,
    //read back
    input wire  [ 3:0]  rid,
    input wire  [31:0]  rdata,
    input wire  [ 1:0]  rresp,
    input wire          rlast,
    input wire          rvalid,
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
    input wire          awready,
    //write data
    output logic [ 3:0] wid,
    output logic [31:0] wdata,
    output logic [ 3:0] wstrb,
    output logic        wlast,
    output logic        wvalid,
    input wire          wready,
    //write back
    input  wire [ 3:0]  bid,
    input  wire [ 1:0]  bresp,
    input  wire         bvalid,
    output logic        bready,

    //debug
    input wire          break_point,
    input wire          infor_flag,
    input wire   [ 4:0] reg_num,
    output logic        ws_valid,
    output logic [31:0] rf_rdata,

    output logic [31:0] debug1_wb_pc,
    output logic [ 3:0] debug1_wb_rf_wen,
    output logic [ 4:0] debug1_wb_rf_wnum,
    output logic [31:0] debug1_wb_rf_wdata,

    output logic [31:0] debug0_wb_pc,
    output logic [ 3:0] debug0_wb_rf_wen,
    output logic [ 4:0] debug0_wb_rf_wnum,
    output logic [31:0] debug0_wb_rf_wdata
);

logic        icache_req;
logic [31:0] icache_addr;
logic        icache_uncached;
logic        icache_addr_ok;
logic        icache_data_ok;
logic [63:0] icache_rdata;

logic        dcache_req;
logic        dcache_wr;
logic [ 1:0] dcache_size;
logic [ 3:0] dcache_wstrb;
logic [31:0] dcache_addr;
logic [31:0] dcache_wdata;
logic        dcache_uncached;
logic        dcache_addr_ok;
logic        dcache_data_ok;
logic [31:0] dcache_rdata;

logic                      inst_rd_req;
logic [ 2:0]               inst_rd_type;
logic [31:0]               inst_rd_addr;
logic                      inst_rd_rdy;
logic                      inst_ret_valid;
logic                      inst_ret_last;
logic [31:0]               inst_ret_data;
logic                      inst_wr_req;
logic [ 2:0]               inst_wr_type;
logic [31:0]               inst_wr_addr;
logic [ 3:0]               inst_wr_wstrb;
logic [`LINE_WIDTH-1:0]    inst_wr_data;
logic                      inst_wr_rdy;

logic                      data_rd_req;
logic [ 2:0]               data_rd_type;
logic [31:0]               data_rd_addr;
logic                      data_rd_rdy;
logic                      data_ret_valid;
logic                      data_ret_last;
logic [31:0]               data_ret_data;
logic                      data_wr_req;
logic [ 2:0]               data_wr_type;
logic [31:0]               data_wr_addr;
logic [ 3:0]               data_wr_wstrb;
logic [`LINE_WIDTH-1:0]    data_wr_data;
logic                      data_wr_rdy;

`ifdef DIFFTEST_EN
difftest_t wb_a_difftest;
difftest_t wb_b_difftest;
difftest_excp_t wb_excp_difftest;
difftest_csr_t wb_csr_difftest;
`endif

core core_0(
    .clk(aclk),
    .resetn(aresetn),

    .icache_req(icache_req),
    .icache_addr(icache_addr),
    .icache_uncached(icache_uncached),
    .icache_addr_ok(icache_addr_ok),
    .icache_data_ok(icache_data_ok),
    .icache_rdata(icache_rdata),

    .dcache_req(dcache_req),
    .dcache_wr(dcache_wr),
    .dcache_size(dcache_size),
    .dcache_wstrb(dcache_wstrb),
    .dcache_addr(dcache_addr),
    .dcache_wdata(dcache_wdata),
    .dcache_uncached(dcache_uncached),
    .dcache_addr_ok(dcache_addr_ok),
    .dcache_data_ok(dcache_data_ok),
    .dcache_rdata(dcache_rdata),

    .debug0_wb_pc(debug0_wb_pc),
    .debug0_wb_rf_wen(debug0_wb_rf_wen),
    .debug0_wb_rf_wnum(debug0_wb_rf_wnum),
    .debug0_wb_rf_wdata(debug0_wb_rf_wdata),

    .debug1_wb_pc(debug1_wb_pc),
    .debug1_wb_rf_wen(debug1_wb_rf_wen),
    .debug1_wb_rf_wnum(debug1_wb_rf_wnum),
    .debug1_wb_rf_wdata(debug1_wb_rf_wdata)

`ifdef DIFFTEST_EN
,   .wb_a_difftest(wb_a_difftest),
    .wb_b_difftest(wb_b_difftest),
    .wb_excp_difftest(wb_excp_difftest),
    .wb_csr_difftest(wb_csr_difftest)
`endif
);

logic [31:0] icache_rdata_l;
logic [31:0] icache_rdata_h;

assign icache_rdata = {icache_rdata_h, icache_rdata_l};

icache icache(
    .clk(aclk),
    .resetn(aresetn),

    .valid(icache_req),
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

logic [31:0] dcache_rdata_l;
logic [31:0] dcache_rdata_h;

assign dcache_rdata = dcache_rdata_l;

// cache dcache_0(
//     .clk(aclk),
//     .resetn(aresetn),

//     .valid(dcache_req),
//     .op(dcache_wr),
//     .tag(dcache_addr[31:12]),
//     .index(dcache_addr[11:`OFFSET_WIDTH]),
//     .offset(dcache_addr[`OFFSET_WIDTH:0]),
//     .wstrb(dcache_wstrb),
//     .wdata(dcache_wdata),
//     .uncached(dcache_uncached),
//     .size(dcache_size),
//     .addr_ok(dcache_addr_ok),
//     .data_ok(dcache_data_ok),
//     .rdata_l(dcache_rdata_l),
//     .rdata_h(dcache_rdata_h),

//     .rd_req(data_rd_req),
//     .rd_type(data_rd_type),
//     .rd_addr(data_rd_addr),
//     .rd_rdy(data_rd_rdy),
//     .ret_valid(data_ret_valid),
//     .ret_last(data_ret_last),
//     .ret_data(data_ret_data),
//     .wr_req(data_wr_req),
//     .wr_type(data_wr_type),
//     .wr_addr(data_wr_addr),
//     .wr_wstrb(data_wr_wstrb),
//     .wr_data(data_wr_data),
//     .wr_rdy(data_wr_rdy)
// );

dcache dcache_0(
    .clk(aclk),
    .resetn(aresetn),

    .p0_valid(dcache_req),
    .p0_op(dcache_wr),
    .p0_tag(dcache_addr[31:12]),
    .p0_index(dcache_addr[11:`OFFSET_WIDTH]),
    .p0_offset(dcache_addr[`OFFSET_WIDTH:0]),
    .p0_wstrb(dcache_wstrb),
    .p0_wdata(dcache_wdata),
    .p0_uncached(dcache_uncached),
    .p0_size(dcache_size),
    .p0_addr_ok(dcache_addr_ok),
    .p0_data_ok(dcache_data_ok),
    .p0_rdata(dcache_rdata_l),

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

axi_bridge axi_bridge_0(
    .clk(aclk),
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
DifftestInstrCommit DifftestInstrCommit0(
    .clock              (aclk                       ),
    .coreid             (0                          ),
    .index              (0                          ),
    .valid              (wb_a_difftest.valid        ),
    .pc                 (debug0_wb_pc               ),
    .instr              (wb_a_difftest.instr        ),
    .skip               (0                          ),
    .is_TLBFILL         (wb_a_difftest.is_TLBFILL   ),
    .TLBFILL_index      (wb_a_difftest.TLBFILL_index),
    .is_CNTinst         (wb_a_difftest.is_CNTinst   ),
    .timer_64_value     (wb_a_difftest.timer_64_value),
    .wen                (debug0_wb_rf_wen           ),
    .wdest              (debug0_wb_rf_wnum          ),
    .wdata              (debug0_wb_rf_wdata         ),
    .csr_rstat          (wb_a_difftest.csr_rstat    ),
    .csr_data           (wb_a_difftest.csr_data     )
);

DifftestStoreEvent DifftestStoreEvent0(
    .clock              (aclk                       ),
    .coreid             (0                          ),
    .index              (0                          ),
    .valid              (wb_a_difftest.store_valid  ),
    .storePAddr         (wb_a_difftest.storePAddr   ),
    .storeVAddr         (wb_a_difftest.storeVAddr   ),
    .storeData          (wb_a_difftest.storeData    )
);

DifftestLoadEvent DifftestLoadEvent0(
    .clock              (aclk                       ),
    .coreid             (0                          ),
    .index              (0                          ),
    .valid              (wb_a_difftest.load_valid   ),
    .paddr              (wb_a_difftest.loadPAddr    ),
    .vaddr              (wb_a_difftest.loadVAddr    )
);

DifftestInstrCommit DifftestInstrCommit1(
    .clock              (aclk                       ),
    .coreid             (0                          ),
    .index              (1                          ),
    .valid              (wb_b_difftest.valid        ),
    .pc                 (debug1_wb_pc               ),
    .instr              (wb_b_difftest.instr        ),
    .skip               (0                          ),
    .is_TLBFILL         (wb_b_difftest.is_TLBFILL   ),
    .TLBFILL_index      (wb_b_difftest.TLBFILL_index),
    .is_CNTinst         (wb_b_difftest.is_CNTinst   ),
    .timer_64_value     (wb_b_difftest.timer_64_value),
    .wen                (debug1_wb_rf_wen           ),
    .wdest              (debug1_wb_rf_wnum          ),
    .wdata              (debug1_wb_rf_wdata         ),
    .csr_rstat          (wb_b_difftest.csr_rstat    ),
    .csr_data           (wb_b_difftest.csr_data     )
);

DifftestStoreEvent DifftestStoreEvent1(
    .clock              (aclk                       ),
    .coreid             (0                          ),
    .index              (1                          ),
    .valid              (wb_b_difftest.store_valid  ),
    .storePAddr         (wb_b_difftest.storePAddr   ),
    .storeVAddr         (wb_b_difftest.storeVAddr   ),
    .storeData          (wb_b_difftest.storeData    )
);

DifftestLoadEvent DifftestLoadEvent1(
    .clock              (aclk                       ),
    .coreid             (0                          ),
    .index              (1                          ),
    .valid              (wb_b_difftest.load_valid   ),
    .paddr              (wb_b_difftest.loadPAddr    ),
    .vaddr              (wb_b_difftest.loadVAddr    )
);

DifftestGRegState DifftestGRegState(
    .clock              (aclk                   ),
    .coreid             (0                      ),
    .gpr_0              (0                      ),
    .gpr_1              (core_0.regfile_0.rf[1] ),
    .gpr_2              (core_0.regfile_0.rf[2] ),
    .gpr_3              (core_0.regfile_0.rf[3] ),
    .gpr_4              (core_0.regfile_0.rf[4] ),
    .gpr_5              (core_0.regfile_0.rf[5] ),
    .gpr_6              (core_0.regfile_0.rf[6] ),
    .gpr_7              (core_0.regfile_0.rf[7] ),
    .gpr_8              (core_0.regfile_0.rf[8] ),
    .gpr_9              (core_0.regfile_0.rf[9] ),
    .gpr_10             (core_0.regfile_0.rf[10]),
    .gpr_11             (core_0.regfile_0.rf[11]),
    .gpr_12             (core_0.regfile_0.rf[12]),
    .gpr_13             (core_0.regfile_0.rf[13]),
    .gpr_14             (core_0.regfile_0.rf[14]),
    .gpr_15             (core_0.regfile_0.rf[15]),
    .gpr_16             (core_0.regfile_0.rf[16]),
    .gpr_17             (core_0.regfile_0.rf[17]),
    .gpr_18             (core_0.regfile_0.rf[18]),
    .gpr_19             (core_0.regfile_0.rf[19]),
    .gpr_20             (core_0.regfile_0.rf[20]),
    .gpr_21             (core_0.regfile_0.rf[21]),
    .gpr_22             (core_0.regfile_0.rf[22]),
    .gpr_23             (core_0.regfile_0.rf[23]),
    .gpr_24             (core_0.regfile_0.rf[24]),
    .gpr_25             (core_0.regfile_0.rf[25]),
    .gpr_26             (core_0.regfile_0.rf[26]),
    .gpr_27             (core_0.regfile_0.rf[27]),
    .gpr_28             (core_0.regfile_0.rf[28]),
    .gpr_29             (core_0.regfile_0.rf[29]),
    .gpr_30             (core_0.regfile_0.rf[30]),
    .gpr_31             (core_0.regfile_0.rf[31])
);

DifftestCSRRegState DifftestCSRRegState(
    .clock              (aclk                  ),
    .coreid             (0                     ),
    .crmd               (wb_csr_difftest.CRMD     ),
    .prmd               (wb_csr_difftest.PRMD     ),
    .euen               (0                     ),
    .ecfg               (wb_csr_difftest.ECFG     ),
    .estat              (wb_csr_difftest.ESTAT    ),
    .era                (wb_csr_difftest.ERA      ),
    .badv               (wb_csr_difftest.BADV     ),
    .eentry             (wb_csr_difftest.EENTRY   ),
    .tlbidx             (wb_csr_difftest.TLBIDX   ),
    .tlbehi             (wb_csr_difftest.TLBEHI   ),
    .tlbelo0            (wb_csr_difftest.TLBELO0  ),
    .tlbelo1            (wb_csr_difftest.TLBELO1  ),
    .asid               (wb_csr_difftest.ASID     ),
    .pgdl               (0                     ),
    .pgdh               (0                     ),
    .save0              (wb_csr_difftest.SAVE0    ),
    .save1              (wb_csr_difftest.SAVE1    ),
    .save2              (wb_csr_difftest.SAVE2    ),
    .save3              (wb_csr_difftest.SAVE3    ),
    .tid                (wb_csr_difftest.TID      ),
    .tcfg               (wb_csr_difftest.TCFG     ),
    .tval               (wb_csr_difftest.TVAL     ),
    .ticlr              (0                     ),
    .llbctl             (0                     ),
    .tlbrentry          (wb_csr_difftest.TLBRENTRY),
    .dmw0               (wb_csr_difftest.DMW0     ),
    .dmw1               (wb_csr_difftest.DMW1     )
);

DifftestExcpEvent DifftestExcpEvent(
    .clock              (aclk           ),
    .coreid             (0              ),
    .excp_valid         (wb_excp_difftest.excp_valid),
    .eret               (wb_excp_difftest.eret),
    .intrNo             (wb_csr_difftest.ESTAT[12:2]),
    .cause              (wb_csr_difftest.ESTAT[21:16]),
    .exceptionPC        (wb_excp_difftest.exceptionPC),
    .exceptionInst      (wb_excp_difftest.exceptionInst)
);

`endif

endmodule
