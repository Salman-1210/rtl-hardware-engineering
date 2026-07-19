module traffic_light_tb;
    logic clk;
    logic rst_n;
    logic [2:0] lights;

    // Instantiate Unit Under Test (UUT)
    traffic_light uut (.*);

    // Generate Clock (10ns period)
    always #5 clk = ~clk;

    initial begin
        $dumpfile("traffic_dump.vcd");
        $dumpvars(0, traffic_light_tb);

        // Initial Reset Sequence
        clk = 0; rst_n = 0;
        #15 rst_n = 1;

        // Run simulation long enough to see multiple full cycles
        #200;

        $finish;
    end

    // Console logging for verification tracking
    always @(lights) begin
        case (lights)
            3'b001: $display("[TIME %0dt] State: GREEN", $time);
            3'b010: $display("[TIME %0dt] State: YELLOW", $time);
            3'b100: $display("[TIME %0dt] State: RED", $time);
        endcase
    end

endmodule