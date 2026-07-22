module cache_2way(
    input wire clk,
    input wire reset,

    input wire [3:0] address,
    input wire [7:0] write_data,
    input wire write_enable,

    output reg [7:0] read_data,
    output reg hit
);

    //========================================================
    // 1. MEMORY STORAGE DECLARATION
    //========================================================
    // Multi-dimensional array ki jagah plain registers 
    // taake indexing samajhna bilkul aasan ho.
    
    reg valid [0:3][0:1];      // 4 sets, har set mein 2 ways (Way0, Way1)
    reg [1:0] tag [0:3][0:1];  // Tag bit storage (2 bits size)
    reg [7:0] data [0:3][0:1]; // Data memory (8 bits size)
    reg lru [0:3];             // LRU bit: 0 -> Way0 PURANI hai, 1 -> Way1 PURANI hai

    //========================================================
    // 2. ADDRESS BREAKDOWN (Combinational Logic)
    //========================================================
    // Address ko 2 hisson mein tora:
    // Bits [1:0] = Index (Set Number: 0, 1, 2, 3)
    // Bits [3:2] = Tag   (Identifier)
    
    wire [1:0] index;
    wire [1:0] addr_tag;

    assign index    = address[1:0];
    assign addr_tag = address[3:2];

    //========================================================
    // 3. COMBINATIONAL LOOKUP (Read & Hit Logic)
    //========================================================
    // Yeh logic Clock ka wait kiye bina fauran check karti hai 
    // ke input address cache mein majood hai ya nahi.
    
    wire way0_hit;
    wire way1_hit;

    // Way0 Hit tab hoga jab: Valid bit 1 ho AND Tag match kar jaye
    assign way0_hit = valid[index][0] && (tag[index][0] == addr_tag);
    
    // Way1 Hit tab hoga jab: Valid bit 1 ho AND Tag match kar jaye
    assign way1_hit = valid[index][1] && (tag[index][1] == addr_tag);

    // Output Data & Hit Decision
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
            read_data = 8'h00; // Cache Miss par default 00
        end
    end

    //========================================================
    // 4. SEQUENTIAL STATE UPDATE (Memory Writes & LRU Update)
    //========================================================
    // Memory arrays mein tabhi change aaye ga jab clock transition hogi.
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset: Tamam sets ko un-roll (manually zero) kar rahe hain.
            // Loop ki jagah plain assignment se samajhna aasan ho jata hai.
            valid[0][0] <= 0; valid[0][1] <= 0; tag[0][0] <= 0; tag[0][1] <= 0; data[0][0] <= 0; data[0][1] <= 0; lru[0] <= 0;
            valid[1][0] <= 0; valid[1][1] <= 0; tag[1][0] <= 0; tag[1][1] <= 0; data[1][0] <= 0; data[1][1] <= 0; lru[1] <= 0;
            valid[2][0] <= 0; valid[2][1] <= 0; tag[2][0] <= 0; tag[2][1] <= 0; data[2][0] <= 0; data[2][1] <= 0; lru[2] <= 0;
            valid[3][0] <= 0; valid[3][1] <= 0; tag[3][0] <= 0; tag[3][1] <= 0; data[3][0] <= 0; data[3][1] <= 0; lru[3] <= 0;
        end 
        else begin
            
            // --- SCENARIO 1: READ OPERATION ---
            if (write_enable == 1'b0) begin
                // Read karte waqt agar Hit hua to hum sirf LRU ko update karenge 
                // taake pata chale kaunsi way recently istemal hui hai.
                if (way0_hit) begin
                    lru[index] <= 1'b1; // Way0 access hui, to next replacement Way1 hogi
                end 
                else if (way1_hit) begin
                    lru[index] <= 1'b0; // Way1 access hui, to next replacement Way0 hogi
                end
            end 
            
            // --- SCENARIO 2: WRITE OPERATION ---
            else begin
                if (way0_hit) begin
                    // Write Hit on Way 0
                    data[index][0] <= write_data;
                    lru[index]     <= 1'b1;
                end 
                else if (way1_hit) begin
                    // Write Hit on Way 1
                    data[index][1] <= write_data;
                    lru[index]     <= 1'b0;
                end 
                else begin
                    // Write MISS: Dynamic Replacement based on LRU
                    if (lru[index] == 1'b0) begin
                        // Way0 ko overwrite karo (Replacement)
                        valid[index][0] <= 1'b1;
                        tag[index][0]   <= addr_tag;
                        data[index][0]  <= write_data;
                        lru[index]      <= 1'b1; // Ab Way0 fresh ho gayi, LRU point karega Way1 ko
                    end 
                    else begin
                        // Way1 ko overwrite karo (Replacement)
                        valid[index][1] <= 1'b1;
                        tag[index][1]   <= addr_tag;
                        data[index][1]  <= write_data;
                        lru[index]      <= 1'b0; // Ab Way1 fresh ho gayi, LRU point karega Way0 ko
                    end
                end
            end

        end
    end

endmodule