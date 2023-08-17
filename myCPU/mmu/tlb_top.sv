`include "../definitions.svh"
`define TLB_STATE_CACHE 0
`define TLB_STATE_L2_LOOKUP 1
`define TLB_STATE_L2_FETCH 2
`define TLB_STATE_REFILL 3

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

    logic s0_valid;
    logic s1_valid;

    //state register
    reg [1:0] inst_tlb_state;
    reg [1:0] data_tlb_state;

    //l2 input register
    reg [18:0] s0_vppn_reg;
    reg [18:0] s1_vppn_reg;
    reg [ 9:0] s0_asid_reg;
    reg [ 9:0] s1_asid_reg;
    reg        s0_va_bit12_reg;
    reg        s1_va_bit12_reg;

    // hit signal
    logic l2_hit_0;
    logic l2_hit_1;
    logic inst_tlb_hit;
    logic data_tlb_hit;

    //refill signal
    logic inst_tlb_refill_valid;
    logic data_tlb_refill_valid;
    logic [TLBIDLEN-1:0] l2_hit_index_0;
    logic [TLBIDLEN-1:0] l2_hit_index_1;
    logic [TLBIDLEN-1:0] inst_tlb_refill_index;
    logic [TLBIDLEN-1:0] data_tlb_refill_index;
    tlb_entry_t inst_tlb_refill_data;
    tlb_entry_t data_tlb_refill_data;
    reg inst_tlb_refill_valid_reg;
    reg data_tlb_refill_valid_reg;
    reg [TLBIDLEN-1:0] inst_tlb_refill_index_reg;
    reg [TLBIDLEN-1:0] data_tlb_refill_index_reg;
    tlb_entry_t  inst_tlb_refill_data_reg;
    tlb_entry_t  data_tlb_refill_data_reg;

    //search port results
    tlb_entry_t l2_entry_0;
    tlb_entry_t l2_entry_1;
    tlb_result_t l2_result_0;
    tlb_result_t l2_result_1;
    tlb_result_t inst_tlb_result;
    tlb_result_t data_tlb_result;

    assign inst_tlb_hit = inst_tlb_result.found;
    assign data_tlb_hit = data_tlb_result.found;

    assign inst_tlb_refill_valid = l2_hit_0 & inst_tlb_state == `TLB_STATE_L2_FETCH;
    assign data_tlb_refill_valid = l2_hit_1 & data_tlb_state == `TLB_STATE_L2_FETCH;
    assign inst_tlb_refill_index = l2_hit_index_0;
    assign data_tlb_refill_index = l2_hit_index_1;
    assign inst_tlb_refill_data = l2_entry_0;
    assign data_tlb_refill_data = l2_entry_1;

    always @(posedge clk) begin: refill_buff
        if(reset) begin
            inst_tlb_refill_valid_reg <= 0;
            data_tlb_refill_valid_reg <= 0;
        end else begin
            inst_tlb_refill_valid_reg <= inst_tlb_refill_valid;
            data_tlb_refill_valid_reg <= data_tlb_refill_valid;
            inst_tlb_refill_index_reg <= inst_tlb_refill_index;
            data_tlb_refill_index_reg <= data_tlb_refill_index;
            inst_tlb_refill_data_reg <= inst_tlb_refill_data;
            data_tlb_refill_data_reg <= data_tlb_refill_data;
        end
    end


    assign l2_result_0.found = l2_hit_0 ;
    assign l2_result_1.found = l2_hit_1;
    assign l2_result_0.index = l2_hit_index_0;
    assign l2_result_1.index = l2_hit_index_1;

    assign s0_result = (inst_tlb_state == `TLB_STATE_CACHE) ? inst_tlb_result : l2_result_0;
    assign s1_result = (data_tlb_state == `TLB_STATE_CACHE) ? data_tlb_result : l2_result_1;
    
    //tcache hit / lookup L2 -> valid result
    assign s0_ok = (inst_tlb_hit & inst_tlb_state == `TLB_STATE_CACHE) | inst_tlb_state == `TLB_STATE_REFILL;
    assign s1_ok = (data_tlb_hit & data_tlb_state == `TLB_STATE_CACHE) | data_tlb_state == `TLB_STATE_REFILL;
    
    
    always @(posedge clk) begin: state_transition
        if(reset) begin
            inst_tlb_state <= `TLB_STATE_CACHE;
            data_tlb_state <= `TLB_STATE_CACHE;
        end else begin
            case(inst_tlb_state)
                `TLB_STATE_CACHE: begin
                    if(s0_valid && (!inst_tlb_hit)) begin
                        inst_tlb_state <= `TLB_STATE_L2_LOOKUP;
                    end
                end
                `TLB_STATE_L2_LOOKUP: begin
                    if(s0_valid) begin
                        inst_tlb_state <= `TLB_STATE_CACHE;
                    end else begin
                        inst_tlb_state <= `TLB_STATE_L2_FETCH;
                    end
                end
                `TLB_STATE_L2_FETCH: begin
                    if(s0_valid) begin
                        inst_tlb_state <= `TLB_STATE_CACHE;
                    end else begin
                        inst_tlb_state <= `TLB_STATE_REFILL;
                    end
                end
                `TLB_STATE_REFILL: begin
                    inst_tlb_state <= `TLB_STATE_CACHE;
                end 
            endcase
            case(data_tlb_state)
                `TLB_STATE_CACHE: begin
                    if(s1_valid && (!data_tlb_hit)) begin
                        data_tlb_state <= `TLB_STATE_L2_LOOKUP;
                    end
                end
                `TLB_STATE_L2_LOOKUP: begin
                    if(s1_valid) begin
                        data_tlb_state <= `TLB_STATE_CACHE;
                    end else begin
                        data_tlb_state <= `TLB_STATE_L2_FETCH;
                    end
                end
                `TLB_STATE_L2_FETCH: begin
                    if(s1_valid) begin
                        data_tlb_state <= `TLB_STATE_CACHE;
                    end else begin
                        data_tlb_state <= `TLB_STATE_REFILL;
                    end
                end
                `TLB_STATE_REFILL: begin
                    data_tlb_state <= `TLB_STATE_CACHE;
                end
            endcase
        end
    end

    assign s0_valid = !((s0_vppn_reg == s0_vppn) && (s0_asid_reg == s0_asid) && (s0_va_bit12_reg == s0_va_bit12));
    assign s1_valid = !((s1_vppn_reg == s1_vppn) && (s1_asid_reg == s1_asid) && (s1_va_bit12_reg == s1_va_bit12));


    always @(posedge clk) begin
        if(reset) begin
            s0_vppn_reg <= 0;
            s0_asid_reg <= 0;
            s0_va_bit12_reg <= 0;
        end else if (inst_tlb_state == `TLB_STATE_CACHE)begin
            s0_vppn_reg <= s0_vppn;
            s0_asid_reg <= s0_asid;
            s0_va_bit12_reg <= s0_va_bit12;
        end
    end

    always @(posedge clk) begin
        if(reset) begin
            s1_vppn_reg <= 0;
            s1_asid_reg <= 0;
            s1_va_bit12_reg <= 0;
        end else if (data_tlb_state == `TLB_STATE_CACHE)begin
            s1_vppn_reg <= s1_vppn;
            s1_asid_reg <= s1_asid;
            s1_va_bit12_reg <= s1_va_bit12;
        end
    end

    always_comb begin: l2_result_comb
        if ((l2_entry_0.ps == 12 && s0_va_bit12_reg == 0) || (l2_entry_0.ps == 21 && s0_vppn_reg[8] == 0)) begin
            l2_result_0.ppn = l2_entry_0.ppn0;
            l2_result_0.ps  = l2_entry_0.ps;
            l2_result_0.plv = l2_entry_0.plv0;
            l2_result_0.mat = l2_entry_0.mat0;
            l2_result_0.d   = l2_entry_0.d0;
            l2_result_0.v   = l2_entry_0.v0;
        end else begin
            l2_result_0.ppn = l2_entry_0.ppn1;
            l2_result_0.ps  = l2_entry_0.ps;
            l2_result_0.plv = l2_entry_0.plv1;
            l2_result_0.mat = l2_entry_0.mat1;
            l2_result_0.d   = l2_entry_0.d1;
            l2_result_0.v   = l2_entry_0.v1;
        end
        if ((l2_entry_1.ps == 12 && s1_va_bit12_reg == 0) || (l2_entry_1.ps == 21 && s1_vppn_reg[8] == 0)) begin
            l2_result_1.ppn = l2_entry_1.ppn0;
            l2_result_1.ps  = l2_entry_1.ps;
            l2_result_1.plv = l2_entry_1.plv0;
            l2_result_1.mat = l2_entry_1.mat0;
            l2_result_1.d   = l2_entry_1.d0;
            l2_result_1.v   = l2_entry_1.v0;
        end else begin
            l2_result_1.ppn = l2_entry_1.ppn1;
            l2_result_1.ps  = l2_entry_1.ps;
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

        .invalid(we || invtlb_valid),
        
        .refill_valid(inst_tlb_refill_valid_reg & inst_tlb_state == `TLB_STATE_REFILL),
        .refill_data(inst_tlb_refill_data_reg),
        .refill_index(inst_tlb_refill_index_reg)
    );

    tcache data_tlb(
        .clk(clk),
        .reset(reset),

        .s_vppn(s1_vppn),
        .s_va_bit12(s1_va_bit12),
        .s_asid(s1_asid),
        .s_result(data_tlb_result),

        .invalid(we || invtlb_valid),
        
        .refill_valid(data_tlb_refill_valid_reg & data_tlb_state == `TLB_STATE_REFILL),
        .refill_data(data_tlb_refill_data_reg),
        .refill_index(data_tlb_refill_index_reg)
    );
    
    tlb_L2 tlb_L2(
        .clk(clk),
        .reset(reset),

        .s0_vppn(s0_vppn_reg),
        .s0_asid(s0_asid_reg),
        .s0_result(l2_entry_0),
        .s0_found(l2_hit_0),
        .s0_index(l2_hit_index_0),

        .s1_vppn(s1_vppn_reg),
        .s1_asid(s1_asid_reg),
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