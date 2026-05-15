#!/usr/bin/env pwsh
# Build ARC.asm in two flavours and report memory budget.
#
# Output:
#   build/arc_ROM.bin     -- assembled at ORG $2360 (the ROM slot)
#   build/arc_C000.bin    -- assembled at ORG $C000 (loadable into RAM)
#   build/arc_*.lst       -- annotated listings
#
# Run from repo root:
#   pwsh tests/build.ps1

$ErrorActionPreference = "Continue"
# sjasmplus writes its banner to stderr; PowerShell's strict mode
# would otherwise treat that as a terminating error.

$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    $sj = Get-ChildItem "$root/tests/sjasmplus" -Recurse -Filter "sjasmplus.exe" |
          Select-Object -First 1
    if (-not $sj) {
        throw "sjasmplus.exe not found under tests/sjasmplus/. Re-extract the release zip."
    }
    $sjExe = $sj.FullName

    $buildDir = "$root/tests/build"
    New-Item -ItemType Directory -Path $buildDir -Force | Out-Null

    function Invoke-BuildVariant {
        param([string]$Name, [int]$Org)

        # ARC.asm is now position-independent (no ORG inside). We
        # write a tiny wrapper that supplies the ORG and INCLUDEs it.
        $wrapper = "$buildDir/_$Name.asm"
        $hex     = '{0:X4}' -f $Org
        $body    = "            ORG `$$hex`r`n            INCLUDE `"$root/ARC.asm`"`r`n"
        Set-Content $wrapper $body -Encoding ASCII

        $bin = "$buildDir/arc_$Name.bin"
        $lst = "$buildDir/arc_$Name.lst"
        & $sjExe $wrapper "--raw=$bin" "--lst=$lst" 2>&1 |
            Out-String |
            Out-File "$buildDir/asm_$Name.log"
        if (-not (Test-Path $bin) -or (Get-Item $bin).Length -eq 0) {
            Write-Host "Assembly FAILED for variant $Name. Log:" -ForegroundColor Red
            Get-Content "$buildDir/asm_$Name.log" | Write-Host
            return $null
        }
        $size = (Get-Item $bin).Length
        # Find end address by scanning listing.
        $endAddr = $Org
        Get-Content $lst | ForEach-Object {
            if ($_ -match '^\s*\d+\s+([0-9A-Fa-f]{4})\s') {
                $a = [Convert]::ToInt32($Matches[1], 16)
                if ($a -gt $endAddr) { $endAddr = $a }
            }
        }
        [PSCustomObject]@{
            Variant  = $Name
            Org      = ('${0:X4}' -f $Org)
            Size     = $size
            EndAddr  = ('${0:X4}' -f $endAddr)
            Bin      = $bin
            Lst      = $lst
        }
    }

    Write-Host "=== sjasmplus build ===" -ForegroundColor Cyan
    $rom  = Invoke-BuildVariant -Name "ROM"  -Org 0x2360
    $ram  = Invoke-BuildVariant -Name "C000" -Org 0xC000

    # Build the test shim too (ARC + BASIC-callable entry at $E000)
    $shimSrc = "$root/tests/test_shim.asm"
    if (Test-Path $shimSrc) {
        $bin = "$buildDir/shim_C000.bin"
        $lst = "$buildDir/shim_C000.lst"
        $sym = "$buildDir/shim_C000.sym"
        Push-Location "$root/tests"
        try {
            & $sjExe $shimSrc "--raw=$bin" "--lst=$lst" "--sym=$sym" 2>&1 |
                Out-String | Out-File "$buildDir/asm_shim.log"
        } finally { Pop-Location }
        if ((Test-Path $bin) -and (Get-Item $bin).Length -gt 0) {
            # Pluck arc_test address from the symbol file
            $entry = (Select-String -Path $sym -Pattern '^\s*arc_test\b').Line
            if ($entry -match '([0-9A-Fa-f]+)\s*$') {
                $addr = [Convert]::ToInt32($Matches[1], 16)
            } else { $addr = 0 }
            $shim = [PSCustomObject]@{
                Variant = "Shim"; Org = '$C000';
                Size = (Get-Item $bin).Length
                EndAddr = ('arc_test=${0:X4}' -f $addr) }
            # Stash the entry address so make_tap.py can read it.
            Set-Content "$buildDir/shim_entry.txt" $addr -Encoding ASCII
        } else {
            Write-Host "Shim assembly FAILED:" -ForegroundColor Red
            Get-Content "$buildDir/asm_shim.log" | Write-Host
            $shim = $null
        }
    } else { $shim = $null }

    # Build the standalone snapshot harness (no BASIC needed).
    $mainSrc = "$root/tests/test_main.asm"
    if (Test-Path $mainSrc) {
        $bin = "$buildDir/test_main.bin"
        $lst = "$buildDir/test_main.lst"
        $sym = "$buildDir/test_main.sym"
        Push-Location "$root/tests"
        try {
            & $sjExe $mainSrc "--raw=$bin" "--lst=$lst" "--sym=$sym" 2>&1 |
                Out-String | Out-File "$buildDir/asm_main.log"
        } finally { Pop-Location }
        if ((Test-Path $bin) -and (Get-Item $bin).Length -gt 0) {
            $entry = (Select-String -Path $sym -Pattern '^\s*test_main\b').Line
            if ($entry -match '([0-9A-Fa-f]+)\s*$') {
                $maddr = [Convert]::ToInt32($Matches[1], 16)
            } else { $maddr = 0 }
            $main = [PSCustomObject]@{
                Variant = "Main"; Org = '$C000';
                Size = (Get-Item $bin).Length
                EndAddr = ('test_main=${0:X4}' -f $maddr) }
        } else {
            Write-Host "test_main assembly FAILED:" -ForegroundColor Red
            Get-Content "$buildDir/asm_main.log" | Write-Host
            $main = $null
        }
    } else { $main = $null }

    @($rom, $ram, $shim, $main) | Where-Object { $_ } |
        Format-Table Variant, Org, Size, EndAddr -AutoSize | Out-Host

    Write-Host "=== Memory budget ===" -ForegroundColor Cyan
    $slotStart = 0x2360
    $slotEnd   = 0x2477    # original arc slot ends where LINE-DRAW begins
    $slot      = $slotEnd - $slotStart
    $over      = $rom.Size - $slot
    Write-Host ("Original ROM arc slot   `$2360..`$2477 = {0} bytes" -f $slot)
    Write-Host ("ARC.asm assembled size  : {0} bytes" -f $rom.Size)
    if ($over -le 0) {
        Write-Host ("FITS. {0} bytes spare." -f (-$over)) -ForegroundColor Green
    } else {
        Write-Host ("OVERFLOWS slot by {0} bytes." -f $over) -ForegroundColor Yellow
        Write-Host "  -> Use the C000 (RAM) variant for testing, OR relocate LINE-DRAW."
    }

    # Extended budget: how much room before S-RND at $25F8?
    $extEnd = 0x25F8
    $ext    = $extEnd - $slotStart
    $extOver= $rom.Size - $ext
    if ($extOver -gt 0) {
        Write-Host ("Also overflows extended budget (`$2360..`$25F8 = $ext bytes).") -ForegroundColor Red
    } else {
        Write-Host ("Fits extended budget `$2360..`$25F8 = $ext bytes. Spare {0}." -f (-$extOver))
    }

    Write-Host "`nWrote: $($rom.Bin)  and  $($ram.Bin)" -ForegroundColor DarkGray
}
finally {
    Pop-Location
}
