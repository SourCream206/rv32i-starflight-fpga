`timescale 1ns/1ps

module tb_cpu;
    reg clk;
    reg rst;

    // CPU Interface Wires
    wire [31:0] imem_addr, imem_rdata;
    wire [31:0] dmem_addr, dmem_rdata, dmem_wdata;
    wire        dmem_we;
    wire [3:0]  dmem_byte_en;
    wire        illegal_instruction;

    // Simulated Memory Arrays (64 words each)
    reg [31:0] instr_mem [0:63];
    reg [31:0] data_mem  [0:63];
    integer i;

    // Instantiate your CPU
    riscVCPU dut (
        .clk(clk), .rst(rst),
        .imem_addr(imem_addr), .imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr), .dmem_rdata(dmem_rdata),
        .dmem_wdata(dmem_wdata), .dmem_we(dmem_we), .dmem_byte_en(dmem_byte_en),
        .illegal_instruction(illegal_instruction)
    );

    // Simulated Memory Read Logic (Word Aligned: Address divided by 4)
    assign imem_rdata = instr_mem[imem_addr >> 2];
    assign dmem_rdata = data_mem[dmem_addr >> 2];

    // Simulated Memory Write Logic
    always @(posedge clk) begin
        if (dmem_we) data_mem[dmem_addr >> 2] <= dmem_wdata;
    end

    // 100MHz Clock Generation
    always #5 clk = ~clk;

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_cpu);

        clk = 0;
        rst = 1;

        for (i = 0; i < 64; i = i + 1) begin
            instr_mem[i] = 32'h00000013;
            data_mem[i] = 32'd0;
        end

        instr_mem[0] = 32'h00500093; // addi x1, x0, 5
        instr_mem[1] = 32'h00a00113; // addi x2, x0, 10
        instr_mem[2] = 32'h002081b3; // add  x3, x1, x2
        instr_mem[3] = 32'h00302023; // sw   x3, 0(x0)
        instr_mem[4] = 32'h00002203; // lw   x4, 0(x0)
        instr_mem[5] = 32'h00418463; // beq  x3, x4, 8
        instr_mem[6] = 32'h06300293; // addi x5, x0, 99 (must be skipped)
        instr_mem[7] = 32'h00700293; // addi x5, x0, 7
        instr_mem[8] = 32'h00502223; // sw   x5, 4(x0)

        #15 rst = 0;
        #150;

        if (data_mem[0] !== 32'd15)
            $fatal(1, "ADD/STORE failed: data_mem[0]=%d", data_mem[0]);
        if (data_mem[1] !== 32'd7)
            $fatal(1, "BRANCH/STORE failed: data_mem[1]=%d", data_mem[1]);
        if (dut.reg_file_inst.registers[5] !== 32'd7)
            $fatal(1, "Taken branch failed: x5=%d", dut.reg_file_inst.registers[5]);

        $display("PASS: RV32I arithmetic, load/store, branch, and register tests");
        $finish;
    end
endmodule