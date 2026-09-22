param(
    [string]$Toolchain = $env:RISCV,
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Toolchain)) {
    throw 'Set RISCV to the bare-metal toolchain directory or pass -Toolchain.'
}

$gcc = Join-Path $Toolchain 'bin\riscv32-unknown-elf-gcc.exe'
$objcopy = Join-Path $Toolchain 'bin\riscv32-unknown-elf-objcopy.exe'
if (!(Test-Path $gcc) -or !(Test-Path $objcopy)) {
    throw "Could not find riscv32-unknown-elf-gcc.exe and objcopy.exe under $Toolchain."
}

$software = Join-Path $ProjectRoot 'software'
$elf = Join-Path $software 'firmware.elf'
$binary = Join-Path $software 'firmware.bin'
$hex = Join-Path $software 'imem.hex'

& $gcc -march=rv32i -mabi=ilp32 -mno-relax -O2 -ffreestanding -nostdlib -nostartfiles `
    '-Wl,--no-relax' '-T' (Join-Path $software 'link.ld') `
    (Join-Path $software 'boot.s') (Join-Path $software 'main.c') '-o' $elf
if ($LASTEXITCODE -ne 0) { throw 'RISC-V firmware compilation failed.' }

& $objcopy '-O' 'binary' $elf $binary
if ($LASTEXITCODE -ne 0) { throw 'ELF-to-binary conversion failed.' }

$bytes = [System.IO.File]::ReadAllBytes($binary)
$words = [System.Collections.Generic.List[string]]::new()
for ($offset = 0; $offset -lt $bytes.Length; $offset += 4) {
    $word = [uint32]0
    for ($byteIndex = 0; $byteIndex -lt 4; $byteIndex++) {
        $index = $offset + $byteIndex
        if ($index -lt $bytes.Length) {
            $word = $word -bor ([uint32]$bytes[$index] -shl (8 * $byteIndex))
        }
    }
    $words.Add(('{0:X8}' -f $word))
}

Set-Content -Path $hex -Value $words -Encoding ascii
Write-Host "Built $elf and $hex ($($words.Count) words)."