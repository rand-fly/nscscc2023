`include "definitions.svh"
// `define SIMU
module dcache(
    // Clock and reset
    input wire clk,
    input wire resetn,

    // Pipe interface
    input wire                      p0_valid,
    input wire                      p1_valid,
    input wire [2:0]                op,
    input wire [`TAG_WIDTH-1:0]     tag,
    input wire [`INDEX_WIDTH-1:0]   index,
    input wire [`OFFSET_WIDTH-1:0]  p0_offset,
    input wire [`OFFSET_WIDTH-1:0]  p1_offset,
    input wire [3:0]                p0_wstrb,
    input wire [3:0]                p1_wstrb,
    input wire [31:0]               p0_wdata,
    input wire [31:0]               p1_wdata,
    input wire                      uncached,
    input wire [1:0]                p0_size,
    input wire [1:0]                p1_size,
    output wire                     addr_ok,
    output wire                     data_ok,
    output wire [31:0]              p0_rdata,
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

wire [`LINE_WIDTH-1:0] data_way0;
wire [`LINE_WIDTH-1:0] data_way1;
wire [`INDEX_WIDTH-1:0] data_addr;

`define CACHE_2WAY

`ifdef CACHE_2WAY

`define CACHE_WAY_NUM 2
`define CACHE_WAY_NUM_LOG2 1

`elsif CACHE_4WAY

`define CACHE_WAY_NUM 4
`define CACHE_WAY_NUM_LOG2 2

`endif

wire cache_rdy;
reg [2:0] op_reg;
wire cacop_reg;
wire [1:0] cacop_id_reg;
wire cacop_iiw_reg;
wire cacop_way_id;

reg [`INDEX_WIDTH-1:0] index_reg;
reg [`INDEX_WIDTH-1:0] index_reg_miss;
reg [`TAG_WIDTH-1:0] tag_reg;
reg [`OFFSET_WIDTH-1:0] p0_offset_reg;
reg [`OFFSET_WIDTH-1:0] p0_offset_reg_miss;
reg [`OFFSET_WIDTH-1:0] p1_offset_reg;
wire [`OFFSET_WIDTH-1:0] p0_offset_cell_w;
wire [`OFFSET_WIDTH-1:0] p1_offset_cell_w;
// reg [1:0] offset_w_reg; // word offset
wire [`OFFSET_WIDTH-3:0] p0_offset_w_reg; // word offset
wire [`OFFSET_WIDTH-3:0] p1_offset_w_reg; // word offset
reg [`OFFSET_WIDTH-3:0] p_offset_w_last_reg;
reg uncached_reg;
reg p1_valid_reg;
reg [1:0] p0_size_reg;
reg [3:0] p0_wstrb_reg;
reg [3:0] p1_wstrb_reg;
reg [31:0] p0_wdata_reg;
reg [31:0] p1_wdata_reg;
// wire [31:0] p1_wdata_valid;
// wire [7:0] wdata_reg_bytes [0:3];
// wire [31:0] wdata_actually;
// reg [31:0] wdata_actually_reg;
reg wdata_ok_reg;

reg [`TAG_WIDTH-1:0] tag_way0 [0:`LINE_NUM-1];
reg [`TAG_WIDTH-1:0] tag_way1 [0:`LINE_NUM-1];
(* keep = "true" *) reg [`TAG_WIDTH-1:0] preload_tag_way0;
(* keep = "true" *) reg [`TAG_WIDTH-1:0] preload_tag_way1;

`ifdef CACHE_4WAY
reg [`TAG_WIDTH-1:0] tag_way2 [0:255];
reg [`TAG_WIDTH-1:0] tag_way3 [0:255];
(* keep = "true" *) reg [`TAG_WIDTH-1:0] preload_tag_way2;
(* keep = "true" *) reg [`TAG_WIDTH-1:0] preload_tag_way3;
`endif

`define get_tag(way_id_,index_) (\
        {20{way_id_==0}} & tag_way0[index_]\
    |   {20{way_id_==1}} & tag_way1[index_]\
`ifdef CACHE_4WAY\
    |   {20{way_id_==2}} & tag_way2[index_]\
    |   {20{way_id_==3}} & tag_way3[index_]\
`endif\
)
`define get_preload_tag(way_id_) (\
        {`TAG_WIDTH{way_id_==0}} & preload_tag_way0\
    |   {`TAG_WIDTH{way_id_==1}} & preload_tag_way1\
`ifdef CACHE_4WAY\
    |   {`TAG_WIDTH{way_id_==2}} & preload_tag_way2\
    |   {`TAG_WIDTH{way_id_==3}} & preload_tag_way3\
`endif\
)

reg [`LINE_NUM-1:0] valid_way0;
reg [`LINE_NUM-1:0] valid_way1;

`ifdef CACHE_4WAY
reg [`LINE_NUM-1:0] valid_way2;
reg [`LINE_NUM-1:0] valid_way3;
`endif

`define get_valid(way_id_,index_) (\
        {1{way_id_==0}} & valid_way0[index_]\
    |   {1{way_id_==1}} & valid_way1[index_]\
`ifdef CACHE_4WAY\
    |   {1{way_id_==2}} & valid_way2[index_]\
    |   {1{way_id_==3}} & valid_way3[index_]\
`endif\
)

// reg [`LINE_WIDTH-1:0] data_way0 [0:`LINE_NUM-1];
// reg [`LINE_WIDTH-1:0] data_way1 [0:`LINE_NUM-1];
// (* keep = "true" *) reg [`LINE_WIDTH-1:0] preload_data_way0;
// (* keep = "true" *) reg [`LINE_WIDTH-1:0] preload_data_way1;

// `ifdef CACHE_4WAY
// reg [`LINE_WIDTH-1:0] data_way2 [0:`LINE_NUM-1];
// reg [`LINE_WIDTH-1:0] data_way3 [0:`LINE_NUM-1];
// (* keep = "true" *) reg [`LINE_WIDTH-1:0] preload_data_way2;
// (* keep = "true" *) reg [`LINE_WIDTH-1:0] preload_data_way3;
// `endif

`define get_data(way_id_) (\
        {`LINE_WIDTH{way_id_==0}} & data_way0\
    |   {`LINE_WIDTH{way_id_==1}} & data_way1\
`ifdef CACHE_4WAY\
    |   {`LINE_WIDTH{way_id_==2}} & data_way2\
    |   {`LINE_WIDTH{way_id_==3}} & data_way3\
`endif\
)
// `define get_preload_data(way_id_) (\
//         {`LINE_WIDTH{way_id_==0}} & preload_data_way0\
//     |   {`LINE_WIDTH{way_id_==1}} & preload_data_way1\
// `ifdef CACHE_4WAY\
//     |   {`LINE_WIDTH{way_id_==2}} & preload_data_way2\
//     |   {`LINE_WIDTH{way_id_==3}} & preload_data_way3\
// `endif\
// )
// `define get_preload_data(way_id_) (\
//         way_id_==0 ? preload_data_way0 :\
//         way_id_==1 ? preload_data_way1 :\
// `ifdef CACHE_4WAY\
//         way_id_==2 ? preload_data_way2 :\
//         way_id_==3 ? preload_data_way3 :\
// `endif\
//         0\
// )

reg [`LINE_NUM-1:0] dirty_way0;
reg [`LINE_NUM-1:0] dirty_way1;

`ifdef CACHE_4WAY
reg [`LINE_NUM-1:0] dirty_way2;
reg [`LINE_NUM-1:0] dirty_way3;
`endif

`define get_dirty(way_id_,index_) (\
        {1{way_id_==0}} & dirty_way0[index_]\
    |   {1{way_id_==1}} & dirty_way1[index_]\
`ifdef CACHE_4WAY\
    |   {1{way_id_==2}} & dirty_way2[index_]\
    |   {1{way_id_==3}} & dirty_way3[index_]\
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

reg [2:0] main_state;

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
parameter MAIN_ST_CACOP12   = 5;   // make cache line invalid

parameter SUB_ST_IDLE = 0;
parameter SUB_ST_WRITE = 1;

wire [2:0]  rd_type_cache;
wire [31:0] rd_addr_cache;
wire rd_req_cache;

reg rd_addr_ok;
wire ret_valid_last;


reg finished;

wire idle;
wire lookup;
wire miss;
wire replace;
wire refill;
wire cacop12;

wire hit_write;
wire refill_write;
wire cache_write;
wire cacop0_write;
wire cacop1_write;
wire cacop2_write;

wire cache_hit;
wire cache_hit_and_cached;
// wire cache_hit_way0;
// wire cache_hit_way1;
// wire cache_hit_way2;
// wire cache_hit_way3;
wire [`CACHE_WAY_NUM-1:0] cache_hit_way;
wire [`CACHE_WAY_NUM_LOG2-1:0] cache_hit_way_id;

wire pipe_interface_latch;

wire [`LINE_WIDTH-1:0] buffer_read_data_new;
// wire [127+24:0] cache_rd_data_ext;
wire [`LINE_WIDTH-1:0] cache_rd_data;
reg [`LINE_WIDTH-1:0] buffer_read_data;
reg [`OFFSET_WIDTH-3+1:0] buffer_read_data_count;
reg [`OFFSET_WIDTH-3+1:0] buffer_read_data_count_start;

reg [`TAG_WIDTH-1:0] replace_tag;
reg [`CACHE_WAY_NUM_LOG2-1:0] replace_way_id_counter;
wire [`CACHE_WAY_NUM_LOG2-1:0] replace_way_id;
wire replace_dirty;

// wire [127+24:0] cache_write_data;
// wire [127:0] cache_write_data;
reg [`LINE_WIDTH-1:0] cache_write_data_reg;
wire [`LINE_WIDTH-1:0] cache_write_data_actually;
reg [`LINE_SIZE-1:0] cache_wstrb_reg;
wire [`CACHE_WAY_NUM_LOG2-1:0] cache_write_way_id;

wire [`LINE_WIDTH-1:0] cache_write_data_strobe;
wire [`LINE_WIDTH-1:0] p0_cache_write_data_strobe;
wire [`LINE_WIDTH-1:0] p1_cache_write_data_strobe;

wire next_same_line;
wire [3:0] p1_wstrb_valid;


assign cacop_reg = op_reg[2];
assign cacop_id_reg = op_reg[1:0];
assign cacop_iiw_reg = cacop_reg & (cacop_id_reg[0] ^ cacop_id_reg[1]);
assign cacop_way_id = (op_reg == OP_CACOP2) ? cache_hit_way_id : p0_offset[`CACHE_WAY_NUM_LOG2-1:0];

assign data_addr = pipe_interface_latch ? index : index_reg;

// assign p1_wdata_valid = p1_valid ? p1_wdata : 0;
assign p1_wstrb_valid = p1_valid ? p1_wstrb : 0;

assign p0_cache_write_data_strobe = {{(`LINE_WIDTH-32){1'b0}},{8{p0_wstrb[3]}},{8{p0_wstrb[2]}},{8{p0_wstrb[1]}},{8{p0_wstrb[0]}}} << (p0_offset_cell_w*8);
assign p1_cache_write_data_strobe = {{(`LINE_WIDTH-32){1'b0}},{8{p1_wstrb_valid[3]}},{8{p1_wstrb_valid[2]}},{8{p1_wstrb_valid[1]}},{8{p1_wstrb_valid[0]}}} << (p1_offset_cell_w*8);
assign cache_write_data_strobe = p0_cache_write_data_strobe | p1_cache_write_data_strobe;

assign p0_offset_cell_w = {p0_offset[`OFFSET_WIDTH-1:2],2'b0};
assign p1_offset_cell_w = {p1_offset[`OFFSET_WIDTH-1:2],2'b0};

assign p0_offset_w_reg = p0_offset_reg[`OFFSET_WIDTH-1:2];
assign p1_offset_w_reg = p1_offset_reg[`OFFSET_WIDTH-1:2];

assign idle = (main_state == MAIN_ST_IDLE);
assign lookup = (main_state == MAIN_ST_LOOKUP);
assign miss = (main_state == MAIN_ST_MISS);
assign replace = (main_state == MAIN_ST_REPLACE);
assign refill = (main_state == MAIN_ST_REFILL);
assign cacop12 = (main_state == MAIN_ST_CACOP12);

assign ret_valid_last = (ret_valid & ret_last);

assign next_same_line = (index == index_reg) & (tag == tag_reg);

assign addr_ok = cache_rdy;
assign pipe_interface_latch = p0_valid & cache_rdy;
assign cache_rdy = idle
    | (lookup & (op_reg == OP_READ) & cache_hit_and_cached) //|
    // (refill & !uncached_reg & (op_reg == OP_READ) & (data_ok | finished) & next_same_line & !fetch_ok) |
    // ((op_reg == OP_WRITE) & cache_hit_and_cached & !hit_write & !refill_write & (op == OP_WRITE) & next_same_line)
    ;

assign replace_dirty = `get_valid(replace_way_id,index_reg_miss) & `get_dirty(replace_way_id, index_reg_miss);

always @(posedge clk) begin
    if (!resetn) begin
        finished <= 1;
    end
    else if (pipe_interface_latch) begin
        finished <= 0;
    end
    else if (!pipe_interface_latch & data_ok) begin
        finished <= 1;
    end
end

always @(posedge clk) begin
    if (!resetn) begin
        cache_wstrb_reg <= 0;
        cache_write_data_reg <= 0;
    end
    else begin
        if (pipe_interface_latch) begin
            op_reg <= op;
            index_reg <= index;
            tag_reg <= tag;
            p0_offset_reg <= p0_offset;
            p1_offset_reg <= p1_offset;
            p_offset_w_last_reg <= p1_valid ? p1_offset[`OFFSET_WIDTH-1:2] : p0_offset[`OFFSET_WIDTH-1:2];
            uncached_reg <= uncached;
            p0_size_reg <= p0_size;
            p0_wstrb_reg <= p0_wstrb;
            p1_wstrb_reg <= p1_wstrb_valid;
            p0_wdata_reg <= p0_wdata;
            p1_wdata_reg <= p1_wdata;
            p1_valid_reg <= p1_valid;
            if (!uncached & (op == OP_WRITE)) begin
                cache_wstrb_reg <= cache_wstrb_reg | ({{(`LINE_SIZE-4){1'b0}},p0_wstrb} << p0_offset_cell_w) | ({{(`LINE_SIZE-4){1'b0}},p1_wstrb_valid} << p1_offset_cell_w);
                cache_write_data_reg <= (cache_write_data_reg & ~cache_write_data_strobe) 
                                        | ((
                                            ({{(`LINE_WIDTH-32){1'b0}},p0_wdata} << (p0_offset_cell_w*8) & p0_cache_write_data_strobe & ~p1_cache_write_data_strobe) 
                                            | ({{(`LINE_WIDTH-32){1'b0}},p1_wdata} << (p1_offset_cell_w*8) & p1_cache_write_data_strobe)
                                            ));
            end
        end
        else if (refill_write | hit_write) begin
            cache_wstrb_reg <= 0;
            cache_write_data_reg <= 0;
        end
        if (lookup) begin
            index_reg_miss <= index_reg;
            p0_offset_reg_miss <= p0_offset_reg;
        end
    end
end

always @(posedge clk) begin
    wdata_ok_reg <= (op == OP_WRITE) & pipe_interface_latch;
end

assign hit_write        = lookup & cache_hit_and_cached & (op_reg == OP_WRITE);
assign cacop0_write     = lookup & (op_reg == OP_CACOP0);

always @(posedge clk) begin
    if (!resetn) begin
        // preload_data_way0 <= 0;
        // preload_data_way1 <= 0;
        preload_tag_way0 <= 0;
        preload_tag_way1 <= 0;
`ifdef CACHE_4WAY
        // preload_data_way2 <= 0;
        // preload_data_way3 <= 0;
        preload_tag_way2 <= 0;
        preload_tag_way3 <= 0;
`endif
    end
    else if ((idle | lookup) & pipe_interface_latch) begin
        // preload_data_way0 <= data_way0[index];
        // preload_data_way1 <= data_way1[index];
        preload_tag_way0 <= tag_way0[index];
        preload_tag_way1 <= tag_way1[index];
`ifdef CACHE_4WAY
        // preload_data_way2 <= data_way2[index];
        // preload_data_way3 <= data_way3[index];
        preload_tag_way2 <= tag_way2[index];
        preload_tag_way3 <= tag_way3[index];
`endif
    end
end

always @(posedge clk) begin
    if (!resetn) begin
        main_state <= 0;
        replace_way_id_counter <= 0;
    end
    else begin
        case(main_state)
            MAIN_ST_IDLE: begin
                if (pipe_interface_latch) begin
                    main_state <= MAIN_ST_LOOKUP;
                end
            end
            MAIN_ST_LOOKUP: begin
                if ((!cacop_reg & cache_hit_and_cached) | (op_reg == OP_CACOP0) | ((op_reg == OP_CACOP2) & !cache_hit_and_cached)) begin
                    if (!p0_valid | hit_write) begin
                        main_state <= MAIN_ST_IDLE;
                    end
                end
                else begin
                    main_state <= MAIN_ST_MISS;
                end
            end
            MAIN_ST_MISS: begin
                if (uncached_reg) begin
                    if ((op_reg == OP_READ) & rd_rdy) begin
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
                else begin
                    main_state <= MAIN_ST_REFILL;
                end
            end
            MAIN_ST_REPLACE: begin
                if (uncached_reg) begin
                    if (wr_rdy) begin
                        main_state <= MAIN_ST_IDLE;
                    end
                end
                else if (rd_rdy) begin
                    if (cacop_iiw_reg) begin
                        main_state <= MAIN_ST_CACOP12;
                    end
                    else begin
                        main_state <= MAIN_ST_REFILL;
                    end
                end
            end
            MAIN_ST_REFILL: begin
                if (ret_valid_last) begin
                    main_state <= MAIN_ST_IDLE;
                    replace_way_id_counter <= replace_way_id_counter + 1;
                end
            end
            MAIN_ST_CACOP12: begin
                main_state <= MAIN_ST_IDLE;
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

assign cache_rd_data = cache_hit
                        ? `get_data(cache_hit_way_id)
                        : (buffer_read_data_count[`OFFSET_WIDTH-3+1] & (buffer_read_data_count[`OFFSET_WIDTH-3:0] == buffer_read_data_count_start[`OFFSET_WIDTH-3:0]))
                            ? buffer_read_data
                            : buffer_read_data_new;

assign p0_rdata = uncached_reg ? ret_data : `get_word(cache_rd_data, p0_offset_w_reg);
assign p1_rdata = `get_word(cache_rd_data, p1_offset_w_reg);

assign data_ok = !cacop_reg & !finished & ((op_reg == OP_READ)
                    ? ((lookup & cache_hit_and_cached) | (uncached_reg
                                                    ? (refill & ret_valid_last)
                                                    : (refill & ret_valid & (buffer_read_data_count >= {(p_offset_w_last_reg < buffer_read_data_count_start[`OFFSET_WIDTH-3:0]),p_offset_w_last_reg}))))
                    : wdata_ok_reg);

always @(posedge clk) begin
    if (miss) begin
        replace_tag <= `get_preload_tag(replace_way_id);
    end
end
assign replace_way_id = cacop_reg ? cacop_way_id : replace_way_id_counter;

// axi interface

assign wr_type = uncached_reg ? {1'b0,p0_size_reg} : WR_TYPE_CACHELINE;
assign wr_addr = uncached_reg ? {tag_reg,index_reg, p0_offset_reg} : {replace_tag,index_reg_miss,{`OFFSET_WIDTH{1'b0}}};
assign wr_data = uncached_reg ? {{(`LINE_WIDTH-32){1'b0}},p0_wdata_reg} : `get_data(replace_way_id);
assign wr_req = replace;
assign wr_wstrb = uncached_reg ? p0_wstrb_reg : 4'b1111;

assign rd_type = uncached_reg ? {1'b0,p0_size_reg} : RD_TYPE_CACHELINE;
assign rd_addr = uncached_reg ? {tag_reg,index_reg, p0_offset_reg} : {tag_reg, index_reg_miss,p0_offset_reg_miss[`OFFSET_WIDTH-1:2],2'b0};
assign rd_req = refill & ~rd_addr_ok;

// fetch data from memory

// assign buffer_read_data_new = (buffer_read_data >> 32) | (ret_data << (32*3));
assign buffer_read_data_new = buffer_read_data | ({{(`LINE_WIDTH-32){1'b0}},ret_data} << (32*buffer_read_data_count[`OFFSET_WIDTH-3:0]));

always @(posedge clk) begin
    // TODO 优化，此处反复写?
    if (!resetn) begin
        buffer_read_data <= 0;
        buffer_read_data_count <= 0;
    end
    else begin
        if (!uncached_reg & refill & ret_valid) begin
            buffer_read_data <= buffer_read_data_new;
            buffer_read_data_count <= buffer_read_data_count + 1;
        end
        if (rd_req) begin
            buffer_read_data <= 0;
            buffer_read_data_count <= {1'b0,rd_addr[`OFFSET_WIDTH-1:2]};
            buffer_read_data_count_start <= {1'b0,rd_addr[`OFFSET_WIDTH-1:2]};
        end
    end
    
end

always @(posedge clk) begin
    if (!refill) begin
        rd_addr_ok <= 0;
    end
    else if (refill & rd_rdy) begin
        rd_addr_ok <= 1;
    end
end

// write data to cache

generate
    // genvar i;
    for (i = 0; i < `LINE_SIZE; i = i + 1) begin: gen_refill_data
        assign cache_write_data_actually[8*i+7:8*i] = cache_wstrb_reg[i] ? cache_write_data_reg[8*i+7:8*i] : cache_rd_data[8*i+7:8*i];
    end
endgenerate


// write data to cache

assign cache_write_way_id = hit_write ? cache_hit_way_id : replace_way_id;

assign refill_write = !uncached_reg & refill & ret_valid_last;
assign cacop1_write = cacop12 & (op_reg == OP_CACOP1);
assign cacop2_write = cacop12 & (op_reg == OP_CACOP2);

assign cache_write = hit_write | refill_write;

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
    else if (cache_write) begin
        case (cache_write_way_id)
            0 : begin
                tag_way0[index_reg] <= tag_reg;
                valid_way0[index_reg] <= 1;
                dirty_way0[index_reg] <= op_reg == OP_WRITE;
            end
            1 : begin
                tag_way1[index_reg] <= tag_reg;
                valid_way1[index_reg] <= 1;
                dirty_way1[index_reg] <= op_reg == OP_WRITE;
            end
`ifdef CACHE_4WAY
            2 : begin
                tag_way2[index_reg] <= tag_reg;
                valid_way2[index_reg] <= 1;
                dirty_way2[index_reg] <= op_reg == OP_WRITE;
            end
            3 : begin
                tag_way3[index_reg] <= tag_reg;
                valid_way3[index_reg] <= 1;
                dirty_way3[index_reg] <= op_reg == OP_WRITE;
            end
`endif
        endcase
    end
    else if (cacop0_write | cacop1_write | cacop2_write) begin
        case (cacop_way_id)
            0 : begin
                valid_way0[index_reg] <= 0;
            end
            1 : begin
                valid_way1[index_reg] <= 0;
            end
`ifdef CACHE_4WAY
            2 : begin
                valid_way2[index_reg] <= 0;
            end
            3 : begin
                valid_way3[index_reg] <= 0;
            end
`endif
        endcase
    end
end

blk_mem_gen_cache_32 dcache_way0_ram(
    .addra(data_addr),
    .clka(clk),
    .dina(cache_write_data_actually),
    .douta(data_way0),
    .wea(cache_write & (cache_write_way_id == 0))
);

blk_mem_gen_cache_32 dcache_way1_ram(
    .addra(data_addr),
    .clka(clk),
    .dina(cache_write_data_actually),
    .douta(data_way1),
    .wea(cache_write & (cache_write_way_id == 1))
);


`define DBG_TAG 20'h1c012
`define DBG_INDEX 7'h3c
// `define DCACHE_DBG

`ifdef DCACHE_DBG
always @(posedge clk) begin
    if (index_reg == `DBG_INDEX) begin
        if (data_ok) begin
            if (op_reg == OP_WRITE) begin
                $display("[%t] p0 write %h(%h,%h,%h) : %h",$time,{tag_reg,index_reg,p0_offset_reg},tag_reg,index_reg,p0_offset_reg,p0_wdata_reg);
                if (p1_valid_reg) begin
                    $display("[%t] p1 write %h(%h,%h,%h) : %h",$time,{tag_reg,index_reg,p1_offset_reg},tag_reg,index_reg,p1_offset_reg,p1_wdata_reg);
                end
            end
            else begin
                $display("[%t] p0 read  %h(%h,%h,%h) : %h",$time,{tag_reg,index_reg,p0_offset_reg},tag_reg,index_reg,p0_offset_reg,p0_rdata);
                if (p1_valid_reg) begin
                    $display("[%t] p1 read  %h(%h,%h,%h) : %h",$time,{tag_reg,index_reg,p1_offset_reg},tag_reg,index_reg,p1_offset_reg,p1_rdata);
                end
                // if ({tag_reg,index_reg,offset_reg} == 32'h3154) begin
                //     $finish;
                // end
            end
        end
        if (refill_write) begin
            $display("[%t] refill_write way: %h, line: %h",$time,replace_way_id, cache_write_data_actually);
        end
        if (hit_write) begin
            $display("[%t] hit_write way   : %h, line: %h",$time,cache_hit_way_id, cache_write_data_actually);
        end
        if (replace & !uncached_reg) begin
            $display("[%t] replace (%h,%h), line: %h",$time, tag_reg,index_reg, wr_data);
        end
    end
end

`endif

// `define PERF_COUNT

`ifdef PERF_COUNT
reg [31:0] last_print_time;

reg [31:0] access_count;
reg [31:0] hit_count;
reg [31:0] uncached_count;

always @(posedge clk) begin
    if (!resetn) begin
        last_print_time <= 0;

        access_count <= 0;
        hit_count <= 0;
        uncached_count <= 0;
    end
    else begin
        if (data_ok) begin
            access_count <= access_count + 1;
            if (uncached_reg) begin
                uncached_count <= uncached_count + 1;
            end
            else begin
                if (cache_hit) begin
                    hit_count <= hit_count + 1;
                end
            end
        end
    end

    if (last_print_time + 10000 < $time) begin
        last_print_time <= $time;

        $display("[%t] dcache1_2 access_count  : %d", $time, access_count);
        $display("[%t] dcache1_2 hit_count     : %d", $time, hit_count);
        $display("[%t] dcache1_2 uncached_count: %d", $time, uncached_count);
    end
end

`endif

endmodule


