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