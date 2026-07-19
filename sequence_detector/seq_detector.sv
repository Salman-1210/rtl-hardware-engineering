module seq_detector (
    input  logic clk,
    input  logic rst_n,
    input  logic x,
    output logic z
);

    typedef enum logic [2:0] {S0, S1, S2, S3, S4} state_t;
    state_t current_state, next_state;

    // State Transition
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) current_state <= S0;
        else        current_state <= next_state;
    end

    // Next State Logic using standard if-else to avoid explicit cast error
    always_comb begin
        next_state = current_state;
        case (current_state)
            S0: if (x) next_state = S1; else next_state = S0;
            S1: if (x) next_state = S2; else next_state = S0;
            S2: if (x) next_state = S2; else next_state = S3;
            S3: if (x) next_state = S4; else next_state = S0;
            S4: if (x) next_state = S2; else next_state = S0;
            default: next_state = S0;
        endcase
    end

    // Output Logic (Moore style)
    assign z = (current_state == S4);

endmodule