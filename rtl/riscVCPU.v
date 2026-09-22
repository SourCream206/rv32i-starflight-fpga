module riscVCPU (
    input  wire        clk,
    input  wire        rst,
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,
    output wire [31:0] dmem_addr,
    input  wire [31:0] dmem_rdata,
    output wire [31:0] dmem_wdata,
    output wire        dmem_we,
    output wire [3:0]  dmem_byte_en,
    output wire        illegal_instruction
);

    wire [31:0] pc_out;
    wire [31:0] branch_target;
    wire        branch_taken;

    pc pc_inst (
        .clk(clk), .rst(rst), .pc_write(1'b1),
        .branch_taken(branch_taken), .branch_target(branch_target), .pc_out(pc_out)
    );
    assign imem_addr = pc_out;

    wire [6:0]  opcode, funct7;
    wire [4:0]  rd, rs1, rs2;
    wire [2:0]  funct3;
    wire [31:0] imm;
    wire        reg_write, mem_read, mem_write, alu_src, branch, jump, is_jalr;
    wire        illegal;
    wire [3:0]  alu_op;

    decoder decoder_inst (
        .instr(imem_rdata),
        .opcode(opcode), .rd(rd), .rs1(rs1), .rs2(rs2),
        .funct3(funct3), .funct7(funct7), .imm(imm),
        .reg_write(reg_write), .mem_read(mem_read), .mem_write(mem_write),
        .alu_src(alu_src), .branch(branch), .jump(jump), .is_jalr(is_jalr),
        .alu_op(alu_op), .illegal(illegal)
    );

    assign illegal_instruction = illegal;

    wire [31:0] rs1_data, rs2_data, rd_data;

    reg_file reg_file_inst (
        .clk(clk), .rst(rst), .we(reg_write),
        .rs1_addr(rs1), .rs2_addr(rs2), .rd_addr(rd),
        .rd_data(rd_data), .rs1_data(rs1_data), .rs2_data(rs2_data)
    );

    wire [31:0] alu_b = (alu_src) ? imm : rs2_data;
    wire [31:0] alu_result;
    wire        alu_zero;

    alu alu_inst (
        .a(rs1_data), .b(alu_b), .alu_op(alu_op),
        .result(alu_result), .zero(alu_zero)
    );

    // --- NEW: Universal Branch & Jump Logic ---
    reg branch_cond_met;
    always @(*) begin
        if (branch) begin
            case (funct3)
                3'b000: branch_cond_met = (rs1_data == rs2_data);                  // BEQ
                3'b001: branch_cond_met = (rs1_data != rs2_data);                  // BNE
                3'b100: branch_cond_met = ($signed(rs1_data) < $signed(rs2_data)); // BLT
                3'b101: branch_cond_met = ($signed(rs1_data) >= $signed(rs2_data));// BGE
                3'b110: branch_cond_met = (rs1_data < rs2_data);                   // BLTU
                3'b111: branch_cond_met = (rs1_data >= rs2_data);                  // BGEU
                default: branch_cond_met = 1'b0;
            endcase
        end else begin
            branch_cond_met = 1'b0;
        end
    end

    // Resolve the Program Counter target
    assign branch_taken  = jump | branch_cond_met;
    assign branch_target = (is_jalr) ? ((rs1_data + imm) & 32'hFFFFFFFE) : (pc_out + imm);

    wire [31:0] load_result;
    assign dmem_addr = alu_result;
    assign dmem_we   = mem_write;

    lsu lsu_inst (
        .addr(dmem_addr), .mem_rdata(dmem_rdata), .funct3(funct3),
        .store_data(rs2_data), .load_result(load_result),
        .mem_wdata(dmem_wdata), .mem_byte_en(dmem_byte_en)
    );

// --- NEW: Expanded Write-Back Multiplexer ---
    wire [31:0] pc_plus_4   = pc_out + 32'd4;
    wire [31:0] pc_plus_imm = pc_out + imm;

    assign rd_data = (jump)                 ? pc_plus_4 :   // Save Return Address
                     (opcode == 7'b0010111) ? pc_plus_imm : // AUIPC
                     (opcode == 7'b0110111) ? imm :         // LUI (NEW FIX)
                     (mem_read)             ? load_result : // Memory Load
                     alu_result;                            // Standard ALU

endmodule