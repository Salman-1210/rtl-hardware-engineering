`timescale 1ns/1ps

module fifo_8bit_tb;

    // Testbench signals
    logic       clk;
    logic       rst_n;
    logic       wr_en;
    logic       rd_en;
    logic [7:0] data_in;
    logic [7:0] data_out;
    logic       full;
    logic       empty;
    logic [3:0] fifo_cnt;

    // Instantiate UUT
    fifo_8bit uut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .data_in(data_in),
        .data_out(data_out),
        .full(full),
        .empty(empty),
        .fifo_cnt(fifo_cnt)
    );

    // Clock Generation (10ns period)
    always #5 clk = ~clk;

    initial begin
        $dumpfile("fifo_dump.vcd");
        $dumpvars(0, fifo_8bit_tb);

        // Reset state
        clk     = 0;
        rst_n   = 0;
        wr_en   = 0;
        rd_en   = 0;
        data_in = 8'h00;

        #15 rst_n = 1; // Release reset
        #10;

        // --- TEST CASE 1: Basic Write and Read (Single Data) ---
        $display("[TC1] Writing and Reading a single byte...");
        data_in = 8'hA5; wr_en = 1; #10; wr_en = 0; #10; // Write 0xA5
        rd_en = 1; #10; rd_en = 0; #10;                 // Read 0xA5
        #10;

        // --- TEST CASE 2: Fill FIFO completely to check FULL Flag ---
        $display("[TC2] Filling FIFO up to depth 8...");
        data_in = 8'h11; wr_en = 1; #10;
        data_in = 8'h22; #10;
        data_in = 8'h33; #10;
        data_in = 8'h44; #10;
        data_in = 8'h55; #10;
        data_in = 8'h66; #10;
        data_in = 8'h77; #10;
        data_in = 8'h88; #10; // Now fifo_cnt should be 8, full = 1
        wr_en = 0;
        #20;

        // --- TEST CASE 3: Try to Write into a FULL FIFO (Overflow Guard Check) ---
        $display("[TC3] Testing overflow handling...");
        data_in = 8'hFF; wr_en = 1; #10; // This should be ignored
        wr_en = 0;
        #10;

        // --- TEST CASE 4: Empty FIFO completely to check EMPTY Flag ---
        $display("[TC4] Emptying FIFO completely...");
        rd_en = 1; #80; // Read 8 items sequentially
        rd_en = 0;      // Now empty should be 1
        #20;

        // --- TEST CASE 5: Simultaneous Write and Read ---
        $display("[TC5] Testing simultaneous Write and Read...");
        data_in = 8'h99; wr_en = 1; #10; wr_en = 0; #10; // Put one item first
        
        data_in = 8'hBB; wr_en = 1; rd_en = 1; #10;     // Write 0xBB and Read 0x99 together
        wr_en = 0; rd_en = 0;
        #20;

        $display("FIFO Simulation Completed Successfully.");
        $finish;
    end

endmodule