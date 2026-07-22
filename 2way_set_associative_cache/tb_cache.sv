`timescale 1ns/1ps

module tb;
    logic       clk;
    logic       reset;
    logic [3:0] address;
    logic [7:0] write_data;
    logic       write_enable;

    logic [7:0] read_data;
    logic       hit;

    cache_2way DUT (
        .clk          (clk),
        .reset        (reset),
        .address      (address),
        .write_data   (write_data),
        .write_enable (write_enable),
        .read_data    (read_data),
        .hit          (hit)
    );
    always #5 clk = ~clk;

    // Waveform Dump
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb);
    end

    // Output Terminal Monitor
    initial begin
        $monitor("TIME=%0t | RESET=%b | WE=%b | ADDR=%b | WDATA=%h | RDATA=%h | HIT=%b", 
                 $time, reset, write_enable, address, write_data, read_data, hit);
    end

    // Test Sequence Execution
    initial begin
        // Reset Setup
        clk = 0; reset = 1;
        address = 4'b0000; write_data = 8'h00; write_enable = 0;
        #12 reset = 0; #8;

        // TEST 1: Write AA to Address 0000
        $display("\n---> TEST-1: WRITE 8'hAA to Address 4'b0000");
        address = 4'b0000; write_data = 8'hAA; write_enable = 1;
        #10;

        // TEST 2: Read Address 0000 (HIT Way0)
        $display("\n---> TEST-2: READ Address 4'b0000");
        write_enable = 0;
        #10;

        // TEST 3: Write BB to Address 0100 (HIT/Placed Way1)
        $display("\n---> TEST-3: WRITE 8'hBB to Address 4'b0100 (Same Index)");
        address = 4'b0100; write_data = 8'hBB; write_enable = 1;
        #10;

        // TEST 4: Read Address 0100 (HIT Way1)
        $display("\n---> TEST-4: READ Address 4'b0100");
        write_enable = 0;
        #10;

        // TEST 5: Write CC to Address 1000 (Eviction Test)
        $display("\n---> TEST-5: WRITE 8'hCC to Address 4'b1000 (Eviction Test)");
        address = 4'b1000; write_data = 8'hCC; write_enable = 1;
        #10;

        // TEST 6: Read Address 0000 (Expect MISS)
        $display("\n---> TEST-6: READ Address 4'b0000 (Expect MISS)");
        address = 4'b0000; write_enable = 0;
        #10;

        // TEST 7: Read Address 0100 (Expect HIT)
        $display("\n---> TEST-7: READ Address 4'b0100 (Expect HIT)");
        address = 4'b0100;
        #10;

        // TEST 8: Read Address 1000 (Expect HIT)
        $display("\n---> TEST-8: READ Address 4'b1000 (Expect HIT)");
        address = 4'b1000;
        #10;

        $display("\nSIMULATION COMPLETE!");
        $finish;
    end

endmodule