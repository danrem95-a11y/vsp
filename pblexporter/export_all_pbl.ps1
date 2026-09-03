<#
.SYNOPSIS
  ONE COMMAND PowerBuilder 11.5 PBL -> source export.

.DESCRIPTION
  Scans -InputDir for *.pbl files, then drives the compiled pblexporter.exe
  (built once from the PowerScript in this folder) to export every object
  PowerScript's LibraryExport can read from each PBL into its own folder under
  -OutputDir:  <OutputDir>\<pblname>\<object>.<ext>   (no per-type subfolders)

  Read-only against the PBLs: pblexporter.exe only calls LibraryDirectory()
  and LibraryExport(), never anything that writes to a .pbl.

.PARAMETER InputDir
  Folder containing the .pbl files to export (e.g. C:\BTV\Apps).

.PARAMETER OutputDir
  Destination SOURCE root (e.g. C:\BTV\SOURCE). Created if missing.

.PARAMETER ExePath
  Path to the compiled pblexporter.exe (see BUILD_INSTRUCTIONS.md - this is a
  one-time manual build inside the PowerBuilder 11.5 IDE, since the external
  ORCA automation API is SySAM-license-gated on this machine and OrcaScript
  has no export command at all).

.PARAMETER Recurse
  Also scan subfolders of -InputDir for .pbl files (off by default).

.EXAMPLE
  .\export_all_pbl.ps1 -InputDir "C:\BTV\Apps" -OutputDir "C:\BTV\SOURCE" -ExePath "C:\BTV\debug\pblexporter\pblexporter.exe"
#>
param(
    [Parameter(Mandatory=$true)][string]$InputDir,
    [Parameter(Mandatory=$true)][string]$OutputDir,
    [Parameter(Mandatory=$true)][string]$ExePath,
    [switch]$Recurse
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $InputDir)) {
    throw "InputDir not found: $InputDir"
}
if (-not (Test-Path -LiteralPath $ExePath)) {
    throw "pblexporter.exe not found at: $ExePath`nBuild it once from the PowerScript in this folder (see BUILD_INSTRUCTIONS.md), then pass its path via -ExePath."
}

$pbls = Get-ChildItem -LiteralPath $InputDir -Filter "*.pbl" -File -Recurse:$Recurse | Sort-Object FullName
if ($pbls.Count -eq 0) {
    Write-Warning "No .pbl files found under $InputDir"
    return
}

Write-Output "Found $($pbls.Count) PBL(s) under $InputDir"

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

# Fresh run: start export.log / failed_objects.log clean instead of appending
# onto a previous run's log (gf_pbl_log always appends).
$exportLog = Join-Path $OutputDir "export.log"
$failLog   = Join-Path $OutputDir "failed_objects.log"
Remove-Item -LiteralPath $exportLog -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $failLog -ErrorAction SilentlyContinue

$worklistPath = Join-Path $OutputDir "_worklist.txt"
$jobfilePath  = Join-Path $OutputDir "_jobfile.txt"

$pbls.FullName | Set-Content -LiteralPath $worklistPath -Encoding ASCII
@($worklistPath, $OutputDir) | Set-Content -LiteralPath $jobfilePath -Encoding ASCII

Write-Output "Running pblexporter.exe (this can take a while for many/large PBLs)..."
# Deliberately NOT using Start-Process: it reproducibly crashes this compiled
# PowerBuilder GUI-subsystem EXE (access violation, 0xC0000005) regardless of
# arguments, -NoNewWindow, elevation, PATH, or working directory - confirmed
# by direct testing. The plain call operator below is what actually works.
& $ExePath $jobfilePath
$exitCode = $LASTEXITCODE
Write-Output "pblexporter.exe exited with code $exitCode"

if (Test-Path -LiteralPath $exportLog) {
    Write-Output ""
    Write-Output "===== export.log ====="
    Get-Content -LiteralPath $exportLog | ForEach-Object {
        if ($_ -match '^\[.*\]\s*(=+|SUMMARY|PBL|TOTAL|-{5,}|Objects |PBL Found)') {
            Write-Output $_
        }
    }
    Write-Output ""
    Write-Output "Full log: $exportLog"
} else {
    Write-Warning "export.log was not created - pblexporter.exe likely failed before it could run (check the exit code / SySAM licensing / job file)."
}

if (Test-Path -LiteralPath $failLog) {
    $failCount = (Get-Content -LiteralPath $failLog | Measure-Object -Line).Lines
    if ($failCount -gt 0) {
        Write-Warning "$failCount entr$(if ($failCount -eq 1) {'y'} else {'ies'}) in failed_objects.log: $failLog"
    }
}
