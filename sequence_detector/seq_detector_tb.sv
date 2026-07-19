module seq_detector_tb;
    logic clk;
    logic rst_n;
    logic x;
    logic z;

    seq_detector uut (.*);

    always #5 clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, seq_detector_tb);
        
        clk = 0; rst_n = 0; x = 0;
        #15 rst_n = 1;
        
        // Sequence: 1 -> 1 -> 0 -> 1
        @(posedge clk); #1 x = 1;
        @(posedge clk); #1 x = 1;
        @(posedge clk); #1 x = 0;
        @(posedge clk); #1 x = 1; 
        
        @(posedge clk); #1;
        if (z) $display("[SUCCESS] 1101 Detected!");

        // Overlap Test
        @(posedge clk); #1 x = 1;
        @(posedge clk); #1 x = 0;
        @(posedge clk); #1 x = 1;
        
        @(posedge clk); #1;
        if (z) $display("[SUCCESS] Overlapping 1101 Detected!");
        
        #20;
        $finish;
    end
endmodule