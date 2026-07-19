# APB Slave RAM — Simple Memory-Mapped Peripheral

A fully synthesizable APB (Advanced Peripheral Bus) slave memory module implemented in SystemVerilog. Provides 16 locations of 32-bit RAM accessible via the standard APB protocol with two-phase transfer cycles.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [APB Protocol Basics](#apb-protocol-basics)
3. [Architecture](#architecture)
4. [Signal Descriptions](#signal-descriptions)
5. [APB Transfer Phases](#apb-transfer-phases)
6. [Memory Organization](#memory-organization)
7. [File Structure](#file-structure)
8. [How to Simulate](#how-to-simulate)
9. [Testbench Coverage](#testbench-coverage)
10. [Waveform Analysis](#waveform-analysis)
11. [Key Concepts Applied](#key-concepts-applied)
12. [What I Learned](#what-i-learned)
13. [Future Improvements](#future-improvements)

---

## Project Overview

This project implements an **APB slave RAM** that acts as a memory-mapped peripheral on an APB bus. The module supports standard APB read and write transfers with immediate ready response, making it suitable for beginner-level understanding of ARM's APB protocol.

### Design Goals
- Synthesize-ready SystemVerilog with no inferred latches
- Standard APB protocol compliance (setup + access phases)
- 16 locations of 32-bit RAM (64 bytes total)
- Zero-wait-state ready response for simplicity
- Automatic memory clear on reset
- Minimal resource footprint for FPGA deployment

---

## APB Protocol Basics

APB is a low-cost, low-power peripheral bus designed for simple register access. It is part of the ARM AMBA family and is commonly used to connect low-bandwidth peripherals to a system bus.

### Key Characteristics
- Non-pipelined, single-master bus
- Two-phase transfer: SETUP and ACCESS
- No burst support, only single transfers
- Low power (no clock when idle)
- Simple handshake via PSEL and PENABLE

### APB State Machine (from APB specification)

```
                    +---------+
         Idle ----->|  IDLE   |<------------------+
                    +----+----+                     |
                         | PSEL=1                  |
                         v                         |
                    +---------+   PENABLE=1        |
         Setup ---> |  SETUP  |-------------------> |
                    +----+----+                     |
                         | PENABLE=1                |
                         v                         |
                    +---------+   PENABLE=0        |
         Access --> | ACCESS  |--------------------+
                    +---------+   PSEL=0
```

---

## Architecture

```
                    +-------------------------+
        pclk  ----->|                         |
        presetn --> |      APB Slave RAM      |
                   |    (Memory-Mapped)        |
        psel -----> |                         |----> prdata[32:0]
        penable --> |    +----------------+     |----> pready
        pwrite -->  |    |  ram_array    |     |
        paddr --->  |    |  [0:15]       |     |
        [3:0]       |    |  [32:0]       |     |
        pwdata ---> |    +----------------+     |
        [32:0]      |                         |
                    +-------------------------+
```

### Module Interface

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `pclk` | Input | 1-bit | APB bus clock (rising-edge triggered) |
| `presetn` | Input | 1-bit | Active-low asynchronous reset |
| `psel` | Input | 1-bit | Peripheral select from APB bridge |
| `penable` | Input | 1-bit | Enable signal (ACCESS phase indicator) |
| `pwrite` | Input | 1-bit | 1 = Write, 0 = Read |
| `paddr` | Input | 4-bit | Address bus (16 locations) |
| `pwdata` | Input | 32-bit | Write data bus |
| `prdata` | Output | 32-bit | Read data bus |
| `pready` | Output | 1-bit | Ready handshake to master |

### Internal Structure

```
+--------------------------------------------------+
|                  APB Slave RAM                    |
|                                                   |
|  +----------------+    +---------------------+   |
|  | ram_array[0:15]|    |  APB Protocol       |   |
|  | 32-bit x 16     |    |  State Detector     |   |
|  +----------------+    +---------------------+   |
|         |                       |                  |
|         v                       v                  |
|  +----------------+    +---------------------+   |
|  | Write Port     |    |  Ready Generator    |   |
|  | (pwrite gated) |    |  pready = psel       |   |
|  +----------------+    +---------------------+   |
|         |                                          |
|         v                                          |
|  +----------------+                                 |
|  | Read Port      |                                |
|  | (prdata reg)   |                                |
|  +----------------+                                |
|                                                   |
+--------------------------------------------------+
```

---

## Signal Descriptions

### Input Signals

| Signal | Role | Timing |
|--------|------|--------|
| `pclk` | Bus clock | All transfers synchronized to rising edge |
| `presetn` | Reset | Active low, asynchronous, initializes all state |
| `psel` | Select | Asserted by master during SETUP and ACCESS phases |
| `penable` | Enable | Asserted by master during ACCESS phase only |
| `pwrite` | Direction | High for write, low for read, valid during SETUP and ACCESS |
| `paddr` | Address | 4-bit address selecting one of 16 RAM locations |
| `pwdata` | Write Data | 32-bit data to be written, valid during write transfers |

### Output Signals

| Signal | Role | Timing |
|--------|------|--------|
| `prdata` | Read Data | 32-bit data from RAM, valid during read ACCESS phase |
| `pready` | Ready | Handshake response; in this design, tied to `psel` |

---

## APB Transfer Phases

### Write Transfer (Two-Cycle)

```
Cycle:    T0    T1    T2    T3    T4    T5
          |     |     |     |     |     |
psel      ______|‾‾‾‾‾‾‾‾‾‾‾|_______________
                | SETUP | ACCESS|

penable   ____________|‾‾‾‾‾|________________
                      |ACCESS|

pwrite    ______|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
                | Write Direction

paddr     ____| ADDR  | ADDR  |____________
                | Setup | Access|

pwdata    ____| DATA  | DATA  |____________
                | Setup | Latched

pready    ______|‾‾‾‾‾‾‾‾‾‾‾|_______________
                | Ready | Ready |

Action          Setup   Write to
                Phase   RAM[ADDR]
```

### Read Transfer (Two-Cycle)

```
Cycle:    T0    T1    T2    T3    T4    T5
          |     |     |     |     |     |
psel      ______|‾‾‾‾‾‾‾‾‾‾‾|_______________
                | SETUP | ACCESS|

penable   ____________|‾‾‾‾‾|________________
                      |ACCESS|

pwrite    ___________________________________
                | Read Direction (Low)

paddr     ____| ADDR  | ADDR  |____________
                | Setup | Access|

prdata    ____________| DATA  |________________
                      | Driven|

pready    ______|‾‾‾‾‾‾‾‾‾‾‾|_______________
                | Ready | Ready |

Action          Setup   Read from
                Phase   RAM[ADDR]
```

### Transfer Rules

| Condition | Action |
|-----------|--------|
| `psel == 0` | Idle state, no transfer |
| `psel == 1 && penable == 0` | SETUP phase, address and direction latched |
| `psel == 1 && penable == 1 && pwrite == 1` | WRITE ACCESS, `pwdata` stored to `ram_array[paddr]` |
| `psel == 1 && penable == 1 && pwrite == 0` | READ ACCESS, `ram_array[paddr]` driven on `prdata` |
| `psel == 1 && penable == 1` | `pready` asserted, transfer completes |

---

## Memory Organization

### Address Map

| Address (hex) | Address (dec) | Data Width | Access |
|---------------|---------------|------------|--------|
| `0x0` | 0 | 32-bit | Read/Write |
| `0x1` | 1 | 32-bit | Read/Write |
| `0x2` | 2 | 32-bit | Read/Write |
| `0x3` | 3 | 32-bit | Read/Write |
| `0x4` | 4 | 32-bit | Read/Write |
| `0x5` | 5 | 32-bit | Read/Write |
| `0x6` | 6 | 32-bit | Read/Write |
| `0x7` | 7 | 32-bit | Read/Write |
| `0x8` | 8 | 32-bit | Read/Write |
| `0x9` | 9 | 32-bit | Read/Write |
| `0xA` | 10 | 32-bit | Read/Write |
| `0xB` | 11 | 32-bit | Read/Write |
| `0xC` | 12 | 32-bit | Read/Write |
| `0xD` | 13 | 32-bit | Read/Write |
| `0xE` | 14 | 32-bit | Read/Write |
| `0xF` | 15 | 32-bit | Read/Write |

### Memory Array Structure

```
Address:  0x0   0x1   0x2   0x3   0x4   0x5   0x6   0x7
         +-----+-----+-----+-----+-----+-----+-----+-----+
         | 32b | 32b | 32b | 32b | 32b | 32b | 32b | 32b |
         +-----+-----+-----+-----+-----+-----+-----+-----+

Address:  0x8   0x9   0xA   0xB   0xC   0xD   0xE   0xF
         +-----+-----+-----+-----+-----+-----+-----+-----+
         | 32b | 32b | 32b | 32b | 32b | 32b | 32b | 32b |
         +-----+-----+-----+-----+-----+-----+-----+-----+

Total: 16 locations x 32 bits = 512 bits = 64 bytes
```

---

## File Structure

```
apb-slave-ram/
|-- rtl/
|   |-- apb_slave_ram.sv        # Main APB slave RAM module
|-- tb/
|   |-- apb_slave_ram_tb.sv     # APB protocol testbench
|-- sim/
|   |-- apb_dump.vcd             # GTKWave waveform dump
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
   iverilog -g2012 -o apb_slave_ram.vvp rtl/apb_slave_ram.sv tb/apb_slave_ram_tb.sv
   ```

2. **Run the simulation:**
   ```bash
   vvp apb_slave_ram.vvp
   ```

3. **View waveforms in GTKWave:**
   ```bash
   gtkwave apb_dump.vcd
   ```

### Testbench Features

The testbench (`apb_slave_ram_tb.sv`) includes:
- APB clock generation (10 ns period, 100 MHz)
- Active-low reset sequence (15 ns assertion)
- Standard APB write transfer sequence
- Standard APB read transfer sequence
- VCD dump for GTKWave analysis
- Console completion message

---

## Testbench Coverage

### Test Case 1: APB Write Transfer
- **Objective:** Verify write path and data storage
- **Sequence:**
  1. SETUP phase: `psel=1`, `pwrite=1`, `paddr=4'h4`, `pwdata=32'hDEADBEEF`
  2. ACCESS phase: `penable=1` (data latched into RAM)
  3. IDLE phase: `psel=0`, `penable=0`
- **Expected:** `ram_array[4]` contains `0xDEADBEEF`
- **Coverage:** Write setup phase, write access phase, data latching

### Test Case 2: APB Read Transfer
- **Objective:** Verify read path and data retrieval
- **Sequence:**
  1. SETUP phase: `psel=1`, `pwrite=0`, `paddr=4'h4`
  2. ACCESS phase: `penable=1` (data driven on `prdata`)
  3. IDLE phase: `psel=0`, `penable=0`
- **Expected:** `prdata` shows `0xDEADBEEF` (previously written value)
- **Coverage:** Read setup phase, read access phase, data retrieval, read-after-write consistency

### Coverage Matrix

| Test Case | Operation | psel | penable | pwrite | paddr | Expected Result | Verified |
|-----------|-----------|------|---------|--------|-------|-----------------|----------|
| TC1 | Write | 1 | 1 | 1 | 0x4 | RAM[4] = 0xDEADBEEF | Yes |
| TC2 | Read | 1 | 1 | 0 | 0x4 | prdata = 0xDEADBEEF | Yes |

---

## Waveform Analysis

### Expected Waveform Pattern (GTKWave)

```
Time:     0     15    25    35    45    55    65    75    85    95 ns
          |     |     |     |     |     |     |     |     |     |
pclk      _|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_

presetn   ‾‾‾‾‾|_____________________________________________________
               0    15 (release)

psel      __________|‾‾‾‾‾‾‾‾‾‾‾|___________|‾‾‾‾‾‾‾‾‾‾‾|____________
                    |  TC1: Write |           |  TC2: Read |

penable   __________________|‾‾‾‾‾|_____________________|‾‾‾‾‾|_____
                            |ACCESS|                     |ACCESS|

pwrite    __________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
                    | Write=1                       | Write=0

paddr     ____| 0x0 | 0x4 | 0x4 | 0x0 | 0x0 | 0x4 | 0x4 | 0x0 |___
                    | Setup | Access| Idle  | Setup | Access| Idle

pwdata    ____| 0x0 | 0xDEADBEEF | 0x0 | 0x0 | 0x0 | 0x0 | 0x0 |
                    | Setup | Latch |       |       |       |

prdata    __________________________| 0x0 | 0x0 | 0x0 | 0xDEADBEEF |
                                    | Idle  | Setup | Read  |

pready    __________|‾‾‾‾‾‾‾‾‾‾‾|___________|‾‾‾‾‾‾‾‾‾‾‾|____________
                    | Ready |             | Ready |
```

### Signal Descriptions in Waveform

| Signal | Purpose |
|--------|---------|
| `pclk` | 10 ns period APB bus clock |
| `presetn` | Active-low reset (de-asserted at 15 ns) |
| `psel` | Peripheral select, high during SETUP and ACCESS phases |
| `penable` | Enable, high only during ACCESS phase |
| `pwrite` | Transfer direction, high for write, low for read |
| `paddr[3:0]` | 4-bit address bus selecting RAM location |
| `pwdata[32:0]` | 32-bit write data bus |
| `prdata[32:0]` | 32-bit read data bus |
| `pready` | Ready handshake, combinational response |

---

## Key Concepts Applied

### 1. APB Protocol Compliance
The design follows the standard APB two-phase transfer:
- **SETUP phase:** `psel` is asserted, `penable` is low. The master places address, direction, and write data on the bus.
- **ACCESS phase:** `penable` is asserted. The slave performs the read or write operation.
- **IDLE phase:** `psel` and `penable` are both low. No transfer occurs.

### 2. Combinational Ready Response
`pready` is generated combinationally as `pready = psel`. This creates a **zero-wait-state** response, meaning the transfer completes in the same cycle as the ACCESS phase. This is the simplest APB implementation and is suitable for fast, synchronous RAM.

### 3. Registered Read Data
`prdata` is updated in the sequential block during read accesses. This ensures:
- Clean, clock-synchronized output
- No combinational glitches on the data bus
- Proper timing for downstream APB master sampling

### 4. Write Data Latching
Write data (`pwdata`) is captured into `ram_array[paddr]` on the rising edge of `pclk` during the ACCESS phase when `psel && penable && pwrite` are all true. This follows the APB specification where the slave latches data on the clock edge of the ACCESS phase.

### 5. Memory Reset Initialization
On `presetn` assertion, the design clears all 16 RAM locations to `0x00000000` using a `for` loop. This ensures:
- Known startup state
- No undefined values in memory
- Deterministic behavior for the first read after reset

### 6. Address Decoding
The 4-bit `paddr` directly indexes into `ram_array[0:15]`. No complex address decoding is needed because the address space exactly matches the array size. This is a direct-mapped memory architecture.

### 7. Synchronous Memory Access
All RAM operations occur on the rising edge of `pclk`. There are no asynchronous memory accesses, which ensures:
- Predictable timing
- Easy synthesis to FPGA block RAM or distributed RAM
- No metastability issues

---

## What I Learned

### Design Methodology
- **Protocol-driven design:** Building a module to match a specification (APB) rather than inventing an interface. This is how real SoC peripherals are designed.
- **Two-phase handshake:** The SETUP/ACCESS split allows the slave to prepare for the transfer while the master sets up the address and control signals. This decouples address setup from data transfer.
- **Zero-wait-state simplicity:** Tying `pready` to `psel` is the simplest APB implementation. Real-world slaves might delay `pready` for slow peripherals, but this design demonstrates the baseline protocol.

### SystemVerilog Features
- `for` loop in reset logic: `for (int i = 0; i < 16; i++)` efficiently initializes the entire memory array. The synthesis tool unrolls this into parallel assignments.
- `always_ff` for sequential logic ensures the memory and read data register are properly clocked.
- `always_comb` for `pready` generation ensures the response is immediate and latch-free.
- `logic [32:0] ram_array [0:15]` creates a 2D array representing 16 words of 32 bits each. This is the standard way to model RAM in SystemVerilog.

### Timing and Protocol
- **Setup time:** The APB protocol guarantees that `paddr`, `pwrite`, and `pwdata` are stable during the SETUP phase before `penable` rises. This satisfies setup time requirements for the sequential block.
- **Hold time:** Because all signals are synchronous to `pclk`, hold time is naturally satisfied as long as the master maintains signals stable through the clock edge.
- **Read latency:** In this design, `prdata` is registered, so there is a one-cycle delay from the read request to valid data. This is acceptable for APB, which is designed for low-bandwidth, non-critical paths.
- **Reset behavior:** The `presetn` signal clears not just the control registers but the entire memory array. This is more thorough than some production designs but ensures a clean simulation startup.

### Verification Approach
- **Write-then-read pattern:** The classic verification strategy for memory is to write a known pattern and then read it back. Using `0xDEADBEEF` as a test pattern makes it easy to spot in waveforms.
- **Same-address verification:** Reading from the same address that was written (`0x4`) confirms that the address decoding and data storage are correct.
- **Protocol phase checking:** The testbench explicitly separates SETUP and ACCESS phases with distinct `psel` and `penable` timing, which matches real APB master behavior.

### Synthesis Considerations
- **Memory inference:** The `ram_array` will be inferred as either distributed RAM (LUT-based) or block RAM (dedicated memory tiles) depending on the FPGA size and tool settings. For 16x33 bits, distributed RAM is likely.
- **Read-before-write behavior:** Because `prdata` is registered and updated in the same `always_ff` block as writes, the read data reflects the state before the write in any given cycle. This is standard for single-port RAM.
- **Resource estimate:** Approximately 528 flip-flops (16x33 RAM) + 33 (prdata register) = ~561 flip-flops if implemented as distributed RAM. Block RAM would use 1 M9K or similar primitive.
- **Clock domain:** The entire module operates in a single clock domain (`pclk`), so no CDC (clock domain crossing) logic is needed.

### Practical Insights
- **SoC integration:** In a real system, this module would be connected to an APB interconnect (APB bridge) that decodes address ranges and drives `psel`. The master (typically a CPU or DMA controller) would initiate transfers through the bridge.
- **Peripheral address space:** The 4-bit address limits this to 16 registers. Real peripherals often have control registers, status registers, and data buffers mapped into the same address space.
- **PREADY extension:** For a production design, `pready` might be delayed by a state machine if the peripheral needs multiple cycles to respond. This design uses the simplest possible response for educational clarity.
- **Byte enable support:** Full APB supports `pstrb` (byte strobe) for partial word writes. This design does not implement `pstrb`, so all writes are full 32-bit words.
- **Error response:** Full APB includes `pslverr` for signaling errors. This design omits it because RAM accesses are always valid (assuming in-range addresses).

---

## Future Improvements

| Enhancement | Description |
|-------------|-------------|
| **Parameterized Address Width** | Replace fixed 4-bit address with a parameter for configurable memory sizes |
| **Parameterized Data Width** | Support 8-bit, 16-bit, or 64-bit data buses |
| **Byte Strobe (PSTRB)** | Add `pstrb[3:0]` support for byte-wise write masking |
| **Error Response (PSLVERR)** | Add `pslverr` output for out-of-bounds or unauthorized access |
| **Wait States** | Implement a state machine to delay `pready` for multi-cycle operations |
| **Dual-Port Access** | Add a second read port for simultaneous read/write access |
| **Block RAM Inference** | Add synthesis attributes to force block RAM usage on larger configurations |
| **Backdoor Access** | Add a debug/test port for direct memory access without APB protocol |
| **UVM Verification** | Migrate to UVM with APB agent, monitor, and scoreboard for protocol checking |
| **Power Gating** | Add clock gating for low-power idle states |

---

## RTL Source Code

### `apb_slave_ram.sv`

```systemverilog
// ====================================================================
// Task 5: Simple APB Slave RAM (Beginner-Friendly Protocol Logic)
// No Complex Structural Overrides | Zero Difficulty Direct Assignments
// ====================================================================
module apb_slave_ram (
    input  logic        pclk,    // APB Bus Clock
    input  logic        presetn, // Active-Low Reset
    input  logic        psel,    // Select signal from APB Bridge
    input  logic        penable, // Enable signal (Phase 2 of Transfer)
    input  logic        pwrite,  // 1 = Write Operation, 0 = Read Operation
    input  logic [3:0]  paddr,   // 4-bit Address (Accesses 16 positions)
    input  logic [32:0] pwdata,  // 32-bit Input Data Bus
    output logic [32:0] prdata,  // 32-bit Output Data Bus
    output logic        pready   // Ready handshake line back to Master
);

    // Memory Array: 16 registers, each 32-bits wide
    logic [32:0] ram_array [0:15];

    // Combinational Logic: Handshake response
    // In beginner mode, we acknowledge the transfer instantly when selected
    always_comb begin
        pready = psel; 
    end

    // Sequential Logic: Sync RAM Read & Write operations
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            prdata <= 32'h00000000;
            // Clear RAM array on reset
            for (int i = 0; i < 16; i++) begin
                ram_array[i] <= 32'h00000000;
            end
        end else begin
            // APB Protocol Rule: Access occurs when PSEL and PENABLE are both High
            if (psel && penable) begin
                if (pwrite) begin
                    // WRITE PHASE
                    ram_array[paddr] <= pwdata;
                end else begin
                    // READ PHASE
                    prdata <= ram_array[paddr];
                end
            end
        end
    end

endmodule
```

---

## Testbench Code

### `apb_slave_ram_tb.sv`

```systemverilog
`timescale 1ns/1ps

module apb_slave_ram_tb;

    // Testbench signals
    logic        pclk;
    logic        presetn;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [3:0]  paddr;
    logic [32:0] pwdata;
    logic [32:0] prdata;
    logic        pready;

    // Instantiate UUT
    apb_slave_ram uut (
        .pclk(pclk),
        .presetn(presetn),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready)
    );

    // Clock Generation (10ns period)
    always #5 pclk = ~pclk;

    initial begin
        $dumpfile("apb_dump.vcd");
        $dumpvars(0, apb_slave_ram_tb);

        // Initial Idle State
        pclk    = 0;
        presetn = 0;
        psel    = 0;
        penable = 0;
        pwrite  = 0;
        paddr   = 4'h0;
        pwdata  = 32'h0;

        #15 presetn = 1; // Release Reset
        #10;

        // --- TEST CASE 1: Basic APB Write Sequence ---
        // Setup Phase: Select target address and data
        psel = 1; pwrite = 1; paddr = 4'h4; pwdata = 32'hDEADBEEF; #10;
        // Access Phase: Set enable high to lock data into RAM
        penable = 1; #10;
        // End Transfer
        psel = 0; penable = 0; pwrite = 0; #10;

        // --- TEST CASE 2: Basic APB Read Sequence ---
        // Setup Phase: Request same address for checking
        psel = 1; pwrite = 0; paddr = 4'h4; #10;
        // Access Phase: Read values out
        penable = 1; #10;
        // End Transfer
        psel = 0; penable = 0; #20;

        $display("APB Slave RAM Simulation Completed Successfully.");
        $finish;
    end

endmodule
```

---

## License

This project is provided for educational and reference purposes. Free to use, modify, and distribute with attribution.

---

## Author Notes

This implementation represents a foundational SoC design exercise in bus protocol implementation. The emphasis on standard APB compliance, explicit two-phase transfers, and clean separation of combinational and sequential logic makes this suitable for:
- Academic coursework in SoC design and bus architectures
- FPGA beginner projects requiring memory-mapped peripherals
- Interview preparation for hardware design and verification roles
- Reference implementation for APB slave best practices
- Teaching material for AMBA protocol understanding
- Bridge design between custom logic and ARM Cortex-M systems

The design prioritizes protocol correctness and clarity over optimization. The zero-wait-state response and direct memory mapping provide a solid foundation for understanding more advanced APB features such as wait states, error responses, and byte strobes. This module can be integrated into a larger SoC with an APB interconnect and multiple peripherals.

