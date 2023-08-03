`include "definitions.svh"

module lsu (
    input clk,
    input reset,
    input cancel,
    // to ex1
    output ready,
    // from ex1
    input valid,
    input start,  // 仅发出请求的第一个周期置为1，但要保证下面的输入不变
    input [31:0] base,
    input [31:0] offset,
    input mem_type_t mem_type,
    input mem_size_t mem_size,
    input [31:0] st_data,
    // to ex1
    output logic have_excp,
    output excp_t excp_type,
    // to wb reg
    output ok,
    input accept_ok,
    output [31:0] ld_data,
    //to mmu
    output logic mmu_req,
    output logic [31:0] mmu_addr,
    output logic mmu_we,
    output logic [1:0] mmu_size,
    output logic [3:0] mmu_wstrb,
    output logic [31:0] mmu_wdata,
    //from mmu
    input mmu_addr_ok,
    input mmu_data_ok,
    input [31:0] mmu_rdata,
    input mmu_tlbr,
    input mmu_pil,
    input mmu_pis,
    input mmu_ppi,
    input mmu_pme
);
  logic             wait_for_addr_ok;
  logic             wait_for_data_ok;
  logic             ok_not_accepted;
  logic      [31:0] ld_data_buf;

  logic      [ 1:0] addr_lowbit_buf;
  mem_type_t        mem_type_buf;
  mem_size_t        mem_size_buf;
  logic      [31:0] ld_data_inner;

  logic             stage2_allowin;
  logic      [31:0] addr;

  assign addr = base + offset;
  assign ready = (!wait_for_addr_ok || mmu_addr_ok && stage2_allowin) && !(start && !mmu_addr_ok);
  assign stage2_allowin = !ok_not_accepted && (!wait_for_data_ok || mmu_data_ok);

  always_ff @(posedge clk) begin
    if (reset) begin
      wait_for_addr_ok <= 1'b0;
    end else begin
      if (start && !mmu_addr_ok && !cancel) begin
        wait_for_addr_ok <= 1'b1;
      end
      if (mmu_addr_ok) begin
        wait_for_addr_ok <= 1'b0;
        addr_lowbit_buf <= mmu_addr[1:0];
        mem_type_buf    <= mem_type;
        mem_size_buf    <= mem_size;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      wait_for_data_ok <= 1'b0;
    end else begin
      if (mmu_addr_ok) begin
        wait_for_data_ok <= 1'b1;
      end else if (mmu_data_ok) begin
        wait_for_data_ok <= 1'b0;
      end
    end
  end

  assign ok = mmu_data_ok || ok_not_accepted;
  assign ld_data = ok_not_accepted ? ld_data_buf : ld_data_inner;

  always_ff @(posedge clk) begin
    if (reset) begin
      ok_not_accepted <= 1'b0;
    end else begin
      if (mmu_data_ok && !accept_ok) begin
        ok_not_accepted <= 1'b1;
        ld_data_buf <= ld_data_inner;
      end else if (accept_ok) begin
        ok_not_accepted <= 1'b0;
      end
    end
  end

  assign mmu_req  = start || wait_for_addr_ok;
  assign mmu_addr = addr;
  assign mmu_we   = mem_type == MEM_STORE;
  assign mmu_size = mem_size == MEM_BYTE ? 2'd0 : mem_size == MEM_HALF ? 2'd1 : 2'd2;

  always_comb begin
    if (mem_type == MEM_STORE) begin
      unique case (mem_size)
        MEM_BYTE: begin
          unique case (addr[1:0])
            2'b00:   mmu_wstrb = 4'b0001;
            2'b01:   mmu_wstrb = 4'b0010;
            2'b10:   mmu_wstrb = 4'b0100;
            default: mmu_wstrb = 4'b1000;
          endcase
          mmu_wdata = {4{st_data[7:0]}};
        end
        MEM_HALF: begin
          unique case (addr[1])
            1'b0:    mmu_wstrb = 4'b0011;
            default: mmu_wstrb = 4'b1100;
          endcase
          mmu_wdata = {2{st_data[15:0]}};
        end
        default: begin
          mmu_wstrb = 4'b1111;
          mmu_wdata = st_data;
        end
      endcase
    end else begin
      mmu_wstrb = 4'b0000;
      mmu_wdata = st_data;
    end
  end

  always_comb begin
    if (!valid) begin
      have_excp = 1'b0;
      excp_type = ALE;
    end else if (mem_size == MEM_HALF && addr[0] || mem_size == MEM_WORD && addr[1:0] != 2'h0) begin
      have_excp = 1'b1;
      excp_type = ALE;
    end else if (mmu_tlbr) begin
      have_excp = 1'b1;
      excp_type = TLBR;
    end else if (mmu_pil) begin
      have_excp = 1'b1;
      excp_type = PIL;
    end else if (mmu_pis) begin
      have_excp = 1'b1;
      excp_type = PIS;
    end else if (mmu_ppi) begin
      have_excp = 1'b1;
      excp_type = PPI;
    end else if (mmu_pme) begin
      have_excp = 1'b1;
      excp_type = PME;
    end else begin
      have_excp = 1'b0;
      excp_type = ALE;
    end
  end

  always_comb begin
    unique case (mem_size_buf)
      MEM_BYTE: begin
        logic [7:0] load_b;
        unique case (addr_lowbit_buf)
          2'b00:   load_b = mmu_rdata[7:0];
          2'b01:   load_b = mmu_rdata[15:8];
          2'b10:   load_b = mmu_rdata[23:16];
          default: load_b = mmu_rdata[31:24];
        endcase
        ld_data_inner = {{24{load_b[7] && mem_type_buf == MEM_LOAD_S}}, load_b};
      end
      MEM_HALF: begin
        logic [15:0] load_h;
        unique case (addr_lowbit_buf[1])
          1'b0:    load_h = mmu_rdata[15:0];
          default: load_h = mmu_rdata[31:16];
        endcase
        ld_data_inner = {{16{load_h[15] && mem_type_buf == MEM_LOAD_S}}, load_h};
      end
      default: begin
        ld_data_inner = mmu_rdata;
      end
    endcase
  end

endmodule
