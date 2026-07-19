# Task 1: 1101 Overlapping Sequence Detector (Moore FSM)

## 📌 Task Overview
This Task implements a synchronous **1101 Overlapping Sequence Detector** using SystemVerilog. The core implementation relies on a **Moore Finite State Machine (FSM)** architecture to continuously monitor a 1-bit serial input stream (`x`) and assert a high output (`z`) for exactly one clock cycle whenever the target sequence `1101` is recognized. 

Because it is configured for **overlapping detection**, the system retains matching historical sub-sequences. For instance, an input stream of `1101101` will trigger the detection flag twice, treating the terminal `1` of the first pattern as the initial `1` of the second pattern.

---

## 🛠️ Architectural Breakdown: What, How, & Why

### 1. Finite State Machine (FSM) Selection
*   **What:** A 5-state Moore FSM consisting of states `S0` (Reset/Idle), `S1` (`1`), `S2` (`11`), `S3` (`110`), and `S4` (`1101`).
*   **How:** The state transitions are governed by an enumerated type `state_t` spanning `[2:0]` bits. 
*   **Why:** A **Moore machine** was chosen over a Mealy machine because its output depends strictly on the current state rather than the instantaneous input values. This decouples the output signal `z` from combinational glitches on input line `x`, ensuring a clean, fully registered, and clock-synchronized output timing pulse.

### 2. State Encoding & Compilation Safety
*   **What:** Explicit enumerated types (`typedef enum logic [2:0]`) are used for state definitions.
*   **How:** Next-state logic evaluates transitions utilizing standard explicit `if-else` conditionals inside a combinational block.
*   **Why:** Many HDL compilers throw strict type-casting errors if integers or raw bit-vectors are implicitly forced into enumerated state registers. Using clean, explicit conditional assignments guarantees robust linting and cross-compiler toolchain compatibility (such as Icarus Verilog and commercial synthesis tools).

### 3. State Transition Sequence (Overlapping Logic)
*   **What:** Handling the boundary condition when sitting at the final state `S4` (sequence completed).
*   **How:** If the system is in `S4` and receives an input `x = 1`, the next state transitions back to `S2` instead of resetting to `S0` or dropping to `S1`.
*   **Why:** Since `S4` represents that `1101` has been found, receiving another `1` immediately creates an overlapping sequence prefix of `11` (the last `1` of the old pattern + the new `1`). Shifting directly to `S2` preserves the system's efficiency, preventing missed detections in streaming telecommunication and serialization hardware.

---

## 💻 Source Code Implementation

### RTL Design (`seq_detector.sv`)
```systemverilog
module seq_detector (
    input  logic clk,
    input  logic rst_n,
    input  logic x,
    output logic z
);

    typedef enum logic [2:0] {S0, S1, S2, S3, S4} state_t;
    state_t current_state, next_state;

    // State Transition: Sequential Block
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) current_state <= S0;
        else        current_state <= next_state;
    end

    // Next State Logic: Combinational Block
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

    // Output Logic: Clean Moore Style (Independent of Input 'x')
    assign z = (current_state == S4);

endmodule
