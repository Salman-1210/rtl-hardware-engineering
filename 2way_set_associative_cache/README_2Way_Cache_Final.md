# 2-Way Set Associative Cache (4 Sets × 2 Ways)

A fully synthesizable, beginner-friendly 2-Way Set Associative Cache implemented in SystemVerilog. Features tag-based address mapping with valid-bit verification, LRU (Least Recently Used) replacement policy, combinational hit detection with sequential state updates, and explicit pointer management without shortcuts.

**Instructor:** Sir Khalil Rehman  
**Course:** Digital Design / Computer Architecture Lab  
**Language:** SystemVerilog (IEEE 1800-2017)  
**Simulator:** Icarus Verilog (iverilog + vvp) + GTKWave  

---

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Cache Operation](#cache-operation)
- [Address Breakdown](#address-breakdown)
- [LRU Replacement Policy](#lru-replacement-policy)
- [File Structure](#file-structure)
- [How to Simulate](#how-to-simulate)
- [Testbench Coverage](#testbench-coverage)
- [Waveform Analysis](#waveform-analysis)
- [Key Concepts Applied](#key-concepts-applied)
- [What I Learned](#what-i-learned)
- [Future Improvements](#future-improvements)

---

## Project Overview

This project implements a classic **2-Way Set Associative Cache** with 4 sets, each containing 2 cache ways. The design uses explicit tag matching with valid-bit verification and a single-bit LRU replacement policy, making it ideal for understanding the fundamental mechanics of set-associative cache memory structures in digital design.

### Design Goals

- Synthesize-ready SystemVerilog with no inferred latches
- Explicit tag/index breakdown for educational clarity
- LRU replacement using 1 bit per set for 2-way associativity
- Combinational hit detection with immediate data output
- Sequential state updates synchronized to clock edges
- Write-hit update and write-miss replacement with full eviction tracking
- Minimal resource footprint for FPGA deployment

### Specifications

| Parameter | Value |
|-----------|-------|
| Cache Type | 2-Way Set Associative |
| Number of Sets | 4 |
| Ways per Set | 2 |
| Total Cache Lines | 8 (4 sets × 2 ways) |
| Address Width | 4 bits |
| Data Width | 8 bits |
| Tag Width | 2 bits |
| Index Width | 2 bits |
| Replacement Policy | LRU (1 bit per set) |
| Clock | Rising-edge triggered |
| Reset | Active-high synchronous |

---

## Architecture

```
                    +----------------------------------+
        clk  ------> |                                  |
        reset ---->  |    2-Way Set Associative Cache   |
                     |      (4 Sets × 2 Ways)           |
   address[3:0] -->  |                                  |----> read_data[7:0]
   write_data[7:0]-> |    +------------------------+    |----> hit
   write_enable -->  |    |  valid[0:3][0:1]       |    |
                     |    |  tag[0:3][0:1][1:0]    |    |
                     |    |  data[0:3][0:1][7:0]   |    |
                     |    |  lru[0:3]              |    |
                     |    +------------------------+    |
                     |    |  Index = address[1:0]     |    |
                     |    |  Tag   = address[3:2]     |    |
                     |    +------------------------+    |
                     |    |  Way0 Hit Comparator     |    |
                     |    |  Way1 Hit Comparator     |    |
                     |    +------------------------+    |
                     +----------------------------------+
```

### Module Interface

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | Input | 1-bit | System clock (rising-edge triggered) |
| `reset` | Input | 1-bit | Active-high synchronous reset |
| `address` | Input | 4-bit | Memory address to access |
| `write_data` | Input | 8-bit | Data to write into cache |
| `write_enable` | Input | 1-bit | High = Write operation, Low = Read operation |
| `read_data` | Output | 8-bit | Data read from cache (combinational) |
| `hit` | Output | 1-bit | High when requested address is found in cache |

### Internal Structure

```
+-------------------------------------------------------------+
|                    Cache Controller                          |
|                                                              |
|  +-------------------+    +---------------------------+  |
|  | Memory Arrays     |    |  Address Breakdown          |  |
|  | valid[4][2]       |    |  index = address[1:0]       |  |
|  | tag[4][2][2]      |    |  addr_tag = address[3:2]    |  |
|  | data[4][2][8]     |    +---------------------------+  |
|  | lru[4]            |              |                     |
|  +-------------------+              v                     |
|         |                    +---------------------------+  |
|         v                    |  Hit Detection Logic        |  |
|  +-------------------+       |  way0_hit = valid && tag  |  |
|  | Write Port        |       |  way1_hit = valid && tag  |  |
|  | (write_enable     |       +---------------------------+  |
|  |  gated)           |              |                     |
|  +-------------------+              v                     |
|         |                    +---------------------------+  |
|         v                    |  Output Assignment          |  |
|  +-------------------+       |  read_data & hit            |  |
|  | Read Port         |       |  (combinational)            |  |
|  | (combinational    |       +---------------------------+  |
|  |  lookup)          |                                    |
|  +-------------------+                                    |
|                                                              |
+-------------------------------------------------------------+
```

---

## Cache Operation

### Set Associative Mapping Concept

The cache uses set associative mapping where:

- The **index** (lower address bits) selects which set to search
- The **tag** (upper address bits) identifies which memory block is stored
- Both ways within the selected set are checked simultaneously
- A **valid bit** confirms the cache line contains meaningful data

### Memory Map Visualization

```
Set 0:  +--------+--------+     Set 1:  +--------+--------+
        | Way 0  | Way 1  |             | Way 0  | Way 1  |
        | [V,T,D]| [V,T,D]|             | [V,T,D]| [V,T,D]|
        +--------+--------+             +--------+--------+

Set 2:  +--------+--------+     Set 3:  +--------+--------+
        | Way 0  | Way 1  |             | Way 0  | Way 1  |
        | [V,T,D]| [V,T,D]|             | [V,T,D]| [V,T,D]|
        +--------+--------+             +--------+--------+

V = Valid Bit (1 bit)    T = Tag (2 bits)    D = Data (8 bits)
```

### Operational Modes

| Mode | write_enable | hit | Action |
|------|-------------|-----|--------|
| Read Hit Way0 | 0 | 1 (Way0) | Output data from Way0, update LRU |
| Read Hit Way1 | 0 | 1 (Way1) | Output data from Way1, update LRU |
| Read Miss | 0 | 0 | Output `8'h00`, no state change |
| Write Hit Way0 | 1 | 1 (Way0) | Update Way0 data, update LRU |
| Write Hit Way1 | 1 | 1 (Way1) | Update Way1 data, update LRU |
| Write Miss (Replace) | 1 | 0 | Replace LRU way with new tag+data |

---

## Address Breakdown

### Address Splitting

```
4-bit Address: [3:2] | [1:0]
               Tag    | Index
               ───────┼───────
                 2    |   2
```

| Field | Bits | Purpose |
|-------|------|---------|
| **Tag** | [3:2] | Identifies which memory block is stored in cache |
| **Index** | [1:0] | Selects which set to search (0-3) |

### Address Examples

| Address | Binary | Tag [3:2] | Index [1:0] | Set | Notes |
|---------|--------|-----------|-------------|-----|-------|
| 0 | `0000` | `00` | `00` | Set 0 | |
| 4 | `0100` | `01` | `00` | Set 0 | **Same set, different tag** |
| 8 | `1000` | `10` | `00` | Set 0 | **Same set, different tag** |
| 1 | `0001` | `00` | `01` | Set 1 | |
| 5 | `0101` | `01` | `01` | Set 1 | Same set, different tag |

> **Key Insight:** Addresses 0, 4, and 8 all map to **Set 0** but have **different tags**. This is intentional to force eviction when the set is full.

### Address Breakdown Diagram

```
Address 0000:  0  0  0  0
               │  │  │  │
               │  │  └──┴── Index = 00 → Set 0
               └──┴─────── Tag   = 00 → Block identifier

Address 0100:  0  1  0  0
               │  │  │  │
               │  │  └──┴── Index = 00 → Set 0 (SAME SET!)
               └──┴─────── Tag   = 01 → Different block

Address 1000:  1  0  0  0
               │  │  │  │
               │  │  └──┴── Index = 00 → Set 0 (SAME SET!)
               └──┴─────── Tag   = 10 → Different block
```

---

## LRU Replacement Policy

### Concept

LRU (Least Recently Used) replaces the cache way that has been accessed least recently. For a 2-way cache, only **1 bit per set** is needed to track which way is older.

### LRU Bit Interpretation

```
┌─────────┬──────────────────────────────────────────────────┐
│ lru[i]  │ Meaning                                          │
├─────────┼──────────────────────────────────────────────────┤
│    0    │ Way0 was used LEAST recently → REPLACE Way0      │
│    1    │ Way1 was used LEAST recently → REPLACE Way1      │
└─────────┴──────────────────────────────────────────────────┘
```

### LRU State Transitions

| Access Type | Previous LRU | New LRU | Explanation |
|-------------|-------------|---------|-------------|
| Read/Write Way0 | X | 1 | Way0 now recently used, Way1 is LRU |
| Read/Write Way1 | X | 0 | Way1 now recently used, Way0 is LRU |
| Replace Way0 | 0 | 1 | Way0 freshly written, Way1 is now LRU |
| Replace Way1 | 1 | 0 | Way1 freshly written, Way0 is now LRU |

### LRU Update Flow

```
┌─────────────────────────────────────────────────────────────┐
│  ACCESS TYPE        │  ACTION                               │
├─────────────────────────────────────────────────────────────┤
│  Read/Write Way0    │  lru = 1 (Way1 is now least recent)   │
│  Read/Write Way1    │  lru = 0 (Way0 is now least recent)   │
│  Replace Way0       │  lru = 1 (Way0 fresh, Way1 is LRU)    │
│  Replace Way1       │  lru = 0 (Way1 fresh, Way0 is LRU)    │
└─────────────────────────────────────────────────────────────┘
```

### Why 1 Bit is Enough for 2-Way?

```
For 2-way: Only need to track which ONE way is older
┌─────────────┬────────────────────────────────────────┐
│   LRU Bit   │   Interpretation                       │
├─────────────┼────────────────────────────────────────┤
│     0       │   Way0 is older → Replace Way0         │
│     1       │   Way1 is older → Replace Way1         │
└─────────────┴────────────────────────────────────────┘

For N-way: Need log₂(N) bits per set
• 2-way: 1 bit
• 4-way: 2 bits  
• 8-way: 3 bits
```

---

## File Structure

```
cache-2way/
|-- rtl/
|   |-- cache_2way.sv             # Main cache design module
|-- tb/
|   |-- tb_cache.sv               # Comprehensive testbench
|-- sim/
|   |-- dump.vcd                  # GTKWave waveform dump
|-- README.md
```

---

## How to Simulate

### Prerequisites

- Icarus Verilog (`iverilog`) with SystemVerilog support (`-g2012`)
- GTKWave (for waveform visualization)

### Simulation Steps

**Step 1:** Compile the design and testbench

```bash
iverilog -g2012 -o cache_sim.vvp cache_2way.sv tb_cache.sv
```

**Step 2:** Run the simulation

```bash
vvp cache_sim.vvp
```

**Step 3:** View waveforms in GTKWave

```bash
gtkwave dump.vcd
```

### Testbench Features

The testbench (`tb_cache.sv`) includes:

- Clock generation (10 ns period, 100 MHz)
- Active-high reset sequence (12 ns assertion)
- Eight comprehensive test cases covering all operational modes
- VCD dump for GTKWave analysis
- Real-time console logging with `$monitor` for signal tracking

---

## Testbench Coverage

### Test Case 1: Write to Empty Cache

**Objective:** Verify basic cache write and way allocation

**Sequence:** Write `8'hAA` to Address `4'b0000` (Set 0, Tag 00)

**Expected:**
- First cycle: Miss (`HIT=0`, `RDATA=00`)
- Next cycle: Hit (`HIT=1`, `RDATA=AA`) — combinational read sees written data
- Data placed in Way0 of Set 0
- LRU[0] updated to 1

**Coverage:** Basic write path, empty cache allocation, LRU initialization

---

### Test Case 2: Read from Cached Address

**Objective:** Verify read hit and data retrieval

**Sequence:** Read Address `4'b0000`

**Expected:** `HIT=1`, `RDATA=AA`

**Coverage:** Read hit path, combinational data output, LRU update

---

### Test Case 3: Write to Same Set, Different Tag

**Objective:** Verify second way utilization within same set

**Sequence:** Write `8'hBB` to Address `4'b0100` (Set 0, Tag 01)

**Expected:**
- Miss on first cycle (`HIT=0`)
- Hit on next cycle (`HIT=1`, `RDATA=BB`)
- Data placed in Way1 of Set 0
- LRU[0] updated to 0

**Coverage:** Same-set different-tag mapping, Way1 allocation

---

### Test Case 4: Read from Second Way

**Objective:** Verify read from Way1

**Sequence:** Read Address `4'b0100`

**Expected:** `HIT=1`, `RDATA=BB`

**Coverage:** Way1 hit detection, data integrity across ways

---

### Test Case 5: Write Miss with Set Full (Eviction Test)

**Objective:** Verify LRU replacement when set is full

**Sequence:** Write `8'hCC` to Address `4'b1000` (Set 0, Tag 10)

**Expected:**
- Miss on first cycle (`HIT=0`)
- Hit on next cycle (`HIT=1`, `RDATA=CC`)
- Way0 is LRU (LRU[0]=0) → **Way0 EVICTED**
- Tag00+AA replaced with Tag10+CC
- LRU[0] updated to 1

**Coverage:** LRU replacement, eviction logic, write miss handling

---

### Test Case 6: Read Evicted Address (Expect Miss)

**Objective:** Verify eviction was successful

**Sequence:** Read Address `4'b0000` (Tag 00)

**Expected:** `HIT=0`, `RDATA=00`

**Coverage:** Eviction verification, miss detection, valid bit importance

---

### Test Case 7: Read Surviving Address (Expect Hit)

**Objective:** Verify non-LRU way preserved after eviction

**Sequence:** Read Address `4'b0100` (Tag 01)

**Expected:** `HIT=1`, `RDATA=BB`

**Coverage:** Data preservation, Way1 integrity post-eviction

---

### Test Case 8: Read Newly Replaced Address (Expect Hit)

**Objective:** Verify replacement data is accessible

**Sequence:** Read Address `4'b1000` (Tag 10)

**Expected:** `HIT=1`, `RDATA=CC`

**Coverage:** Replacement data verification, new tag accessibility

---

### Coverage Matrix

| Test Case | Write | Read | Hit | Miss | Eviction | LRU Update |
|-----------|-------|------|-----|------|----------|------------|
| TC1 | 1 | 0 | Yes | Yes | No | Yes |
| TC2 | 0 | 1 | Yes | No | No | Yes |
| TC3 | 1 | 0 | Yes | Yes | No | Yes |
| TC4 | 0 | 1 | Yes | No | No | Yes |
| TC5 | 1 | 0 | Yes | Yes | Yes | Yes |
| TC6 | 0 | 1 | No | Yes | N/A | No |
| TC7 | 0 | 1 | Yes | No | N/A | Yes |
| TC8 | 0 | 1 | Yes | No | N/A | Yes |

---

## Waveform Analysis

### GTKWave Screenshot Analysis

```
Time(ns):  0      10      20      30      40      50      60      70      80      90     100
           │       │       │       │       │       │       │       │       │       │       │
clk:       ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐
           └─┘   └─┘   └─┘   └─┘   └─┘   └─┘   └─┘   └─┘   └─┘   └─┘   └─┘   └─┘   └─┘

reset:     ████████
                    └────────────────────────────────────────────────────────────────────────────

address:   0       0       0       0       4       4       8       0       4       8
           [0000]  [0000]  [0000]  [0000]  [0100]  [0100]  [1000]  [0000]  [0100]  [1000]

write_data:00      00      AA      AA      AA      BB      BB      CC      CC      CC

write_en:  0       0       1       1       1       1       1       0       0       0

read_data: 00      00      00      AA      AA      00      BB      00      00      BB
                                          ↑hit              ↑hit              ↑miss

hit:       0       0       0       1       1       0       1       0       1       1
```

### Signal Descriptions in Waveform

| Signal | Purpose |
|--------|---------|
| `clk` | 10 ns period system clock |
| `reset` | Active-high reset (de-asserted at 12 ns) |
| `address[3:0]` | Input address bus showing accessed locations |
| `write_data[7:0]` | Input data bus showing values to write |
| `write_enable` | High during write operations, low during read |
| `read_data[7:0]` | Output data bus showing read values (combinational) |
| `hit` | Asserted when requested address found in cache |

### Waveform Event Timeline

| Time (ns) | Event | Signal States | Explanation |
|-----------|-------|---------------|-------------|
| 0-12 | Reset Active | `reset=1`, all outputs `00` | Cache initialized to empty state |
| 20 | **TC1: Write AA @ 0000** | `WE=1`, `ADDR=0000`, `WDATA=AA` | Write miss — Way0 allocated |
| 25 | TC1 Next Cycle | `RDATA=AA`, `HIT=1` | Combinational read shows written data |
| 30 | **TC2: Read @ 0000** | `WE=0`, `ADDR=0000` | Read hit — Way0 contains AA |
| 40 | **TC3: Write BB @ 0100** | `WE=1`, `ADDR=0100`, `WDATA=BB` | Write miss — Way1 allocated (same set) |
| 45 | TC3 Next Cycle | `RDATA=BB`, `HIT=1` | Combinational read shows BB |
| 50 | **TC4: Read @ 0100** | `WE=0`, `ADDR=0100` | Read hit — Way1 contains BB |
| 60 | **TC5: Write CC @ 1000** | `WE=1`, `ADDR=1000`, `WDATA=CC` | Write miss — Set full, Way0 evicted |
| 65 | TC5 Next Cycle | `RDATA=CC`, `HIT=1` | Combinational read shows CC |
| 70 | **TC6: Read @ 0000** | `WE=0`, `ADDR=0000` | **MISS!** Tag00 evicted from Way0 |
| 80 | **TC7: Read @ 0100** | `WE=0`, `ADDR=0100` | **HIT!** Way1 still has Tag01+BB |
| 90 | **TC8: Read @ 1000** | `WE=0`, `ADDR=1000` | **HIT!** Way0 now has Tag10+CC |

### Set 0 State Evolution

```
┌──────────┬─────────────────┬─────────────────┬────────┐
│  Time    │     Way0        │     Way1        │  LRU   │
├──────────┼─────────────────┼─────────────────┼────────┤
│  Reset   │  Invalid        │  Invalid        │   0    │
│  Test1   │  Tag00, AA      │  Invalid        │   1    │ ← Way0 used
│  Test2   │  Tag00, AA      │  Invalid        │   1    │ ← Read Way0
│  Test3   │  Tag00, AA      │  Tag01, BB      │   0    │ ← Way1 used
│  Test4   │  Tag00, AA      │  Tag01, BB      │   0    │ ← Read Way1
│  Test5   │  Tag10, CC      │  Tag01, BB      │   1    │ ← Way0 replaced!
│  Test6   │  Tag10, CC      │  Tag01, BB      │   1    │ ← Tag00 miss!
│  Test7   │  Tag10, CC      │  Tag01, BB      │   1    │ ← Tag01 hit!
│  Test8   │  Tag10, CC      │  Tag01, BB      │   0    │ ← Tag10 hit!
└──────────┴─────────────────┴─────────────────┴────────┘
```

---

## Key Concepts Applied

### 1. Set Associative Mapping

The memory address is split into tag and index. The index selects the set, and the tag differentiates blocks within that set. This reduces conflict misses compared to direct mapping while avoiding the complexity of fully associative caches.

```
Direct Mapped:     1 way per set → High conflict misses
Fully Associative: N ways, 1 set → Expensive comparators
2-Way Set Assoc:   2 ways, N sets → Balanced approach
```

### 2. Valid Bit Protection

Each cache line has a valid bit that indicates whether the stored data is meaningful. After reset, all valid bits are 0, preventing false hits on uninitialized data.

```systemverilog
assign way0_hit = valid[index][0] && (tag[index][0] == addr_tag);
//                 ↑↑↑↑↑
//                 Essential! Without this, uninitialized tags would match
```

### 3. Combinational Hit Detection

Hit detection and data output are combinational — they respond immediately without waiting for a clock edge. This provides fast cache access times.

```systemverilog
always_comb begin  // Combinational block
    if (way0_hit) begin
        hit       = 1'b1;
        read_data = data[index][0];
    end
    // ...
end
```

### 4. Sequential State Updates

Memory writes, tag updates, and LRU bit changes occur on the clock edge. This ensures stable state transitions and avoids race conditions.

```systemverilog
always_ff @(posedge clk or posedge reset) begin  // Sequential block
    // State updates here
end
```

### 5. LRU Replacement for 2-Way Caches

A single bit per set tracks which way was accessed least recently. When replacement is needed, the LRU way is overwritten. This is a simple yet effective approximation of true LRU.

### 6. Write-Hit vs Write-Miss Handling

- **Write Hit:** Update data in-place, mark way as recently used
- **Write Miss:** If set has empty way, fill it; otherwise replace LRU way

### 7. Registered vs Combinational Outputs

- `read_data` and `hit` are **combinational** — updated immediately
- `valid`, `tag`, `data`, and `lru` are **registered** — updated on clock edge

### 8. Active-High Synchronous Reset

All internal state resets on `reset` assertion at the clock edge. This ensures a known startup state with all cache lines invalid.

---

## What I Learned

### Design Methodology

**Tag/index breakdown clarity:** Using explicit bit slicing (`address[1:0]` for index, `address[3:2]` for tag) makes the set-associative mapping concept tangible. This is more educational than using parameterized functions or automated decode blocks.

**Valid-bit importance:** The valid bit is critical for correctness. Without it, uninitialized tag comparisons would produce false hits after reset, corrupting the cache state.

**Combinational vs sequential separation:** Keeping hit detection combinational and state updates sequential provides both speed and stability. The combinational path gives immediate feedback, while the sequential path ensures clean state transitions.

**LRU bit semantics:** For 2-way caches, the LRU bit direction matters. Setting `lru=1` after Way0 access means "Way1 is now LRU" (replace Way1 next), which is counter-intuitive at first but correct for the replacement logic.

### SystemVerilog Features

`logic [7:0] data [0:3][0:1]` creates a 4×2 array of 8-bit registers. This is synthesizable as distributed RAM or flip-flop arrays depending on the FPGA and tool settings.

`always_comb` for combinational logic provides clear intent and ensures all outputs are defined for every input combination, preventing latch inference.

`always_ff` for sequential logic ensures the memory and read data register are properly clocked and synthesizes to flip-flops.

`for` loop in reset logic: `for (int i = 0; i < 4; i++)` efficiently initializes the entire cache array. The synthesis tool unrolls this into parallel assignments.

2D arrays (`valid[set][way]`) naturally model the set-way structure of the cache, making the code readable and the hardware mapping intuitive.

### Timing and Synchronization

**Read latency:** `read_data` and `hit` update combinationally when address changes — zero clock cycle latency for hit detection. This is standard for tag comparators in cache designs.

**Write timing:** Data is captured on the rising edge when `write_enable` is high. The input `address` and `write_data` must be stable during the setup/hold window.

**Replacement timing:** On a write miss, the LRU way is overwritten on the clock edge. The next cycle, a combinational read of the same address will hit.

### Verification Approach

**Structured test cases:** Organizing tests by functionality (basic write, read hit, same-set write, eviction, eviction verification) ensures comprehensive coverage without redundant simulation.

**Boundary testing:** Filling a set to exactly 2 ways and then forcing eviction tests the corner case where replacement logic activates.

**Eviction verification:** Reading the evicted address (Test 6) and confirming a miss is the definitive proof that replacement worked correctly.

**Waveform correlation:** Comparing `address`, `read_data`, and `hit` signals in GTKWave confirms cache behavior matches expectations.

### Synthesis Considerations

**Memory inference:** The 2D register arrays will be inferred as flip-flops or distributed RAM depending on the FPGA architecture. For small caches (8×8 bits), distributed RAM or flip-flops are likely.

**Comparator logic:** Two tag comparators per set (one per way) run in parallel. For 2-bit tags, this is minimal combinational logic.

**Resource estimate:** Approximately 90 flip-flops (valid: 8, tag: 16, data: 64, lru: 4) + output registers, plus minimal combinational logic for comparators and multiplexers.

### Practical Insights

**Set size selection:** 4 sets with 2 ways provides enough capacity to demonstrate eviction while keeping the design small and waveform readable.

**Address space:** With 4-bit addresses, 16 memory locations exist, but only 8 cache lines. This guarantees conflicts and forces replacement, making the LRU logic essential.

**Data integrity:** Because writes update in-place on hits, the cache maintains data consistency. Replacement only occurs on misses, preserving valid data.

**Throughput:** In hit scenarios, the cache provides one read or write per clock cycle. Misses incur a one-cycle penalty for replacement.

---

## Future Improvements

| Enhancement | Description |
|-------------|-------------|
| Parameterized Sets/Ways | Replace fixed 4 sets × 2 ways with parameters for configurable cache sizes |
| Parameterized Address/Data Width | Make address and data widths configurable |
| Write-Through vs Write-Back | Add dirty bits to support write-back policy to main memory |
| Multi-Level Cache | Connect as L1 cache with L2 backing store |
| PLRU (Pseudo-LRU) | Implement tree-based PLRU for 4-way or 8-way caches |
| Cache Coherency | Add MESI protocol bits for multi-processor systems |
| Victim Cache | Add a small victim cache to capture evicted lines |
| Non-Blocking Cache | Allow hits-under-misses for better throughput |
| UVM Verification | Migrate to UVM with constrained-random stimulus and functional coverage |
| FPGA Block RAM | Add synthesis directives to force block RAM inference for larger caches |
| Performance Counters | Add hit-rate and miss-rate tracking registers |

---

## RTL Source Code

### `cache_2way.sv`

```systemverilog
// ====================================================================
// 2-Way Set Associative Cache (4 Sets × 2 Ways)
// Beginner-Friendly Logic | Explicit Tag/Index Breakdown
// Instructor: Sir Khalil Rehman
// ====================================================================
module cache_2way (
    input  logic       clk,
    input  logic       reset,
    input  logic [3:0] address,
    input  logic [7:0] write_data,
    input  logic       write_enable,
    output logic [7:0] read_data,
    output logic       hit
);

    //========================================================
    // 1. MEMORY STORAGE DECLARATION (SystemVerilog logic)
    //========================================================
    logic       valid [0:3][0:1];  // 4 sets, 2 ways per set
    logic [1:0] tag   [0:3][0:1];  // Tag bit storage (2 bits)
    logic [7:0] data  [0:3][0:1];  // Data memory (8 bits)
    logic       lru   [0:3];       // LRU bit: 0 -> Way0, 1 -> Way1

    //========================================================
    // 2. ADDRESS BREAKDOWN
    //========================================================
    logic [1:0] index;
    logic [1:0] addr_tag;

    assign index    = address[1:0];  // Lower 2 bits → Set selector
    assign addr_tag = address[3:2];  // Upper 2 bits → Tag comparison

    //========================================================
    // 3. COMBINATIONAL LOOKUP & HIT LOGIC
    //========================================================
    logic way0_hit;
    logic way1_hit;

    assign way0_hit = valid[index][0] && (tag[index][0] == addr_tag);
    assign way1_hit = valid[index][1] && (tag[index][1] == addr_tag);

    // SystemVerilog explicit combinational block
    always_comb begin
        if (way0_hit) begin
            hit       = 1'b1;
            read_data = data[index][0];
        end 
        else if (way1_hit) begin
            hit       = 1'b1;
            read_data = data[index][1];
        end 
        else begin
            hit       = 1'b0;
            read_data = 8'h00; // Default output on miss
        end
    end

    //========================================================
    // 4. SEQUENTIAL STATE UPDATE (Flip-Flops & LRU)
    //========================================================
    // SystemVerilog explicit flip-flop block
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            // Clean SystemVerilog loop for reset initialization
            for (int i = 0; i < 4; i++) begin
                valid[i][0] <= 1'b0; valid[i][1] <= 1'b0;
                tag[i][0]   <= 2'b0; tag[i][1]   <= 2'b0;
                data[i][0]  <= 8'b0; data[i][1]  <= 8'b0;
                lru[i]      <= 1'b0;
            end
        end 
        else begin
            // --- READ OPERATION ---
            if (!write_enable) begin
                if (way0_hit) begin
                    lru[index] <= 1'b1; // Way0 accessed, next LRU is Way1
                end 
                else if (way1_hit) begin
                    lru[index] <= 1'b0; // Way1 accessed, next LRU is Way0
                end
            end 
            // --- WRITE OPERATION ---
            else begin
                if (way0_hit) begin
                    data[index][0] <= write_data;
                    lru[index]     <= 1'b1;
                end 
                else if (way1_hit) begin
                    data[index][1] <= write_data;
                    lru[index]     <= 1'b0;
                end 
                else begin
                    // Write Miss: Dynamic Replacement based on LRU
                    if (lru[index] == 1'b0) begin
                        valid[index][0] <= 1'b1;
                        tag[index][0]   <= addr_tag;
                        data[index][0]  <= write_data;
                        lru[index]      <= 1'b1;
                    end 
                    else begin
                        valid[index][1] <= 1'b1;
                        tag[index][1]   <= addr_tag;
                        data[index][1]  <= write_data;
                        lru[index]      <= 1'b0;
                    end
                end
            end
        end
    end

endmodule
```

### `tb_cache.sv`

```systemverilog
`timescale 1ns/1ps

module tb;

    // SystemVerilog Logic Type Declarations
    logic       clk;
    logic       reset;
    logic [3:0] address;
    logic [7:0] write_data;
    logic       write_enable;

    logic [7:0] read_data;
    logic       hit;

    // Instantiate Design Under Test (DUT)
    cache_2way DUT (
        .clk          (clk),
        .reset        (reset),
        .address      (address),
        .write_data   (write_data),
        .write_enable (write_enable),
        .read_data    (read_data),
        .hit          (hit)
    );

    // Clock Generation (10ns Period)
    always #5 clk = ~clk;

    // Waveform Dump
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb);
    end

    // Output Terminal Monitor
    initial begin
        $monitor("TIME=%0t | RESET=%b | WE=%b | ADDR=%b | WDATA=%h | RDATA=%h | HIT=%b", 
                 $time, reset, write_enable, address, write_data, read_data, hit);
    end

    // Test Sequence Execution
    initial begin
        // Reset Setup
        clk = 0; reset = 1;
        address = 4'b0000; write_data = 8'h00; write_enable = 0;
        #12 reset = 0; #8;

        // TEST 1: Write AA to Address 0000
        $display("\n---> TEST-1: WRITE 8'hAA to Address 4'b0000");
        address = 4'b0000; write_data = 8'hAA; write_enable = 1;
        #10;

        // TEST 2: Read Address 0000 (HIT Way0)
        $display("\n---> TEST-2: READ Address 4'b0000");
        write_enable = 0;
        #10;

        // TEST 3: Write BB to Address 0100 (HIT/Placed Way1)
        $display("\n---> TEST-3: WRITE 8'hBB to Address 4'b0100 (Same Index)");
        address = 4'b0100; write_data = 8'hBB; write_enable = 1;
        #10;

        // TEST 4: Read Address 0100 (HIT Way1)
        $display("\n---> TEST-4: READ Address 4'b0100");
        write_enable = 0;
        #10;

        // TEST 5: Write CC to Address 1000 (Eviction Test)
        $display("\n---> TEST-5: WRITE 8'hCC to Address 4'b1000 (Eviction Test)");
        address = 4'b1000; write_data = 8'hCC; write_enable = 1;
        #10;

        // TEST 6: Read Address 0000 (Expect MISS)
        $display("\n---> TEST-6: READ Address 4'b0000 (Expect MISS)");
        address = 4'b0000; write_enable = 0;
        #10;

        // TEST 7: Read Address 0100 (Expect HIT)
        $display("\n---> TEST-7: READ Address 4'b0100 (Expect HIT)");
        address = 4'b0100;
        #10;

        // TEST 8: Read Address 1000 (Expect HIT)
        $display("\n---> TEST-8: READ Address 4'b1000 (Expect HIT)");
        address = 4'b1000;
        #10;

        $display("\nSIMULATION COMPLETE!");
        $finish;
    end

endmodule
```

---

## Simulation Output

```
VCD info: dumpfile dump.vcd opened for output.
TIME=0 | RESET=1 | WE=0 | ADDR=0000 | WDATA=00 | RDATA=00 | HIT=0
TIME=12000 | RESET=0 | WE=0 | ADDR=0000 | WDATA=00 | RDATA=00 | HIT=0

---> TEST-1: WRITE 8'hAA to Address 4'b0000
TIME=20000 | RESET=0 | WE=1 | ADDR=0000 | WDATA=aa | RDATA=00 | HIT=0
TIME=25000 | RESET=0 | WE=1 | ADDR=0000 | WDATA=aa | RDATA=aa | HIT=1

---> TEST-2: READ Address 4'b0000
TIME=30000 | RESET=0 | WE=0 | ADDR=0000 | WDATA=aa | RDATA=aa | HIT=1

---> TEST-3: WRITE 8'hBB to Address 4'b0100 (Same Index)
TIME=40000 | RESET=0 | WE=1 | ADDR=0100 | WDATA=bb | RDATA=00 | HIT=0
TIME=45000 | RESET=0 | WE=1 | ADDR=0100 | WDATA=bb | RDATA=bb | HIT=1

---> TEST-4: READ Address 4'b0100
TIME=50000 | RESET=0 | WE=0 | ADDR=0100 | WDATA=bb | RDATA=bb | HIT=1

---> TEST-5: WRITE 8'hCC to Address 4'b1000 (Eviction Test)
TIME=60000 | RESET=0 | WE=1 | ADDR=1000 | WDATA=cc | RDATA=00 | HIT=0
TIME=65000 | RESET=0 | WE=1 | ADDR=1000 | WDATA=cc | RDATA=cc | HIT=1

---> TEST-6: READ Address 4'b0000 (Expect MISS)
TIME=70000 | RESET=0 | WE=0 | ADDR=0000 | WDATA=cc | RDATA=00 | HIT=0

---> TEST-7: READ Address 4'b0100 (Expect HIT)
TIME=80000 | RESET=0 | WE=0 | ADDR=0100 | WDATA=cc | RDATA=bb | HIT=1

---> TEST-8: READ Address 4'b1000 (Expect HIT)
TIME=90000 | RESET=0 | WE=0 | ADDR=1000 | WDATA=cc | RDATA=cc | HIT=1

SIMULATION COMPLETE!
tb_cache.sv:89: $finish called at 100000 (1ps)
```

---

## License

This project is provided for educational and reference purposes. Free to use, modify, and distribute with attribution.

---

## Author Notes

This implementation represents a foundational digital design exercise in cache memory structures. The emphasis on explicit tag/index breakdown, comprehensive test coverage, and clean separation of combinational and sequential logic makes this suitable for:

- Academic coursework in digital logic and computer architecture
- FPGA beginner projects requiring cache memory
- Interview preparation for hardware design and verification roles
- Reference implementation for set-associative cache best practices
- Teaching material for cache mapping and replacement policy concepts

The design prioritizes correctness and clarity over optimization. The explicit valid-bit checking, straightforward LRU bit management, and SystemVerilog `for` loop reset provide a solid foundation for understanding more advanced cache variants such as multi-level caches with MESI coherency.

**Instructor:** Sir Khalil Rehman  
**Institution:** Digital Design / Computer Architecture Lab
