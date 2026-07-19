// ====================================================================
// Task 4: Simple 8-bit FIFO Buffer (Depth = 8)
// Beginner-Friendly Logic | No Complex Pointer Shortcuts
// ====================================================================
module fifo_8bit (
    input  logic       clk,      // System Clock
    input  logic       rst_n,    // Active-Low Asynchronous Reset
    input  logic       wr_en,    // Write Enable
    input  logic       rd_en,    // Read Enable
    input  logic [7:0] data_in,  // 8-bit Input Data
    output logic [7:0] data_out, // 8-bit Output Data
    output logic       full,     // High when FIFO is full
    output logic       empty,    // High when FIFO is empty
    output logic [3:0] fifo_cnt  // Tracks number of elements (0 to 8)
);

    // Memory Array: 8 registers, each 8-bits wide
    logic [7:0] memory [0:7];

    // Pointers to track positions (0 to 7)
    logic [2:0] wr_ptr;
    logic [2:0] rd_ptr;

    // 1. Combinational Flag Logic
    always_comb begin
        empty = (fifo_cnt == 4'd0);
        full  = (fifo_cnt == 4'd8);
    end

    // 2. Sequential Logic: Registers, Pointers, and Counter Management
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr   <= 3'b000;
            rd_ptr   <= 3'b000;
            fifo_cnt <= 4'd0;
            data_out <= 8'h00;
        end else begin
            
            // WRITE OPERATION (If enabled and not full)
            if (wr_en && !full) begin
                memory[wr_ptr] <= data_in;
                wr_ptr         <= wr_ptr + 3'b001; // Automatically wraps at 7 -> 0
            end

            // READ OPERATION (If enabled and not empty)
            if (rd_en && !empty) begin
                data_out <= memory[rd_ptr];
                rd_ptr   <= rd_ptr + 3'b001;  // Automatically wraps at 7 -> 0
            end

            // COUNTER TRACKING LOOPS (No Shortcuts)
            if ((wr_en && !full) && !(rd_en && !empty)) begin
                fifo_cnt <= fifo_cnt + 4'd1; // Only Write happened
            end 
            else if ((rd_en && !empty) && !(wr_en && !full)) begin
                fifo_cnt <= fifo_cnt - 4'd1; // Only Read happened
            end
            // If both happen at the same time, fifo_cnt stays the same.
        end
    end

endmodule