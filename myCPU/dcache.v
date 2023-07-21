`include "definitions.svh"

module dcache(
    // Clock and reset
    input wire clk,
    input wire resetn,

    // Pipe interface
    // TODO
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

    input wire                      p2_valid,
    input wire                      p2_op,
    input wire [`TAG_WIDTH-1:0]     p2_tag,
    input wire [`INDEX_WIDTH-1:0]   p2_index,
    input wire [`OFFSET_WIDTH-1:0]  p2_offset,
    input wire [3:0]                p2_wstrb, // write strobe
    input wire [31:0]               p2_wdata,
    input wire                      p2_uncached,
    input wire [1:0]                p2_size,
    output wire                     p2_addr_ok,
    output wire                     p2_data_ok,
    output wire [31:0]              p2_rdata,


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

`define CACHE_2WAY

`ifdef CACHE_2WAY

`define CACHE_WAY_NUM 2
`define CACHE_WAY_NUM_LOG2 1

`elsif CACHE_4WAY

`define CACHE_WAY_NUM 4
`define CACHE_WAY_NUM_LOG2 2

`endif

reg                         p1_op_reg;
reg [`INDEX_WIDTH-1:0]      p1_index_reg;
reg [`INDEX_WIDTH-1:0]      p1_index_reg_miss;
reg [`TAG_WIDTH-1:0]        p1_tag_reg;
reg [`OFFSET_WIDTH-1:0]     p1_offset_reg;
wire [`OFFSET_WIDTH-3:0]    p1_offset_w_reg; // word offset
reg                         p1_uncached_reg;
reg [1:0]                   p1_size_reg;
reg [3:0]                   p1_wstrb_reg;
reg [31:0]                  p1_wdata_reg;
reg                         p1_wdata_ok_reg;

reg                         p2_op_reg;
reg [`INDEX_WIDTH-1:0]      p2_index_reg;
reg [`INDEX_WIDTH-1:0]      p2_index_reg_miss;
reg [`TAG_WIDTH-1:0]        p2_tag_reg;
reg [`OFFSET_WIDTH-1:0]     p2_offset_reg;
wire [`OFFSET_WIDTH-3:0]    p2_offset_w_reg; // word offset
reg                         p2_uncached_reg;
reg [1:0]                   p2_size_reg;
reg [3:0]                   p2_wstrb_reg;
reg [31:0]                  p2_wdata_reg;
reg                         p2_wdata_ok_reg;

// bkl_mem_gen_dpaceche data_way0(
//     .addra(),
//     .clka(),
//     .dina(),
//     .douta(),
//     .wea(),

//     .addrb(),
//     .clkb(),
//     .dinb(),
//     .doutb(),
//     .web()
// );

// port1
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
reg [`LINE_NUM-1:0] P1_valid_way1;

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

// port2
reg                     [`TAG_WIDTH-1:0] p2_tag_way0 [0:`LINE_NUM-1];
reg                     [`TAG_WIDTH-1:0] p2_tag_way1 [0:`LINE_NUM-1];
(* keep = "true" *) reg [`TAG_WIDTH-1:0] p2_preload_tag_way0;
(* keep = "true" *) reg [`TAG_WIDTH-1:0] p2_preload_tag_way1;

`ifdef CACHE_4WAY
reg                     [`TAG_WIDTH-1:0] p2_tag_way2 [0:255];
reg                     [`TAG_WIDTH-1:0] p2_tag_way3 [0:255];
(* keep = "true" *) reg [`TAG_WIDTH-1:0] p2_preload_tag_way2;
(* keep = "true" *) reg [`TAG_WIDTH-1:0] p2_preload_tag_way3;
`endif

`define p2_get_preload_tag(way_id_) (\
        {`TAG_WIDTH{way_id_==0}} & p2_preload_tag_way0\
    |   {`TAG_WIDTH{way_id_==1}} & p2_preload_tag_way1\
`ifdef CACHE_4WAY\
    |   {`TAG_WIDTH{way_id_==2}} & p2_preload_tag_way2\
    |   {`TAG_WIDTH{way_id_==3}} & p2_preload_tag_way3\
`endif\
)


reg [`LINE_NUM-1:0] p2_valid_way0;
reg [`LINE_NUM-1:0] p2_valid_way1;

`ifdef CACHE_4WAY
reg [`LINE_NUM-1:0] p2_valid_way2;
reg [`LINE_NUM-1:0] p2_valid_way3;
`endif

`define p2_get_valid(way_id_,index_) (\
        {1{way_id_==0}} & p2_valid_way0[index_]\
    |   {1{way_id_==1}} & p2_valid_way1[index_]\
`ifdef CACHE_4WAY\
    |   {1{way_id_==2}} & p2_valid_way2[index_]\
    |   {1{way_id_==3}} & p2_valid_way3[index_]\
`endif\
)

reg [`LINE_NUM-1:0] p2_dirty_way0;
reg [`LINE_NUM-1:0] p2_dirty_way1;

`ifdef CACHE_4WAY
reg [`LINE_NUM-1:0] p2_dirty_way2;
reg [`LINE_NUM-1:0] p2_dirty_way3;
`endif

`define p2_get_dirty(way_id_,index_) (\
        {1{way_id_==0}} & p2_dirty_way0[index_]\
    |   {1{way_id_==1}} & p2_dirty_way1[index_]\
`ifdef CACHE_4WAY\
    |   {1{way_id_==2}} & p2_dirty_way2[index_]\
    |   {1{way_id_==3}} & p2_dirty_way3[index_]\
`endif\
)


reg [2:0] p1_main_state;
reg [2:0] p2_main_state;

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

wire [2:0]  rd_type_cache;
wire [31:0] rd_addr_cache;
wire rd_req_cache;

wire [31:0] rd_addr_prefetch;
wire rd_req_prefetch;

reg rd_addr_ok;
wire ret_valid_last;


reg finished;

wire p1_idle;
wire p1_lookup;
wire p1_miss;
wire p1_replace;
wire p1_refill;
wire p1_hit_write;
wire p1_refill_write;

wire p2_idle;
wire p2_lookup;
wire p2_miss;
wire p2_replace;
wire p2_refill;
wire p2_hit_write;
wire p2_refill_write;

wire p1_cache_hit;
wire p1_cache_hit_and_cached;
wire [`CACHE_WAY_NUM-1:0]       p1_cache_hit_way;
wire [`CACHE_WAY_NUM_LOG2-1:0]  p1_cache_hit_way_id;

wire p2_cache_hit;
wire p2_cache_hit_and_cached;
wire [`CACHE_WAY_NUM-1:0]       p2_cache_hit_way;
wire [`CACHE_WAY_NUM_LOG2-1:0]  p2_cache_hit_way_id;

wire pipe_interface_latch;

reg [`OFFSET_WIDTH-3:0] buffer_read_data_count;

reg [`TAG_WIDTH-1:0]            p1_replace_tag;
reg [`CACHE_WAY_NUM_LOG2-1:0]   p1_replace_way_id;
wire                            p1_replace_dirty;

reg [`TAG_WIDTH-1:0]            p2_replace_tag;
reg [`CACHE_WAY_NUM_LOG2-1:0]   p2_replace_way_id;
wire                            p2_replace_dirty;

reg [`LINE_WIDTH-1:0]   p1_cache_write_data_reg;
wire [`LINE_WIDTH-1:0]  p1_cache_write_data_actually;
reg [`LINE_SIZE-1:0]    p1_cache_wstrb_reg;
wire [`LINE_WIDTH-1:0]  p1cache_write_data_strobe;

reg [`LINE_WIDTH-1:0]   p2_cache_write_data_reg;
wire [`LINE_WIDTH-1:0]  p2_cache_write_data_actually;
reg [`LINE_SIZE-1:0]    p2_cache_wstrb_reg;
wire [`LINE_WIDTH-1:0]  p2cache_write_data_strobe;

wire next_p2_next_p1_same_line;
wire next_p1_p1_same_line;
wire next_p1_p2_same_line;
wire next_p2_p1_same_line;
wire next_p2_p2_same_line;

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

assign p1_offset_w_reg = p1_offset_reg[`OFFSET_WIDTH-1:2];
assign P2_offset_w_reg = p2_offset_reg[`OFFSET_WIDTH-1:2];

assign p1_idle = (main_state == MAIN_ST_IDLE);
assign p1_lookup = (main_state == MAIN_ST_LOOKUP);
assign p1_miss = (main_state == MAIN_ST_MISS);
assign p1_replace = (main_state == MAIN_ST_REPLACE);
assign p1_refill = (main_state == MAIN_ST_REFILL);

assign p2_idle = (main_state == MAIN_ST_IDLE);
assign p2_lookup = (main_state == MAIN_ST_LOOKUP);
assign p2_miss = (main_state == MAIN_ST_MISS);
assign p2_replace = (main_state == MAIN_ST_REPLACE);
assign p2_refill = (main_state == MAIN_ST_REFILL);

assign ret_valid_last = (ret_valid & ret_last);

assign next_p2_next_p1_same_line = (p2_index == p1_index) & (P2_tag == P1_tag);
assign next_p1_p1_same_line = (p1_index == p1_index_reg) & (P1_tag == P1_tag_reg);
assign next_p1_p2_same_line = (p1_index == p2_index_reg) & (P1_tag == P2_tag_reg);
assign next_p2_p1_same_line = (p2_index == p1_index_reg) & (P2_tag == P1_tag_reg);
assign next_p2_p2_same_line = (p2_index == p2_index_reg) & (P2_tag == P2_tag_reg);

assign pipe_interface_latch = valid & (
    idle | 
    (p1_lookup & (p1_op_reg == OP_READ) & p1_cache_hit_and_cached & & (p2_op_reg == OP_READ) & p2_cache_hit_and_cached)) |
    (refill & !uncached_reg & (op_reg == OP_READ) & (data_ok | finished) & next_same_line & !fetch_ok) |
    ((op_reg == OP_WRITE) & cache_hit_and_cached & !hit_write & !refill_write & (op == OP_WRITE) & next_same_line)
    );

assign replace_dirty = `get_valid(replace_way_id,index_reg_miss) & `get_dirty(replace_way_id, index_reg_miss);

always @(posedge clk) begin
    if (!resetn) begin
        finished <= 1;
    end
    else if (addr_ok) begin
        finished <= 0;
    end
    else if (!addr_ok & data_ok) begin
        finished <= 1;
    end
end

always @(posedge clk) begin
    if (!resetn) begin

    end
    else begin
        if (pipe_interface_latch) begin
            op_reg          <= op;
            index_reg       <= index;
            tag_reg         <= tag;
            offset_reg      <= offset;
            uncached_reg    <= uncached;
            size_reg        <= size;
            wstrb_reg       <= wstrb;
            wdata_reg       <= wdata;
        end
        if (lookup) begin
            index_reg_miss <= index_reg;
        end
    end
end

assign addr_ok = pipe_interface_latch;

always @(posedge clk) begin
    wdata_ok_reg <= (op == OP_WRITE) & pipe_interface_latch;
end

assign hit_write = lookup & cache_hit_and_cached & (op_reg == OP_WRITE);

always @(posedge clk) begin
    if (!resetn) begin
        main_state <= 0;
        replace_way_id <= 0;
    end
    else begin
        case(main_state)
            MAIN_ST_IDLE: begin
                if (pipe_interface_latch) begin
                    main_state <= MAIN_ST_LOOKUP;
                end
            end
            MAIN_ST_LOOKUP: begin
                if (cache_hit_and_cached) begin
                    if (!valid | hit_write) begin
                        main_state <= MAIN_ST_IDLE;
                    end
                    else begin
                        replace_way_id <= replace_way_id + 1;
                    end
                end
                else begin
                    main_state <= MAIN_ST_MISS;
                end
            end
            MAIN_ST_MISS: begin
                if (!prefetching) begin    
                    if (uncached_reg) begin
                        if ((op_reg == OP_READ) & rd_rdy & !prefetching) begin
                            main_state <= MAIN_ST_REFILL;
                        end
                        else if ((op_reg == OP_WRITE) & wr_rdy) begin
                            main_state <= MAIN_ST_REPLACE;
                        end
                    end
                    else if (replace_dirty) begin
                        if (wr_rdy) begin
                            main_state <= MAIN_ST_REPLACE;
                        end
                    end
                    else if (!prefetching) begin
                        main_state <= MAIN_ST_REFILL;
                    end
                end
            end
            MAIN_ST_REPLACE: begin
                if (uncached_reg) begin
                    if (wr_rdy) begin
                        main_state <= MAIN_ST_IDLE;
                    end
                end
                else if (rd_rdy & !prefetching) begin
                    main_state <= MAIN_ST_REFILL;
                end
            end
            MAIN_ST_REFILL: begin
                if (fetch_ok) begin
                    main_state <= MAIN_ST_IDLE;
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
        assign cache_hit_way[i] = `get_valid(i, index_reg) & (`get_preload_tag(i) == tag_reg);
    end
endgenerate

assign cache_hit = cache_hit_way != 0;
assign cache_hit_and_cached = cache_hit & !uncached_reg;


`ifdef CACHE_2WAY
assign cache_hit_way_id =   {1{cache_hit_way[0]}} & 0 |
                            {1{cache_hit_way[1]}} & 1;
`elsif CACHE_4WAY
assign cache_hit_way_id =   {2{cache_hit_way[0]}} & 0 |
                            {2{cache_hit_way[1]}} & 1 |
                            {2{cache_hit_way[2]}} & 2 |
                            {2{cache_hit_way[3]}} & 3;
`endif

// assign cache_rd_data = cache_hit ? `get_preload_data(cache_hit_way_id) : (ret_valid_last ? buffer_read_data_new : 0);
assign cache_rd_data = cache_hit
                        ? `get_preload_data(cache_hit_way_id)
                        : prefetch_hit
                            ? prefetch_data_reg
                            : buffer_read_data_new;

assign rdata_l = uncached_reg ? ret_data : `get_word(cache_rd_data, offset_w_reg);
assign rdata_h = `get_word(cache_rd_data, offset_w_reg+1);

// assign data_ok = (op_reg == OP_READ) ? ((lookup & cache_hit) | ret_valid_last) : wdata_ok_reg;
assign data_ok = !finished & ((op_reg == OP_READ)
                    ? ((lookup & cache_hit_and_cached) | prefetch_hit | (uncached_reg
                                                    ? (refill & ret_valid_last)
                                                    : ((refill | (prefetching & prefetch_same_line)) & ret_valid & (buffer_read_data_count >= offset_reg[`OFFSET_WIDTH-1:2]))))
                    : wdata_ok_reg);

always @(posedge clk) begin
    if (miss) begin
        // replace_tag <= replace_way_id ? tag_way1[index_reg] : tag_way0[index_reg];
        // replace_tag <= `get_tag(replace_way_id, index_reg);
        replace_tag <= `get_preload_tag(replace_way_id);
    end
end

// axi interface

assign wr_type = uncached_reg ? {1'b0,size_reg} : WR_TYPE_CACHELINE;
assign wr_addr = uncached_reg ? {tag_reg,index_reg,offset_reg} : {replace_tag,index_reg_miss,{`OFFSET_WIDTH{1'b0}}};
// assign wr_data = replace_way_id ? data_way1[index_reg] : data_way0[index_reg];
// assign wr_data = `get_data(replace_way_id, index_reg);
assign wr_data = uncached_reg ? {{(`LINE_WIDTH-32){1'b0}},wdata_reg} : `get_preload_data(replace_way_id);
assign wr_req = replace;
assign wr_wstrb = uncached_reg ? wstrb_reg : 4'b1111;

assign rd_type_cache = uncached_reg ? {1'b0,size_reg} : RD_TYPE_CACHELINE;
assign rd_addr_cache = uncached_reg ? {tag_reg,index_reg,offset_reg} : {tag_reg, index_reg_miss,{`OFFSET_WIDTH{1'b0}}};
assign rd_req_cache = !prefetch_hit & refill & ~rd_addr_ok;

assign rd_type = prefetching ? RD_TYPE_CACHELINE : rd_type_cache;
assign rd_addr = prefetching ? rd_addr_prefetch : rd_addr_cache;
assign rd_req = prefetching ? rd_req_prefetch : rd_req_cache;

// fetch data from memory

// assign buffer_read_data_new = (buffer_read_data >> 32) | (ret_data << (32*3));
assign buffer_read_data_new = buffer_read_data | ({{(`LINE_WIDTH-32){1'b0}},ret_data} << (32*buffer_read_data_count));

always @(posedge clk) begin
    // TODO 优化，此处反复写?
    if (!resetn) begin
        buffer_read_data <= 0;
        buffer_read_data_count <= 0;
    end
    else begin
        if (ret_valid) begin
            buffer_read_data <= buffer_read_data_new;
            buffer_read_data_count <= buffer_read_data_count + 1;
        end
        if (ret_last) begin
            buffer_read_data <= 0;
            buffer_read_data_count <= 0;
        end
    end
    
end

always @(posedge clk) begin
    if (!(refill | prefetching)) begin
        rd_addr_ok <= 0;
    end
    else if ((refill | prefetching) & rd_rdy) begin
        rd_addr_ok <= 1;
    end
end

// write data to cache

generate
    // genvar i;
    for (i = 0; i < `LINE_SIZE; i = i + 1) begin: gen_refill_data
        assign p1_cache_write_data_actually[8*i+7:8*i] = p1_cache_wstrb_reg[i]
                                                        ? p1_cache_write_data_reg[8*i+7:8*i]
                                                        : p1_cache_rd_data[8*i+7:8*i];
        assign p2_cache_write_data_actually[8*i+7:8*i] = p2_cache_wstrb_reg[i]
                                                        ? p2_cache_write_data_reg[8*i+7:8*i]
                                                        : p2_cache_rd_data[8*i+7:8*i];
    end
endgenerate


// write data to cache

// assign cache_write_way_id = hit_write ? cache_hit_way_id : replace_way_id;

assign p1_refill_write = !uncached_reg & refill & fetch_ok;

always @(posedge clk) begin
    if (!resetn) begin: valid_tb_reset
        // valid_tb <= 0;
        integer j;
        for (j = 0; j < `CACHE_WAY_NUM; j = j + 1) begin
            valid_way0 <= 0;
            valid_way1 <= 0;
`ifdef CACHE_4WAY
            valid_way2 <= 0;
            valid_way3 <= 0;
`endif
        end
    end
    else if (refill_write) begin
        case (replace_way_id)
            0 : begin
                tag_way0[index_reg] <= tag_reg;
                valid_way0[index_reg] <= 1;
                data_way0[index_reg] <= cache_write_data_actually;
                dirty_way0[index_reg] <= op_reg == OP_WRITE;
            end
            1 : begin
                tag_way1[index_reg] <= tag_reg;
                valid_way1[index_reg] <= 1;
                data_way1[index_reg] <= cache_write_data_actually;
                dirty_way1[index_reg] <= op_reg == OP_WRITE;
            end
`ifdef CACHE_4WAY
            2 : begin
                tag_way2[index_reg] <= tag_reg;
                valid_way2[index_reg] <= 1;
                data_way2[index_reg] <= cache_write_data_actually;
                dirty_way2[index_reg] <= op_reg == OP_WRITE;
            end
            3 : begin
                tag_way3[index_reg] <= tag_reg;
                valid_way3[index_reg] <= 1;
                data_way3[index_reg] <= cache_write_data_actually;
                dirty_way3[index_reg] <= op_reg == OP_WRITE;
            end
`endif
        endcase
    end
    else if (hit_write) begin
        case (cache_hit_way_id)
            0 : begin
                tag_way0[index_reg] <= tag_reg;
                valid_way0[index_reg] <= 1;
                data_way0[index_reg] <= cache_write_data_actually;
                dirty_way0[index_reg] <= 1;
            end
            1 : begin
                tag_way1[index_reg] <= tag_reg;
                valid_way1[index_reg] <= 1;
                data_way1[index_reg] <= cache_write_data_actually;
                dirty_way1[index_reg] <= 1;
            end
`ifdef CACHE_4WAY
            2 : begin
                tag_way2[index_reg] <= tag_reg;
                valid_way2[index_reg] <= 1;
                data_way2[index_reg] <= cache_write_data_actually;
                dirty_way2[index_reg] <= 1;
            end
            3 : begin
                tag_way3[index_reg] <= tag_reg;
                valid_way3[index_reg] <= 1;
                data_way3[index_reg] <= cache_write_data_actually;
                dirty_way3[index_reg] <= 1;
            end
`endif
        endcase
    end
end


endmodule