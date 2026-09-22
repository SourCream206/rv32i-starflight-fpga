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

## Verification

The CPU regression and VGA renderer tests are run with Questa. Quartus analysis and fitting are used for the DE10-Lite top-level integration.

## Status

The CPU and VGA renderer are implemented and simulation-tested. Final hardware validation still requires programming the generated `.sof` and testing VGA, accelerometer input, and buttons on the physical DE10-Lite.
