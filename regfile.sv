`include "definitions.svh"

module regfile(
    input  wire         clk,

    input  wire  [ 4:0] raddr1,
    output logic [31:0] rdata1,

    input  wire  [ 4:0] raddr2,
    output logic [31:0] rdata2,

    input  wire  [ 4:0] raddr3,
    output logic [31:0] rdata3,

    input  wire  [ 4:0] raddr4,
    output logic [31:0] rdata4,

    input  wire        we1,
    input  wire [ 4:0] waddr1,
    input  wire [31:0] wdata1,

    input  wire        we2,
    input  wire [ 4:0] waddr2,
    input  wire [31:0] wdata2
);

logic [31:0] rf[31:0];

always_ff @(posedge clk) begin
    if (we1) rf[waddr1] <= wdata1;
    if (we2) rf[waddr2] <= wdata2;
end

assign rdata1 = rf[raddr1];
assign rdata2 = rf[raddr2];
assign rdata3 = rf[raddr3];
assign rdata4 = rf[raddr4];

endmodule
