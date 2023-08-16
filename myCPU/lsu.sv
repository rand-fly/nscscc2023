`include "definitions.svh"

module lsu (
    input                                   clk,
    input                                   reset,
    // from ex1
    input                                   prepare,
    input                                   valid,
    output                                  ready,
    input               [             31:0] addr,
    input  mem_opcode_t                     opcode,
    input               [             31:0] st_data,
    // dcacop_valid 用于发起 dcacop 请求
    // cacop2_valid 用于完成 icacop2 和 dcacop2 的 tlb 例外检查
    input                                   dcacop_valid,
    input               [              1:0] cacop_op,
    input                                   cacop2_valid,
    output                                  cacop2_ok,
    output logic                            have_excp,
    output excp_t                           excp_type,
    // to wb reg
    output                                  ok,
    output logic        [             31:0] ld_data,
    // to/from dcache
    output                                  dcache_p0_valid,
    output                                  dcache_p1_valid,
    output              [              2:0] dcache_op,
    output              [   `TAG_WIDTH-1:0] dcache_tag,
    output              [ `INDEX_WIDTH-1:0] dcache_index,
    output              [`OFFSET_WIDTH-1:0] dcache_p0_offset,
    output              [`OFFSET_WIDTH-1:0] dcache_p1_offset,
    output logic        [              3:0] dcache_p0_wstrb,
    output              [              3:0] dcache_p1_wstrb,
    output logic        [             31:0] dcache_p0_wdata,
    output              [             31:0] dcache_p1_wdata,
    output                                  dcache_uncached,
    output              [              1:0] dcache_p0_size,
    output              [              1:0] dcache_p1_size,
    input                                   dcache_addr_ok,
    input                                   dcache_data_ok,
    input               [             31:0] dcache_p0_rdata,
    input               [             31:0] dcache_p1_rdata,
    // to/from mmu
    output                                  mmu_valid,
    output              [   `TAG_WIDTH-1:0] mmu_vtag,
    input                                   mmu_ok,
    input               [   `TAG_WIDTH-1:0] mmu_ptag,
    input               [              1:0] mmu_mat,
    input                                   mmu_page_fault,
    input                                   mmu_page_invalid,
    input                                   mmu_page_dirty,
    input                                   mmu_plv_fault
);
  logic              mmu_ok_reg;
  logic        [1:0] addr_lowbit_reg;
  mem_opcode_t       opcode_reg;

  always_ff @(posedge clk) begin
    if (reset) begin
      mmu_ok_reg <= 1'b0;
    end else begin
      if (valid && ready || cacop2_valid || have_excp) begin
        mmu_ok_reg <= 1'b0;
      end else if (mmu_ok) begin
        mmu_ok_reg <= 1'b1;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (valid && ready) begin
      addr_lowbit_reg <= addr[1:0];
      opcode_reg <= opcode;
    end
  end

  assign ready = dcache_addr_ok && (mmu_ok || mmu_ok_reg);

  assign ok = dcache_data_ok;

  assign dcache_p0_valid = valid && !have_excp && (mmu_ok || mmu_ok_reg) || dcacop_valid;
  assign dcache_tag = mmu_ptag;
  assign dcache_index = addr[`OFFSET_WIDTH+`INDEX_WIDTH-1:`OFFSET_WIDTH];
  assign dcache_p0_offset = addr[`OFFSET_WIDTH-1:0];
  assign dcache_op = dcacop_valid ? {1'b1, cacop_op} : {2'd0, opcode.store};
  assign dcache_p0_size = opcode.size_byte ? 2'd0 : opcode.size_half ? 2'd1 : 2'd2;
  assign dcache_uncached = mmu_mat == 2'd0;

  assign dcache_p1_valid = 1'b0;
  assign dcache_p1_offset = 0;
  assign dcache_p1_size = 0;
  assign dcache_p1_wstrb = 0;
  assign dcache_p1_wdata = 0;

  assign mmu_vtag = addr[31:31-`TAG_WIDTH+1];
  assign mmu_valid = valid && !mmu_ok_reg || cacop2_valid;

  assign cacop2_ok = mmu_ok;

  always_comb begin
    if (opcode.size_byte) begin
      unique case (addr[1:0])
        2'b00: dcache_p0_wstrb = 4'b0001;
        2'b01: dcache_p0_wstrb = 4'b0010;
        2'b10: dcache_p0_wstrb = 4'b0100;
        2'b11: dcache_p0_wstrb = 4'b1000;
      endcase
      dcache_p0_wdata = {4{st_data[7:0]}};
    end else if (opcode.size_half) begin
      unique case (addr[1])
        1'b0: dcache_p0_wstrb = 4'b0011;
        1'b1: dcache_p0_wstrb = 4'b1100;
      endcase
      dcache_p0_wdata = {2{st_data[15:0]}};
    end else begin
      dcache_p0_wstrb = 4'b1111;
      dcache_p0_wdata = st_data;
    end
  end

  always_comb begin
    if (!valid) begin
      if (cacop2_valid && mmu_page_fault) begin
        have_excp = 1'b1;
        excp_type = D_TLBR;
      end else if (cacop2_valid && mmu_page_invalid) begin
        have_excp = 1'b1;
        excp_type = PIL;
      end else begin
        have_excp = 1'b0;
        excp_type = ALE;
      end
    end else if (opcode.size_half && addr[0] || opcode.size_word && addr[1:0] != 2'h0) begin
      have_excp = 1'b1;
      excp_type = ALE;
    end else if (mmu_page_fault && (mmu_ok || mmu_ok_reg)) begin
      have_excp = 1'b1;
      excp_type = D_TLBR;
    end else if (mmu_page_invalid && opcode.load && (mmu_ok || mmu_ok_reg)) begin
      have_excp = 1'b1;
      excp_type = PIL;
    end else if (mmu_page_invalid && opcode.store && (mmu_ok || mmu_ok_reg)) begin
      have_excp = 1'b1;
      excp_type = PIS;
    end else if (mmu_plv_fault && (mmu_ok || mmu_ok_reg)) begin
      have_excp = 1'b1;
      excp_type = PPI;
    end else if (mmu_page_dirty && opcode.store && (mmu_ok || mmu_ok_reg)) begin
      have_excp = 1'b1;
      excp_type = PME;
    end else begin
      have_excp = 1'b0;
      excp_type = ALE;
    end
  end

  always_comb begin
    if (opcode_reg.size_byte) begin
      logic [7:0] load_b;
      unique case (addr_lowbit_reg[1:0])
        2'b00: load_b = dcache_p0_rdata[7:0];
        2'b01: load_b = dcache_p0_rdata[15:8];
        2'b10: load_b = dcache_p0_rdata[23:16];
        2'b11: load_b = dcache_p0_rdata[31:24];
      endcase
      ld_data = {{24{load_b[7] && opcode_reg.load_sign}}, load_b};
    end else if (opcode_reg.size_half) begin
      logic [15:0] load_h;
      unique case (addr_lowbit_reg[1])
        1'b0: load_h = dcache_p0_rdata[15:0];
        1'b1: load_h = dcache_p0_rdata[31:16];
      endcase
      ld_data = {{16{load_h[15] && opcode_reg.load_sign}}, load_h};
    end else begin
      ld_data = dcache_p0_rdata;
    end
  end

endmodule
