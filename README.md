# RTL Hardware Engineering — SystemVerilog Learning Repository

A structured collection of hands-on digital design projects developed as part of a Chip Design course covering RTL fundamentals and industrial protocols. Each module includes synthesizable SystemVerilog RTL, self-checking testbenches, and comprehensive documentation.

---

## Course Information

| Field | Details |
|-------|---------|
| **Course** | Chip Design (RTL & Industrial Protocols) |
| **Instructor** | Sir Khalil Rehman |
| **Focus Area** | Digital RTL Design, Finite State Machines, Memory Interfaces, Bus Protocols |
| **Language** | SystemVerilog (IEEE 1800-2017) |
| **Target Platform** | FPGA (Xilinx/Intel) and ASIC Synthesis |

---

## Repository Structure

```
rtl-hardware-engineering/
|
|-- apb_slave_ram/                  # Task : APB Slave RAM (AMBA Protocol)
|   |-- README.md
|   |-- apb_slave_ram.sv
|   |-- apb_slave_ram_tb.sv
|   |-- apb_slave_ram_waveform.png
|
|-- fifo_8bit/                      # Task : 8-bit FIFO Buffer (Depth = 8)
|   |-- README.md
|   |-- fifo_8bit.sv
|   |-- fifo_8bit_tb.sv
|   |-- fifo_8bit_waveform.png
|
|-- sequence_detector/              # Task : Sequence Detector (FSM)
|   |-- README.md
|   |-- seq_detector.sv
|   |-- seq_detector_tb.sv
|   |-- seq_detector_waveform.png
|
|-- traffic_light/                  # Task : Traffic Light Controller (Moore FSM)
|   |-- README.md
|   |-- traffic_light.sv
|   |-- traffic_light_tb.sv
|   |-- traffic_fsm_waveform.png
|
|
|-- vending_machine/                # Task : Vending Machine Controller (Moore FSM)
|   |-- README.md
|   |-- vending_machine.sv
|   |-- vending_machine_tb.sv
|   |-- vending_fsm_waveform.png
|
|-- .gitignore
|-- README.md                       # This file
```

---

## Current Progress

### Completed Modules

| # | Module | Concept | Complexity |
|---|--------|---------|------------|
| 1 | **Traffic Light Controller** | Moore FSM with integrated timer | Beginner |
| 2 | **Vending Machine Controller** | Multi-state Moore FSM with input accumulation | Beginner |
| 3 | **8-bit FIFO Buffer** | Circular buffer with pointer arithmetic | Intermediate |
| 4 | **APB Slave RAM** | AMBA APB protocol slave implementation | Intermediate |
| 5 | **Sequence Detector** | Pattern recognition FSM | Intermediate |

### Design Methodology

Every module in this repository follows a consistent development pattern:

1. **Specification Analysis** — Understand requirements and derive state diagrams or block diagrams
2. **RTL Coding** — Implement in SystemVerilog using `always_ff` for sequential and `always_comb` for combinational logic
3. **Testbench Development** — Build self-checking testbenches with VCD dump for waveform analysis
4. **Simulation & Verification** — Run with Icarus Verilog, analyze in GTKWave, verify against expected behavior
5. **Documentation** — Write comprehensive README with architecture, timing diagrams, and lessons learned

---

## What We Are Learning

### Core RTL Concepts

| Topic | Status | Application |
|-------|--------|-------------|
| Moore vs Mealy FSM | Completed | Traffic Light, Vending Machine, Sequence Detector |
| State Encoding (`enum`) | Completed | All FSM modules |
| Three-Block FSM Structure | Completed | All FSM modules |
| Counter Integration | Completed | Traffic Light (timer), FIFO (pointer tracking) |
| Circular Buffer Design | Completed | FIFO (wr_ptr/rd_ptr with natural overflow) |
| Combinational Flag Generation | Completed | FIFO (full/empty), APB (pready) |
| Registered Outputs | Completed | FIFO (data_out), APB (prdata) |
| Overflow/Underflow Protection | Completed | FIFO (enable gating), Vending Machine (exact/overpay) |

### Industrial Protocols

| Protocol | Status | Module |
|----------|--------|--------|
| **AMBA APB** | Completed | APB Slave RAM |
| AMBA AHB | Planned | Future bridge module |
| AMBA AXI4-Lite | Planned | Future high-performance peripheral |
| UART | Planned | Future serial communication module |
| SPI | Planned | Future flash/memory interface |
| I2C | Planned | Future sensor interface |

### Verification Techniques

| Technique | Status | Application |
|-----------|--------|-------------|
| Self-Checking Testbenches | Completed | All modules |
| VCD Waveform Analysis | Completed | All modules (GTKWave) |
| Console Logging (`$display`) | Completed | All modules |
| Boundary Condition Testing | Completed | FIFO (full/empty), Vending Machine (exact/overpay) |
| Protocol Phase Checking | Completed | APB (SETUP/ACCESS) |
| Coverage Matrices | Completed | All modules |

---

## Future Roadmap

### Short Term (Next 4-6 Weeks)

| Module | Concept | Protocol / Technique |
|--------|---------|---------------------|
| **UART Transceiver** | Serial communication, baud rate generation | UART (TX/RX) |
| **SPI Master** | Synchronous serial, clock polarity/phase | SPI Mode 0-3 |
| **I2C Controller** | Open-drain bus, start/stop conditions | I2C |
| **AXI4-Lite Slave** | High-performance bus, burst transfers | AMBA AXI4-Lite |
| **PWM Generator** | Duty cycle control, frequency generation | N/A |

### Medium Term (Next 2-3 Months)

| Module | Concept | Goal |
|--------|---------|------|
| **RISC-V Core (RV32I)** | 5-stage pipeline, hazard detection | CPU architecture |
| **Cache Controller** | Direct-mapped cache, hit/miss logic | Memory hierarchy |
| **DMA Controller** | Burst transfers, scatter-gather | System performance |
| **DDR3 Memory Interface** | PHY layer, timing calibration | High-speed memory |
| **PCIe Endpoint** | TLP packets, configuration space | High-speed IO |

### Long Term (6+ Months)

| Goal | Description |
|------|-------------|
| **Complete SoC Design** | Integrate RISC-V core, DMA, UART, SPI, APB interconnect on FPGA |
| **ASIC Tapeout Preparation** | Synthesis with Synopsys DC, floorplanning, STA |
| **UVM Verification Environment** | Industry-standard verification for all modules |
| **Formal Property Verification** | SVA assertions for protocol compliance |
| **Low-Power Design** | Clock gating, power domains, UPF flow |

---

## Tools & Environment

| Tool | Purpose | Version |
|------|---------|---------|
| Icarus Verilog | Simulation | v12+ |
| GTKWave | Waveform viewing | v3.3+ |
| Visual Studio Code | Code editing | Latest |
| Xilinx Vivado | FPGA synthesis (planned) | 2023.1+ |
| Synopsys Design Compiler | ASIC synthesis (planned) | N/A |
| Verilator | Fast simulation (planned) | v5+ |

---

## How to Use This Repository

### Clone and Explore

```bash
git clone https://github.com/your-username/rtl-hardware-engineering.git
cd rtl-hardware-engineering
```

### Simulate Any Module

```bash
cd <module_name>/

# Compile
iverilog -g2012 -o sim.vvp <module_name>.sv <module_name>_tb.sv

# Run
vvp sim.vvp

# View waveforms
gtkwave <dump_file>.vcd
```

### Read Module Documentation

Each module has its own `README.md` with:
- Architecture diagrams and block diagrams
- State transition tables and timing diagrams
- Signal descriptions and interface specifications
- Testbench coverage matrices
- Key concepts and lessons learned
- Future improvement suggestions

---

## Key Takeaways So Far

### Design Principles
- **Clean separation of concerns:** Sequential logic (`always_ff`) handles state and registers; combinational logic (`always_comb`) handles next-state and output decoding
- **Protocol compliance:** Following specifications (APB) precisely ensures interoperability with standard IP blocks
- **Defensive design:** Overflow guards, underflow protection, and default cases in FSMs prevent undefined behavior
- **Explicit over implicit:** Using `enum` for states, named parameters, and clear signal names makes code self-documenting

### Verification Mindset
- **Test the boundaries:** Every module includes tests for minimum, maximum, and edge-case conditions
- **Waveform correlation:** Simulation results are always cross-checked against expected timing diagrams
- **Protocol phase verification:** For bus interfaces, each phase (SETUP, ACCESS) is verified independently
- **Coverage-driven approach:** Test cases are mapped to functional coverage points

---

## Acknowledgments

This repository is developed under the guidance of **Sir Khalil Rehman**, whose structured approach to teaching chip design has provided the foundation for understanding RTL design, industrial protocols, and hardware verification methodologies.

---

## License

This repository is provided for educational and reference purposes. Free to use, modify, and distribute with attribution.

---

## Contact

For questions, suggestions, or collaboration opportunities related to RTL design and chip architecture, feel free to reach out via GitHub issues or discussions.

