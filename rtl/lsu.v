module lsu (
    input  wire [31:0] addr,
    input  wire [31:0] mem_rdata,
    input  wire [2:0]  funct3,
    input  wire [31:0] store_data,
    output reg  [31:0] load_result,
    output reg  [31:0] mem_wdata,
    output reg  [3:0]  mem_byte_en
);

    wire [1:0] byte_offset = addr[1:0];

    // Store Logic: Data alignment and byte-enable generation
    always @(*) begin
        mem_byte_en = 4'b0000;
        mem_wdata   = 32'd0;

        case (funct3[1:0]) // Examine bottom 2 bits for size (Byte, Half, Word)
            2'b00: begin // SB (Store Byte)
                mem_wdata = {4{store_data[7:0]}}; // Replicate byte across all lanes
                mem_byte_en = 4'b0001 << byte_offset;
            end
            2'b01: begin // SH (Store Halfword)
                mem_wdata = {2{store_data[15:0]}};
                mem_byte_en = (byte_offset[1]) ? 4'b1100 : 4'b0011;
            end
            2'b10: begin // SW (Store Word)
                mem_wdata = store_data;
                mem_byte_en = 4'b1111;
            end
            default: ;
        endcase
    end

    // Load Logic: Data extraction and sign/zero extension
    always @(*) begin
        load_result = 32'd0;
        
        case (funct3)
            3'b000: // LB (Load Byte, Sign-Extended)
                case (byte_offset)
                    2'b00: load_result = {{24{mem_rdata[7]}},  mem_rdata[7:0]};
                    2'b01: load_result = {{24{mem_rdata[15]}}, mem_rdata[15:8]};
                    2'b10: load_result = {{24{mem_rdata[23]}}, mem_rdata[23:16]};
                    2'b11: load_result = {{24{mem_rdata[31]}}, mem_rdata[31:24]};
                endcase
            3'b100: // LBU (Load Byte, Zero-Extended)
                case (byte_offset)
                    2'b00: load_result = {24'd0, mem_rdata[7:0]};
                    2'b01: load_result = {24'd0, mem_rdata[15:8]};
                    2'b10: load_result = {24'd0, mem_rdata[23:16]};
                    2'b11: load_result = {24'd0, mem_rdata[31:24]};
                endcase
            3'b001: // LH (Load Halfword, Sign-Extended)
                if (byte_offset[1]) load_result = {{16{mem_rdata[31]}}, mem_rdata[31:16]};
                else                load_result = {{16{mem_rdata[15]}}, mem_rdata[15:0]};
            3'b101: // LHU (Load Halfword, Zero-Extended)
                if (byte_offset[1]) load_result = {16'd0, mem_rdata[31:16]};
                else                load_result = {16'd0, mem_rdata[15:0]};
            3'b010: // LW (Load Word)
                load_result = mem_rdata;
            default: ;
        endcase
    end

endmodule