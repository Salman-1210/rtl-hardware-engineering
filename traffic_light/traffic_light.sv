module traffic_light (
    input  logic clk,
    input  logic rst_n,
    output logic [2:0] lights // [2]=RED, [1]=YELLOW, [0]=GREEN
);

    // State definitions using explicit enumeration
    typedef enum logic [1:0] {
        GREEN  = 2'b00,
        YELLOW = 2'b01,
        RED    = 2'b10
    } state_t;

    state_t current_state, next_state;
    logic [3:0] count; // 4-bit timer counter

    // State Transition & Counter: Sequential Block
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= GREEN;
            count         <= 4'd0;
        end else begin
            current_state <= next_state;
            // Timer logic: Reset counter on state change, else increment
            if (current_state != next_state)
                count <= 4'd0;
            else
                count <= count + 4'd1;
        end
    end

    // Next State Logic: Combinational Block
    always_comb begin
        next_state = current_state;
        case (current_state)
            // GREEN stays for 7 clock cycles (0 to 6), transitions on 7th
            GREEN:  if (count == 4'd6) next_state = YELLOW;
            
            // YELLOW stays for 2 clock cycles (0 to 1), transitions on 2nd
            YELLOW: if (count == 4'd1) next_state = RED;
            
            // RED stays for 5 clock cycles (0 to 4), transitions on 5th
            RED:    if (count == 4'd4) next_state = GREEN;
            
            default: next_state = GREEN;
        endcase
    end

    // Output Logic: Clean Moore Style Mapping
    always_comb begin
        case (current_state)
            GREEN:  lights = 3'b001; // Green HIGH
            YELLOW: lights = 3'b010; // Yellow HIGH
            RED:    lights = 3'b100; // Red HIGH
            default: lights = 3'b001;
        endcase
    end

endmodule