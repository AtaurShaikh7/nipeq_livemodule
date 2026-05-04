# Final Movement - script version (can be run by MacroTest.exe or manually)
# Called by exe:  powershell -ExecutionPolicy Bypass -File FinalMovement.ps1 -ConfigPath "path\to\appsettings.json"
# Manual run:    powershell -ExecutionPolicy Bypass -File FinalMovement.ps1
#               (uses default paths below if -ConfigPath not provided)

param([string]$ConfigPath = "")

# ========== CONFIG (defaults; overridden by -ConfigPath if provided) ==========
$SourceFolder       = "C:\Users\sa_pim_windows\Downloads"
$IndexOutputDir     = "D:\Valuefy\DataLoadProcess\DailyData\IndexData\NSEDATA"
$FinFieOutputDir    = "D:\Valuefy\DataLoadProcess\DailyData\OtherData"
$CustodianDataDir   = "D:\Valuefy\DataLoadProcess\DailyData\CustodianData"
$Password           = ""

if ($ConfigPath -and (Test-Path -LiteralPath $ConfigPath)) {
    try {
        $config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
        if ($config.FinalMovement) {
            $SourceFolder     = $config.FinalMovement.SourceFolder.TrimEnd('\', '/')
            $IndexOutputDir   = $config.FinalMovement.IndexOutputDirectory.TrimEnd('\', '/')
            $FinFieOutputDir   = $config.FinalMovement.FinFieOutputDirectory.TrimEnd('\', '/')
            $CustodianDataDir  = $config.FinalMovement.CustodianDataDirectory.TrimEnd('\', '/')
            if ($config.FinalMovement.Password) { $Password = $config.FinalMovement.Password.ToString().Trim() }
        }
    } catch { Write-Warning "Could not read config: $_" }
}

# Index zip filename prefix -> subfolder name (longest first for matching)
$IndexMap = @(
    @{ Prefix = "nifty500_multicap_50_25_25"; Folder = "CNX NIFTY500_MULTICAP" },
    @{ Prefix = "nifty_dividend_opportunities_50"; Folder = "CNX DIVOPP" },
    @{ Prefix = "nifty_india_consumption"; Folder = "CNX CONSUMPTION" },
    @{ Prefix = "nifty_largemidcap_250"; Folder = "CNX LARGEMIDCAP 250" },
    @{ Prefix = "nifty_infrastructure"; Folder = "CNX INFRASTRUCTURE" },
    @{ Prefix = "nifty_smallcap_250"; Folder = "CNX SMALLCAP 250" },
    @{ Prefix = "nifty_midcap_150"; Folder = "CNX MIDCAP 150" },
    @{ Prefix = "nifty_500"; Folder = "CNX NIFTY 500" },
    @{ Prefix = "nifty_100"; Folder = "CNX 100" },
    @{ Prefix = "nifty_50"; Folder = "CNX NIFTY" },
    @{ Prefix = "nifty_bank"; Folder = "CNX BANK NIFTY" },
    @{ Prefix = "nifty_mnc"; Folder = "NIFTY MNC" }
)

# ========== HELPERS ==========
# Get 8-digit date: first from effdate.txt (written by exe --write-effdate), else from filenames in source.
function Get-EffdateForMovement {
    param([string]$ConfigPath, [string]$SourceFolder)
    if ($ConfigPath) {
        $dir = Split-Path -Parent $ConfigPath
        $effdateFile = Join-Path $dir "effdate.txt"
        if (Test-Path -LiteralPath $effdateFile) {
            $d = (Get-Content -LiteralPath $effdateFile -Raw).Trim()
            if ($d -match "^\d{8}$") { return $d }
        }
    }
    $files = Get-ChildItem -Path $SourceFolder -File -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        if ($f.Name -match "(\d{8})") { return $Matches[1] }
    }
    return $null
}

function Expand-ZipToDirectory {
    param([string]$ZipPath, [string]$DestDir)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    # If destination already has files from a previous run, clear it so we can replace with fresh contents.
    if (Test-Path -LiteralPath $DestDir) {
        Get-ChildItem -Path $DestDir -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
    }
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $DestDir)
}

# Extract password-protected zip using 7-Zip (script + 7z = no AV flag on exe). Returns $true if success.
function Expand-ZipWith7Zip {
    param([string]$ZipPath, [string]$DestDir, [string]$Password, [ref]$ErrorMsg)
    $ErrorMsg.Value = $null
    $path7z = $null
    $pf = [Environment]::GetFolderPath("ProgramFiles")
    $pf86 = [Environment]::GetFolderPath("ProgramFilesX86")
    if ($pf) { $p = Join-Path $pf "7-Zip\7z.exe"; if (Test-Path -LiteralPath $p) { $path7z = $p } }
    if (-not $path7z -and $pf86) { $p = Join-Path $pf86 "7-Zip\7z.exe"; if (Test-Path -LiteralPath $p) { $path7z = $p } }
    if (-not $path7z) {
        try {
            $where = & where.exe 7z 2>$null
            if ($where) { $path7z = ($where -split "`n")[0].Trim() }
        } catch { }
    }
    if (-not $path7z -or -not (Test-Path -LiteralPath $path7z)) {
        $ErrorMsg.Value = "7-Zip not found. Install 7-Zip or add 7z.exe to PATH for password-protected zips."
        return $false
    }
    if (-not (Test-Path -LiteralPath $ZipPath)) { $ErrorMsg.Value = "Zip file not found."; return $false }
    New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
    $argList = @("x", "-y", "-o$DestDir", "-p$Password", $ZipPath)
    try {
        $proc = Start-Process -FilePath $path7z -ArgumentList $argList -Wait -PassThru -NoNewWindow
        if ($proc.ExitCode -ne 0) { $ErrorMsg.Value = "7z exit code $($proc.ExitCode)"; return $false }
        return $true
    } catch { $ErrorMsg.Value = $_.Exception.Message; return $false }
}

# ========== MAIN ==========
$ErrorActionPreference = "Stop"
Write-Host "Final Movement (script)" -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $SourceFolder)) {
    Write-Host "ERROR: Source folder not found: $SourceFolder" -ForegroundColor Red
    exit 30
}

foreach ($d in @($IndexOutputDir, $FinFieOutputDir, $CustodianDataDir)) {
    if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

$extractedDate = Get-EffdateForMovement -ConfigPath $ConfigPath -SourceFolder $SourceFolder
if (-not $extractedDate) {
    Write-Host "ERROR: No date for file movement. Run MacroTest.exe --write-effdate first, or ensure effdate.txt exists or source has files with 8-digit date." -ForegroundColor Red
    exit 30
}
Write-Host "Date (effdate): $extractedDate"

$indexDateFolder = Join-Path $IndexOutputDir $extractedDate
New-Item -ItemType Directory -Path $indexDateFolder -Force | Out-Null

# Zips to process: index/NAV/VALUEFY by date (yyyymmdd or ddmmyy); FIN/FIE by prefix (FIN{ddmmy}.ZIP, FIE{ddmmy}.ZIP)
$ddmmyy = $extractedDate.Substring(6,2) + $extractedDate.Substring(4,2) + $extractedDate.Substring(2,2)
$allZips = Get-ChildItem -Path $SourceFolder -Filter "*.zip" -File -ErrorAction SilentlyContinue | Where-Object {
    $n = $_.Name; $l = $n.ToLowerInvariant()
    $n -match $extractedDate -or $n -match $ddmmyy -or $l -match '^fin\d' -or $l -match '^fie\d'
} | ForEach-Object { $_.FullName }
Write-Host "Zip files (date $extractedDate / $ddmmyy + FIN/FIE): $($allZips.Count)"

# ---------- STEP 1a: MOVE INDEX ZIPS ----------
Write-Host "`n=== STEP 1a: MOVE INDEX ZIPS ===" -ForegroundColor Cyan
$moved = @()
foreach ($zipPath in $allZips) {
    $name = [System.IO.Path]::GetFileName($zipPath)
    $lower = $name.ToLowerInvariant()
    if ($lower -match "rlmf_rlmf") { continue }
    if ($lower -match "^(fin|fie)") { continue }

    $folder = $null
    foreach ($entry in $IndexMap) {
        if ($lower.StartsWith($entry.Prefix)) { $folder = $entry.Folder; break }
    }
    if (-not $folder) { continue }

    $destDir = Join-Path $indexDateFolder $folder
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    $destZip = Join-Path $destDir $name

    try {
        Move-Item -LiteralPath $zipPath -Destination $destZip -Force
        Write-Host "  MOVED: $name -> $folder"
        $moved += @{ DestZip = $destZip; Folder = $folder; Name = $name }
    } catch { Write-Host "  FAIL: $name - $_" -ForegroundColor Red }
}
Write-Host "Step 1a done. Moved $($moved.Count) index zips."

# ---------- STEP 1b: EXTRACT INDEX ZIPS ----------
Write-Host "`n=== STEP 1b: EXTRACT INDEX ZIPS ===" -ForegroundColor Cyan
foreach ($m in $moved) {
    try {
        Expand-ZipToDirectory -ZipPath $m.DestZip -DestDir (Split-Path $m.DestZip)
        Write-Host "  EXTRACTED: $($m.Name)"
    } catch { Write-Host "  EXTRACT FAILED: $($m.Name) - $_" -ForegroundColor Red }
}
Write-Host "Step 1b done."

# ---------- STEP 2: RLMF NAV ZIP (password-protected: use 7-Zip; else built-in) ----------
Write-Host "`n=== STEP 2: RLMF NAV ZIP ===" -ForegroundColor Cyan
$navZip = $allZips | Where-Object { [System.IO.Path]::GetFileName($_).ToLowerInvariant() -match "^rlmf_rlmf_navcsv1_\d{6}\.zip$" } | Select-Object -First 1
if (-not $navZip) { Write-Host "  Not found." }
else {
    $navName = [System.IO.Path]::GetFileName($navZip)
    Write-Host "  Found: $navName"
    if ($navName -match "(\d{6})") {
        $ddmmyy = $Matches[1]
        $ddmmyyyy = $ddmmyy.Substring(0,4) + "20" + $ddmmyy.Substring(4,2)
    } else { $ddmmyyyy = $extractedDate }

    $navExtract = Join-Path $SourceFolder "_nav_extract"
    if (Test-Path $navExtract) { Remove-Item -Recurse -Force $navExtract }
    New-Item -ItemType Directory -Path $navExtract -Force | Out-Null
    $extracted = $false
    if ($Password) {
        $errMsg = ""
        if (Expand-ZipWith7Zip -ZipPath $navZip -DestDir $navExtract -Password $Password -ErrorMsg ([ref]$errMsg)) { $extracted = $true }
        else { Write-Host "  FAIL (7-Zip): $errMsg" -ForegroundColor Red }
    }
    if (-not $extracted) {
        try {
            Expand-ZipToDirectory -ZipPath $navZip -DestDir $navExtract
            $extracted = $true
        } catch { Write-Host "  FAIL (built-in): $_" -ForegroundColor Red }
    }
    if ($extracted) {
        $firstFile = Get-ChildItem -Path $navExtract -File | Select-Object -First 1
        if ($firstFile) {
            $destCsv = Join-Path $CustodianDataDir "NAV_$ddmmyyyy.csv"
            Move-Item -LiteralPath $firstFile.FullName -Destination $destCsv -Force
            Write-Host "  OK: $($firstFile.Name) -> NAV_$ddmmyyyy.csv"
        } else { Write-Host "  WARN: zip empty." }
    }
    if (Test-Path $navExtract) { Remove-Item -Recurse -Force $navExtract -ErrorAction SilentlyContinue }
}

# ---------- STEP 3: RLMF VALUEFY ZIP (password-protected: use 7-Zip; else built-in) ----------
Write-Host "`n=== STEP 3: RLMF VALUEFY ZIP ===" -ForegroundColor Cyan
$valuefyDdmmyy = ""
$valZip = $allZips | Where-Object { [System.IO.Path]::GetFileName($_).ToLowerInvariant() -match "^rlmf_rlmf_valuefy_\d{6}\.zip$" } | Select-Object -First 1
if (-not $valZip) { Write-Host "  Not found." }
else {
    $valName = [System.IO.Path]::GetFileName($valZip)
    Write-Host "  Found: $valName"
    if ($valName -match "(\d{6})") { $valuefyDdmmyy = $Matches[1] }

    $valTemp = Join-Path $SourceFolder "_valuefy_temp"
    if (Test-Path $valTemp) { Remove-Item -Recurse -Force $valTemp }
    New-Item -ItemType Directory -Path $valTemp -Force | Out-Null
    $extracted = $false
    if ($Password) {
        $errMsg = ""
        if (Expand-ZipWith7Zip -ZipPath $valZip -DestDir $valTemp -Password $Password -ErrorMsg ([ref]$errMsg)) { $extracted = $true }
        else { Write-Host "  FAIL (7-Zip): $errMsg" -ForegroundColor Red }
    }
    if (-not $extracted) {
        try {
            Expand-ZipToDirectory -ZipPath $valZip -DestDir $valTemp
            $extracted = $true
        } catch { Write-Host "  FAIL (built-in): $_" -ForegroundColor Red }
    }
    if ($extracted) {
        $destFolder = Join-Path (Join-Path $CustodianDataDir "VALUEFY$valuefyDdmmyy") "RLMF_RLMF_VALUEFY"
        New-Item -ItemType Directory -Path $destFolder -Force | Out-Null
        Get-ChildItem -Path $valTemp -File | ForEach-Object {
            Move-Item -LiteralPath $_.FullName -Destination (Join-Path $destFolder $_.Name) -Force
            Write-Host "  OK: $($_.Name) -> VALUEFY$valuefyDdmmyy\RLMF_RLMF_VALUEFY"
        }
    }
    if (Test-Path $valTemp) { Remove-Item -Recurse -Force $valTemp -ErrorAction SilentlyContinue }
}

# ---------- STEP 4: FIN / FIE ZIPS ----------
Write-Host "`n=== STEP 4: FIN / FIE ZIPS ===" -ForegroundColor Cyan
foreach ($prefix in @("fin","fie")) {
    $found = $allZips | Where-Object { [System.IO.Path]::GetFileName($_).ToLowerInvariant().StartsWith($prefix) } | Select-Object -First 1
    if (-not $found) { Write-Host "  $($prefix.ToUpper()): not found."; continue }
    $fname = [System.IO.Path]::GetFileName($found)
    if (-not (Test-Path -LiteralPath $found)) { Write-Host "  ${fname}: source gone."; continue }
    try {
        # Extract in source folder (under a temp subfolder), delete zip, then move files to destination, replacing existing
        $tempDir = Join-Path $SourceFolder "_${prefix}_temp"
        if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

        Expand-ZipToDirectory -ZipPath $found -DestDir $tempDir
        Remove-Item -LiteralPath $found -Force

        Get-ChildItem -Path $tempDir -File -Recurse | ForEach-Object {
            $destPath = Join-Path $FinFieOutputDir $_.Name
            Move-Item -LiteralPath $_.FullName -Destination $destPath -Force
        }

        Remove-Item -Recurse -Force $tempDir
        Write-Host "  OK: $fname -> OtherData (unzipped in source, moved files)"
    } catch { Write-Host "  FAIL: $fname - $_" -ForegroundColor Red }
}

    # ---------- STEP 5: VALUEFY EXCEL CLEAN (requires Excel installed) ----------
Write-Host "`n=== STEP 5: VALUEFY EXCEL CLEAN ===" -ForegroundColor Cyan
if ($valuefyDdmmyy) {
    $excelPath = Join-Path (Join-Path (Join-Path $CustodianDataDir "VALUEFY$valuefyDdmmyy") "RLMF_RLMF_VALUEFY") "IN_MF_TRADE_DUMP_REPORT.xls"
    if (Test-Path -LiteralPath $excelPath) {
        try {
            $excel = New-Object -ComObject Excel.Application
            $excel.Visible = $false
            $excel.DisplayAlerts = $false
            $wb = $excel.Workbooks.Open($excelPath)
            $sheet = $wb.Sheets.Item(1)
            $used = $sheet.UsedRange
            $lastRow = $used.Rows.Count
            $qtyCol = $null; $assetCol = $null
            for ($c = 1; $c -le 50; $c++) {
                $h = ($sheet.Cells.Item(1, $c).Text -as [string]).Trim().ToLower()
                if ($h -eq "quantity") { $qtyCol = $c }
                if ($h -eq "asset type") { $assetCol = $c }
                if ($qtyCol -and $assetCol) { break }
            }
            if ($qtyCol -and $assetCol) {
                $rowsToDelete = [System.Collections.ArrayList]@()
                for ($r = 2; $r -le $lastRow; $r++) {
                    $qtyVal = $sheet.Cells.Item($r, $qtyCol).Value2
                    $qty = 0; if ($qtyVal -ne $null) { [double]::TryParse($qtyVal.ToString(), [ref]$qty) | Out-Null }
                    $asset = (($sheet.Cells.Item($r, $assetCol).Text -as [string]) -as [string]).Trim().ToUpper()
                    if ($qty -eq 0 -and $asset -ne "PTC") { $rowsToDelete.Add($r) | Out-Null }
                    elseif ($qty -eq 0 -and $asset -eq "PTC") { $sheet.Cells.Item($r, $qtyCol).Value2 = 0.01 }
                }
                for ($i = $rowsToDelete.Count - 1; $i -ge 0; $i--) {
                    $sheet.Rows.Item($rowsToDelete[$i]).Delete() | Out-Null
                }
            }
            $wb.Save()
            $wb.Close($false)
            $excel.Quit()
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
            Write-Host "  OK: cleaned"
        } catch {
            Write-Host "  FAIL (Excel COM): $_" -ForegroundColor Red
            Write-Host "  If Excel is not installed, skip this step or run the .exe only for Excel clean."
        }
    } else { Write-Host "  Not found: $excelPath" }
} else { Write-Host "  No VALUEFY folder (Step 3 not run)." }

# ---------- DONE ----------
Write-Host "`n=== DONE ===" -ForegroundColor Green
Write-Host "  Index   -> $IndexOutputDir\$extractedDate\"
Write-Host "  FIN/FIE -> $FinFieOutputDir"
Write-Host "  RLMF    -> $CustodianDataDir"
Write-Host "  xlsx    -> left in $SourceFolder"
