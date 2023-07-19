`define CACHE_LINE_32B

`ifdef CACHE_LINE_16B
`define LINE_SIZE 16
`define LINE_WIDTH 128
`define TAG_WIDTH 20
`define INDEX_WIDTH 8
`define LINE_NUM 256
`define OFFSET_WIDTH 4
`elsif CACHE_LINE_32B
`define LINE_SIZE 32
`define LINE_WIDTH 256
`define TAG_WIDTH 20
`define INDEX_WIDTH 7
`define LINE_NUM 128
`define OFFSET_WIDTH 5
`endif

module icache(
    // Clock and reset
    input wire clk,
    input wire resetn,

    // Pipe interface
    input wire valid,
    input wire [`TAG_WIDTH-1:0] tag,
    input wire [`INDEX_WIDTH-1:0] index,
    input wire [`OFFSET_WIDTH-1:0] offset,
    input wire uncached,
    output wire addr_ok,
    output wire data_ok,
    // output wire [31:0] rdata,
    output wire [31:0] rdata_l,
    output wire [31:0] rdata_h,

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

reg [`INDEX_WIDTH-1:0] index_reg;
reg [`INDEX_WIDTH-1:0] index_reg_miss;
reg [`TAG_WIDTH-1:0] tag_reg;
reg [`OFFSET_WIDTH-1:0] offset_reg;
// reg [1:0] offset_w_reg; // word offset
wire [`OFFSET_WIDTH-3:0] offset_w_reg; // word offset
reg uncached_reg;

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

reg [`LINE_WIDTH-1:0] data_way0 [0:`LINE_NUM-1];
reg [`LINE_WIDTH-1:0] data_way1 [0:`LINE_NUM-1];
(* keep = "true" *) reg [`LINE_WIDTH-1:0] preload_data_way0;
(* keep = "true" *) reg [`LINE_WIDTH-1:0] preload_data_way1;

`ifdef CACHE_4WAY
reg [`LINE_WIDTH-1:0] data_way2 [0:`LINE_NUM-1];
reg [`LINE_WIDTH-1:0] data_way3 [0:`LINE_NUM-1];
(* keep = "true" *) reg [`LINE_WIDTH-1:0] preload_data_way2;
(* keep = "true" *) reg [`LINE_WIDTH-1:0] preload_data_way3;
`endif

`define get_preload_data(way_id_) (\
        {`LINE_WIDTH{way_id_==0}} & preload_data_way0\
    |   {`LINE_WIDTH{way_id_==1}} & preload_data_way1\
`ifdef CACHE_4WAY\
    |   {`LINE_WIDTH{way_id_==2}} & preload_data_way2\
    |   {`LINE_WIDTH{way_id_==3}} & preload_data_way3\
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
)

reg [2:0] main_state;

`define RD_TYPE_WORD      3'b010
`define RD_TYPE_CACHELINE 3'b100


`define MAIN_ST_IDLE 0
`define MAIN_ST_LOOKUP 1
`define MAIN_ST_MISS 2      // wait for memory finish writing previous data
`define MAIN_ST_REFILL 4

wire [2:0]  rd_type_cache;
wire [31:0] rd_addr_cache;
wire rd_req_cache;

wire [31:0] rd_addr_prefetch;
wire rd_req_prefetch;

reg rd_addr_ok;
wire ret_valid_last;


reg finished;

wire idle;
wire lookup;
wire miss;
wire refill;

wire cache_hit;
wire cache_hit_and_cached;
wire refill_write;

wire [`CACHE_WAY_NUM-1:0] cache_hit_way;
wire [`CACHE_WAY_NUM_LOG2-1:0] cache_hit_way_id;

wire pipe_interface_latch;

wire [`LINE_WIDTH-1:0] buffer_read_data_new;
// wire [127+24:0] cache_rd_data_ext;
wire [`LINE_WIDTH-1:0] cache_rd_data;
reg [`LINE_WIDTH-1:0] buffer_read_data;
reg [`OFFSET_WIDTH-3:0] buffer_read_data_count;

reg [`CACHE_WAY_NUM_LOG2-1:0] refill_way_id;

wire [`LINE_WIDTH-1:0] cache_write_data_actually;

wire next_same_line;

wire rdata_h_valid;

// prefetch

wire [`TAG_WIDTH-1:0]    prefetch_tag;
wire [`INDEX_WIDTH-1:0]  prefetch_index;

reg [`TAG_WIDTH-1:0]    prefetch_tag_reg;
reg [`INDEX_WIDTH-1:0]  prefetch_index_reg;
reg [`LINE_WIDTH-1:0]   prefetch_data_reg;
reg                     prefetch_valid_reg;

reg                     prefetching;

wire prefetch_cached;
wire [`CACHE_WAY_NUM-1:0] prefetch_cached_way;
wire prefetch_hit;
wire prefetch_same_line;
wire prefetch_next_same_line;

wire fetch_ok;

assign offset_w_reg = offset_reg[`OFFSET_WIDTH-1:2];

assign idle = (main_state == `MAIN_ST_IDLE);
assign lookup = (main_state == `MAIN_ST_LOOKUP);
assign miss = (main_state == `MAIN_ST_MISS);
assign refill = (main_state == `MAIN_ST_REFILL);

assign ret_valid_last = (ret_valid & ret_last);

assign next_same_line = (index == index_reg) & (tag == tag_reg);

assign pipe_interface_latch = valid & (
    (idle & !(prefetching & prefetch_next_same_line & ret_valid_last)) | 
    (lookup & cache_hit_and_cached) |
    (refill & !uncached_reg & (data_ok | finished) & next_same_line & !fetch_ok));

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
            index_reg <= index;
            tag_reg <= tag;
            // offset_w_reg <= offset[3:2];
            offset_reg <= offset;
            uncached_reg <= uncached;
        end
        if (lookup) begin
            index_reg_miss <= index_reg;
        end
    end
end

assign addr_ok = pipe_interface_latch;

always @(posedge clk) begin
    if (!resetn) begin
        preload_data_way0 <= 0;
        preload_data_way1 <= 0;
        preload_tag_way0 <= 0;
        preload_tag_way1 <= 0;
`ifdef CACHE_4WAY
        preload_data_way2 <= 0;
        preload_data_way3 <= 0;
        preload_tag_way2 <= 0;
        preload_tag_way3 <= 0;
`endif
    end
    else if ((idle | lookup) & pipe_interface_latch) begin
        preload_data_way0 <= data_way0[index];
        preload_data_way1 <= data_way1[index];
        preload_tag_way0 <= tag_way0[index];
        preload_tag_way1 <= tag_way1[index];
`ifdef CACHE_4WAY
        preload_data_way2 <= data_way2[index];
        preload_data_way3 <= data_way3[index];
        preload_tag_way2 <= tag_way2[index];
        preload_tag_way3 <= tag_way3[index];
`endif
    end
end

always @(posedge clk) begin
    if (!resetn) begin
        main_state <= 0;
        refill_way_id <= 0;
    end
    else begin
        case(main_state)
            `MAIN_ST_IDLE: begin
                if (pipe_interface_latch) begin
                    main_state <= `MAIN_ST_LOOKUP;
                end
            end
            `MAIN_ST_LOOKUP: begin
                if (cache_hit_and_cached) begin
                    if (!valid) begin
                        main_state <= `MAIN_ST_IDLE;
                    end
                end
                else begin
                    main_state <= `MAIN_ST_MISS;
                end
            end
            `MAIN_ST_MISS: begin
                if (!prefetching) begin    
                    if (uncached_reg) begin
                        if (rd_rdy & !prefetching) begin
                            main_state <= `MAIN_ST_REFILL;
                        end
                    end
                    else if (!prefetching) begin
                        main_state <= `MAIN_ST_REFILL;
                    end
                end
            end
            `MAIN_ST_REFILL: begin
                if (fetch_ok) begin
                    main_state <= `MAIN_ST_IDLE;
                    refill_way_id <= refill_way_id + 1;
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
                        : (prefetch_hit)
                            ? prefetch_data_reg
                            : buffer_read_data_new;

assign rdata_l = uncached_reg ? ret_data : `get_word(cache_rd_data, offset_w_reg);
assign rdata_h = `get_word(cache_rd_data, offset_w_reg+1);
assign rdata_h_valid = offset_reg[`OFFSET_WIDTH-1:2] != {(`OFFSET_WIDTH-2){1'b1}};

// assign data_ok = (op_reg == OP_READ) ? ((lookup & cache_hit) | ret_valid_last) : wdata_ok_reg;
assign data_ok = !finished & ((lookup & cache_hit_and_cached) 
                                | prefetch_hit
                                | (uncached_reg
                                    ?   (refill & ret_valid_last)
                                    :   ((refill | (prefetching & prefetch_same_line)) & ret_valid & (rdata_h_valid
                                                                                                                ? (buffer_read_data_count > offset_reg[`OFFSET_WIDTH-1:2])
                                                                                                                : (buffer_read_data_count >= offset_reg[`OFFSET_WIDTH-1:2]))
                                        )
                                )
                            );

// axi interface

assign wr_type = 0;
assign wr_addr = 0;
assign wr_data = 0;
assign wr_req = 0;
assign wr_wstrb = 0;

assign rd_type_cache = uncached_reg ? `RD_TYPE_WORD : `RD_TYPE_CACHELINE;
assign rd_addr_cache = uncached_reg ? {tag_reg,index_reg,offset_reg} : {tag_reg, index_reg_miss,{`OFFSET_WIDTH{1'b0}}};
assign rd_req_cache = !prefetch_hit & refill & ~rd_addr_ok;

assign rd_type = prefetching ? `RD_TYPE_CACHELINE : rd_type_cache;
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
        if (ret_valid_last) begin
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

// assign cache_write_way_id = hit_write ? cache_hit_way_id : replace_way_id;

assign refill_write = !uncached_reg & refill & fetch_ok;

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
        case (refill_way_id)
            0 : begin
                tag_way0[index_reg] <= tag_reg;
                valid_way0[index_reg] <= 1;
                data_way0[index_reg] <= cache_rd_data;
            end
            1 : begin
                tag_way1[index_reg] <= tag_reg;
                valid_way1[index_reg] <= 1;
                data_way1[index_reg] <= cache_rd_data;
            end
`ifdef CACHE_4WAY
            2 : begin
                tag_way2[index_reg] <= tag_reg;
                valid_way2[index_reg] <= 1;
                data_way2[index_reg] <= cache_rd_data;
            end
            3 : begin
                tag_way3[index_reg] <= tag_reg;
                valid_way3[index_reg] <= 1;
                data_way3[index_reg] <= cache_rd_data;
            end
`endif
        endcase
    end
end


// prefetch data from memory

assign prefetch_tag = tag_reg;
assign prefetch_index = index_reg + 1;
assign rd_addr_prefetch = {prefetch_tag_reg,prefetch_index_reg,{`OFFSET_WIDTH{1'b0}}};
assign rd_req_prefetch = prefetching & !rd_addr_ok;

generate
    // genvar i;
    for (i = 0; i < `CACHE_WAY_NUM; i = i + 1) begin: gen_prefetch_cached_way
        assign prefetch_cached_way[i] = `get_valid(i, prefetch_index) & (`get_tag(i, prefetch_index) == prefetch_tag);
    end
endgenerate

assign prefetch_next_same_line = (prefetch_index == index_reg) & (prefetch_tag == tag_reg);
assign prefetch_same_line = (prefetch_index_reg == index_reg) & (prefetch_tag_reg == tag_reg);

assign prefetch_cached = prefetch_cached_way != 0;
assign prefetch_hit = !uncached_reg & prefetch_valid_reg & prefetch_same_line;

assign fetch_ok = prefetch_hit | ret_valid_last;


always @(posedge clk) begin
    if (!resetn) begin
        prefetching <= 0;
        prefetch_valid_reg <= 0;
        prefetch_tag_reg <= 0;
        prefetch_index_reg <= 0;
    end
    else if (!prefetching & (lookup & cache_hit_and_cached) & (prefetch_index!=0) & !prefetch_cached & !uncached_reg & ((prefetch_tag != prefetch_tag_reg) | (prefetch_index != prefetch_index_reg))) begin
        prefetching <= 1;
        prefetch_valid_reg <= 0;
        prefetch_tag_reg <= prefetch_tag;
        prefetch_index_reg <= prefetch_index;
    end
    if (prefetching & ret_valid_last) begin
        prefetching <= 0;
        prefetch_valid_reg <= 1;
        prefetch_data_reg <= buffer_read_data_new;
    end
end


endmodule