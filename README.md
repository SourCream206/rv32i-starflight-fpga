# RV32I Starflight FPGA

A custom RV32I-style RISC-V CPU on an Intel MAX 10 DE10-Lite FPGA, extended with a procedural pseudo-3D VGA space-shooter renderer controlled by the onboard accelerometer and pushbuttons.

## Project Scope

- Custom 32-bit RV32I-style CPU core in Verilog
- Memory-mapped accelerometer, buttons, LEDs, HEX displays, and VGA game registers
- 640x480 procedural VGA renderer with a ship and depth-scaled asteroid
- Bare-metal C firmware target for `rv32i` / `ilp32`
- Questa CPU and VGA simulation testbenches

## Hardware

Target board: Terasic DE10-Lite, MAX 10 `10M50DAF484C7G`.

The current game architecture avoids a framebuffer. C updates compact object state, while FPGA logic generates VGA timing and draws the scene.

## Firmware

The intended compiler target is:

```text
-march=rv32i -mabi=ilp32
```

Build with a bare-metal `riscv32-unknown-elf` toolchain:

```powershell
$env:RISCV = 'C:\path\to\riscv-toolchain'
.\software\build.ps1
```

The script generates `software/firmware.elf` and `software/imem.hex`. Generated firmware files are ignored by Git.

## Build and Test

### CPU and VGA simulation

From the project root, with Questa on the standard Intel installation path:

```powershell
& 'C:\altera_lite\25.1std\questa_fse\win64\vlog.exe' -work work rtl/alu.v rtl/pc.v rtl/reg_file.v rtl/decoder.v rtl/lsu.v rtl/riscVCPU.v tb/tb_cpu.v
& 'C:\altera_lite\25.1std\questa_fse\win64\vsim.exe' -c tb_cpu -do 'run -all; quit -f'
& 'C:\altera_lite\25.1std\questa_fse\win64\vlog.exe' -work work rtl/vga_timing.v rtl/game_video.v tb/tb_video.v
& 'C:\altera_lite\25.1std\questa_fse\win64\vsim.exe' -c tb_video -do 'run -all; quit -f'
```

Both tests should print `PASS`.

### Build the C game firmware

The current CPU requires a bare-metal RV32I toolchain. The default RISC-V toolchain target is often RV64GC, so use explicit RV32I flags through `build.ps1`:

```powershell
$env:RISCV = 'C:\path\to\riscv-toolchain'
.\software\build.ps1
```

This must update `software/imem.hex`. If `imem.hex` still contains only nine words, the FPGA will run the old accelerometer display demo rather than the C game.

### Build in Quartus

Open `riscVCPU.qpf` in Quartus Prime, or run:

```powershell
.\scripts\build_fpga.ps1
```

The script runs the complete Quartus flow and should create `output_files\riscVCPU.sof`.

Program that `.sof` with Quartus Programmer using the DE10-Lite USB-Blaster. Connect VGA before powering the board. Release reset, then verify the static scene before testing accelerometer movement and the button input.

### Current test status

The CPU and VGA simulations pass. The checked-in `.sof` contains the VGA renderer and static scene, but the C game is not present until the firmware toolchain is installed and `software/build.ps1` is run. Timing should also be reviewed in `output_files\riscVCPU.sta.rpt` before relying on high-speed CPU execution.

## Verification

The CPU regression and VGA renderer tests are run with Questa. Quartus analysis and fitting are used for the DE10-Lite top-level integration.

## Status

The CPU and VGA renderer are implemented and simulation-tested. Final hardware validation still requires programming the generated `.sof` and testing VGA, accelerometer input, and buttons on the physical DE10-Lite.