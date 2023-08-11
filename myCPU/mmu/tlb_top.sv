`define TLB_STATE_CACHE 0
`define TLB_STATE_L2    1

module tlb_top
    (
        input clk,
        input reset,

        // search port 0 (for fetch)
        input               [18:0] s0_vppn,
        input                      s0_va_bit12,
        input               [ 9:0] s0_asid,
        output tlb_result_t        s0_result,
        output                     s0_ok,

        // search port 1 (for load/store)
        input               [18:0] s1_vppn,
        input                      s1_va_bit12,
        input               [ 9:0] s1_asid,
        output tlb_result_t        s1_result,
        output                     s1_ok,

        // invtlb opcode
        input        invtlb_valid,
        input [ 4:0] invtlb_op,
        input [ 9:0] invtlb_asid,
        input [31:0] invtlb_va,

        // write port
        input                            we,       //w(rite) e(nable)
        input             [TLBIDLEN-1:0] w_index,
        input tlb_entry_t                w_entry,

        // read port
        input              [TLBIDLEN-1:0] r_index,
        output tlb_entry_t                r_entry
    );

    // hit signal
    logic l2_hit_0;
    logic l2_hit_1;
    logic inst_tlb_hit = inst_tlb_result.found;
    logic data_tlb_hit = data_tlb_result.found;

    //refill signal
    logic inst_tlb_refill_valid;
    logic data_tlb_refill_valid;
    logic [TLBIDLEN-1:0] l2_hit_index_0;
    logic [TLBIDLEN-1:0] l2_hit_index_1;
    logic [TLBIDLEN-1:0] inst_tlb_refill_index;
    logic [TLBIDLEN-1:0] data_tlb_refill_index;
    tlb_entry_t inst_tlb_refill_data;
    tlb_entry_t data_tlb_refill_data;

    assign inst_tlb_refill_valid = l2_hit_0 & inst_tlb_state;
    assign data_tlb_refill_valid = l2_hit_1 & data_tlb_state;
    assign inst_tlb_refill_index = l2_hit_index_0;
    assign data_tlb_refill_index = l2_hit_index_1;
    assign inst_tlb_refill_data = l2_entry_0;
    assign data_tlb_refill_data = l2_entry_1;

    //search port results
    tlb_entry_t l2_entry_0;
    tlb_entry_t l2_entry_1;
    tlb_result_t l2_result_0;
    tlb_result_t l2_result_1;
    tlb_result_t inst_tlb_result;
    tlb_result_t data_tlb_result;

    assign l2_result_0.found = l2_hit_0 ;
    assign l2_result_1.found = l2_hit_1;
    assign s0_index = l2_hit_index_0;
    assign s1_index = l2_hit_index_1;

    assign s0_result = (l2_result_0 & 64{inst_tlb_state}) | (inst_tlb_hit & 64{~inst_tlb_state});
    assign s1_result = (l2_result_1 & 64{data_tlb_state}) | (data_tlb_hit & 64{~data_tlb_state});
    
    //tcache hit / lookup L2 -> valid result
    assign s0_ok = (inst_tlb_hit & ~inst_tlb_state) | inst_tlb_state;
    assign s1_ok = (data_tlb_hit & ~data_tlb_state) | data_tlb_state;
    
    //state register
    reg inst_tlb_state;
    reg data_tlb_state;
    always @(posedge clk) begin: state_transition
        if(reset) begin
            inst_tlb_state <= `TLB_STATE_CACHE;
            data_tlb_state <= `TLB_STATE_CACHE;
        end else begin
            inst_tlb_state <= ~(inst_tlb_hit | inst_tlb_state);
            data_tlb_state <= ~(data_tlb_hit | data_tlb_state);
        end
    end


    always_comb begin: l2_result_comb
        logic [TLBIDLEN-1:0] i;
        if ((l2_entry_0.ps4MB == 0 && s0_va_bit12 == 0) || (l2_entry_0.ps4MB == 1 && s0_vppn[8] == 0)) begin
            l2_result_0.ppn = l2_entry_0.ppn0;
            l2_result_0.ps  = l2_entry_0.ps4MB ? 21 : 12;
            l2_result_0.plv = l2_entry_0.plv0;
            l2_result_0.mat = l2_entry_0.mat0;
            l2_result_0.d   = l2_entry_0.d0;
            l2_result_0.v   = l2_entry_0.v0;
        end else begin
            l2_result_0.ppn = l2_entry_0.ppn1;
            l2_result_0.ps  = l2_entry_0.ps4MB ? 21 : 12;
            l2_result_0.plv = l2_entry_0.plv1;
            l2_result_0.mat = l2_entry_0.mat1;
            l2_result_0.d   = l2_entry_0.d1;
            l2_result_0.v   = l2_entry_0.v1;
        end
        if ((l2_entry_1.ps4MB == 0 && s1_va_bit12 == 0) || (l2_entry_1.ps4MB == 1 && s1_vppn[8] == 0)) begin
            l2_result_1.ppn = l2_entry_1.ppn0;
            l2_result_1.ps  = l2_entry_1.ps4MB ? 21 : 12;
            l2_result_1.plv = l2_entry_1.plv0;
            l2_result_1.mat = l2_entry_1.mat0;
            l2_result_1.d   = l2_entry_1.d0;
            l2_result_1.v   = l2_entry_1.v0;
        end else begin
            l2_result_1.ppn = l2_entry_1.ppn1;
            l2_result_1.ps  = l2_entry_1.ps4MB ? 21 : 12;
            l2_result_1.plv = l2_entry_1.plv1;
            l2_result_1.mat = l2_entry_1.mat1;
            l2_result_1.d   = l2_entry_1.d1;
            l2_result_1.v   = l2_entry_1.v1;
        end
    end

    tcache inst_tlb(
        .clk(clk),
        .reset(reset),

        .s_vppn(s0_vppn),
        .s_va_bit12(s0_va_bit12),
        .s_asid(s0_asid),
        .s_result(inst_tlb_result),

        .we(we),
        .w_index(w_index),
        .w_entry(w_entry),

        .refill_valid(inst_tlb_refill_valid),
        .refill_data(inst_tlb_refill_data),
        .refill_index(inst_tlb_refill_index)
    );

    tcache data_tlb(
        .clk(clk),
        .reset(reset),

        .s_vppn(s1_vppn),
        .s_va_bit12(s1_va_bit12),
        .s_asid(s1_asid),
        .s_result(data_tlb_result),

        .we(we),
        .w_index(w_index),
        .w_entry(w_entry),

        .refill_valid(data_tlb_refill_valid),
        .refill_data(data_tlb_refill_data),
        .refill_index(data_tlb_refill_index)
    );
    
    tlb_L2 tlb_L2(
        .clk(clk),
        .reset(reset),

        .s0_vppn(s0_vppn),
        .s0_asid(s0_asid),
        .s0_result(l2_entry_0),
        .s0_found(l2_hit_0),
        .s0_index(l2_hit_index_0),

        .s1_vppn(s1_vppn),
        .s1_asid(s1_asid),
        .s1_result(l2_entry_1),
        .s1_found(l2_hit_1),
        .s1_index(l2_hit_index_1),

        .invtlb_valid(invtlb_valid),
        .invtlb_op(invtlb_op),
        .invtlb_asid(invtlb_asid),
        .invtlb_va(invtlb_va),

        .we(we),
        .w_index(w_index),
        .w_entry(w_entry),

        .r_index(r_index),
        .r_entry(r_entry)
    );

    

endmodule