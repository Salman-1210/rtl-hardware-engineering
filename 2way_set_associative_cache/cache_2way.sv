`timescale 1ns/1ps

module cache_2way (
    input  logic       clk,
    input  logic       reset,
    input  logic [3:0] address,
    input  logic [7:0] write_data,
    input  logic       write_enable,
    output logic [7:0] read_data,
    output logic       hit
);

    //========================================================
    // 1. MEMORY STORAGE DECLARATION (SystemVerilog logic)
    //========================================================
    logic       valid [0:3][0:1];  // 4 sets, 2 ways per set
    logic [1:0] tag   [0:3][0:1];  // Tag bit storage (2 bits)
    logic [7:0] data  [0:3][0:1];  // Data memory (8 bits)
    logic       lru   [0:3];       // LRU bit: 0 -> Way0, 1 -> Way1

    //========================================================
    // 2. ADDRESS BREAKDOWN
    //========================================================
    logic [1:0] index;
    logic [1:0] addr_tag;

    assign index    = address[1:0];
    assign addr_tag = address[3:2];

    //========================================================
    // 3. COMBINATIONAL LOOKUP & HIT LOGIC
    //========================================================
    logic way0_hit;
    logic way1_hit;

    assign way0_hit = valid[index][0] && (tag[index][0] == addr_tag);
    assign way1_hit = valid[index][1] && (tag[index][1] == addr_tag);

    // SystemVerilog explicit combinational block
    always_comb begin
        if (way0_hit) begin
            hit       = 1'b1;
            read_data = data[index][0];
        end 
        else if (way1_hit) begin
            hit       = 1'b1;
            read_data = data[index][1];
        end 
        else begin
            hit       = 1'b0;
            read_data = 8'h00; // Default output on miss
        end
    end

    //========================================================
    // 4. SEQUENTIAL STATE UPDATE (Flip-Flops & LRU)
    //========================================================
    // SystemVerilog explicit flip-flop block
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            // Clean SystemVerilog loop for reset initialization
            for (int i = 0; i < 4; i++) begin
                valid[i][0] <= 1'b0; valid[i][1] <= 1'b0;
                tag[i][0]   <= 2'b0; tag[i][1]   <= 2'b0;
                data[i][0]  <= 8'b0; data[i][1]  <= 8'b0;
                lru[i]      <= 1'b0;
            end
        end 
        else begin
            // --- READ OPERATION ---
            if (!write_enable) begin
                if (way0_hit) begin
                    lru[index] <= 1'b1; // Way0 accessed, next LRU is Way1
                end 
                else if (way1_hit) begin
                    lru[index] <= 1'b0; // Way1 accessed, next LRU is Way0
                end
            end 
            // --- WRITE OPERATION ---
            else begin
                if (way0_hit) begin
                    data[index][0] <= write_data;
                    lru[index]     <= 1'b1;
                end 
                else if (way1_hit) begin
                    data[index][1] <= write_data;
                    lru[index]     <= 1'b0;
                end 
                else begin
                    // Write Miss: Dynamic Replacement based on LRU
                    if (lru[index] == 1'b0) begin
                        valid[index][0] <= 1'b1;
                        tag[index][0]   <= addr_tag;
                        data[index][0]  <= write_data;
                        lru[index]      <= 1'b1;
                    end 
                    else begin
                        valid[index][1] <= 1'b1;
                        tag[index][1]   <= addr_tag;
                        data[index][1]  <= write_data;
                        lru[index]      <= 1'b0;
                    end
                end
            end
        end
    end

endmodule