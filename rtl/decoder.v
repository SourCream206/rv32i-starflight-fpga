module decoder (
    input  wire [31:0] instr,
    output wire [6:0]  opcode,
    output wire [4:0]  rd,
    output wire [4:0]  rs1,
    output wire [4:0]  rs2,
    output wire [2:0]  funct3,
    output wire [6:0]  funct7,
    output reg  [31:0] imm,
    output reg         reg_write,
    output reg         mem_read,
    output reg         mem_write,
    output reg         alu_src,
    output reg         branch,
    output reg         jump,     
    output reg         is_jalr,  
    output reg  [3:0]  alu_op,
    output reg         illegal
);

    assign opcode = instr[6:0];
    assign rd     = instr[11:7];
    assign funct3 = instr[14:12];
    assign rs1    = instr[19:15];
    assign rs2    = instr[24:20];
    assign funct7 = instr[31:25];

    localparam OP_R_TYPE  = 7'b0110011;
    localparam OP_I_TYPE  = 7'b0010011;
    localparam OP_LOAD    = 7'b0000011;
    localparam OP_STORE   = 7'b0100011;
    localparam OP_BRANCH  = 7'b1100011;
    localparam OP_LUI     = 7'b0110111;
    localparam OP_AUIPC   = 7'b0010111;
    localparam OP_JAL     = 7'b1101111;
    localparam OP_JALR    = 7'b1100111;

    always @(*) begin
        reg_write = 1'b0;
        mem_read  = 1'b0;
        mem_write = 1'b0;
        alu_src   = 1'b0;
        branch    = 1'b0;
        jump      = 1'b0;
        is_jalr   = 1'b0;
        alu_op    = 4'b0000;
        imm       = 32'd0;
        illegal    = 1'b1;

        case (opcode)
            OP_R_TYPE: begin
                case (funct3)
                    3'b000: begin
                        if (funct7 == 7'b0000000 || funct7 == 7'b0100000) begin
                            reg_write = 1'b1;
                            illegal = 1'b0;
                            alu_op = (funct7[5]) ? 4'b0001 : 4'b0000;
                        end
                    end
                    3'b001: begin
                        if (funct7 == 7'b0000000) begin
                            reg_write = 1'b1;
                            illegal = 1'b0;
                            alu_op = 4'b0101;
                        end
                    end
                    3'b010: begin
                        if (funct7 == 7'b0000000) begin
                            reg_write = 1'b1;
                            illegal = 1'b0;
                            alu_op = 4'b1000;
                        end
                    end
                    3'b011: begin
                        if (funct7 == 7'b0000000) begin
                            reg_write = 1'b1;
                            illegal = 1'b0;
                            alu_op = 4'b1001;
                        end
                    end
                    3'b100: begin
                        if (funct7 == 7'b0000000) begin
                            reg_write = 1'b1;
                            illegal = 1'b0;
                            alu_op = 4'b0100;
                        end
                    end
                    3'b101: begin
                        if (funct7 == 7'b0000000 || funct7 == 7'b0100000) begin
                            reg_write = 1'b1;
                            illegal = 1'b0;
                            alu_op = (funct7[5]) ? 4'b0111 : 4'b0110;
                        end
                    end
                    3'b110: begin
                        if (funct7 == 7'b0000000) begin
                            reg_write = 1'b1;
                            illegal = 1'b0;
                            alu_op = 4'b0011;
                        end
                    end
                    3'b111: begin
                        if (funct7 == 7'b0000000) begin
                            reg_write = 1'b1;
                            illegal = 1'b0;
                            alu_op = 4'b0010;
                        end
                    end
                endcase
            end

            OP_I_TYPE: begin
                alu_src   = 1'b1;
                imm       = {{20{instr[31]}}, instr[31:20]};
                case (funct3)
                    3'b000: begin reg_write = 1'b1; illegal = 1'b0; alu_op = 4'b0000; end
                    3'b100: begin reg_write = 1'b1; illegal = 1'b0; alu_op = 4'b0100; end
                    3'b110: begin reg_write = 1'b1; illegal = 1'b0; alu_op = 4'b0011; end
                    3'b111: begin reg_write = 1'b1; illegal = 1'b0; alu_op = 4'b0010; end
                    3'b001: begin
                        if (funct7 == 7'b0000000) begin
                            reg_write = 1'b1;
                            illegal = 1'b0;
                            alu_op = 4'b0101;
                        end
                    end
                    3'b101: begin
                        if (funct7 == 7'b0000000 || funct7 == 7'b0100000) begin
                            reg_write = 1'b1;
                            illegal = 1'b0;
                            alu_op = (funct7[5]) ? 4'b0111 : 4'b0110;
                        end
                    end
                endcase
            end

            OP_LOAD: begin
                if (funct3 == 3'b000 || funct3 == 3'b001 || funct3 == 3'b010 ||
                    funct3 == 3'b100 || funct3 == 3'b101) begin
                    reg_write = 1'b1;
                    mem_read  = 1'b1;
                    alu_src   = 1'b1;
                    alu_op    = 4'b0000;
                    illegal   = 1'b0;
                    imm       = {{20{instr[31]}}, instr[31:20]};
                end
            end

            OP_STORE: begin
                if (funct3 == 3'b000 || funct3 == 3'b001 || funct3 == 3'b010) begin
                    mem_write = 1'b1;
                    alu_src   = 1'b1;
                    alu_op    = 4'b0000;
                    illegal   = 1'b0;
                    imm       = {{20{instr[31]}}, instr[31:25], instr[11:7]};
                end
            end

            OP_BRANCH: begin
                if (funct3 == 3'b000 || funct3 == 3'b001 || funct3 == 3'b100 ||
                    funct3 == 3'b101 || funct3 == 3'b110 || funct3 == 3'b111) begin
                    branch = 1'b1;
                    illegal = 1'b0;
                    imm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
                end
            end

            OP_LUI: begin
                reg_write = 1'b1;
                illegal = 1'b0;
                imm       = {instr[31:12], 12'd0};
            end

            OP_AUIPC: begin
                reg_write = 1'b1;
                illegal = 1'b0;
                imm       = {instr[31:12], 12'd0};
            end

            OP_JAL: begin
                jump      = 1'b1;
                reg_write = 1'b1;
                illegal = 1'b0;
                imm       = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
            end

            OP_JALR: begin
                if (funct3 == 3'b000) begin
                    jump      = 1'b1;
                    is_jalr   = 1'b1;
                    reg_write = 1'b1;
                    alu_src   = 1'b1;
                    illegal   = 1'b0;
                    imm       = {{20{instr[31]}}, instr[31:20]};
                end
            end

            7'b0001111: begin
                if (funct3 == 3'b000 || funct3 == 3'b001)
                    illegal = 1'b0;
            end

            default: ;
        endcase
    end
endmodule