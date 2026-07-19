`timescale 1ns/1ps

module vending_machine_tb;

    // Testbench signals
    logic       clk;
    logic       rst_n;
    logic       coin_5;
    logic       coin_10;
    logic       dispense;
    logic [1:0] change;

    // Instantiate Unit Under Test (UUT)
    vending_machine uut (
        .clk(clk),
        .rst_n(rst_n),
        .coin_5(coin_5),
        .coin_10(coin_10),
        .dispense(dispense),
        .change(change)
    );

    // Clock Generation (10ns period)
    always #5 clk = ~clk;

    initial begin
        $dumpfile("vending_dump.vcd");
        $dumpvars(0, vending_machine_tb);

        clk     = 0;
        rst_n   = 0;
        coin_5  = 0;
        coin_10 = 0;

        #15 rst_n = 1;
        #10;

        // TC1: 5 -> 5 -> 5
        coin_5 = 1; #10; coin_5 = 0; #10;
        coin_5 = 1; #10; coin_5 = 0; #10;
        coin_5 = 1; #10; coin_5 = 0; #10;
        #20;

        // TC2: 5 -> 10
        coin_5 = 1;  #10; coin_5 = 0;  #10;
        coin_10 = 1; #10; coin_10 = 0; #10;
        #20;

        // TC3: 10 -> 10
        coin_10 = 1; #10; coin_10 = 0; #10;
        coin_10 = 1; #10; coin_10 = 0; #10;
        #20;

        $display("Simulation Completed Successfully.");
        $finish;
    end

endmodule