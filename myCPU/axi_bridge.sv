// test only
`include "definitions.svh"


module axi_bridge(
    input    wire clk,
    input    wire reset,

    output   reg[ 3:0] arid,
    output   reg[31:0] araddr,
    output   reg[ 7:0] arlen,
    output   reg[ 2:0] arsize,
    output   wire[ 1:0] arburst,
    output   wire[ 1:0] arlock,
    output   wire[ 3:0] arcache,
    output   wire[ 2:0] arprot,
    output   reg       arvalid,
    input    wire      arready,

    input    wire[ 3:0] rid,
    input    wire[31:0] rdata,
    input    wire[ 1:0] rresp,
    input    wire       rlast,
    input    wire       rvalid,
    output   reg    rready,

    output   wire[ 3:0] awid,
    output   reg[31:0] awaddr,
    output   reg[ 7:0] awlen,
    output   reg[ 2:0] awsize,
    output   wire[ 1:0] awburst,
    output   wire[ 1:0] awlock,
    output   wire[ 3:0] awcache,
    output   wire[ 2:0] awprot,
    output   reg       awvalid,
    input    wire       awready,

    output   wire[ 3:0] wid,
    output   reg[31:0] wdata,
    output   reg[ 3:0] wstrb,
    output   reg       wlast,
    output   reg       wvalid,
    input    wire      wready,

    input    wire[ 3:0] bid,
    input    wire[ 1:0] bresp,
    input    wire       bvalid,
    output   reg    bready,
    //cache sign
    input  wire                     inst_rd_req     ,
    input  wire[ 2:0]               inst_rd_type    ,
    input  wire[31:0]               inst_rd_addr    ,
    output wire                     inst_rd_rdy     ,
    output wire                     inst_ret_valid  ,
    output wire                     inst_ret_last   ,
    output wire[31:0]               inst_ret_data   ,
    input  wire                     inst_wr_req     ,
    input  wire[ 2:0]               inst_wr_type    ,
    input  wire[31:0]               inst_wr_addr    ,
    input  wire[ 3:0]               inst_wr_wstrb   ,
    input  wire[`LINE_WIDTH-1:0]    inst_wr_data    ,
    output wire                     inst_wr_rdy     ,

    input  wire                     data_rd_req     ,
    input  wire[ 2:0]               data_rd_type    ,
    input  wire[31:0]               data_rd_addr    ,
    output wire                     data_rd_rdy     ,
    output wire                     data_ret_valid  ,
    output wire                     data_ret_last   ,
    output wire[31:0]               data_ret_data   ,
    input  wire                     data_wr_req     ,
    input  wire[ 2:0]               data_wr_type    ,
    input  wire[31:0]               data_wr_addr    ,
    input  wire[ 3:0]               data_wr_wstrb   ,
    input  wire[`LINE_WIDTH-1:0]    data_wr_data    ,
    output wire                     data_wr_rdy     ,
    output wire                     write_buffer_empty
);

//fixed signal
assign  arlock  = 2'b0;
assign  arcache = 4'b0;
assign  arprot  = 3'b0;
assign  awid    = 4'b1;
assign  awburst = 2'b1;
assign  awlock  = 2'b0;
assign  awcache = 4'b0;
assign  awprot  = 3'b0;
assign  wid     = 4'b1;

assign  inst_wr_rdy = 1'b1;

parameter RD_REQ_ST_IDLE = 1'b0;
parameter RD_REQ_ST_RDY = 1'b1;

parameter RD_RES_ST_IDLE = 1'b0;
parameter RD_RES_ST_RX = 1'b1;

parameter WR_ST_REQ_IDLE = 3'b000;
parameter WR_ST_ADDR_RDY = 3'b001;
parameter WR_ST_DATA_RDY = 3'b010;
parameter WR_ST_RDY = 3'b011;
parameter WR_ST_TX = 3'b100;
parameter WR_ST_TX_WAIT = 3'b101;
parameter WR_ST_WAIT_B = 3'b110;

reg       read_requst_state;
reg       read_respond_state;
reg [2:0] write_state;

wire      write_wait_enable;

wire         rd_requst_state_is_empty;
wire         rd_requst_can_receive;

assign arburst = (inst_rd_cache_line | data_rd_cache_line) ? 2'b10 : 2'b1;
assign rd_requst_state_is_empty = read_requst_state == RD_REQ_ST_IDLE;

wire        data_rd_cache_line;
wire        inst_rd_cache_line;
wire [ 2:0] data_real_rd_size;
wire [ 7:0] data_real_rd_len ;
wire [ 2:0] inst_real_rd_size;
wire [ 7:0] inst_real_rd_len ;
wire        data_wr_cache_line;
wire [ 2:0] data_real_wr_size;
wire [ 7:0] data_real_wr_len ;

reg [`LINE_WIDTH-1:0]                write_buffer_data;
reg [`OFFSET_WIDTH-3:0]              write_countdown_reg;

wire                    write_buffer_last;

assign write_buffer_empty = (write_countdown_reg == {(`OFFSET_WIDTH-2){1'b0}}) & !write_wait_enable;

assign rd_requst_can_receive = rd_requst_state_is_empty & !(write_wait_enable & !(bvalid & bready));

assign data_rd_rdy = rd_requst_can_receive;
assign inst_rd_rdy = !data_rd_req & rd_requst_can_receive;

assign data_rd_cache_line = data_rd_type == 3'b100;
assign data_real_rd_size  = data_rd_cache_line ? 3'b10 : data_rd_type;
assign data_real_rd_len   = data_rd_cache_line ? (`LINE_WORD_NUM-1) : 8'b0;

assign inst_rd_cache_line = inst_rd_type == 3'b100;
assign inst_real_rd_size  = inst_rd_cache_line ? 3'b10 : inst_rd_type;
assign inst_real_rd_len   = inst_rd_cache_line ? (`LINE_WORD_NUM-1) : 8'b0;

assign data_wr_cache_line = data_wr_type == 3'b100;
assign data_real_wr_size  = data_wr_cache_line ? 3'b10 : data_wr_type;
assign data_real_wr_len   = data_wr_cache_line ? (`LINE_WORD_NUM-1) : 8'b0;

assign inst_ret_valid = !rid[0] & rvalid;
assign inst_ret_last  = !rid[0] & rlast;
assign inst_ret_data  = rdata;
assign data_ret_valid =  rid[0] & rvalid;
assign data_ret_last  =  rid[0] & rlast;
assign data_ret_data  = rdata;

assign data_wr_rdy = (write_state == WR_ST_REQ_IDLE);

assign write_buffer_last = write_countdown_reg == 1;

always @(posedge clk) begin
    if (reset) begin
        read_requst_state <= RD_REQ_ST_IDLE;
        arvalid <= 1'b0;
    end
    else case (read_requst_state)
        RD_REQ_ST_IDLE: begin
            if (data_rd_req) begin
                if (write_wait_enable) begin
                    if (bvalid & bready) begin // TODO faster
                        read_requst_state <= RD_REQ_ST_RDY;
                        arid <= 4'b1;
                        araddr <= data_rd_addr;
                        arsize <= data_real_rd_size;
                        arlen  <= data_real_rd_len;
                        arvalid <= 1'b1;
                    end
                end
                else begin
                    read_requst_state <= RD_REQ_ST_RDY;
                    arid <= 4'b1;
                    araddr <= data_rd_addr;
                    arsize <= data_real_rd_size;
                    arlen  <= data_real_rd_len;
                    arvalid <= 1'b1;
                end
            end
            else if (inst_rd_req) begin
                if (write_wait_enable) begin
                    if (bvalid & bready) begin
                        read_requst_state <= RD_REQ_ST_RDY;
                        arid <= 4'b0;
                        araddr <= inst_rd_addr;
                        arsize <= inst_real_rd_size;
                        arlen  <= inst_real_rd_len;
                        arvalid <= 1'b1;
                    end
                end
                else begin
                    read_requst_state <= RD_REQ_ST_RDY;
                    arid <= 4'b0;
                    araddr <= inst_rd_addr;
                    arsize <= inst_real_rd_size;
                    arlen  <= inst_real_rd_len;
                    arvalid <= 1'b1;
                end
            end
        end
        RD_REQ_ST_RDY: begin
            if (arready & arid[0]) begin
                read_requst_state <= RD_REQ_ST_IDLE;
                arvalid <= 1'b0;
            end
            else if (arready & !arid[0]) begin 
                read_requst_state <= RD_REQ_ST_IDLE;
                arvalid <= 1'b0;
            end
        end
    endcase
end

always @(posedge clk) begin
    if (reset) begin
        read_respond_state <= RD_RES_ST_IDLE;
        rready <= 1'b1;
    end
    else case (read_respond_state)
        RD_RES_ST_IDLE: begin
            if (rvalid & rready) begin 
                read_respond_state <= RD_RES_ST_RX;
            end
        end
        RD_RES_ST_RX: begin
            if (rlast & rvalid) begin
                read_respond_state <= RD_RES_ST_IDLE;
            end
        end
    endcase
end

always @(posedge clk) begin
    if (reset) begin
        write_state <= WR_ST_REQ_IDLE;
        awvalid <= 1'b0;
        wvalid  <= 1'b0;
        wlast   <= 1'b0;
        bready  <= 1'b0;
        
        write_countdown_reg <= 0;
        write_buffer_data   <= 0;
    end
    else case (write_state)
        WR_ST_REQ_IDLE: begin
            if (data_wr_req) begin
                write_state <= WR_ST_TX_WAIT;
                //end
                awaddr  <= data_wr_addr;
                awsize  <= data_real_wr_size;
                awlen   <= data_real_wr_len;
                awvalid <= 1'b1;
                wdata   <= data_wr_data[31:0];
                wstrb   <= data_wr_wstrb;

                write_buffer_data <= {32'b0, data_wr_data[`LINE_WIDTH-1:32]};

                if (data_wr_type == 3'b100) begin
                    write_countdown_reg <= {(`OFFSET_WIDTH-2){1'b1}};
                end
                else begin
                    write_countdown_reg <= 0;
                    wlast <= 1'b1;
                end
            end
        end
        WR_ST_TX_WAIT: begin
            if (awready) begin
                write_state <= WR_ST_TX;
                awvalid <= 1'b0;
		wvalid  <= 1'b1;
            end
        end 
        WR_ST_TX: begin
            if (wready) begin
                if (wlast) begin
                    write_state <= WR_ST_WAIT_B;
                    wvalid <= 1'b0;
                    wlast <= 1'b0;
        	    bready <= 1'b1;
                end
                else begin
                    if (write_buffer_last) begin
                        wlast <= 1'b1;
                    end
                
                    write_state <= WR_ST_TX;
    
                    wdata   <= write_buffer_data[31:0];
                    wvalid  <= 1'b1;
                    write_buffer_data <= {32'b0, write_buffer_data[`LINE_WIDTH-1:32]};
                    write_countdown_reg  <= write_countdown_reg - 1;
                end
            end
        end
        WR_ST_WAIT_B: begin
            if (bvalid & bready) begin
                write_state <= WR_ST_REQ_IDLE;
                bready <= 1'b0;
            end
        end
        default: begin
            write_state <= WR_ST_REQ_IDLE;
        end
    endcase
end

assign write_wait_enable = !(write_state == WR_ST_REQ_IDLE);

endmodule
