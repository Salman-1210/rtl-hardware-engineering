// ====================================================================
// Task 3: Basic Vending Machine Controller (Moore FSM)
// Target Cost: 15 Rupees | Accepted Coins: Rs. 5, Rs. 10
// ====================================================================
module vending_machine (
    input  logic       clk,      // System Clock
    input  logic       rst_n,    // Active-Low Asynchronous Reset
    input  logic       coin_5,   // High when Rs. 5 coin is inserted
    input  logic       coin_10,  // High when Rs. 10 coin is inserted
    output logic       dispense, // High when item is dispensed (Rs. 15 reached)
    output logic [1:0] change    // Remaining change tracker (0, 5, or 10)
);

    // Explicit State Declarations (No Shortcuts, Pure Moore States)
    typedef enum logic [2:0] {
        ST_0  = 3'b000,   // 0 Rupees collected
        ST_5  = 3'b001,   // 5 Rupees collected
        ST_10 = 3'b010,   // 10 Rupees collected
        ST_15 = 3'b011,   // 15 Rupees reached (Dispense, 0 Change)
        ST_20 = 3'b100    // 20 Rupees reached (Dispense, 5 Change)
    } state_t;

    state_t current_state, next_state;

    // 1. Sequential Block: State Transition Registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= ST_0;
        end else begin
            current_state <= next_state;
        end
    end

    // 2. Combinational Block: Next State Lookahead Logic
    always_comb begin
        next_state = current_state;

        case (current_state)
            ST_0: begin
                if (coin_5)       next_state = ST_5;
                else if (coin_10) next_state = ST_10;
                else              next_state = ST_0;
            end

            ST_5: begin
                if (coin_5)       next_state = ST_10;
                else if (coin_10) next_state = ST_15;
                else              next_state = ST_5;
            end

            ST_10: begin
                if (coin_5)       next_state = ST_15;
                else if (coin_10) next_state = ST_20;
                else              next_state = ST_10;
            end

            ST_15: begin
                next_state = ST_0;
            end

            ST_20: begin
                next_state = ST_0;
            end

            default: next_state = ST_0;
        endcase
    end

    // 3. Moore Output Block: Clean, Glitch-Free Registered Mapping
    always_comb begin
        case (current_state)
            ST_0: begin
                dispense = 1'b0;
                change   = 2'b00;
            end
            ST_5: begin
                dispense = 1'b0;
                change   = 2'b00;
            end
            ST_10: begin
                dispense = 1'b0;
                change   = 2'b00;
            end
            ST_15: begin
                dispense = 1'b1;
                change   = 2'b00;
            end
            ST_20: begin
                dispense = 1'b1;
                change   = 2'b01;
            end
            default: begin
                dispense = 1'b0;
                change   = 2'b00;
            end
        endcase
    end

endmodule