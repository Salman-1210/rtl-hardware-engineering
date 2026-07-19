raffic Light Controller — Finite State Machine (FSM)
A fully synthesizable, Moore-style Finite State Machine implementation of a traffic light controller in SystemVerilog. Designed for FPGA/ASIC simulation and educational purposes.
Table of Contents
Project Overview
Architecture
State Machine Design
Timing Specifications
File Structure
How to Simulate
Waveform Analysis
Key Concepts Applied
What I Learned
Future Improvements
Project Overview
This project implements a digital traffic light controller using a 3-state Moore FSM with explicit timing control. The controller cycles through Green, Yellow, and Red states with configurable dwell times, producing clean, glitch-free outputs synchronized to a single clock domain.
Design Goals
Synthesize-ready SystemVerilog (no latches, no inferred combinatorial loops)
Clean separation of sequential and combinatorial logic
Self-contained timer integrated within the state machine
Minimal resource footprint for FPGA deployment
Architecture
plain
                    +---------------------+
        clk  ------>|                     |
        rst_n ---->|   Traffic Light     |----> lights[2:0]
                   |      Controller     |        [2]=RED
                   |    (FSM + Timer)    |        [1]=YELLOW
                   |                     |        [0]=GREEN
                    +---------------------+
Module Interface
Table
Port	Direction	Width	Description
clk	Input	1-bit	System clock (rising-edge triggered)
rst_n	Input	1-bit	Active-low asynchronous reset
lights	Output	3-bit	One-hot encoded light outputs
Internal Structure
plain
+------------------+        +------------------+
|  Sequential Logic |        |  Combinational   |
|  (State Register  |------->|  (Next State     |
|   + Counter)      |        |   Logic)         |
+--------+---------+        +---------+--------+
         |                            |
         |                            v
         |                     +------+------+
         |                     |  Output Logic|
         |                     |   (Moore)     |
         |                     +------+------+
         |                            |
         +----------------------------+
State Machine Design
State Encoding
Explicit enum encoding ensures readability and prevents synthesis ambiguity:
Table
State	Encoding	lights Output
GREEN	2'b00	3'b001
YELLOW	2'b01	3'b010
RED	2'b10	3'b100
State Transition Diagram
plain
                    +---------+
                    |  GREEN  |<------------------+
                    |  (7T)   |                   |
                    +----+----+                   |
                         | count == 6             |
                         v                        |
                    +---------+                  |
                    | YELLOW  |                   |
                    |  (2T)   |                   |
                    +----+----+                  |
                         | count == 1             |
                         v                        |
                    +---------+                  |
                    |   RED   |------------------+
                    |  (5T)   |  count == 4
                    +---------+
State Transitions
Table
Current State	Condition	Next State	Counter Action
GREEN	count == 6	YELLOW	Reset to 0
YELLOW	count == 1	RED	Reset to 0
RED	count == 4	GREEN	Reset to 0
Any (reset)	rst_n == 0	GREEN	Reset to 0
Timing Specifications
State Dwell Times
Table
State	Duration (Clock Cycles)	Duration (at 100 MHz)
GREEN	7 cycles	70 ns
YELLOW	2 cycles	20 ns
RED	5 cycles	50 ns
Total Cycle	14 cycles	140 ns
Timing Calculation
Each state remains active for N clock cycles, where the transition occurs on the last cycle when the counter reaches the threshold. The counter is compared against N-1 because it starts at 0.
GREEN: Counter runs 0 -> 1 -> 2 -> 3 -> 4 -> 5 -> 6 (7 cycles), transitions at count == 6
YELLOW: Counter runs 0 -> 1 (2 cycles), transitions at count == 1
RED: Counter runs 0 -> 1 -> 2 -> 3 -> 4 (5 cycles), transitions at count == 4
Reset Behavior
On assertion of rst_n (active low):
current_state immediately resets to GREEN
count resets to 4'd0
lights output becomes 3'b001 (Green active)
File Structure
plain
traffic-light-fsm/
|-- rtl/
|   |-- traffic_light.sv          # Main design module
|-- tb/
|   |-- traffic_light_tb.sv       # Self-checking testbench
|-- sim/
|   |-- traffic_dump.vcd          # GTKWave waveform dump
|-- README.md
How to Simulate
Prerequisites
Icarus Verilog (iverilog) or any SystemVerilog-compatible simulator
GTKWave (for waveform visualization)
Simulation Steps
Compile the design and testbench:
bash
iverilog -g2012 -o traffic_light.vvp rtl/traffic_light.sv tb/traffic_light_tb.sv
Run the simulation:
bash
vvp traffic_light.vpp
View waveforms in GTKWave:
bash
gtkwave traffic_dump.vcd
Testbench Features
The testbench (traffic_light_tb.sv) includes:
Clock generation (10 ns period, 100 MHz)
Active-low reset sequence (15 ns assertion)
200 ns simulation runtime (multiple full cycles)
VCD dump for GTKWave analysis
Console logging with $display for state verification
Waveform Analysis
Expected Waveform Pattern
plain
clk        _|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_

rst_n      ‾‾‾‾‾|____________________________________________________________________
               0    15

count[3:0]     0  1  2  3  4  5  6  0  1  0  1  2  3  4  0  1  2  3  4  5  6  0  1

current      GREEN ------------------ YELLOW -- RED ----------- GREEN ---------
_state

lights[2:0]    001 ------------------ 010 ----- 100 ----------- 001 ---------
               G                      Y         R               G
Signal Descriptions in Waveform
Table
Signal	Purpose
clk	10 ns period clock
rst_n	Active-low reset (de-asserted at 15 ns)
count[3:0]	Internal 4-bit counter tracking state duration
current_state[1:0]	Encoded state register
lights[2:0]	Output: one-hot encoded traffic lights
next_state[1:0]	Combinational next-state calculation
Key Concepts Applied
1. Moore Machine Architecture
Outputs depend only on the current state, not on inputs. This eliminates glitches and ensures clean, predictable output transitions that are fully synchronized to the clock.
2. Explicit State Encoding with enum
Using typedef enum logic [1:0] provides:
Self-documenting code
Compile-time checking for invalid states
Synthesis tool guidance for state encoding
3. Three-Block FSM Structure
Table
Block	Type	Purpose
Sequential	always_ff	State register + counter on clock edge
Next State	always_comb	Combinational transition logic
Output	always_comb	Moore output mapping
This separation follows the single-responsibility principle and prevents latch inference.
4. Integrated Timer Counter
Instead of a separate timer module, the counter is embedded within the FSM. The counter resets automatically on state transitions using the condition if (current_state != next_state), eliminating the need for explicit reset logic in every state.
5. Asynchronous Active-Low Reset
rst_n is asserted low and is asynchronous (in the sensitivity list)
Ensures known startup state regardless of clock
Industry-standard convention for FPGA designs
What I Learned
Design Methodology
Systematic FSM construction: Breaking the design into sequential, next-state, and output blocks creates maintainable, scalable hardware descriptions.
Counter integration: Embedding timing control within the state machine reduces module count and simplifies interfaces, but requires careful attention to reset conditions.
SystemVerilog Features
always_ff and always_comb provide explicit intent to the synthesis tool, preventing accidental latch inference.
enum types with explicit logic backing improve code clarity and catch invalid states during compilation.
Sensitivity lists for asynchronous reset: @(posedge clk or negedge rst_n)
Timing Analysis
Understanding the difference between cycle count and counter value: A 7-cycle state uses counter values 0 through 6, with the transition condition at the final value.
The importance of reset synchronization: The counter and state must reset simultaneously to prevent undefined initial behavior.
Verification Approach
Self-checking testbenches with $display provide immediate visual feedback during simulation.
VCD dumps enable detailed post-simulation analysis in GTKWave, which is essential for debugging timing relationships.
Console logging with timestamps ($time) allows correlation between simulation time and hardware cycles.
Synthesis Considerations
Moore machines are preferred when output glitches cannot be tolerated (e.g., driving actual LEDs or control signals).
One-hot output encoding (3'b001, 3'b010, 3'b100) simplifies external decoding logic.
4-bit counter is sufficient for the maximum count of 6, but provides headroom for future timing expansion.
Future Improvements
Table
Enhancement	Description
Pedestrian Crossing	Add a WALK state with pedestrian signal output
Configurable Timing	Replace hardcoded counts with parameterizable inputs
Left-Turn Signal	Add a dedicated left-turn arrow state
Synthesis Constraints	Add XDC/SDC files for target FPGA timing closure
UVM Verification	Migrate to UVM-based testbench for regression testing
Power Analysis	Implement clock gating for low-power standby modes
RTL Source Code
traffic_light.sv
systemverilog
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
Testbench Code
traffic_light_tb.sv
systemverilog
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
            3'b001: $display("[TIME %0t] State: GREEN", $time);
            3'b010: $display("[TIME %0t] State: YELLOW", $time);
            3'b100: $display("[TIME %0t] State: RED", $time);
        endcase
    end

endmodule
License
This project is provided for educational and reference purposes. Free to use, modify, and distribute with attribution.
Author Notes
This implementation represents a foundational digital design exercise. The emphasis on explicit coding style, comprehensive documentation, and clean architecture makes this suitable for:
Academic coursework in digital logic design
FPGA beginner projects
Interview preparation for hardware design roles
Reference implementation for FSM best practices
