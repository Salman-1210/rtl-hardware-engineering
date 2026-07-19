`timescale 1ns/1ps

module apb_slave_ram_tb;

    // Testbench signals
    logic        pclk;
    logic        presetn;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [3:0]  paddr;
    logic [32:0] pwdata;
    logic [32:0] prdata;
    logic        pready;

    // Instantiate UUT
    apb_slave_ram uut (
        .pclk(pclk),
        .presetn(presetn),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready)
    );

    // Clock Generation (10ns period)
    always #5 pclk = ~pclk;

    initial begin
        $dumpfile("apb_dump.vcd");
        $dumpvars(0, apb_slave_ram_tb);

        // Initial Idle State
        pclk    = 0;
        presetn = 0;
        psel    = 0;
        penable = 0;
        pwrite  = 0;
        paddr   = 4'h0;
        pwdata  = 32'h0;

        #15 presetn = 1; // Release Reset
        #10;

        // --- TEST CASE 1: Basic APB Write Sequence ---
        // Setup Phase: Select target address and data
        psel = 1; pwrite = 1; paddr = 4'h4; pwdata = 32'hDEADBEEF; #10;
        // Access Phase: Set enable high to lock data into RAM
        penable = 1; #10;
        // End Transfer
        psel = 0; penable = 0; pwrite = 0; #10;

        // --- TEST CASE 2: Basic APB Read Sequence ---
        // Setup Phase: Request same address for checking
        psel = 1; pwrite = 0; paddr = 4'h4; #10;
        // Access Phase: Read values out
        penable = 1; #10;
        // End Transfer
        psel = 0; penable = 0; #20;

        $display("APB Slave RAM Simulation Completed Successfully.");
        $finish;
    end

endmodule