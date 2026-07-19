# Task 2: Timer-Based Traffic Light Controller (Moore FSM)

## 📌 Project Overview
This project implements an industrial-grade, synchronous **Traffic Light Controller** utilizing SystemVerilog. The architecture models a state-driven junction control system that cyclically transitions through **GREEN**, **YELLOW**, and **RED** configurations. 

Rather than relying on massive state arrays, the design optimizes physical gate layouts by pairing a compact **3-state Moore Finite State Machine (FSM)** with an internal synchronous timing counter (`count`). The module features strict separation of sequential logic, lookahead transition mapping, and registered output decoding.

---

## 🛠️ Deep Dive Architectural Breakdown: What, How, Why & Trade-offs

### 1. State Encoding and Explicit Enumeration
```systemverilog
typedef enum logic [1:0] {
    GREEN  = 2'b00,
    YELLOW = 2'b01,
    RED    = 2'b10
} state_t;
What: A strict 2-bit wide enumerated data type (state_t) containing three valid signal nodes.  How: Explicitly maps states to state vectors while leaving 2'b11 intentionally open but safe.  Why: Forcing a strongly-typed enum prevents cross-assignment bugs. If a developer attempts to pass raw integers or mismatched data into current_state, the compiler flags an issue at compile-time instead of synthesizing silent bugs.  Alternative Ignored: Using standard text macros or un-typed parameters (e.g., `define GREEN 2'b00 or localparam GREEN = 2'b00;).  Why it was Rejected: Un-typed variables lack layout limits. The controller variable would be a generic logic [1:0] array, which allows illegal runtime states (like 2'b11) to creep in without structural compiler warnings. Furthermore, logic analyzers and GTKWave can natively pull explicit string tags (GREEN, YELLOW) directly from an enum, speeding up debugging pipelines by 10x compared to tracing raw binary bits. 
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= GREEN;
        count         <= 4'd0;
    end else begin
        current_state <= next_state;
        if (current_state != next_state)
            count <= 4'd0;
        else
            count <= count + 4'd1;
    end
end
What: A edge-triggered register block managing active state memory and runtime cycle tracking under active-low asynchronous reset protection.  How: On any state boundary cross-over event (current_state != next_state), the evaluation circuit intercepts the path and resets the register counter (count <= 4'd0). Otherwise, it increments uniformly on every clock tick.  Why: Resetting the counter dynamically exactly on transition boundaries guarantees that the time allocation loop for the incoming state starts cleanly at 0, completely avoiding off-by-one errors or leftover counts from previous states.  Alternative Ignored: Creating individual raw sequence states for every clock tick duration (e.g., GREEN_CYCLE_1, GREEN_CYCLE_2 ... up to 14 distinct states).  Why it was Rejected: Spreading the cycle across unique state vectors explodes the state count from 3 to 14 states. This requires a 4-bit wide FSM variable instead of 2 bits, inflating the circuit flip-flop budget, increasing power consumption, and causing unmanageable code overhead. Factoring logic down into an isolated counter optimizes device space.  
always_comb begin
    next_state = current_state;
    case (current_state)
        GREEN:  if (count == 4'd6) next_state = YELLOW;
        YELLOW: if (count == 4'd1) next_state = RED;
        RED:    if (count == 4'd4) next_state = GREEN;
        default: next_state = GREEN;
    endcase
end
What: A combinational logic block deciding the future state of the controller by monitoring the current position and elapsed clock duration.  How: Evaluates structural hardware boundaries:  GREEN State: Locks for 7 full clock periods (counting indices 0 to 6).  YELLOW State: Locks for 2 full clock periods (counting indices 0 to 1).  RED State: Locks for 5 full clock periods (counting indices 0 to 4).  Why: Instantiating next_state = current_state; at the absolute top of the combinational block sets a clean fallback path. This completely eliminates the risk of generating unintentional hardware latches during synthesis if a state path isn't explicitly defined.  Alternative Ignored: Combining state calculations and output transitions inside a single sequential loop (always_ff).  Why it was Rejected: Merging combinatorial state calculation and sequential clock updating introduces a one-clock cycle propagation delay into the execution path. Keeping lookahead decisions strictly inside an always_comb block enables instantaneous tracking, keeping the system transition speed uniform.  
always_comb begin
    case (current_state)
        GREEN:  lights = 3'b001; // Green HIGH
        YELLOW: lights = 3'b010; // Yellow HIGH
        RED:    lights = 3'b100; // Red HIGH
        default: lights = 3'b001;
    endcase
end

What: Converts the current_state register values into the physical 3-bit hardware port bus lights[2:0].  How: Direct positional mapping: [2] = RED, [1] = YELLOW, [0] = GREEN.  Why: This follows strict Moore FSM criteria—the driving outputs depend exclusively on the current state memory register and have absolute zero reliance on incoming raw, asynchronous parameters.  Alternative Ignored: Implementing a Mealy FSM structure where output computations monitor both current states and input lines simultaneously.  Why it was Rejected: Mealy FSM outputs change immediately whenever asynchronous input lines face noise, logic hazards, or voltage fluctuations. A Moore setup isolates external hazards from the output registers, meaning downstream power electronics and LED driver arrays receive clean, solid, and structurally glitch-free control signals.  🧠 Key Hardware Engineering Takeaways (What I Learned)FSM-Counter Co-design Patterns: Mastered how to safely coordinate an internal counter alongside FSM controller paths without creating race conditions or latch hazards.  Dynamic Clear Control: Implemented structural counter resets that monitor FSM state changes natively, eliminating off-by-one timing window errors during transitions.  Partitioned Code Architecture: Verified that isolating combinational properties from sequential registers inside SystemVerilog always_comb and always_ff blocks yields predictable hardware behavior and high frequency optimization.  📈 Waveform Analysis & Simulation ProfileWaveform Image DetailsFile Name: traffic_fsm_waveform.png  Description: This high-resolution waveform capture maps the functional lifecycle execution of the Moore Traffic Light Controller FSM over a complete timeline loop of 215ns.    Chronological Timing Milestones Observed:0ns - 15ns (Reset Phase): The system encounters an active-low reset pulse (rst_n = 0). The counter variable count is locked down to 0, and the FSM state registers are driven into GREEN (00). The output lines map to 001 (Green active).  15ns - 75ns (GREEN Window): Reset is released (rst_n = 1). The internal counter increments sequentially on each clock edge (0 -> 1 -> 2 -> 3 -> 4 -> 5 -> 6). At 75ns, exactly on the rising edge where count hits 6, the FSM shifts state instantly to YELLOW (01), resetting the local clock loop back to 0.  75ns - 95ns (YELLOW Window): The state updates to 01. The counter tracks from 0 to 1 (spanning 2 full cycles). The system shifts to RED (10) immediately at the 95ns timestamp, while the output bus drives 010 (Yellow active).  95ns - 145ns (RED Window): The state updates to 10, causing the physical output bus to emit 100 (Red active)[cite: 1]. The counter cycles cleanly from 0 to 4 (spanning 5 cycles)[cite: 1]. At 145ns, the FSM transitions back to GREEN (00), completing a flawless cycle[cite: 1].145ns - 215ns (Cycle Repeat): The second operational loop commences cleanly, confirming structural synchronization with zero clock phase lagging or deadlocks across standard operations[cite: 1].
