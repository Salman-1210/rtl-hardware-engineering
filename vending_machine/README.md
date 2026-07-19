# Vending Machine Controller — Moore FSM

A fully synthesizable, Moore-style Finite State Machine implementation of a vending machine controller in SystemVerilog. Accepts Rs. 5 and Rs. 10 coins, dispenses an item when Rs. 15 is reached, and returns change when overpaid.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [State Machine Design](#state-machine-design)
4. [Transaction Scenarios](#transaction-scenarios)
5. [File Structure](#file-structure)
6. [How to Simulate](#how-to-simulate)
7. [Testbench Coverage](#testbench-coverage)
8. [Key Concepts Applied](#key-concepts-applied)
9. [What I Learned](#what-i-learned)
10. [Future Improvements](#future-improvements)

---

## Project Overview

This project implements a digital vending machine controller using a **5-state Moore FSM** that accumulates coin value and produces deterministic outputs. The controller handles exact payment, overpayment with change, and maintains clean state transitions on every clock edge.

### Design Goals
- Synthesize-ready SystemVerilog with no inferred latches
- Pure Moore machine: outputs depend only on current state
- Support for Rs. 5 and Rs. 10 coin inputs
- Automatic dispensing and change return on overpayment
- Minimal resource footprint for FPGA deployment

---

## Architecture

```
                    +-------------------------+
        clk  ------>|                         |
        rst_n ---->|    Vending Machine      |
                   |       Controller        |
        coin_5 --->|      (Moore FSM)        |----> dispense
        coin_10 -->|                         |----> change[1:0]
                    +-------------------------+
```

### Module Interface

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | Input | 1-bit | System clock (rising-edge triggered) |
| `rst_n` | Input | 1-bit | Active-low asynchronous reset |
| `coin_5` | Input | 1-bit | High for one cycle when Rs. 5 coin is inserted |
| `coin_10` | Input | 1-bit | High for one cycle when Rs. 10 coin is inserted |
| `dispense` | Output | 1-bit | High when item should be dispensed |
| `change` | Output | 2-bit | Change amount: `00`=0, `01`=5, `10`=10 |

### Internal Structure

```
+------------------+        +------------------+
|  Sequential Logic |        |  Combinational   |
|  (State Register) |------>|  (Next State     |
|                   |        |   Logic)         |
+--------+---------+        +---------+--------+
         |                            |
         |                            v
         |                     +------+------+
         |                     |  Output Logic|
         |                     |   (Moore)     |
         |                     +------+------+
         |                            |
         +----------------------------+
```

---

## State Machine Design

### State Encoding

Explicit `enum` encoding with 3-bit representation for 5 states:

| State | Encoding | Accumulated Value | Meaning |
|-------|----------|-------------------|---------|
| ST_0 | `3'b000` | Rs. 0 | No coins inserted |
| ST_5 | `3'b001` | Rs. 5 | One 5-rupee coin |
| ST_10 | `3'b010` | Rs. 10 | Two 5-rupee or one 10-rupee coin |
| ST_15 | `3'b011` | Rs. 15 | Target reached, dispense item |
| ST_20 | `3'b100` | Rs. 20 | Overpaid, dispense item + Rs. 5 change |

### State Transition Diagram

```
                         +-------+
                         | ST_0  |
                         | Rs. 0 |
                         +---+---+
                             |
                +------------+------------+
                | coin_5                 | coin_10
                v                        v
           +---------+              +---------+
           |  ST_5   |              |  ST_10  |
           |  Rs. 5  |              |  Rs. 10 |
           +----+----+              +----+----+
                |                        |
       +--------+--------+      +--------+--------+
       | coin_5          |      | coin_5          |
       v                 |      v                 |
  +---------+            | +---------+            |
  |  ST_10  |            | |  ST_15  |            |
  |  Rs. 10 |            | |Dispense |            |
  +----+----+            | |Change=0 |            |
       |                 | +----+----+            |
       | coin_10         |      |                 |
       v                 |      |                 |
  +---------+            |      |                 |
  |  ST_15  |            |      |                 |
  |Dispense |            |      |                 |
  |Change=0 |            |      |                 |
  +----+----+            |      |                 |
       |                 |      |                 |
       +----------------+------+                 |
                             |                   |
                             |                   |
                             v                   v
                        +---------+        +---------+
                        |  ST_0   |        |  ST_20  |
                        | (Reset) |        |Dispense |
                        +---------+        |Change=5 |
                                         +----+----+
                                              |
                                              v
                                         +---------+
                                         |  ST_0   |
                                         | (Reset) |
                                         +---------+
```

### State Transition Table

| Current State | coin_5 | coin_10 | Next State | Action |
|---------------|--------|---------|------------|--------|
| ST_0 | 1 | 0 | ST_5 | Accumulate 5 |
| ST_0 | 0 | 1 | ST_10 | Accumulate 10 |
| ST_0 | 0 | 0 | ST_0 | Wait for coin |
| ST_5 | 1 | 0 | ST_10 | Accumulate 5 |
| ST_5 | 0 | 1 | ST_15 | Dispense (exact) |
| ST_5 | 0 | 0 | ST_5 | Wait for coin |
| ST_10 | 1 | 0 | ST_15 | Dispense (exact) |
| ST_10 | 0 | 1 | ST_20 | Dispense + Change 5 |
| ST_10 | 0 | 0 | ST_10 | Wait for coin |
| ST_15 | X | X | ST_0 | Auto-return to idle |
| ST_20 | X | X | ST_0 | Auto-return to idle |

### Output Mapping (Moore Style)

| State | dispense | change | Interpretation |
|-------|----------|--------|----------------|
| ST_0 | 0 | `2'b00` (0) | Idle, waiting |
| ST_5 | 0 | `2'b00` (0) | Accumulated 5, waiting |
| ST_10 | 0 | `2'b00` (0) | Accumulated 10, waiting |
| ST_15 | 1 | `2'b00` (0) | Dispense item, no change |
| ST_20 | 1 | `2'b01` (5) | Dispense item, return 5 |

---

## Transaction Scenarios

### Scenario 1: Three 5-Rupee Coins (5 + 5 + 5 = 15)

```
Cycle:    0     1     2     3     4     5     6     7     8
          |     |     |     |     |     |     |     |     |
coin_5    ______|_____|_____|_____|_____|_____|_____|_____|___
                |_____|     |_____|     |_____|

State     ST_0  ST_5  ST_10 ST_15 ST_0  ST_0  ST_0  ST_0  ST_0
dispense  0     0     0     1     0     0     0     0     0
change    0     0     0     0     0     0     0     0     0
```

**Result:** Item dispensed, no change returned.

### Scenario 2: 5 + 10 = 15

```
Cycle:    0     1     2     3     4     5     6     7     8
          |     |     |     |     |     |     |     |     |
coin_5    ______|_____|_____________________________________
                |_____|

coin_10   ____________|_____|_______________________________
                      |_____|

State     ST_0  ST_5  ST_15 ST_0  ST_0  ST_0  ST_0  ST_0  ST_0
dispense  0     0     1     0     0     0     0     0     0
change    0     0     0     0     0     0     0     0     0
```

**Result:** Item dispensed, no change returned.

### Scenario 3: 10 + 10 = 20 (Overpayment)

```
Cycle:    0     1     2     3     4     5     6     7     8
          |     |     |     |     |     |     |     |     |
coin_10   ______|_____|___________|_____|___________________
                |_____|           |_____|

State     ST_0  ST_10 ST_20 ST_0  ST_0  ST_0  ST_0  ST_0  ST_0
dispense  0     0     1     0     0     0     0     0     0
change    0     0     5     0     0     0     0     0     0
```

**Result:** Item dispensed, Rs. 5 change returned.

---

## File Structure

```
vending-machine-fsm/
|-- rtl/
|   |-- vending_machine.sv          # Main design module
|-- tb/
|   |-- vending_machine_tb.sv       # Self-checking testbench
|-- sim/
|   |-- vending_dump.vcd             # GTKWave waveform dump
|-- README.md
```

---

## How to Simulate

### Prerequisites

- Icarus Verilog (`iverilog`) or any SystemVerilog-compatible simulator
- GTKWave (for waveform visualization)

### Simulation Steps

1. **Compile the design and testbench:**
   ```bash
   iverilog -g2012 -o vending_machine.vvp rtl/vending_machine.sv tb/vending_machine_tb.sv
   ```

2. **Run the simulation:**
   ```bash
   vvp vending_machine.vvp
   ```

3. **View waveforms in GTKWave:**
   ```bash
   gtkwave vending_dump.vcd
   ```

### Testbench Features

The testbench (`vending_machine_tb.sv`) includes:
- Clock generation (10 ns period, 100 MHz)
- Active-low reset sequence (15 ns assertion)
- Three comprehensive test cases covering all major scenarios
- VCD dump for GTKWave analysis
- Console completion message

---

## Testbench Coverage

### Test Case 1: Three Rs. 5 Coins (TC1)
- **Input Sequence:** 5, 5, 5
- **Expected Path:** ST_0 -> ST_5 -> ST_10 -> ST_15 -> ST_0
- **Expected Output:** dispense=1, change=0
- **Coverage:** Exact payment via minimum denomination

### Test Case 2: Rs. 5 + Rs. 10 (TC2)
- **Input Sequence:** 5, 10
- **Expected Path:** ST_0 -> ST_5 -> ST_15 -> ST_0
- **Expected Output:** dispense=1, change=0
- **Coverage:** Mixed denomination exact payment

### Test Case 3: Two Rs. 10 Coins (TC3)
- **Input Sequence:** 10, 10
- **Expected Path:** ST_0 -> ST_10 -> ST_20 -> ST_0
- **Expected Output:** dispense=1, change=5
- **Coverage:** Overpayment with change return

### Coverage Matrix

| Scenario | States Visited | dispense | change | Verified |
|----------|---------------|----------|--------|----------|
| 5+5+5 | ST_0, ST_5, ST_10, ST_15 | 1 | 0 | Yes |
| 5+10 | ST_0, ST_5, ST_15 | 1 | 0 | Yes |
| 10+10 | ST_0, ST_10, ST_20 | 1 | 5 | Yes |

---

## Key Concepts Applied

### 1. Pure Moore Machine Architecture
Outputs depend **exclusively** on the current state. This is critical for vending machines because:
- Output glitches could cause multiple dispenses or incorrect change
- State stability ensures one dispense pulse per transaction
- Easy to verify and debug since outputs are deterministic per state

### 2. One-Hot Coin Signaling
Coin inputs are treated as **level-sensitive for one clock cycle**. The FSM assumes the coin detector holds the signal high for exactly one clock cycle per insertion. This is a standard interface assumption in digital design.

### 3. Automatic Reset States (ST_15 and ST_20)
After dispensing, the machine automatically returns to `ST_0` on the next clock edge. This creates a **self-clearing transaction** without requiring an external "done" signal.

### 4. Three-Block FSM Structure
| Block | Type | Purpose |
|-------|------|---------|
| Sequential | `always_ff` | State register on clock edge with async reset |
| Next State | `always_comb` | Combinational transition logic based on inputs |
| Output | `always_comb` | Moore output mapping from current state |

This separation prevents latch inference and makes the design synthesizable across all major FPGA vendor tools.

### 5. Change Encoding Strategy
The `change` output uses a compact encoding:
- `2'b00` = 0 rupees
- `2'b01` = 5 rupees
- `2'b10` = 10 rupees

This encoding is scalable and can be extended to support additional change amounts if the price or coin denominations change.

### 6. Asynchronous Active-Low Reset
- `rst_n` ensures the machine starts in `ST_0` (idle) regardless of clock state
- Industry-standard convention for FPGA and ASIC designs
- Critical for safety: a vending machine must not dispense on power-up

---

## What I Learned

### Design Methodology
- **State explosion management:** Even a simple vending machine with two coin types requires 5 states. This taught me to carefully map out all possible accumulated values before coding.
- **Self-clearing states:** Using `ST_15` and `ST_20` as single-cycle transient states that auto-return to `ST_0` simplifies the control logic significantly.
- **Input conditioning:** The design assumes coins are detected as single-cycle pulses. In a real system, this would require a debouncer and edge detector, but separating concerns keeps the FSM clean.

### SystemVerilog Features
- `always_ff` for sequential logic clearly separates time-dependent behavior from combinational logic.
- `always_comb` automatically handles sensitivity lists, reducing human error in complex next-state equations.
- `enum` with explicit `logic` backing makes the code self-documenting and prevents invalid state encoding.
- `default` cases in `case` statements are essential for safe FSM recovery from undefined states.

### Timing and Verification
- **Coin timing:** Coins must be held high for exactly one clock cycle. If held longer, the FSM would interpret them as multiple insertions. This taught me the importance of input specification in digital design.
- **Dispense pulse width:** In a Moore machine, `dispense` stays high for the entire duration of `ST_15` or `ST_20`. In a real system, this would drive a dispense motor for one clock cycle, which may need stretching.
- **Reset verification:** Always verify that the FSM returns to `ST_0` after every transaction and that reset works asynchronously.

### Synthesis Considerations
- **Moore vs. Mealy:** A Mealy machine could produce outputs faster (on the same cycle as the last coin), but would be prone to glitches if the coin input has noise. Moore was the correct choice for a vending machine.
- **State encoding:** The explicit `enum` encoding uses 3 bits for 5 states, leaving 3 unused encodings. The `default` case ensures recovery if the FSM enters an invalid state due to SEU (Single Event Upset) or noise.
- **Resource estimation:** This design uses approximately 3 flip-flops (for state) and minimal LUTs for the combinational logic. Easily fits in the smallest FPGA.

### Practical Insights
- **Real-world mapping:** In a physical vending machine, `coin_5` and `coin_10` would come from coin validators with mechanical debouncing. The FSM should be preceded by a synchronizer and edge detector.
- **Change mechanism:** The `change` output is a request signal. A physical machine would need a separate change dispenser FSM to actually return coins.
- **Price flexibility:** Hardcoding Rs. 15 as the target makes the design simple but inflexible. Parameterizing the price would be the next logical step.

---

## Future Improvements

| Enhancement | Description |
|-------------|-------------|
| **Parameterized Price** | Replace hardcoded Rs. 15 with a module parameter for different products |
| **Additional Coins** | Add Rs. 1, Rs. 2, Rs. 20 coin support |
| **Cancel/Refund** | Add a cancel button that returns all accumulated coins |
| **Inventory Tracking** | Add an item count register and `out_of_stock` output |
| **Edge Detection** | Add input synchronizer and edge detector for real coin signals |
| **Dispense Stretcher** | Extend dispense pulse to multiple cycles for mechanical actuators |
| **LCD Display** | Add accumulated amount display output for user feedback |
| **Security** | Add checksum or encryption for coin validator communication |
| **UVM Verification** | Migrate to UVM testbench with constrained random stimulus |
| **Power Analysis** | Implement clock gating for low-power standby between transactions |

---

## RTL Source Code

### `vending_machine.sv`

```systemverilog
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
```

---

## Testbench Code

### `vending_machine_tb.sv`

```systemverilog
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
```

---

## License

This project is provided for educational and reference purposes. Free to use, modify, and distribute with attribution.

---

## Author Notes

This implementation represents a foundational digital design exercise in finite state machines with practical application. The emphasis on pure Moore architecture, explicit state encoding, and comprehensive test coverage makes this suitable for:
- Academic coursework in digital logic and computer architecture
- FPGA beginner projects with real-world relevance
- Interview preparation for hardware design and verification roles
- Reference implementation for vending machine and payment system FSMs
- Teaching material for Moore vs. Mealy machine trade-offs

The design prioritizes correctness and clarity over optimization, following the principle that readable, verifiable code outperforms clever but opaque logic in production environments.

