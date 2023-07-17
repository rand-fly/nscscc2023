`include "definitions.svh"

`define CACHE_LINE_32B
`ifdef CACHE_LINE_16B
`define LINE_WIDTH 128
`define LINE_WORD_NUM 4
`elsif CACHE_LINE_32B
`define LINE_WIDTH 256
`define LINE_WORD_NUM 8
`endif

module mycpu_top(
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

    output logic [31:0] debug0_wb_pc,
    output logic [ 3:0] debug0_wb_rf_wen,
    output logic [ 4:0] debug0_wb_rf_wnum,
    output logic [31:0] debug0_wb_rf_wdata,

    output logic [31:0] debug1_wb_pc,
    output logic [ 3:0] debug1_wb_rf_wen,
    output logic [ 4:0] debug1_wb_rf_wnum,
    output logic [31:0] debug1_wb_rf_wdata 
);

logic        icache_req;
logic        icache_wr;
logic [ 1:0] icache_size;
logic [ 3:0] icache_wstrb;
logic [31:0] icache_addr;
logic [31:0] icache_wdata;
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

core core_0(
    .clk(aclk),
    .resetn(aresetn),

    .icache_req(icache_req),
    .icache_wr(icache_wr),
    .icache_size(icache_size),
    .icache_wstrb(icache_wstrb),
    .icache_addr(icache_addr),
    .icache_wdata(icache_wdata),
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
);

logic [31:0] icache_rdata_l;
logic [31:0] icache_rdata_h;

assign icache_rdata = {icache_rdata_h, icache_rdata_l};

cache icache(
    .clk(aclk),
    .resetn(aresetn),

    .valid(icache_req),
    .op(icache_wr),
    .tag(icache_addr[31:12]),
    .index(icache_addr[11:5]),
    .offset(icache_addr[4:0]),
    .wstrb(icache_wstrb),
    .wdata(icache_wdata),
    .uncached(icache_uncached),
    .size(icache_size),
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

cache dcache(
    .clk(aclk),
    .resetn(aresetn),

    .valid(dcache_req),
    .op(dcache_wr),
    .tag(dcache_addr[31:12]),
    .index(dcache_addr[11:5]),
    .offset(dcache_addr[4:0]),
    .wstrb(dcache_wstrb),
    .wdata(dcache_wdata),
    .uncached(dcache_uncached),
    .size(dcache_size),
    .addr_ok(dcache_addr_ok),
    .data_ok(dcache_data_ok),
    .rdata_l(dcache_rdata_l),
    .rdata_h(dcache_rdata_h),

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

endmodule