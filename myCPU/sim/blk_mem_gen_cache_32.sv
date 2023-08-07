// for verilator simulation
`ifdef SIMU

module blk_mem_gen_cache_32 (
    input wire clka,
    input wire [0:0] wea,
    input wire [6:0] addra,
    input wire [255:0] dina,
    output reg [255:0] douta
);

  reg [255:0] mem[0:127];

  always @(posedge clka) begin
    if (wea) begin
      mem[addra] <= dina;
    end
    douta <= mem[addra];
  end

endmodule

`endif
