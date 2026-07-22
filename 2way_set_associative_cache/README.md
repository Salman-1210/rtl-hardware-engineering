#  2-Way Set Associative Cache — Verilog Implementation

> **Course:** Digital Design / Computer Architecture Lab  
> **Module:** Cache Memory Design  
> **Language:** Verilog HDL  
> **Simulator:** Icarus Verilog (iverilog + vvp) + GTKWave  
> **Instructor Reference:** Self-Guided Project with Standard Digital Design Principles  

---

##  Table of Contents

1. [Project Overview](#1-project-overview)
2. [Cache Architecture Theory](#2-cache-architecture-theory)
3. [Module: `cache_2way.v`](#3-module-cache_2wayv)
4. [Testbench: `tb_cache.v`](#4-testbench-tb_cachev)
5. [Address Breakdown Deep Dive](#5-address-breakdown-deep-dive)
6. [LRU Replacement Policy Explained](#6-lru-replacement-policy-explained)
7. [Simulation Output Analysis](#7-simulation-output-analysis)
8. [GTKWave Waveform Analysis](#8-gtkwave-waveform-analysis)
9. [How to Run](#9-how-to-run)

---

## 1. Project Overview

###  Objective
Design and simulate a **2-Way Set Associative Cache** in Verilog that supports:
- **Read operations** with hit/miss detection
- **Write operations** (write-hit and write-miss with replacement)
- **LRU (Least Recently Used)** replacement policy
- Full reset capability

###  Specifications
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

---

## 2. Cache Architecture Theory

### 🔹 What is Set Associative Mapping?

```
┌─────────────────────────────────────────────────────────────┐
│                    MAIN MEMORY (16 locations)                │
│  Address: 0000 to 1111 (4-bit address = 16 bytes)            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              CACHE MEMORY (8 lines, 2-way associative)      │
│                                                             │
│   ┌─────────────┐  ┌─────────────┐                        │
│   │   SET 0     │  │   SET 1     │                        │
│   │ ┌───┬───┐   │  │ ┌───┬───┐   │                        │
│   │ │Way│Way│   │  │ │Way│Way│   │                        │
│   │ │ 0 │ 1 │   │  │ │ 0 │ 1 │   │                        │
│   │ └───┴───┘   │  │ └───┴───┘   │                        │
│   └─────────────┘  └─────────────┘                        │
│   ┌─────────────┐  ┌─────────────┐                        │
│   │   SET 2     │  │   SET 3     │                        │
│   │ ┌───┬───┐   │  │ ┌───┬───┐   │                        │
│   │ │Way│Way│   │  │ │Way│Way│   │                        │
│   │ │ 0 │ 1 │   │  │ │ 0 │ 1 │   │                        │
│   │ └───┴───┘   │  │ └───┴───┘   │                        │
│   └─────────────┘  └─────────────┘                        │
└─────────────────────────────────────────────────────────────┘
```

### 🔹 Address Splitting

```
4-bit Address: [3:2] | [1:0]
               Tag    | Index
               ───────┼───────
                 2    |   2
```

| Field | Bits | Purpose |
|-------|------|---------|
| **Tag** | [3:2] | Identifies which memory block is stored |
| **Index** | [1:0] | Selects which set to look in (0-3) |

### 🔹 Why 2-Way Associative?

- **Direct Mapped**: Simple but suffers from conflict misses
- **Fully Associative**: No conflicts but expensive (large comparator)
- **2-Way Set Associative**: Sweet spot — reduces conflicts while keeping hardware reasonable

---

## 3. Module: `cache_2way.v`

###  File Structure
```
cache_2way.v
├── Port Declarations
├── Memory Storage Arrays
├── Address Breakdown (Combinational)
├── Hit Detection Logic (Combinational)
├── Output Assignment (Combinational)
└── State Update (Sequential)
```

###  Port Interface

```verilog
module cache_2way(
    input  wire        clk,           // Clock signal
    input  wire        reset,         // Active-high reset
    input  wire [3:0]  address,       // 4-bit memory address
    input  wire [7:0]  write_data,    // 8-bit data to write
    input  wire        write_enable,  // 1=Write, 0=Read
    output reg  [7:0]  read_data,     // 8-bit data read from cache
    output reg         hit            // 1=Hit, 0=Miss
);
```

###  Memory Storage Declaration

```verilog
// Valid bit: Tells if cache line contains valid data
reg valid [0:3][0:1];      // [set][way] → 4 sets × 2 ways

// Tag storage: Identifies which memory block is cached
reg [1:0] tag [0:3][0:1];  // [set][way] → 2-bit tag

// Data storage: Actual cached data
reg [7:0] data [0:3][0:1]; // [set][way] → 8-bit data

// LRU bit: Tracks which way was used least recently
reg lru [0:3];             // [set] → 0=Way0 is LRU, 1=Way1 is LRU
```

**Why these dimensions?**
- `valid[0:3][0:1]` → 4 sets, each with 2 ways
- `tag[0:3][0:1]` → Each cache line needs a tag to identify the memory block
- `data[0:3][0:1]` → Each cache line stores 8-bit data
- `lru[0:3]` → Only 1 bit needed per set for 2-way (0 or 1)

###  Address Breakdown (Combinational)

```verilog
wire [1:0] index;      // Selects the set
wire [1:0] addr_tag; // Tag from incoming address

assign index    = address[1:0];  // Lower 2 bits → Set selector
assign addr_tag = address[3:2];  // Upper 2 bits → Tag comparison
```

**Example:**
| Address | Binary | Tag [3:2] | Index [1:0] | Set |
|---------|--------|-----------|-------------|-----|
| 0 | `0000` | `00` | `00` | Set 0 |
| 4 | `0100` | `01` | `00` | Set 0 |
| 8 | `1000` | `10` | `00` | Set 0 |
| 1 | `0001` | `00` | `01` | Set 1 |

> **Key Insight:** Addresses 0, 4, 8 all map to **Set 0** but have **different tags**!

###  Hit Detection Logic (Combinational)

```verilog
wire way0_hit;
wire way1_hit;

// Way0 Hit: Valid must be 1 AND tag must match
assign way0_hit = valid[index][0] && (tag[index][0] == addr_tag);

// Way1 Hit: Valid must be 1 AND tag must match
assign way1_hit = valid[index][1] && (tag[index][1] == addr_tag);
```

**Why `&& valid` is necessary?**
- Without valid check, a tag match on an uninitialized line would falsely report a hit
- After reset, all valid bits are 0 → no false hits

###  Output Assignment (Combinational)

```verilog
always @(*) begin
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
        read_data = 8'h00;  // Default on miss
    end
end
```

**Why `always @(*)`?**
- This is combinational logic → output changes immediately when inputs change
- No clock needed for read → fast access
- Real caches use this for hit detection and data output

###  Sequential State Update (Clocked)

```verilog
always @(posedge clk or posedge reset) begin
    if (reset) begin
        // Reset all storage to known state
        valid[0][0] <= 0; valid[0][1] <= 0; 
        tag[0][0]   <= 0; tag[0][1]   <= 0;
        data[0][0]  <= 0; data[0][1]  <= 0;
        lru[0]      <= 0;
        // ... repeat for all 4 sets
    end 
    else begin
        // READ OPERATION
        if (write_enable == 1'b0) begin
            if (way0_hit)      lru[index] <= 1'b1;  // Way0 used → Way1 is now LRU
            else if (way1_hit) lru[index] <= 1'b0;  // Way1 used → Way0 is now LRU
        end 
        // WRITE OPERATION
        else begin
            if (way0_hit) begin
                data[index][0] <= write_data;  // Update data
                lru[index]     <= 1'b1;        // Mark Way0 as recently used
            end 
            else if (way1_hit) begin
                data[index][1] <= write_data;
                lru[index]     <= 1'b0;
            end 
            else begin  // WRITE MISS → Replace LRU way
                if (lru[index] == 1'b0) begin
                    // Way0 is LRU → Replace it
                    valid[index][0] <= 1'b1;
                    tag[index][0]   <= addr_tag;
                    data[index][0]  <= write_data;
                    lru[index]      <= 1'b1;  // Way0 now fresh, Way1 is LRU
                end 
                else begin
                    // Way1 is LRU → Replace it
                    valid[index][1] <= 1'b1;
                    tag[index][1]   <= addr_tag;
                    data[index][1]  <= write_data;
                    lru[index]      <= 1'b0;  // Way1 now fresh, Way0 is LRU
                end
            end
        end
    end
end
```

###  LRU Logic Deep Dive

```
LRU Bit Interpretation:
┌─────────┬────────────────────────────────────────────┐
│ lru[i]  │ Meaning                                    │
├─────────┼────────────────────────────────────────────┤
│    0    │ Way0 was used LEAST recently → REPLACE Way0│
│    1    │ Way1 was used LEAST recently → REPLACE Way1│
└─────────┴────────────────────────────────────────────┘

State Transitions:
┌──────────────┬──────────────────┬─────────────────────┐
│   Access     │   Previous LRU   │   New LRU           │
├──────────────┼──────────────────┼─────────────────────┤
│ Way0 Hit     │       X          │        1            │
│ Way1 Hit     │       X          │        0            │
│ Replace Way0 │       0          │        1            │
│ Replace Way1 │       1          │        0            │
└──────────────┴──────────────────┴─────────────────────┘
```

---

## 4. Testbench: `tb_cache.v`

###  File Structure
```
tb_cache.v
├── Signal Declarations
├── DUT Instantiation
├── Clock Generation (10ns period)
├── VCD Dump Setup
├── Real-Time Monitor
└── Test Sequence (8 Tests)
```

###  Clock Generation

```verilog
always #5 clk = ~clk;  // 10ns period = 100MHz
```

###  Test Sequence Overview

| Test | Operation | Address | Data | Expected Result |
|------|-----------|---------|------|-----------------|
| 1 | Write | `0000` (Set0, Tag00) | `AA` | Miss → Way0 fill |
| 2 | Read | `0000` (Set0, Tag00) | — | Hit → `AA` |
| 3 | Write | `0100` (Set0, Tag01) | `BB` | Miss → Way1 fill |
| 4 | Read | `0100` (Set0, Tag01) | — | Hit → `BB` |
| 5 | Write | `1000` (Set0, Tag10) | `CC` | Miss → Evict Way0 (LRU) |
| 6 | Read | `0000` (Set0, Tag00) | — | Miss (evicted!) |
| 7 | Read | `0100` (Set0, Tag01) | — | Hit → `BB` |
| 8 | Read | `1000` (Set0, Tag10) | — | Hit → `CC` |

###  Why These Tests?

```
Set 0 State Evolution:
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

## 5. Address Breakdown Deep Dive

### Binary Analysis of Test Addresses

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

> **All three addresses map to Set 0!** This is intentional to force eviction.

---

## 6. LRU Replacement Policy Explained

### Concept
LRU replaces the cache line that has been **least recently accessed**.

### Why 1 Bit is Enough for 2-Way?

```
For 2-way: Only need to track which ONE way is older
┌─────────────┬────────────────────────────────────────┐
│   LRU Bit   │   Interpretation                     │
├─────────────┼────────────────────────────────────────┤
│     0       │   Way0 is older → Replace Way0       │
│     1       │   Way1 is older → Replace Way1       │
└─────────────┴────────────────────────────────────────┘

For N-way: Need log₂(N) bits per set
• 2-way: 1 bit
• 4-way: 2 bits  
• 8-way: 3 bits
```

### LRU Update Rules (Your Implementation)

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

---

## 7. Simulation Output Analysis

### Terminal Output

```
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
tb_cache.v:89: $finish called at 100000 (1ps)
```

###  Line-by-Line Analysis

| Time | Event | Explanation |
|------|-------|-------------|
| 0ns | Reset active | All cache lines invalid, outputs zero |
| 12ns | Reset released | Cache ready for operations |
| 20ns | **Test 1: Write AA @ 0000** | Write miss (empty cache). Data written to Way0 of Set 0 |
| 25ns | Next cycle | Combinational read shows `RDATA=AA, HIT=1` (write-through visible) |
| 30ns | **Test 2: Read @ 0000** | Hit! Way0 contains Tag00+AA. LRU updated to 1 |
| 40ns | **Test 3: Write BB @ 0100** | Write miss (Tag01 ≠ Tag00). Way1 of Set 0 used |
| 45ns | Next cycle | `RDATA=BB, HIT=1`. LRU updated to 0 |
| 50ns | **Test 4: Read @ 0100** | Hit! Way1 contains Tag01+BB. LRU stays 0 |
| 60ns | **Test 5: Write CC @ 1000** | Write miss (Tag10 ≠ Tag00, ≠ Tag01). Set 0 full! |
| | | LRU=0 → Way0 is least recent → **Way0 EVICTED**, replaced with Tag10+CC |
| 65ns | Next cycle | `RDATA=CC, HIT=1`. LRU updated to 1 |
| 70ns | **Test 6: Read @ 0000** | **MISS!** Way0 now has Tag10, Way1 has Tag01. Tag00 not found! |
| 80ns | **Test 7: Read @ 0100** | **HIT!** Way1 still has Tag01+BB. Correctly preserved! |
| 90ns | **Test 8: Read @ 1000** | **HIT!** Way0 has Tag10+CC. Replacement successful! |

---

## 8. GTKWave Waveform Analysis

### Waveform Overview

```
Time(ns):  0      10      20      30      40      50      60      70      80      90     100
           │       │       │       │       │       │       │       │       │       │       │
clk:       ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐
           └─┘   └─┘   └─┘   └─┘   └─┘   └─┘   └─┘   └─┘   └─┘   └─┘   └─┘   └─┘   └─┘   └─┘

reset:     ████████
                    └─────────────────────────────────────────────────────────────────────────

address:   0       0       0       0       4       4       8       0       4       8
           [0000]  [0000]  [0000]  [0000]  [0100]  [0100]  [1000]  [0000]  [0100]  [1000]

write_data:00      00      AA      AA      AA      BB      BB      CC      CC      CC

write_en:  0       0       1       1       1       1       1       0       0       0

read_data: 00      00      00      AA      AA      00      BB      00      00      BB
                                          ↑miss   ↑hit              ↑miss   ↑hit

hit:       0       0       0       1       1       0       1       0       1       1
```

### Signal-by-Signal Analysis

#### `address[3:0]` (Input)
- **0-12ns**: `0000` (reset period)
- **20ns**: `0000` (Test 1)
- **40ns**: `0100` (Test 3) — Same index (00), different tag (01)
- **60ns**: `1000` (Test 5) — Same index (00), tag (10) — triggers eviction
- **70ns**: `0000` (Test 6) — Should miss (was evicted!)

#### `read_data[7:0]` (Output)
- **Combinational behavior**: Changes immediately when address/tag match
- **20ns**: `00` (miss, cache empty)
- **25ns**: `AA` (hit, Way0 has AA)
- **40ns**: `00` (miss, Tag01 not in cache yet)
- **45ns**: `BB` (hit, Way1 now has BB)
- **70ns**: `00` (MISS! Tag00 was evicted from Way0)  **Key verification**

#### `hit` (Output)
- **0ns**: 0 (reset, no valid data)
- **20ns**: 0 (first write miss)
- **25ns**: 1 (write hit — combinational read sees written data)
- **40ns**: 0 (write miss — new tag)
- **70ns**: 0 (READ MISS — eviction confirmed!) 

#### `write_enable`
- High during write operations (Tests 1, 3, 5)
- Low during read operations (Tests 2, 4, 6, 7, 8)

---

## 9. How to Run

### Prerequisites
- Icarus Verilog (`iverilog`)
- GTKWave (for waveform viewing)

### Compilation & Simulation

```bash
# Step 1: Compile
iverilog -o cache_sim.vvp cache_2way.v tb_cache.v

# Step 2: Run simulation
vvp cache_sim.vvp

# Step 3: View waveforms
gtkwave dump.vcd
```

### Expected Output

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
tb_cache.v:89: $finish called at 100000 (1ps)
```


##  Verification Summary

| Test | Description | Result |
|------|-------------|--------|
| Write Miss (Empty Cache) | AA @ 0000 |  Way0 filled |
| Read Hit | 0000 |  Returns AA |
| Write Miss (Same Set, Other Way) | BB @ 0100 |  Way1 filled |
| Read Hit | 0100 |  Returns BB |
| Write Miss (Set Full, Eviction) | CC @ 1000 |  Way0 evicted, CC placed |
| Read Miss (Evicted Data) | 0000 |  Correctly misses |
| Read Hit (Surviving Data) | 0100 |  Returns BB |
| Read Hit (New Data) | 1000 |  Returns CC |

---

##  Key Learning Outcomes

1. **Set Associative Mapping**: Addresses map to sets, tags differentiate blocks within a set
2. **Valid Bit Importance**: Prevents false hits on uninitialized data
3. **LRU Replacement**: Simple 1-bit implementation for 2-way caches
4. **Combinational vs Sequential**: Hit detection is combinational (fast), state updates are sequential (stable)
5. **Write Policies**: Write-hit updates data in-place; write-miss triggers replacement

---

##  Notes

- This is an **educational implementation** focusing on clarity
- Real-world caches include: dirty bits, write-back to main memory, byte enables, etc.
- The manual unrolling of reset logic (instead of `for` loops) improves synthesis compatibility and readability

---

