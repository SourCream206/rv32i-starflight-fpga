param(
    [string]$Toolchain = $env:RISCV,
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$Source = 'main.c'
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Toolchain)) {
    throw 'Set RISCV to the bare-metal toolchain directory or pass -Toolchain.'
}

$prefixes = @('riscv32-unknown-elf', 'riscv-none-elf')
$gcc = $null
$objcopy = $null
foreach ($prefix in $prefixes) {
    $candidateGcc = Join-Path $Toolchain "bin\$prefix-gcc.exe"
    $candidateObjcopy = Join-Path $Toolchain "bin\$prefix-objcopy.exe"
    if ((Test-Path $candidateGcc) -and (Test-Path $candidateObjcopy)) {
        $gcc = $candidateGcc
        $objcopy = $candidateObjcopy
        break
    }
}
if (!$gcc -or !$objcopy) {
    throw "Could not find a supported RISC-V GCC/objcopy pair under $Toolchain."
}

$software = Join-Path $ProjectRoot 'software'
$sourceFile = Join-Path $software $Source
if (!(Test-Path $sourceFile)) {
    throw "Firmware source not found: $sourceFile"
}
$elf = Join-Path $software 'firmware.elf'
$binary = Join-Path $software 'firmware.bin'
$hex = Join-Path $software 'imem.hex'

& $gcc -march=rv32i -mabi=ilp32 -mno-relax -O2 -ffreestanding -nostdlib -nostartfiles `
    '-Wl,--no-relax' '-T' (Join-Path $software 'link.ld') `
    (Join-Path $software 'boot.s') $sourceFile '-o' $elf
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