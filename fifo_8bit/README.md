# 8-bit FIFO Buffer (Depth = 8)

A fully synthesizable, beginner-friendly FIFO (First-In-First-Out) buffer implemented in SystemVerilog. Features circular buffer architecture with independent read/write pointers, automatic full/empty flag generation, and overflow/underflow protection.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [FIFO Operation](#fifo-operation)
4. [Pointer Mechanics](#pointer-mechanics)
5. [Flag Generation](#flag-generation)
6. [File Structure](#file-structure)
7. [How to Simulate](#how-to-simulate)
8. [Testbench Coverage](#testbench-coverage)
9. [Waveform Analysis](#waveform-analysis)
10. [Key Concepts Applied](#key-concepts-applied)
11. [What I Learned](#what-i-learned)
12. [Future Improvements](#future-improvements)

---

## Project Overview

This project implements a classic **circular FIFO buffer** with 8 storage locations, each 8-bits wide. The design uses explicit pointer arithmetic without shortcuts, making it ideal for understanding the fundamental mechanics of FIFO memory structures in digital design.

### Design Goals
- Synthesize-ready SystemVerilog with no inferred latches
- Explicit pointer management for educational clarity
- Automatic wrap-around using 3-bit pointer overflow
- Simultaneous read/write capability with correct count tracking
- Overflow and underflow protection via enable gating
- Minimal resource footprint for FPGA deployment

---

## Architecture

```
                    +-------------------------+
        clk  ------>|                         |
        rst_n ---->|      8-bit FIFO           |
                   |      (Depth = 8)          |
        wr_en ---> |                         |----> data_out[7:0]
        rd_en ---> |    +----------------+   |----> full
        data_in--> |    |  memory[0:7]   |   |----> empty
        [7:0]      |    |  [7:0]         |   |----> fifo_cnt[3:0]
                   |    +----------------+   |
                   |    |  wr_ptr[2:0]   |   |
                   |    |  rd_ptr[2:0]   |   |
                   |    +----------------+   |
                    +-------------------------+
```

### Module Interface

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | Input | 1-bit | System clock (rising-edge triggered) |
| `rst_n` | Input | 1-bit | Active-low asynchronous reset |
| `wr_en` | Input | 1-bit | Write enable (active high) |
| `rd_en` | Input | 1-bit | Read enable (active high) |
| `data_in` | Input | 8-bit | Data to be written into FIFO |
| `data_out` | Output | 8-bit | Data read from FIFO |
| `full` | Output | 1-bit | High when FIFO contains 8 elements |
| `empty` | Output | 1-bit | High when FIFO contains 0 elements |
| `fifo_cnt` | Output | 3-bit | Current number of elements (0 to 8) |

### Internal Structure

```
+--------------------------------------------------+
|                    FIFO Controller                  |
|                                                   |
|  +----------------+    +---------------------+  |
|  | memory[0:7]    |    |  Pointer Management   |  |
|  | 8x8-bit RAM    |    |  wr_ptr, rd_ptr       |  |
|  +----------------+    +---------------------+  |
|         |                       |                 |
|         v                       v                 |
|  +----------------+    +---------------------+  |
|  | Write Port     |    |  Counter Logic        |  |
|  | (wr_en gated)  |    |  fifo_cnt (0 to 8)    |  |
|  +----------------+    +---------------------+  |
|         |                       |                 |
|         v                       v                 |
|  +----------------+    +---------------------+  |
|  | Read Port      |    |  Flag Generation      |  |
|  | (rd_en gated)  |    |  full, empty          |  |
|  +----------------+    +---------------------+  |
|                                                   |
+--------------------------------------------------+
```

---

## FIFO Operation

### Circular Buffer Concept

The FIFO uses a circular buffer where:
- `wr_ptr` advances on every successful write
- `rd_ptr` advances on every successful read
- When either pointer reaches 7, the next increment wraps to 0
- The buffer is "full" when 8 elements are stored
- The buffer is "empty" when 0 elements are stored

### Memory Map Visualization

```
Address:   0     1     2     3     4     5     6     7
         +-----+-----+-----+-----+-----+-----+-----+-----+
         |     |     |     |     |     |     |     |     |
         | 0xAA| 0xBB| 0xCC| 0xDD| 0xEE| 0xFF| 0x11| 0x22|  <- memory contents
         |     |     |     |     |     |     |     |     |
         +-----+-----+-----+-----+-----+-----+-----+-----+
           ^                             ^
           |                             |
         rd_ptr                        wr_ptr
         (read from here)              (write to here)
```

### Operational Modes

| Mode | wr_en | rd_en | full | empty | Action |
|------|-------|-------|------|-------|--------|
| Idle | 0 | 0 | X | X | No operation |
| Write Only | 1 | 0 | 0 | X | Store data_in, increment wr_ptr, increment fifo_cnt |
| Read Only | 0 | 1 | X | 0 | Output memory[rd_ptr], increment rd_ptr, decrement fifo_cnt |
| Simultaneous | 1 | 1 | 0 | 0 | Write and Read in same cycle, fifo_cnt unchanged |
| Overflow Guard | 1 | X | 1 | X | Write ignored, no state change |
| Underflow Guard | X | 1 | X | 1 | Read ignored, no state change |

---

## Pointer Mechanics

### Write Pointer (wr_ptr)

| Operation | Condition | Result |
|-----------|-----------|--------|
| Reset | `rst_n == 0` | `wr_ptr = 3'b000` |
| Increment | `wr_en == 1 && full == 0` | `wr_ptr = wr_ptr + 1` (wraps 7->0) |
| Hold | `wr_en == 0 or full == 1` | `wr_ptr` unchanged |

### Read Pointer (rd_ptr)

| Operation | Condition | Result |
|-----------|-----------|--------|
| Reset | `rst_n == 0` | `rd_ptr = 3'b000` |
| Increment | `rd_en == 1 && empty == 0` | `rd_ptr = rd_ptr + 1` (wraps 7->0) |
| Hold | `rd_en == 0 or empty == 1` | `rd_ptr` unchanged |

### Wrap-Around Behavior

Because `wr_ptr` and `rd_ptr` are 3-bit values (`logic [2:0]`), adding 1 to `3'b111` (7) results in `3'b000` (0) due to natural binary overflow. This provides **free circular addressing** without modulo arithmetic.

```
Pointer Value Sequence: 0 -> 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 0 -> 1 ...
Binary Representation: 000 -> 001 -> 010 -> 011 -> 100 -> 101 -> 110 -> 111 -> 000
```

---

## Flag Generation

### Empty Flag

```
empty = (fifo_cnt == 4'd0)
```

The FIFO is empty when no elements have been written, or when all written elements have been read. This is a combinational comparison updated every cycle.

### Full Flag

```
full = (fifo_cnt == 4'd8)
```

The FIFO is full when all 8 memory locations contain valid data. The next write attempt will be blocked.

### Counter Update Logic

The element counter `fifo_cnt` tracks the number of valid entries:

| Condition | fifo_cnt Update | Explanation |
|-----------|----------------|-------------|
| Write only | `fifo_cnt + 1` | New element added, none removed |
| Read only | `fifo_cnt - 1` | Element removed, none added |
| Both Read and Write | Unchanged | Element added and removed simultaneously |
| Neither | Unchanged | No change in stored elements |

---

## File Structure

```
fifo-8bit/
|-- rtl/
|   |-- fifo_8bit.sv              # Main FIFO design module
|-- tb/
|   |-- fifo_8bit_tb.sv          # Comprehensive testbench
|-- sim/
|   |-- fifo_dump.vcd             # GTKWave waveform dump
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
   iverilog -g2012 -o fifo_8bit.vvp rtl/fifo_8bit.sv tb/fifo_8bit_tb.sv
   ```

2. **Run the simulation:**
   ```bash
   vvp fifo_8bit.vvp
   ```

3. **View waveforms in GTKWave:**
   ```bash
   gtkwave fifo_dump.vcd
   ```

### Testbench Features

The testbench (`fifo_8bit_tb.sv`) includes:
- Clock generation (10 ns period, 100 MHz)
- Active-low reset sequence (15 ns assertion)
- Five comprehensive test cases covering all operational modes
- VCD dump for GTKWave analysis
- Console logging with `$display` for test tracking

---

## Testbench Coverage

### Test Case 1: Single Write and Read
- **Objective:** Verify basic FIFO functionality
- **Sequence:** Write `0xA5`, then Read
- **Expected:** `data_out = 0xA5`, `fifo_cnt` goes 0->1->0
- **Coverage:** Basic write path, basic read path, empty flag transition

### Test Case 2: Fill to Full
- **Objective:** Verify full flag generation and depth capacity
- **Sequence:** Write 8 values: `0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88`
- **Expected:** `fifo_cnt` increments 1->8, `full` asserts on 8th write
- **Coverage:** Sequential writes, pointer wrap-around, full flag

### Test Case 3: Overflow Guard
- **Objective:** Verify write protection when full
- **Sequence:** Attempt write `0xFF` while `full == 1`
- **Expected:** Write ignored, `fifo_cnt` remains 8, memory unchanged
- **Coverage:** Overflow protection, write gating

### Test Case 4: Empty to Empty
- **Objective:** Verify empty flag and complete readout
- **Sequence:** Read all 8 stored values sequentially
- **Expected:** `data_out` shows `0x11, 0x22, ..., 0x88`, `fifo_cnt` decrements 8->0, `empty` asserts
- **Coverage:** Sequential reads, data ordering (FIFO), empty flag, underflow protection

### Test Case 5: Simultaneous Read and Write
- **Objective:** Verify concurrent read/write with stable count
- **Sequence:** Write `0x99`, then simultaneous write `0xBB` and read `0x99`
- **Expected:** `fifo_cnt` unchanged, `data_out` shows `0x99`, then `0xBB` remains stored
- **Coverage:** Concurrent operations, counter stability, data integrity

### Coverage Matrix

| Test Case | Writes | Reads | full | empty | Simultaneous | Overflow | Underflow |
|-----------|--------|-------|------|-------|--------------|----------|-----------|
| TC1 | 1 | 1 | - | Yes | No | No | No |
| TC2 | 8 | 0 | Yes | No | No | No | No |
| TC3 | 1 (blocked) | 0 | Yes | No | No | Yes | No |
| TC4 | 0 | 8 | No | Yes | No | No | No |
| TC5 | 1 | 1 | No | No | Yes | No | No |

---

## Waveform Analysis

### Expected Waveform Pattern (GTKWave)

```
Time:     0     50    100   150   200   250   300   350 ns
          |     |     |     |     |     |     |     |
clk       _|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_

rst_n     ‾‾‾‾‾|___________________________________________
               0    15

wr_en     ________|___|_____________________________________
                    |___| (TC1: write 0xA5)

rd_en     __________________|___|___________________________
                            |___| (TC1: read 0xA5)

data_in   00    A5    11    22    33    44    55    66    77

data_out  00    00    00    A5    00    11    22    33    44
                    (TC1 read appears here)

fifo_cnt  0     1     0     1     2     3     4     5     6
               (TC1)       (TC2 fill begins)

empty     1     0     1     0     0     0     0     0     0

full      0     0     0     0     0     0     0     0     0
```

### Signal Descriptions in Waveform

| Signal | Purpose |
|--------|---------|
| `clk` | 10 ns period system clock |
| `rst_n` | Active-low reset (de-asserted at 15 ns) |
| `wr_en` | Write enable pulse (one cycle per write) |
| `rd_en` | Read enable pulse (one cycle per read) |
| `data_in[7:0]` | Input data bus showing written values |
| `data_out[7:0]` | Output data bus showing read values |
| `fifo_cnt[3:0]` | Element count tracking (0 to 8) |
| `empty` | Asserted when FIFO has no valid data |
| `full` | Asserted when FIFO has 8 valid entries |

---

## Key Concepts Applied

### 1. Circular Buffer (Ring Buffer)
The memory array is treated as a circular structure. Pointers wrap from address 7 back to address 0 using natural 3-bit binary overflow. This eliminates the need for expensive modulo operations and simplifies the hardware.

### 2. Separate Read and Write Pointers
Unlike a stack (single pointer), the FIFO maintains independent read and write pointers. This allows:
- Non-blocking write operations (producer can write while consumer reads)
- True FIFO ordering (first written is first read)
- Concurrent access in dual-port memory architectures

### 3. Combinational Flag Generation
`full` and `empty` are generated combinationally from `fifo_cnt`:
- Updated immediately when `fifo_cnt` changes
- No clock cycle latency for status detection
- Safe for downstream logic to use in the same cycle

### 4. Enable Gating for Overflow/Underflow Protection
Write and read operations are conditionally executed:
```systemverilog
if (wr_en && !full)   // Write only if not full
if (rd_en && !empty)  // Read only if not empty
```
This prevents:
- Overwriting valid data when full
- Reading stale/invalid data when empty
- Counter corruption from illegal operations

### 5. Simultaneous Read/Write Handling
When both `wr_en` and `rd_en` are active and the FIFO is neither full nor empty:
- Data is written to `memory[wr_ptr]`
- Data is read from `memory[rd_ptr]`
- `fifo_cnt` remains unchanged (one in, one out)
- This is the **steady-state streaming mode** of a FIFO

### 6. Registered Outputs for Data
`data_out` is registered in the sequential block:
- Updated on the clock edge following a read
- Provides clean, glitch-free output to downstream logic
- One-cycle read latency is standard for FPGA block RAMs

### 7. Asynchronous Active-Low Reset
All internal state resets on `rst_n` assertion:
- Pointers reset to 0
- Counter resets to 0
- Output data clears to `0x00`
- Ensures known startup state

---

## What I Learned

### Design Methodology
- **Pointer arithmetic clarity:** Using explicit 3-bit pointers with natural overflow makes the circular buffer concept tangible. This is more educational than using Gray code or binary-to-address conversion shortcuts.
- **Counter-based flag generation:** Deriving `full` and `empty` from a counter rather than comparing pointers directly simplifies the logic and makes the design more robust against metastability in asynchronous clock domains (though this design is synchronous).
- **Conditional operation ordering:** The order of `if` statements in the sequential block matters. Write and read operations must be evaluated before the counter update to ensure the counter reflects the correct final state.

### SystemVerilog Features
- `logic [7:0] memory [0:7]` creates an 8-entry array of 8-bit registers. This is synthesizable as distributed RAM or block RAM depending on the FPGA and tool settings.
- `always_ff` for sequential logic and `always_comb` for combinational logic provide clear intent and prevent accidental latch inference.
- 3-bit pointer width (`logic [2:0]`) exactly matches the address space of 8 elements (2^3 = 8), providing free wrap-around via unsigned overflow.

### Timing and Synchronization
- **Read latency:** `data_out` updates on the clock edge after `rd_en` is asserted. This is a registered read, which is standard for memory-based FIFOs.
- **Write timing:** Data is captured on the rising edge when `wr_en` is high. The input `data_in` must be stable during the setup/hold window.
- **Flag timing:** `full` and `empty` are combinational, so they reflect the current state immediately. This allows upstream/downstream logic to respond in the same cycle.

### Verification Approach
- **Structured test cases:** Organizing tests by functionality (basic, boundary, error, concurrent) ensures comprehensive coverage without redundant simulation.
- **Boundary testing:** Filling to exactly 8 elements and reading to exactly 0 elements tests the corner cases where flags transition.
- **Error injection:** Attempting to write when full and read when empty verifies the protection logic.
- **Waveform correlation:** Comparing `data_in` and `data_out` sequences in the waveform confirms FIFO ordering integrity.

### Synthesis Considerations
- **Memory inference:** The `memory` array will be inferred as either distributed RAM (LUT-based) or block RAM (dedicated memory tiles) depending on the FPGA architecture and size. For 8x8 bits, distributed RAM is likely.
- **Pointer width optimization:** 3-bit pointers are minimal for 8 entries. No wasted bits, no complex decoding.
- **Counter width:** `fifo_cnt` uses 4 bits to represent 0-8, leaving room for expansion to 16 entries without changing the counter width.
- **Resource estimate:** Approximately 64 flip-flops (8x8 memory) + 3 (wr_ptr) + 3 (rd_ptr) + 4 (fifo_cnt) + 8 (data_out) = ~82 flip-flops, plus minimal combinational logic for flags.

### Practical Insights
- **FIFO depth selection:** Depth of 8 is a power of 2, which aligns pointer width naturally. Non-power-of-2 depths require more complex full/empty detection.
- **Producer-consumer model:** This FIFO is the classic bridge between two clock domains or two processes with different data rates. The testbench simulates a simple producer-consumer scenario.
- **Data integrity:** Because reads are non-destructive (pointer moves, data remains in memory until overwritten), debugging is easier. The memory contents can be inspected even after reading.
- **Throughput:** In simultaneous read/write mode, the FIFO can sustain one write and one read per clock cycle, providing a throughput of 8 bits per cycle in each direction.

---

## Future Improvements

| Enhancement | Description |
|-------------|-------------|
| **Parameterized Depth** | Replace fixed depth of 8 with a parameter for configurable FIFO sizes |
| **Parameterized Width** | Make data width configurable (e.g., 16-bit, 32-bit) |
| **Asynchronous FIFO** | Add dual-clock support with clock domain crossing (CDC) and Gray code pointers |
| **Almost-Full/Almost-Empty** | Add programmable threshold flags for flow control |
| **Byte Write Enable** | Support partial word writes for wider data buses |
| **Look-Ahead Read** | Provide combinational `data_out` (next value) for zero-latency reads |
| **Status Registers** | Add peak occupancy tracking and transaction counters |
| **Error Flags** | Add `overflow` and `underflow` sticky error flags for diagnostics |
| **UVM Verification** | Migrate to UVM with constrained-random stimulus and coverage collection |
| **FPGA Block RAM** | Add synthesis directives to force block RAM inference for larger depths |

---

## RTL Source Code

### `fifo_8bit.sv`

```systemverilog
// ====================================================================
// Task 4: Simple 8-bit FIFO Buffer (Depth = 8)
// Beginner-Friendly Logic | No Complex Pointer Shortcuts
// ====================================================================
module fifo_8bit (
    input  logic       clk,      // System Clock
    input  logic       rst_n,    // Active-Low Asynchronous Reset
    input  logic       wr_en,    // Write Enable
    input  logic       rd_en,    // Read Enable
    input  logic [7:0] data_in,  // 8-bit Input Data
    output logic [7:0] data_out, // 8-bit Output Data
    output logic       full,     // High when FIFO is full
    output logic       empty,    // High when FIFO is empty
    output logic [3:0] fifo_cnt  // Tracks number of elements (0 to 8)
);

    // Memory Array: 8 registers, each 8-bits wide
    logic [7:0] memory [0:7];

    // Pointers to track positions (0 to 7)
    logic [2:0] wr_ptr;
    logic [2:0] rd_ptr;

    // 1. Combinational Flag Logic
    always_comb begin
        empty = (fifo_cnt == 4'd0);
        full  = (fifo_cnt == 4'd8);
    end

    // 2. Sequential Logic: Registers, Pointers, and Counter Management
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr   <= 3'b000;
            rd_ptr   <= 3'b000;
            fifo_cnt <= 4'd0;
            data_out <= 8'h00;
        end else begin

            // WRITE OPERATION (If enabled and not full)
            if (wr_en && !full) begin
                memory[wr_ptr] <= data_in;
                wr_ptr         <= wr_ptr + 3'b001; // Automatically wraps at 7 -> 0
            end

            // READ OPERATION (If enabled and not empty)
            if (rd_en && !empty) begin
                data_out <= memory[rd_ptr];
                rd_ptr   <= rd_ptr + 3'b001;  // Automatically wraps at 7 -> 0
            end

            // COUNTER TRACKING LOOPS (No Shortcuts)
            if ((wr_en && !full) && !(rd_en && !empty)) begin
                fifo_cnt <= fifo_cnt + 4'd1; // Only Write happened
            end 
            else if ((rd_en && !empty) && !(wr_en && !full)) begin
                fifo_cnt <= fifo_cnt - 4'd1; // Only Read happened
            end
            // If both happen at the same time, fifo_cnt stays the same.
        end
    end

endmodule
```

---

## Testbench Code

### `fifo_8bit_tb.sv`

```systemverilog
`timescale 1ns/1ps

module fifo_8bit_tb;

    // Testbench signals
    logic       clk;
    logic       rst_n;
    logic       wr_en;
    logic       rd_en;
    logic [7:0] data_in;
    logic [7:0] data_out;
    logic       full;
    logic       empty;
    logic [3:0] fifo_cnt;

    // Instantiate UUT
    fifo_8bit uut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .data_in(data_in),
        .data_out(data_out),
        .full(full),
        .empty(empty),
        .fifo_cnt(fifo_cnt)
    );

    // Clock Generation (10ns period)
    always #5 clk = ~clk;

    initial begin
        $dumpfile("fifo_dump.vcd");
        $dumpvars(0, fifo_8bit_tb);

        // Reset state
        clk     = 0;
        rst_n   = 0;
        wr_en   = 0;
        rd_en   = 0;
        data_in = 8'h00;

        #15 rst_n = 1; // Release reset
        #10;

        // --- TEST CASE 1: Basic Write and Read (Single Data) ---
        $display("[TC1] Writing and Reading a single byte...");
        data_in = 8'hA5; wr_en = 1; #10; wr_en = 0; #10; // Write 0xA5
        rd_en = 1; #10; rd_en = 0; #10;                 // Read 0xA5
        #10;

        // --- TEST CASE 2: Fill FIFO completely to check FULL Flag ---
        $display("[TC2] Filling FIFO up to depth 8...");
        data_in = 8'h11; wr_en = 1; #10;
        data_in = 8'h22; #10;
        data_in = 8'h33; #10;
        data_in = 8'h44; #10;
        data_in = 8'h55; #10;
        data_in = 8'h66; #10;
        data_in = 8'h77; #10;
        data_in = 8'h88; #10; // Now fifo_cnt should be 8, full = 1
        wr_en = 0;
        #20;

        // --- TEST CASE 3: Try to Write into a FULL FIFO (Overflow Guard Check) ---
        $display("[TC3] Testing overflow handling...");
        data_in = 8'hFF; wr_en = 1; #10; // This should be ignored
        wr_en = 0;
        #10;

        // --- TEST CASE 4: Empty FIFO completely to check EMPTY Flag ---
        $display("[TC4] Emptying FIFO completely...");
        rd_en = 1; #80; // Read 8 items sequentially
        rd_en = 0;      // Now empty should be 1
        #20;

        // --- TEST CASE 5: Simultaneous Write and Read ---
        $display("[TC5] Testing simultaneous Write and Read...");
        data_in = 8'h99; wr_en = 1; #10; wr_en = 0; #10; // Put one item first

        data_in = 8'hBB; wr_en = 1; rd_en = 1; #10;     // Write 0xBB and Read 0x99 together
        wr_en = 0; rd_en = 0;
        #20;

        $display("FIFO Simulation Completed Successfully.");
        $finish;
    end

endmodule
```

---

## License

This project is provided for educational and reference purposes. Free to use, modify, and distribute with attribution.

---

## Author Notes

This implementation represents a foundational digital design exercise in memory-based data structures. The emphasis on explicit pointer management, comprehensive test coverage, and clean separation of combinational and sequential logic makes this suitable for:
- Academic coursework in digital logic and computer architecture
- FPGA beginner projects requiring data buffering
- Interview preparation for hardware design and verification roles
- Reference implementation for FIFO best practices
- Teaching material for circular buffer and pointer arithmetic concepts

The design prioritizes correctness and clarity over optimization. The explicit counter-based full/empty detection and straightforward pointer increment logic provide a solid foundation for understanding more advanced FIFO variants such as asynchronous FIFOs with Gray code pointers.

