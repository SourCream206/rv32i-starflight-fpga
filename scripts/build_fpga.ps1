param(
    [string]$Quartus = 'C:\altera_lite\25.1std\quartus\bin64\quartus_sh.exe'
)

$ErrorActionPreference = 'Stop'

if (!(Test-Path $Quartus)) {
    throw "Quartus executable not found: $Quartus"
}

& $Quartus --flow compile riscVCPU
if ($LASTEXITCODE -ne 0) {
    throw 'Quartus compilation failed. Review output_files\riscVCPU.flow.rpt.'
}

$sof = Join-Path $PSScriptRoot '..\output_files\riscVCPU.sof'
if (!(Test-Path $sof)) {
    throw "Quartus completed without producing $sof"
}

Write-Host "Created $sof"
