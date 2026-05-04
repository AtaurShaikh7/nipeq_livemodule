# Wrapper: runs effdate -> file movement -> [optional] full exe.
# Outlook download automation has been removed; ensure required files are present in SourceFolder before running.
# Usage:
#   RunFinalMovementWrapper.ps1                 = full run
#   RunFinalMovementWrapper.ps1 -DownloadOnly   = effdate only (no file movement, no exe)
$ErrorActionPreference = "Continue"
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Get-Location | Select-Object -ExpandProperty Path }
$logPath = Join-Path $scriptDir "RunFinalMovement.log"

$downloadOnly = $false
foreach ($a in $args) {
    if ($a -eq "-DownloadOnly" -or $a -eq "--no-exe" -or $a -eq "test") { $downloadOnly = $true; break }
}

$startTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$header = "=== RunFinalMovement started $startTime ==="
if ($downloadOnly) { $header += " (TEST: effdate only, movement + exe skipped)" }
$header | Set-Content -Path $logPath -Encoding UTF8
Write-Host $header

function Run-Step {
    param([string]$Name, [scriptblock]$Block)
    $stepHeader = "`n--- $Name ---"
    $stepHeader | Out-File -FilePath $logPath -Append -Encoding UTF8
    Write-Host $stepHeader
    try {
        $out = & $Block 2>&1
        $exitCode = $LASTEXITCODE
        foreach ($line in $out) {
            $s = $line.ToString()
            $s | Out-File -FilePath $logPath -Append -Encoding UTF8
            Write-Host $s
        }
        return $exitCode
    } catch {
        $err = $_.Exception.Message
        $err | Out-File -FilePath $logPath -Append -Encoding UTF8
        Write-Host $err -ForegroundColor Red
        return 1
    }
}

# No "Press any key" when run from this wrapper
$env:MacroTestNoPause = "1"

# Find folder that contains MacroTest.exe (script dir or bin\Debug\net9.0 or bin\Release\net9.0)
$exeDir = $scriptDir
if (-not (Test-Path -LiteralPath (Join-Path $scriptDir "MacroTest.exe"))) {
    if (Test-Path -LiteralPath (Join-Path $scriptDir "bin\Debug\net9.0\MacroTest.exe")) {
        $exeDir = Join-Path $scriptDir "bin\Debug\net9.0"
    } elseif (Test-Path -LiteralPath (Join-Path $scriptDir "bin\Release\net9.0\MacroTest.exe")) {
        $exeDir = Join-Path $scriptDir "bin\Release\net9.0"
    }
}
"Using exe dir: $exeDir" | Out-File -FilePath $logPath -Append -Encoding UTF8

# 1) Get effdate from Oracle
$r1 = Run-Step "Get effdate from Oracle" {
    Set-Location -LiteralPath $exeDir
    & (Join-Path $exeDir "MacroTest.exe") --write-effdate
}
if ($r1 -ne 0) {
    "Failed to get effdate. Exit code: $r1" | Out-File -FilePath $logPath -Append -Encoding UTF8
    Write-Host "Failed to get effdate from Oracle." -ForegroundColor Red
    exit $r1
}

# Copy effdate.txt next to appsettings.json (scriptDir) so both OutlookDownload and FinalMovement can read it
$effFromExe = Join-Path $exeDir "effdate.txt"
$effToRoot  = Join-Path $scriptDir "effdate.txt"
if (Test-Path -LiteralPath $effFromExe) {
    if ($effFromExe -ne $effToRoot) {
        Copy-Item -LiteralPath $effFromExe -Destination $effToRoot -Force
        "Copied effdate.txt: $effFromExe -> $effToRoot" | Out-File -FilePath $logPath -Append -Encoding UTF8
    }
} else {
    "WARNING: effdate.txt not found at $effFromExe" | Out-File -FilePath $logPath -Append -Encoding UTF8
}

# 2) File movement (skipped in effdate-only test mode)
$r2 = 0
if (-not $downloadOnly) {
    $finalMovementScript = Join-Path $scriptDir "FinalMovement.ps1"
    if (-not (Test-Path -LiteralPath $finalMovementScript)) { $finalMovementScript = Join-Path $exeDir "FinalMovement.ps1" }
    $configForMovement = Join-Path $scriptDir "appsettings.json"
    $r2 = Run-Step "Final Movement (PowerShell)" {
        Set-Location -LiteralPath $scriptDir
        & powershell -NoProfile -ExecutionPolicy Bypass -File $finalMovementScript -ConfigPath $configForMovement
    }
    if ($r2 -ne 0) {
        "Final Movement had exit code $r2 (continuing to full pipeline)." | Out-File -FilePath $logPath -Append -Encoding UTF8
        Write-Host "Final Movement had issues (exit $r2). Continuing to full pipeline." -ForegroundColor Yellow
    }
} else {
    "Effdate-only mode: Final Movement skipped." | Out-File -FilePath $logPath -Append -Encoding UTF8
    Write-Host "Effdate-only mode: skipping file movement." -ForegroundColor Cyan
}

# 3) Full pipeline (Dion, BSE, macro, procs, holdings) - skipped in effdate-only mode
if (-not $downloadOnly) {
    $r3 = Run-Step "MacroTest full pipeline" {
        Set-Location -LiteralPath $exeDir
        & (Join-Path $exeDir "MacroTest.exe")
        exit $LASTEXITCODE
    }
    $endTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $footer = "`n=== RunFinalMovement finished $endTime (pipeline exit: $r3) ==="
    $footer | Out-File -FilePath $logPath -Append -Encoding UTF8
    Write-Host $footer
    Write-Host "`nFull log written to: $logPath" -ForegroundColor Cyan
    exit $r3
} else {
    $endTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $footer = "`n=== RunFinalMovement finished $endTime (TEST: download only, movement + exe skipped) ==="
    $footer | Out-File -FilePath $logPath -Append -Encoding UTF8
    Write-Host $footer
    Write-Host "File movement and exe steps skipped (download-only mode)." -ForegroundColor Cyan
    Write-Host "`nFull log written to: $logPath" -ForegroundColor Cyan
    exit 0
}
