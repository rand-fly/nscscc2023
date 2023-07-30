`include "definitions.svh"

module dcache(
    // Clock and reset
    input wire clk,
    input wire resetn,

    // Pipe interface
    input wire                      p0_valid,
    input wire                      p0_op,
    input wire [`TAG_WIDTH-1:0]     p0_tag,
    input wire [`INDEX_WIDTH-1:0]   p0_index,
    input wire [`OFFSET_WIDTH-1:0]  p0_offset,
    input wire [3:0]                p0_wstrb, // write strobe
    input wire [31:0]               p0_wdata,
    input wire                      p0_uncached,
    input wire [1:0]                p0_size,
    output wire                     p0_addr_ok,
    output wire                     p0_data_ok,
    output wire [31:0]              p0_rdata,

    input wire                      p1_valid,
    input wire                      p1_op,
    input wire [`TAG_WIDTH-1:0]     p1_tag,
    input wire [`INDEX_WIDTH-1:0]   p1_index,
    input wire [`OFFSET_WIDTH-1:0]  p1_offset,
    input wire [3:0]                p1_wstrb, // write strobe
    input wire [31:0]               p1_wdata,
    input wire                      p1_uncached,
    input wire [1:0]                p1_size,
    output wire                     p1_addr_ok,
    output wire                     p1_data_ok,
    output wire [31:0]              p1_rdata,


    // AXI
    output wire rd_req,
    output wire [2:0] rd_type,
    output wire [31:0] rd_addr,
    input wire rd_rdy,
    input wire ret_valid,
    input wire ret_last,
    input wire [31:0] ret_data,
    output wire wr_req,
    output wire [2:0] wr_type,
    output wire [31:0] wr_addr,
    output wire [3:0] wr_wstrb,
    output wire [`LINE_WIDTH-1:0] wr_data,
    input wire wr_rdy
);

wire [`LINE_WIDTH-1:0] p0_data_way0;
wire [`LINE_WIDTH-1:0] p0_data_way1;
wire [`LINE_WIDTH-1:0] p1_data_way0;
wire [`LINE_WIDTH-1:0] p1_data_way1;
wire [`INDEX_WIDTH-1:0] p0_data_addr;
wire [`INDEX_WIDTH-1:0] p1_data_addr;

blk_mem_gen_cache_32 data_way0_ram(
    .addra(p0_data_addr),
    .clka(clk),
    .dina(p0_cache_write_data_actually),
    .douta(p0_data_way0),
    .wea(p0_cache_write & (p0_cache_write_way_id == 0)),

    .addrb(p1_data_addr),
    .clkb(clk),
    .dinb(p1_cache_write_data_actually),
    .doutb(p1_data_way0),
    .web(p1_cache_write & (p1_cache_write_way_id == 0))
);

blk_mem_gen_cache_32 data_way1_ram(
    .addra(p0_data_addr),
    .clka(clk),
    .dina(p0_cache_write_data_actually),
    .douta(p0_data_way1),
    .wea(p0_cache_write & (p0_cache_write_way_id == 1)),

    .addrb(p1_data_addr),
    .clkb(clk),
    .dinb(p1_cache_write_data_actually),
    .doutb(p1_data_way1),
    .web(p1_cache_write & (p1_cache_write_way_id == 1))
);

`ifdef CACHE_4WAY
wire [`LINE_WIDTH-1:0] p0_data_way2;
wire [`LINE_WIDTH-1:0] p0_data_way3;
wire [`LINE_WIDTH-1:0] p1_data_way2;
wire [`LINE_WIDTH-1:0] p1_data_way3;
bkl_mem_gen_cache_32 data_way2_ram(
    .addra(p0_data_addr),
    .clka(clk),
    .dina(p0_cache_write_data_actually),
    .douta(p0_data_way2),
    .wea(p0_cache_write & (p0_cache_write_way_id == 2)),

    .addrb(p1_data_addr),
    .clkb(clk),
    .dinb(p1_cache_write_data_actually),
    .doutb(p1_data_way2),
    .web(p1_cache_write & (p1_cache_write_way_id == 2))
);

bkl_mem_gen_cache_32 data_way3_ram(
    .addra(p0_data_addr),
    .clka(clk),
    .dina(p0_cache_write_data_actually),
    .douta(p0_data_way3),
    .wea(p0_cache_write & (p0_cache_write_way_id == 3)),

    .addrb(p1_data_addr),
    .clkb(clk),
    .dinb(p1_cache_write_data_actually),
    .doutb(p1_data_way3),
    .web(p1_cache_write & (p1_cache_write_way_id == 3))
);
`endif


`define CACHE_2WAY

`ifdef CACHE_2WAY

`define CACHE_WAY_NUM 2
`define CACHE_WAY_NUM_LOG2 1

`elsif CACHE_4WAY

`define CACHE_WAY_NUM 4
`define CACHE_WAY_NUM_LOG2 2

`endif

reg                         p0_op_reg;
reg [`INDEX_WIDTH-1:0]      p0_index_reg;
reg [`INDEX_WIDTH-1:0]      p0_index_reg_miss;
reg [`TAG_WIDTH-1:0]        p0_tag_reg;
reg [`OFFSET_WIDTH-1:0]     p0_offset_reg;
reg [`OFFSET_WIDTH-1:0]     p0_offset_reg_miss;
wire [`OFFSET_WIDTH-1:0]    p0_offset_cell_w;
wire [`OFFSET_WIDTH-3:0]    p0_offset_w_reg; // word offset
reg                         p0_uncached_reg;
reg [1:0]                   p0_size_reg;
reg [3:0]                   p0_wstrb_reg;
reg [31:0]                  p0_wdata_reg;
reg                         p0_wdata_ok_reg;

reg                         p1_op_reg;
reg [`INDEX_WIDTH-1:0]      p1_index_reg;
reg [`INDEX_WIDTH-1:0]      p1_index_reg_miss;
reg [`TAG_WIDTH-1:0]        p1_tag_reg;
reg [`OFFSET_WIDTH-1:0]     p1_offset_reg;
reg [`OFFSET_WIDTH-1:0]     p1_offset_reg_miss;
wire [`OFFSET_WIDTH-1:0]    p1_offset_cell_w;
wire [`OFFSET_WIDTH-3:0]    p1_offset_w_reg; // word offset
reg                         p1_uncached_reg;
reg [1:0]                   p1_size_reg;
reg [3:0]                   p1_wstrb_reg;
reg [31:0]                  p1_wdata_reg;
reg                         p1_wdata_ok_reg;

// port1


`define p0_get_data(way_id_) (\
        {`LINE_WIDTH{way_id_==0}} & p0_data_way0\
    |   {`LINE_WIDTH{way_id_==1}} & p0_data_way1\
`ifdef CACHE_4WAY\
    |   {`LINE_WIDTH{way_id_==2}} & p0_data_way2\
    |   {`LINE_WIDTH{way_id_==3}} & p0_data_way3\
`endif\
)



reg                     [`TAG_WIDTH-1:0] p0_tag_way0 [0:`LINE_NUM-1];
reg                     [`TAG_WIDTH-1:0] p0_tag_way1 [0:`LINE_NUM-1];
(* keep = "true" *) reg [`TAG_WIDTH-1:0] p0_preload_tag_way0;
(* keep = "true" *) reg [`TAG_WIDTH-1:0] p0_preload_tag_way1;

`ifdef CACHE_4WAY
reg                     [`TAG_WIDTH-1:0] p0_tag_way2 [0:255];
reg                     [`TAG_WIDTH-1:0] p0_tag_way3 [0:255];
(* keep = "true" *) reg [`TAG_WIDTH-1:0] p0_preload_tag_way2;
(* keep = "true" *) reg [`TAG_WIDTH-1:0] p0_preload_tag_way3;
`endif

`define p0_get_preload_tag(way_id_) (\
        {`TAG_WIDTH{way_id_==0}} & p0_preload_tag_way0\
    |   {`TAG_WIDTH{way_id_==1}} & p0_preload_tag_way1\
`ifdef CACHE_4WAY\
    |   {`TAG_WIDTH{way_id_==2}} & p0_preload_tag_way2\
    |   {`TAG_WIDTH{way_id_==3}} & p0_preload_tag_way3\
`endif\
)


reg [`LINE_NUM-1:0] p0_valid_way0;
reg [`LINE_NUM-1:0] p0_valid_way1;

`ifdef CACHE_4WAY
reg [`LINE_NUM-1:0] p0_valid_way2;
reg [`LINE_NUM-1:0] p0_valid_way3;
`endif

`define p0_get_valid(way_id_,index_) (\
        {1{way_id_==0}} & p0_valid_way0[index_]\
    |   {1{way_id_==1}} & p0_valid_way1[index_]\
`ifdef CACHE_4WAY\
    |   {1{way_id_==2}} & p0_valid_way2[index_]\
    |   {1{way_id_==3}} & p0_valid_way3[index_]\
`endif\
)

reg [`LINE_NUM-1:0] p0_dirty_way0;
reg [`LINE_NUM-1:0] p0_dirty_way1;

`ifdef CACHE_4WAY
reg [`LINE_NUM-1:0] p0_dirty_way2;
reg [`LINE_NUM-1:0] p0_dirty_way3;
`endif

`define p0_get_dirty(way_id_,index_) (\
        {1{way_id_==0}} & p0_dirty_way0[index_]\
    |   {1{way_id_==1}} & p0_dirty_way1[index_]\
`ifdef CACHE_4WAY\
    |   {1{way_id_==2}} & p0_dirty_way2[index_]\
    |   {1{way_id_==3}} & p0_dirty_way3[index_]\
`endif\
)

// port2

`define p1_get_data(way_id_) (\
        {`LINE_WIDTH{way_id_==0}} & p1_data_way0\
    |   {`LINE_WIDTH{way_id_==1}} & p1_data_way1\
`ifdef CACHE_4WAY\
    |   {`LINE_WIDTH{way_id_==2}} & p1_data_way2\
    |   {`LINE_WIDTH{way_id_==3}} & p1_data_way3\
`endif\
)

reg                     [`TAG_WIDTH-1:0] p1_tag_way0 [0:`LINE_NUM-1];
reg                     [`TAG_WIDTH-1:0] p1_tag_way1 [0:`LINE_NUM-1];
(* keep = "true" *) reg [`TAG_WIDTH-1:0] p1_preload_tag_way0;
(* keep = "true" *) reg [`TAG_WIDTH-1:0] p1_preload_tag_way1;

`ifdef CACHE_4WAY
reg                     [`TAG_WIDTH-1:0] p1_tag_way2 [0:255];
reg                     [`TAG_WIDTH-1:0] p1_tag_way3 [0:255];
(* keep = "true" *) reg [`TAG_WIDTH-1:0] p1_preload_tag_way2;
(* keep = "true" *) reg [`TAG_WIDTH-1:0] p1_preload_tag_way3;
`endif

`define p1_get_preload_tag(way_id_) (\
        {`TAG_WIDTH{way_id_==0}} & p1_preload_tag_way0\
    |   {`TAG_WIDTH{way_id_==1}} & p1_preload_tag_way1\
`ifdef CACHE_4WAY\
    |   {`TAG_WIDTH{way_id_==2}} & p1_preload_tag_way2\
    |   {`TAG_WIDTH{way_id_==3}} & p1_preload_tag_way3\
`endif\
)


reg [`LINE_NUM-1:0] p1_valid_way0;
reg [`LINE_NUM-1:0] p1_valid_way1;

`ifdef CACHE_4WAY
reg [`LINE_NUM-1:0] p1_valid_way2;
reg [`LINE_NUM-1:0] p1_valid_way3;
`endif

`define p1_get_valid(way_id_,index_) (\
        {1{way_id_==0}} & p1_valid_way0[index_]\
    |   {1{way_id_==1}} & p1_valid_way1[index_]\
`ifdef CACHE_4WAY\
    |   {1{way_id_==2}} & p1_valid_way2[index_]\
    |   {1{way_id_==3}} & p1_valid_way3[index_]\
`endif\
)

reg [`LINE_NUM-1:0] p1_dirty_way0;
reg [`LINE_NUM-1:0] p1_dirty_way1;

`ifdef CACHE_4WAY
reg [`LINE_NUM-1:0] p1_dirty_way2;
reg [`LINE_NUM-1:0] p1_dirty_way3;
`endif

`define p1_get_dirty(way_id_,index_) (\
        {1{way_id_==0}} & p1_dirty_way0[index_]\
    |   {1{way_id_==1}} & p1_dirty_way1[index_]\
`ifdef CACHE_4WAY\
    |   {1{way_id_==2}} & p1_dirty_way2[index_]\
    |   {1{way_id_==3}} & p1_dirty_way3[index_]\
`endif\
)

`define get_word(data_,offset_) (\
        {32{offset_==0}} & data_[31:0]\
    |   {32{offset_==1}} & data_[63:32]\
    |   {32{offset_==2}} & data_[95:64]\
    |   {32{offset_==3}} & data_[127:96]\
`ifdef CACHE_LINE_32B\
    |   {32{offset_==4}} & data_[159:128]\
    |   {32{offset_==5}} & data_[191:160]\
    |   {32{offset_==6}} & data_[223:192]\
    |   {32{offset_==7}} & data_[255:224]\
`endif\
`ifdef CACHE_LINE_64B\
    |   {32{offset_==4  }} & data_[159:128]\
    |   {32{offset_==5  }} & data_[191:160]\
    |   {32{offset_==6  }} & data_[223:192]\
    |   {32{offset_==7  }} & data_[255:224]\
    |   {32{offset_==8  }} & data_[287:256]\
    |   {32{offset_==9  }} & data_[319:288]\
    |   {32{offset_==10 }} & data_[351:320]\
    |   {32{offset_==11 }} & data_[383:352]\
    |   {32{offset_==12 }} & data_[415:384]\
    |   {32{offset_==13 }} & data_[447:416]\
    |   {32{offset_==14 }} & data_[479:448]\
    |   {32{offset_==15 }} & data_[511:480]\
`endif\
)


reg [2:0] p0_main_state;
reg [2:0] p1_main_state;

parameter OP_READ   =   3'b000;
parameter OP_WRITE  =   3'b001;
parameter OP_CACOP0 =   3'b100;
parameter OP_CACOP1 =   3'b101;
parameter OP_CACOP2 =   3'b110;
parameter OP_CACOP3 =   3'b111;

parameter RD_TYPE_CACHELINE = 3'b100;
parameter WR_TYPE_CACHELINE = 3'b100;

parameter MAIN_ST_IDLE      = 0;
parameter MAIN_ST_LOOKUP    = 1;
parameter MAIN_ST_MISS      = 2;      // wait for memory finish writing previous data
parameter MAIN_ST_REPLACE   = 3;   // write data and wait for memory finish reading miss data
parameter MAIN_ST_REFILL    = 4;

wire                    p0_rd_req;
wire [2:0]              p0_rd_type;
wire [31:0]             p0_rd_addr;
wire                    p0_wr_req;
wire [2:0]              p0_wr_type;
wire [31:0]             p0_wr_addr;
wire [3:0]              p0_wr_wstrb;
wire [`LINE_WIDTH-1:0]  p0_wr_data;

wire                    p1_rd_req;
wire [2:0]              p1_rd_type;
wire [31:0]             p1_rd_addr;
wire                    p1_wr_req;
wire [2:0]              p1_wr_type;
wire [31:0]             p1_wr_addr;
wire [3:0]              p1_wr_wstrb;
wire [`LINE_WIDTH-1:0]  p1_wr_data;

reg rd_addr_ok;
wire ret_valid_last;


reg p0_finished;
reg p1_finished;

wire p0_idle;
wire p0_lookup;
wire p0_miss;
wire p0_replace;
wire p0_refill;
wire p0_hit_write;
wire p0_refill_write;
wire p0_cache_write;

wire p1_idle;
wire p1_lookup;
wire p1_miss;
wire p1_replace;
wire p1_refill;
wire p1_hit_write;
wire p1_refill_write;
wire p1_cache_write;

wire p0_cache_hit;
wire p0_cache_hit_and_cached;
wire [`CACHE_WAY_NUM-1:0]       p0_cache_hit_way;
wire [`CACHE_WAY_NUM_LOG2-1:0]  p0_cache_hit_way_id;

wire p1_cache_hit;
wire p1_cache_hit_and_cached;
wire [`CACHE_WAY_NUM-1:0]       p1_cache_hit_way;
wire [`CACHE_WAY_NUM_LOG2-1:0]  p1_cache_hit_way_id;

wire pipe_interface_latch;

wire [`LINE_WIDTH-1:0]  p0_buffer_read_data_new;
wire [`LINE_WIDTH-1:0]  p0_cache_rd_data;
reg [`LINE_WIDTH-1:0]   p0_buffer_read_data;
reg [`OFFSET_WIDTH-3+1:0] p0_buffer_read_data_count;
reg [`OFFSET_WIDTH-3+1:0] p0_buffer_read_data_count_start;

wire [`LINE_WIDTH-1:0]  p1_buffer_read_data_new;
wire [`LINE_WIDTH-1:0]  p1_cache_rd_data;
reg [`LINE_WIDTH-1:0]   p1_buffer_read_data;
reg [`OFFSET_WIDTH-3+1:0] p1_buffer_read_data_count;
reg [`OFFSET_WIDTH-3+1:0] p1_buffer_read_data_count_start;

reg [`CACHE_WAY_NUM_LOG2-1:0]   replace_way_id;

reg [`TAG_WIDTH-1:0]            p0_replace_tag;
wire                            p0_replace_dirty;

reg [`TAG_WIDTH-1:0]            p1_replace_tag;
wire                            p1_replace_dirty;

reg [`LINE_WIDTH-1:0]           p0_cache_write_data_reg;
wire [`LINE_WIDTH-1:0]          p0_cache_write_data_actually;
reg [`LINE_SIZE-1:0]            p0_cache_wstrb_reg;
wire [`LINE_WIDTH-1:0]          p0_cache_write_data_strobe;
wire [`CACHE_WAY_NUM_LOG2-1:0]  p0_cache_write_way_id;

reg [`LINE_WIDTH-1:0]           p1_cache_write_data_reg;
wire [`LINE_WIDTH-1:0]          p1_cache_write_data_actually;
reg [`LINE_SIZE-1:0]            p1_cache_wstrb_reg;
wire [`LINE_WIDTH-1:0]          p1_cache_write_data_strobe;
wire [`CACHE_WAY_NUM_LOG2-1:0]  p1_cache_write_way_id;


wire next_p0_p0_same_line;
wire next_p0_p1_same_line;
wire next_p1_p0_same_line;
wire next_p1_p1_same_line;
wire next_p1_next_p0_same_line;
wire next_all_same_line;
wire merge_next_p0_next_p1;
reg merge_p0_p1_reg;

// generate
//     genvar i;
//     for (i = 0; i < 4; i = i + 1) begin: gen_wdata_actually
//         assign wdata_actually[8*i+7:8*i] = wstrb_reg[i] ? wdata_reg[8*i+7:8*i] : rdata[8*i+7:8*i];
//     end
// endgenerate

// always @(posedge clk) begin
//     if (main_state == MAIN_ST_LOOKUP) begin
//         wdata_actually_reg <= wdata_actually;
//     end
// end

assign p0_data_addr = (p0_addr_ok) ? p0_index : p0_index_reg;
assign p1_data_addr = (p1_addr_ok) ? p1_index : p1_index_reg;

assign p0_cache_write_data_strobe = {{(`LINE_WIDTH-32){1'b0}},
                                        {8{p0_wstrb[3]}},{8{p0_wstrb[2]}},
                                        {8{p0_wstrb[1]}},{8{p0_wstrb[0]}}} << (p0_offset_cell_w*8);
assign p1_cache_write_data_strobe = {{(`LINE_WIDTH-32){1'b0}},
                                        {8{p1_wstrb[3]}},
                                        {8{p1_wstrb[2]}},
                                        {8{p1_wstrb[1]}},
                                        {8{p1_wstrb[0]}}} << (p1_offset_cell_w*8);

assign p0_offset_cell_w = {p0_offset[`OFFSET_WIDTH-1:2],2'b0};
assign p1_offset_cell_w = {p1_offset[`OFFSET_WIDTH-1:2],2'b0};

assign p0_offset_w_reg = p0_offset_reg[`OFFSET_WIDTH-1:2];
assign p1_offset_w_reg = p1_offset_reg[`OFFSET_WIDTH-1:2];

assign p0_idle      = (p0_main_state == MAIN_ST_IDLE);
assign p0_lookup    = (p0_main_state == MAIN_ST_LOOKUP);
assign p0_miss      = (p0_main_state == MAIN_ST_MISS);
assign p0_replace   = (p0_main_state == MAIN_ST_REPLACE);
assign p0_refill    = (p0_main_state == MAIN_ST_REFILL);

assign p1_idle      = (p1_main_state == MAIN_ST_IDLE);
assign p1_lookup    = (p1_main_state == MAIN_ST_LOOKUP);
assign p1_miss      = (p1_main_state == MAIN_ST_MISS);
assign p1_replace   = (p1_main_state == MAIN_ST_REPLACE);
assign p1_refill    = (p1_main_state == MAIN_ST_REFILL);

assign ret_valid_last = (ret_valid & ret_last);

assign next_p0_p0_same_line = (p0_index == p0_index_reg) & (p0_tag == p0_tag_reg);
assign next_p0_p1_same_line = (p0_index == p1_index_reg) & (p0_tag == p1_tag_reg);
assign next_p1_p0_same_line = (p1_index == p0_index_reg) & (p1_tag == p0_tag_reg);
assign next_p1_p1_same_line = (p1_index == p1_index_reg) & (p1_tag == p1_tag_reg);
assign next_p1_next_p0_same_line = (p1_tag == p0_tag)
                                & (p1_index == p0_index);
assign next_all_same_line = next_p0_p0_same_line | next_p0_p1_same_line
                            | next_p1_p0_same_line | next_p1_p1_same_line;
assign merge_next_p0_next_p1 = next_p1_next_p0_same_line
                                & (p0_valid & p1_valid) & (p0_op == OP_WRITE) & (p1_op == OP_WRITE)
                                & (p0_uncached == p1_uncached);

assign pipe_interface_latch = p0_valid & (
    (p0_idle & p1_idle) |
    (p0_lookup & (p0_op_reg == OP_READ) & p0_cache_hit_and_cached & (p1_idle | ((p1_op_reg == OP_READ) & p1_cache_hit_and_cached)))
    );

assign p0_replace_dirty = `p0_get_valid(replace_way_id,p0_index_reg_miss) & `p0_get_dirty(replace_way_id, p0_index_reg_miss);
assign p1_replace_dirty = `p1_get_valid(replace_way_id,p1_index_reg_miss) & `p1_get_dirty(replace_way_id, p1_index_reg_miss);

always @(posedge clk) begin
    if (!resetn) begin
        p0_finished <= 1;
        p1_finished <= 1;
    end
    else begin
        if (p0_addr_ok) begin
            p0_finished <= 0;
        end
        else if (!p0_addr_ok & p0_data_ok) begin
            p0_finished <= 1;
        end
        if (p1_addr_ok) begin
            p1_finished <= 0;
        end
        else if (!p1_addr_ok & p1_data_ok) begin
            p1_finished <= 1;
        end
    end
end

wire [`LINE_SIZE-1:0]   p0_cache_wstrb_new = p0_cache_wstrb_reg | ({{(`LINE_SIZE-4){1'b0}},p0_wstrb} << p0_offset_cell_w);
wire [`LINE_WIDTH-1:0]  p0_cache_write_data_append = ({{(`LINE_WIDTH-32){1'b0}},p0_wdata} << (p0_offset_cell_w*8)) & p0_cache_write_data_strobe;

wire [`LINE_SIZE-1:0]   p1_cache_wstrb_new = p1_cache_wstrb_reg | ({{(`LINE_SIZE-4){1'b0}},p1_wstrb} << p1_offset_cell_w);
wire [`LINE_WIDTH-1:0]  p1_cache_write_data_append = ({{(`LINE_WIDTH-32){1'b0}},p1_wdata} << (p1_offset_cell_w*8)) & p1_cache_write_data_strobe;

always @(posedge clk) begin
    if (!resetn) begin
        merge_p0_p1_reg <= 0;
        p0_cache_wstrb_reg <= 0;
        p0_cache_write_data_reg <= 0;
        p1_cache_wstrb_reg <= 0;
        p1_cache_write_data_reg <= 0;
    end
    else begin
        // p0
        if (p0_addr_ok) begin
            p0_op_reg          <= p0_op;
            p0_index_reg       <= p0_index;
            p0_tag_reg         <= p0_tag;
            p0_offset_reg      <= p0_offset;
            p0_uncached_reg    <= p0_uncached;
            p0_size_reg        <= p0_size;
            p0_wstrb_reg       <= p0_wstrb;
            p0_wdata_reg       <= p0_wdata;
            if (!p0_uncached & (p0_op == OP_WRITE)) begin
                p0_cache_wstrb_reg      <= p0_cache_wstrb_new | ({(`LINE_SIZE){merge_next_p0_next_p1}} & p1_cache_wstrb_new);
                p0_cache_write_data_reg <= (p0_cache_write_data_reg & ~(p0_cache_write_data_strobe
                                            | ({(`LINE_WIDTH){merge_next_p0_next_p1}} & p1_cache_write_data_strobe)))
                                            | p0_cache_write_data_append | ({(`LINE_WIDTH){merge_next_p0_next_p1}} & p1_cache_write_data_append);
            end

            merge_p0_p1_reg <= merge_next_p0_next_p1;
        end
        else if (p0_refill_write | p0_hit_write) begin
            p0_cache_wstrb_reg <= 0;
            p0_cache_write_data_reg <= 0;
        end
        if (p0_lookup) begin
            p0_index_reg_miss <= p0_index_reg;
            p0_offset_reg_miss <= p0_offset_reg;
        end

        // p1
        if (p1_addr_ok) begin
            p1_op_reg          <= p1_op;
            p1_index_reg       <= p1_index;
            p1_tag_reg         <= p1_tag;
            p1_offset_reg      <= p1_offset;
            p1_uncached_reg    <= p1_uncached;
            p1_size_reg        <= p1_size;
            p1_wstrb_reg       <= p1_wstrb;
            p1_wdata_reg       <= p1_wdata;
            if (!p1_uncached & (p1_op == OP_WRITE) & !merge_next_p0_next_p1) begin
                p1_cache_wstrb_reg      <= p1_cache_wstrb_new;
                p1_cache_write_data_reg <= (p1_cache_write_data_reg & ~p1_cache_write_data_strobe)
                                            | p1_cache_write_data_append;
            end
        end
        else if (p1_refill_write | p1_hit_write) begin
            p1_cache_wstrb_reg <= 0;
            p1_cache_write_data_reg <= 0;
        end
        if (p1_lookup) begin
            p1_index_reg_miss <= p1_index_reg;
            p1_offset_reg_miss <= p1_offset_reg;
        end
    end
end

assign p0_addr_ok = pipe_interface_latch;
assign p1_addr_ok = p1_valid & pipe_interface_latch;

always @(posedge clk) begin
    p0_wdata_ok_reg <= (p0_op == OP_WRITE) & pipe_interface_latch;
    p1_wdata_ok_reg <= (p1_op == OP_WRITE) & pipe_interface_latch & p0_valid;
end

assign p0_hit_write = p0_lookup & p0_cache_hit_and_cached & (p0_op_reg == OP_WRITE);
assign p1_hit_write = p1_lookup & p1_cache_hit_and_cached & (p1_op_reg == OP_WRITE);

always @(posedge clk) begin
    if (!resetn) begin
        p0_preload_tag_way0 <= 0;
        p1_preload_tag_way0 <= 0;
        p0_preload_tag_way1 <= 0;
        p1_preload_tag_way1 <= 0;
`ifdef CACHE_4WAY
        p0_preload_tag_way2 <= 0;
        p1_preload_tag_way2 <= 0;
        p0_preload_tag_way3 <= 0;
        p1_preload_tag_way3 <= 0;
`endif
    end
    else begin
        if ((p0_idle | p0_lookup) & pipe_interface_latch) begin
            p0_preload_tag_way0 <= p0_tag_way0[p0_index];
            p0_preload_tag_way1 <= p0_tag_way1[p0_index];
`ifdef CACHE_4WAY
            p0_preload_tag_way2 <= p0_tag_way2[p0_index];
            p0_preload_tag_way3 <= p0_tag_way3[p0_index];
`endif
        end
        if ((p1_idle | p1_lookup) & pipe_interface_latch) begin
            p1_preload_tag_way0 <= p1_tag_way0[p1_index];
            p1_preload_tag_way1 <= p1_tag_way1[p1_index];
`ifdef CACHE_4WAY
            p1_preload_tag_way2 <= p1_tag_way2[p1_index];
            p1_preload_tag_way3 <= p1_tag_way3[p1_index];
`endif
        end
    end
end

always @(posedge clk) begin
    if (!resetn) begin
        p0_main_state <= 0;
        p1_main_state <= 0;

        replace_way_id <= 0;
    end
    else begin
        // p0 state
        case(p0_main_state)
            MAIN_ST_IDLE: begin
                if (pipe_interface_latch) begin
                    p0_main_state <= MAIN_ST_LOOKUP;
                end
            end
            MAIN_ST_LOOKUP: begin
                if (p0_cache_hit_and_cached & (p1_idle | p1_cache_hit_and_cached)) begin
                    if (!p0_addr_ok) begin
                        p0_main_state <= MAIN_ST_IDLE;
                    end
                end
                else begin
                    p0_main_state <= MAIN_ST_MISS;
                end
            end
            MAIN_ST_MISS: begin
                if (p0_uncached_reg) begin
                    if ((p0_op_reg == OP_READ) & rd_rdy) begin
                        p0_main_state <= MAIN_ST_REFILL;
                    end
                    else if ((p0_op_reg == OP_WRITE) & wr_rdy) begin
                        p0_main_state <= MAIN_ST_REPLACE;
                    end
                end
                else if (p0_replace_dirty) begin
                    if (wr_rdy) begin
                        p0_main_state <= MAIN_ST_REPLACE;
                    end
                end
                else begin
                    p0_main_state <= MAIN_ST_REFILL;
                end
            end
            MAIN_ST_REPLACE: begin
                if (p0_uncached_reg) begin
                    if (wr_rdy) begin
                        p0_main_state <= MAIN_ST_IDLE;
                    end
                end
                else if (rd_rdy) begin
                    p0_main_state <= MAIN_ST_REFILL;
                end
            end
            MAIN_ST_REFILL: begin
                if (ret_valid_last) begin
                    p0_main_state <= MAIN_ST_IDLE;
                    replace_way_id <= replace_way_id + 1;
                end
            end
        endcase

        // p1 state
        case(p1_main_state)
            MAIN_ST_IDLE: begin
                if (pipe_interface_latch & p1_valid & !merge_next_p0_next_p1) begin
                    p1_main_state <= MAIN_ST_LOOKUP;
                end
            end
            MAIN_ST_LOOKUP: begin
                if (p0_cache_hit_and_cached & p1_cache_hit_and_cached) begin
                    if (!p1_addr_ok) begin
                        p1_main_state <= MAIN_ST_IDLE;
                    end
                    else begin
                        replace_way_id <= replace_way_id + 1;
                    end
                end
                else begin
                    p1_main_state <= MAIN_ST_MISS;
                end
            end
            MAIN_ST_MISS: begin
                if (!p0_miss) begin
                    if (p1_uncached_reg) begin
                        if ((p1_op_reg == OP_READ) & rd_rdy) begin
                            p1_main_state <= MAIN_ST_REFILL;
                        end
                        else if ((p1_op_reg == OP_WRITE) & wr_rdy) begin
                            p1_main_state <= MAIN_ST_REPLACE;
                        end
                    end
                    else if (p1_replace_dirty) begin
                        if (wr_rdy) begin
                            p1_main_state <= MAIN_ST_REPLACE;
                        end
                    end
                    else if(!p0_replace & !p0_refill) begin
                        p1_main_state <= MAIN_ST_REFILL;
                    end
                end
            end
            MAIN_ST_REPLACE: begin
                if (p1_uncached_reg) begin
                    if (wr_rdy) begin
                        p1_main_state <= MAIN_ST_IDLE;
                    end
                end
                else if (rd_rdy & !p0_refill) begin
                    p1_main_state <= MAIN_ST_REFILL;
                end
            end
            MAIN_ST_REFILL: begin
                if (p1_refill_write) begin
                    p1_main_state <= MAIN_ST_IDLE;
                    replace_way_id <= replace_way_id + 1;
                end
            end
        endcase
    end
end

generate
    genvar i;
    for (i = 0; i < `CACHE_WAY_NUM; i = i + 1) begin: gen_cache_hit_way
        // assign cache_hit_way[i] = `get_valid(i, index_reg) && (`get_tag(i, index_reg) == tag_reg);
        assign p0_cache_hit_way[i] = `p0_get_valid(i, p0_index_reg) & (`p0_get_preload_tag(i) == p0_tag_reg);
        assign p1_cache_hit_way[i] = `p1_get_valid(i, p1_index_reg) & (`p1_get_preload_tag(i) == p1_tag_reg);
    end
endgenerate

assign p0_cache_hit = p0_cache_hit_way != 0;
assign p0_cache_hit_and_cached = p0_cache_hit & !p0_uncached_reg;
assign p1_cache_hit = p1_cache_hit_way != 0;
assign p1_cache_hit_and_cached = p1_cache_hit & !p1_uncached_reg;


`ifdef CACHE_2WAY
assign p0_cache_hit_way_id =    {1{p0_cache_hit_way[0]}} & 0 |
                                {1{p0_cache_hit_way[1]}} & 1;
assign p1_cache_hit_way_id =    {1{p1_cache_hit_way[0]}} & 0 |
                                {1{p1_cache_hit_way[1]}} & 1;
`elsif CACHE_4WAY
assign p0_cache_hit_way_id =    {2{p0_cache_hit_way[0]}} & 0 |
                                {2{p0_cache_hit_way[1]}} & 1 |
                                {2{p0_cache_hit_way[2]}} & 2 |
                                {2{p0_cache_hit_way[3]}} & 3;
assign p1_cache_hit_way_id =    {2{p1_cache_hit_way[0]}} & 0 |
                                {2{p1_cache_hit_way[1]}} & 1 |
                                {2{p1_cache_hit_way[2]}} & 2 |
                                {2{p1_cache_hit_way[3]}} & 3;
`endif

assign p0_cache_rd_data = p0_cache_hit
                        ? `p0_get_data(p0_cache_hit_way_id)
                        : (p0_buffer_read_data_count[`OFFSET_WIDTH-3+1] & (p0_buffer_read_data_count[`OFFSET_WIDTH-3:0] == p0_offset_reg_miss[`OFFSET_WIDTH-1:2]))
                            ? p0_buffer_read_data
                            : p0_buffer_read_data_new;
assign p1_cache_rd_data = p1_cache_hit
                        ? `p1_get_data(p1_cache_hit_way_id)
                        : (p1_buffer_read_data_count[`OFFSET_WIDTH-3+1] & (p1_buffer_read_data_count[`OFFSET_WIDTH-3:0] == p1_offset_reg_miss[`OFFSET_WIDTH-1:2]))
                            ? p1_buffer_read_data
                            : p1_buffer_read_data_new;

assign p0_rdata = p0_uncached_reg ? ret_data : `get_word(p0_cache_rd_data, p0_offset_w_reg);
assign p1_rdata = p1_uncached_reg ? ret_data : `get_word(p1_cache_rd_data, p1_offset_w_reg);

assign p0_data_ok = !p0_finished & ((p0_op_reg == OP_READ)
                    ? ((p0_lookup & p0_cache_hit_and_cached) | (p0_uncached_reg
                                                    ? (p0_refill & ret_valid_last)
                                                    : (p0_refill & ret_valid & (p0_buffer_read_data_count >= {(p0_offset_w_reg < p0_buffer_read_data_count_start),p0_offset_w_reg}))))
                    : p0_wdata_ok_reg);
assign p1_data_ok = merge_p0_p1_reg
                        ? (!p0_finished & ((p0_op_reg == OP_READ)
                                            ? ((p0_lookup & p0_cache_hit_and_cached) | (p0_uncached_reg
                                                                            ? (p0_refill & ret_valid_last)
                                                                            : (p0_refill & ret_valid & (p0_buffer_read_data_count >= {(p1_offset_w_reg < p0_buffer_read_data_count_start),p1_offset_w_reg}))))
                                            : p0_wdata_ok_reg))
                        : (!p1_finished & ((p1_op_reg == OP_READ)
                                            ? ((p1_lookup & p1_cache_hit_and_cached) | (p1_uncached_reg
                                                                            ? (p1_refill & ret_valid_last)
                                                                            : (p1_refill & ret_valid & (p1_buffer_read_data_count >= {(p1_offset_w_reg < p1_buffer_read_data_count_start),p1_offset_w_reg}))))
                                            : p1_wdata_ok_reg));

always @(posedge clk) begin
    if (p0_miss) begin
        p0_replace_tag <= `p0_get_preload_tag(replace_way_id);
    end
end

always @(posedge clk) begin
    if (p1_miss) begin
        p1_replace_tag <= `p1_get_preload_tag(replace_way_id);
    end
end

// axi interface

assign p0_wr_type   = p0_uncached_reg ? {1'b0,p0_size_reg} : WR_TYPE_CACHELINE;
assign p0_wr_addr   = p0_uncached_reg ? {p0_tag_reg,p0_index_reg,p0_offset_reg} : {p0_replace_tag,p0_index_reg_miss,{`OFFSET_WIDTH{1'b0}}};
assign p0_wr_data   = p0_uncached_reg ? {{(`LINE_WIDTH-32){1'b0}},p0_wdata_reg} : `p0_get_data(replace_way_id);
assign p0_wr_req    = p0_replace;
assign p0_wr_wstrb  = p0_uncached_reg ? p0_wstrb_reg : 4'b1111;

assign p1_wr_type   = p1_uncached_reg ? {1'b0,p1_size_reg} : WR_TYPE_CACHELINE;
assign p1_wr_addr   = p1_uncached_reg ? {p1_tag_reg,p1_index_reg,p1_offset_reg} : {p1_replace_tag,p1_index_reg_miss,{`OFFSET_WIDTH{1'b0}}};
assign p1_wr_data   = p1_uncached_reg ? {{(`LINE_WIDTH-32){1'b0}},p1_wdata_reg} : `p1_get_data(replace_way_id);
assign p1_wr_req    = p1_replace;
assign p1_wr_wstrb  = p1_uncached_reg ? p1_wstrb_reg : 4'b1111;

assign wr_type   = p0_wr_req ? p0_wr_type : p1_wr_type;
assign wr_addr   = p0_wr_req ? p0_wr_addr : p1_wr_addr;
assign wr_data   = p0_wr_req ? p0_wr_data : p1_wr_data;
assign wr_req    = p0_wr_req | p1_wr_req;
assign wr_wstrb  = p0_wr_req ? p0_wr_wstrb : p1_wr_wstrb;

assign p0_rd_type   = p0_uncached_reg ? {1'b0,p0_size_reg} : RD_TYPE_CACHELINE;
assign p0_rd_addr   = p0_uncached_reg ? {p0_tag_reg,p0_index_reg,p0_offset_reg} : {p0_tag_reg, p0_index_reg_miss,p0_offset_reg_miss[`OFFSET_WIDTH-1:2],2'b0};
assign p0_rd_req    = p0_refill & ~rd_addr_ok;

assign p1_rd_type   = p1_uncached_reg ? {1'b0,p1_size_reg} : RD_TYPE_CACHELINE;
assign p1_rd_addr   = p1_uncached_reg ? {p1_tag_reg,p1_index_reg,p1_offset_reg} : {p1_tag_reg, p1_index_reg_miss,p1_offset_reg_miss[`OFFSET_WIDTH-1:2],2'b0};
assign p1_rd_req    = p1_refill & ~rd_addr_ok;

assign rd_type   = p0_refill ? p0_rd_type : p1_rd_type;
assign rd_addr   = p0_refill ? p0_rd_addr : p1_rd_addr;
assign rd_req    = p0_rd_req | p1_rd_req;

// fetch data from memory

// assign buffer_read_data_new = (buffer_read_data >> 32) | (ret_data << (32*3));
assign p0_buffer_read_data_new = p0_buffer_read_data | ({{(`LINE_WIDTH-32){1'b0}},ret_data} << (32*p0_buffer_read_data_count[`OFFSET_WIDTH-3:0]));
assign p1_buffer_read_data_new = p1_buffer_read_data | ({{(`LINE_WIDTH-32){1'b0}},ret_data} << (32*p1_buffer_read_data_count[`OFFSET_WIDTH-3:0]));

always @(posedge clk) begin
    // TODO 优化，此处反复写?
    if (!resetn) begin
        p0_buffer_read_data <= 0;
        p0_buffer_read_data_count <= 0;

        p1_buffer_read_data <= 0;
        p1_buffer_read_data_count <= 0;
    end
    else begin
        if (!p0_uncached_reg & p0_refill & ret_valid) begin
            p0_buffer_read_data         <= p0_buffer_read_data_new;
            p0_buffer_read_data_count   <= p0_buffer_read_data_count + 1;
        end
        if (p0_rd_req) begin
            p0_buffer_read_data <= 0;
            p0_buffer_read_data_count <= p0_rd_addr[`OFFSET_WIDTH-1:2];
            p0_buffer_read_data_count_start <= p0_rd_addr[`OFFSET_WIDTH-1:2];
        end

        if (!p1_uncached_reg & p1_refill & ret_valid) begin
            p1_buffer_read_data         <= p1_buffer_read_data_new;
            p1_buffer_read_data_count   <= p1_buffer_read_data_count + 1;
        end
        if (p1_rd_req) begin
            p1_buffer_read_data <= 0;
            p1_buffer_read_data_count <= p1_rd_addr[`OFFSET_WIDTH-1:2];
            p1_buffer_read_data_count_start <= p1_rd_addr[`OFFSET_WIDTH-1:2];
        end
    end
    
end

always @(posedge clk) begin
    if (!(p0_refill | p1_refill)) begin
        rd_addr_ok <= 0;
    end
    else if ((p0_refill | p1_refill) & rd_rdy) begin
        rd_addr_ok <= 1;
    end
end

// write data to cache

generate
    // genvar i;
    for (i = 0; i < `LINE_SIZE; i = i + 1) begin: gen_refill_data
        assign p0_cache_write_data_actually[8*i+7:8*i] = p0_cache_wstrb_reg[i]
                                                        ? p0_cache_write_data_reg[8*i+7:8*i]
                                                        : p0_cache_rd_data[8*i+7:8*i];
        assign p1_cache_write_data_actually[8*i+7:8*i] = p1_cache_wstrb_reg[i]
                                                        ? p1_cache_write_data_reg[8*i+7:8*i]
                                                        : p1_cache_rd_data[8*i+7:8*i];
    end
endgenerate


// write data to cache

assign p0_cache_write_way_id = p0_hit_write ? p0_cache_hit_way_id : replace_way_id;
assign p1_cache_write_way_id = p1_hit_write ? p1_cache_hit_way_id : replace_way_id;

assign p0_refill_write = !p0_uncached_reg & p0_refill & ret_valid_last;
assign p1_refill_write = !p1_uncached_reg & p1_refill & ret_valid_last;

assign p0_cache_write = p0_hit_write | p0_refill_write;
assign p1_cache_write = p1_hit_write | p1_refill_write;


always @(posedge clk) begin
    if (!resetn) begin: valid_tb_reset
        // valid_tb <= 0;
        integer j;
        for (j = 0; j < `CACHE_WAY_NUM; j = j + 1) begin
            p0_valid_way0 <= 0;
            p1_valid_way0 <= 0;
            p0_valid_way1 <= 0;
            p1_valid_way1 <= 0;
`ifdef CACHE_4WAY
            p0_valid_way2 <= 0;
            p1_valid_way2 <= 0;
            p0_valid_way3 <= 0;
            p1_valid_way3 <= 0;
`endif
        end
    end
    else if (p0_cache_write) begin
        case (p0_cache_write_way_id)
            0 : begin
                p0_tag_way0    [p0_index_reg] <= p0_tag_reg;
                p0_valid_way0  [p0_index_reg] <= 1;
                p0_dirty_way0  [p0_index_reg] <= p0_op_reg == OP_WRITE;

                p1_tag_way0    [p0_index_reg] <= p0_tag_reg;
                p1_valid_way0  [p0_index_reg] <= 1;
                p1_dirty_way0  [p0_index_reg] <= p0_op_reg == OP_WRITE;
            end
            1 : begin
                p0_tag_way1    [p0_index_reg] <= p0_tag_reg;
                p0_valid_way1  [p0_index_reg] <= 1;
                p0_dirty_way1  [p0_index_reg] <= p0_op_reg == OP_WRITE;

                p1_tag_way1    [p0_index_reg] <= p0_tag_reg;
                p1_valid_way1  [p0_index_reg] <= 1;
                p1_dirty_way1  [p0_index_reg] <= p0_op_reg == OP_WRITE;
            end
`ifdef CACHE_4WAY
            2 : begin
                p0_tag_way2    [p0_index_reg] <= p0_tag_reg;
                p0_valid_way2  [p0_index_reg] <= 1;
                p0_dirty_way2  [p0_index_reg] <= p0_op_reg == OP_WRITE;

                p1_tag_way2    [p0_index_reg] <= p0_tag_reg;
                p1_valid_way2  [p0_index_reg] <= 1;
                p1_dirty_way2  [p0_index_reg] <= p0_op_reg == OP_WRITE;
            end
            3 : begin
                p0_tag_way3    [p0_index_reg] <= p0_tag_reg;
                p0_valid_way3  [p0_index_reg] <= 1;
                p0_dirty_way3  [p0_index_reg] <= p0_op_reg == OP_WRITE;

                p1_tag_way3    [p0_index_reg] <= p0_tag_reg;
                p1_valid_way3  [p0_index_reg] <= 1;
                p1_dirty_way3  [p0_index_reg] <= p0_op_reg == OP_WRITE;
            end
`endif
        endcase
    end
    else if (p1_cache_write) begin
        case (p1_cache_write_way_id)
            0 : begin
                p0_tag_way0    [p1_index_reg] <= p1_tag_reg;
                p0_valid_way0  [p1_index_reg] <= 1;
                p0_dirty_way0  [p1_index_reg] <= p1_op_reg == OP_WRITE;

                p1_tag_way0    [p1_index_reg] <= p1_tag_reg;
                p1_valid_way0  [p1_index_reg] <= 1;
                p1_dirty_way0  [p1_index_reg] <= p1_op_reg == OP_WRITE;
            end
            1 : begin
                p0_tag_way1    [p1_index_reg] <= p1_tag_reg;
                p0_valid_way1  [p1_index_reg] <= 1;
                p0_dirty_way1  [p1_index_reg] <= p1_op_reg == OP_WRITE;

                p1_tag_way1    [p1_index_reg] <= p1_tag_reg;
                p1_valid_way1  [p1_index_reg] <= 1;
                p1_dirty_way1  [p1_index_reg] <= p1_op_reg == OP_WRITE;
            end
`ifdef CACHE_4WAY
            2 : begin
                p0_tag_way2    [p1_index_reg] <= p1_tag_reg;
                p0_valid_way2  [p1_index_reg] <= 1;
                p0_dirty_way2  [p1_index_reg] <= p1_op_reg == OP_WRITE;

                p1_tag_way2    [p1_index_reg] <= p1_tag_reg;
                p1_valid_way2  [p1_index_reg] <= 1;
                p1_dirty_way2  [p1_index_reg] <= p1_op_reg == OP_WRITE;
            end
            3 : begin
                p0_tag_way3    [p1_index_reg] <= p1_tag_reg;
                p0_valid_way3  [p1_index_reg] <= 1;
                p0_dirty_way3  [p1_index_reg] <= p1_op_reg == OP_WRITE;

                p1_tag_way3    [p1_index_reg] <= p1_tag_reg;
                p1_valid_way3  [p1_index_reg] <= 1;
                p1_dirty_way3  [p1_index_reg] <= p1_op_reg == OP_WRITE;
            end
`endif
        endcase
    end
end

`define DBG_TAG 20'h205
`define DBG_INDEX 7'h6f
// `define DCACHE_DBG

`ifdef DCACHE_DBG
always @(posedge clk) begin
    if (p0_index_reg == `DBG_INDEX) begin
        if (p0_data_ok) begin
            if (p0_op_reg == OP_WRITE) begin
                $display("[%t] p0 write %h(%h,%h,%h) : %h",$time,{p0_tag_reg,p0_index_reg,p0_offset_reg},p0_tag_reg,p0_index_reg,p0_offset_reg,p0_wdata_reg);
            end
            else begin
                $display("[%t] p0 read  %h(%h,%h,%h) : %h",$time,{p0_tag_reg,p0_index_reg,p0_offset_reg},p0_tag_reg,p0_index_reg,p0_offset_reg,p0_rdata);
                // if ({tag_reg,index_reg,offset_reg} == 32'h3154) begin
                //     $finish;
                // end
            end
        end
        if (p0_refill_write) begin
            $display("[%t] p0 refill_write way: %h, line: %h",$time,p0_cache_write_way_id, p0_cache_write_data_actually);
        end
        if (p0_hit_write) begin
            $display("[%t] p0 hit_write way   : %h, line: %h",$time,p0_cache_write_way_id, p0_cache_write_data_actually);
        end
        if (p0_replace & !p0_uncached_reg) begin
            $display("[%t] p0 replace (%h,%h), line: %h",$time, p0_tag_reg,p0_index_reg, p0_wr_data);
        end
    end
    if (p1_index_reg == `DBG_INDEX) begin

        if (p1_data_ok) begin
            if (merge_p0_p1_reg) begin
                $display("[%t] merge p0 p1", $time);
            end
            if (p1_op_reg == OP_WRITE) begin
                $display("[%t] p1 write %h(%h,%h,%h) : %h",$time,{p1_tag_reg,p1_index_reg,p1_offset_reg},p1_tag_reg,p1_index_reg,p1_offset_reg,p1_wdata_reg);
            end
            else begin
                $display("[%t] p1 read  %h(%h,%h,%h) : %h",$time,{p1_tag_reg,p1_index_reg,p1_offset_reg},p1_tag_reg,p1_index_reg,p1_offset_reg,p1_rdata);
                // if ({tag_reg,index_reg,offset_reg} == 32'h3154) begin
                //     $finish;
                // end
            end
        end
        if (p1_refill_write) begin
            $display("[%t] p1 refill_write way: %h, line: %h",$time,p1_cache_write_way_id, p1_cache_write_data_actually);
        end
        if (p1_hit_write) begin
            $display("[%t] p1 hit_write way   : %h, line: %h",$time,p1_cache_write_way_id, p1_cache_write_data_actually);
        end
        if (p1_replace & !p1_uncached_reg) begin
            $display("[%t] p1 replace (%h,%h), line: %h",$time, p1_tag_reg,p1_index_reg, p1_wr_data);
        end
    end
end

`endif


endmodule


// for verilator simulation
`ifdef SIMU

module blk_mem_gen_cache_32(
  input wire clka,
  input wire [0:0]wea,
  input wire [6:0]addra,
  input wire [255:0]dina,
  output reg [255:0]douta,

  input wire clkb,
  input wire [0:0]web,
  input wire [6:0]addrb,
  input wire [255:0]dinb,
  output reg [255:0]doutb
);

reg [255:0] mem [0:127];

always @(posedge clka) begin
    if (wea) begin
        mem[addra] <= dina;
    end
    douta <= mem[addra];
end

always @(posedge clkb) begin
    if (web) begin
        mem[addrb] <= dinb;
    end
    doutb <= mem[addrb];
end

endmodule


`endif