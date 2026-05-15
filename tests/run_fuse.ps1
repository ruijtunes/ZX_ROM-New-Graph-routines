# Launch Fuse with a self-contained .sna snapshot of one arc test.
#
# The snapshot has: ARC code at $C000, args at $5B10/$5B15/$5B1A as
# 5-byte ZX FP, COORDS at $5C7D/$5C7E, and PC = test_main which calls
# the shim and HALTs.  No BASIC, no tape loading.
#
# Usage:
#   pwsh tests/run_fuse.ps1                    # default: quarter_ne
#   pwsh tests/run_fuse.ps1 -Case major_270
#   pwsh tests/run_fuse.ps1 -List

param(
    [string]$Case = "quarter_ne",
    [switch]$List
)

$root = Split-Path -Parent $PSScriptRoot
$fuse = "C:\Program Files (x86)\Fuse\fuse.exe"

if ($List) {
    Push-Location $root
    try { python -c "from tests.test_cases import CASES; print('\n'.join(CASES.keys()))" }
    finally { Pop-Location }
    return
}

if (-not (Test-Path $fuse)) {
    Write-Host "fuse.exe not found at $fuse" -ForegroundColor Red
    exit 1
}

# Regenerate snapshot for this case (fast: pure Python).
Push-Location $root
try { python tests/make_sna.py $Case }
finally { Pop-Location }

$sna = "$root/tests/build/arc_test_$Case.sna"
if (-not (Test-Path $sna)) {
    Write-Host "Snapshot not produced for '$Case'." -ForegroundColor Red
    exit 1
}

Write-Host "Launching Fuse: $Case" -ForegroundColor Cyan
Write-Host "  sna = $sna" -ForegroundColor DarkGray
Start-Process $fuse -ArgumentList @("`"$sna`"") -WorkingDirectory (Split-Path $fuse)
