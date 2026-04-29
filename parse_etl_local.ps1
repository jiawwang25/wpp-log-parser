# ETL Parser - tracefmt.exe in same directory
# Path: C:\wpplog\log\typeC
# Usage: cd C:\wpplog\log\typeC
#        .\parse_etl_local.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ETL Log Parser" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Set the log directory
$logDir = "C:\wpplog\log\typeC"

# Change to log directory
Set-Location $logDir
Write-Host "Working directory: $logDir" -ForegroundColor Yellow

# Check if tracefmt.exe exists in current directory
if (-not (Test-Path ".\tracefmt.exe")) {
    Write-Host "ERROR: tracefmt.exe not found in $logDir" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "Found: tracefmt.exe" -ForegroundColor Green

# Get ETL files (exclude .txt and .sum files)
Write-Host ""
Write-Host "Searching for ETL files..." -ForegroundColor Yellow
$allFiles = Get-ChildItem -Filter "*.etl*" -File

# Filter out .txt and .sum files
$etlFiles = $allFiles | Where-Object { 
    $_.Extension -ne ".txt" -and 
    $_.Extension -ne ".sum" -and 
    $_.Name -notlike "*.txt" -and 
    $_.Name -notlike "*.sum"
}

if ($allFiles.Count -gt $etlFiles.Count) {
    $skippedFileCount = $allFiles.Count - $etlFiles.Count
    Write-Host "Skipped $skippedFileCount non-ETL file(s) (.txt, .sum)" -ForegroundColor Yellow
}

if ($etlFiles.Count -eq 0) {
    Write-Host "ERROR: No ETL files found!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Found $($etlFiles.Count) ETL file(s) to process:" -ForegroundColor Green
foreach ($file in $etlFiles) {
    Write-Host "  - $($file.Name) ($([math]::Round($file.Length/1KB, 2)) KB)" -ForegroundColor White
}

# Set environment variable
$env:TRACE_FORMAT_PREFIX = "[%9!d!][%8!04x!.%3!04x!: %4!s!][%1!s!]%2!s!: %!FUNC!::"

# Symbol path
$symbolPath = "CACHE*c:\SymCache;SRV*http://mssymbolproxy:80;SRV*http://msdl.microsoft.com/download/symbols;SRV*http://windowssymbols.qualcomm.com/symbols/"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Processing Files" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Process each file
$successCount = 0
$failCount = 0
$skippedCount = 0

foreach ($file in $etlFiles) {
    Write-Host ""
    Write-Host "--- Processing: $($file.Name) ---" -ForegroundColor Cyan
    
    $inputFile = $file.Name
    $outputFile = "$inputFile.txt"
    
    # Skip if output already exists
    if (Test-Path $outputFile) {
        $existingSize = (Get-Item $outputFile).Length
        Write-Host "SKIPPED: Output already exists ($([math]::Round($existingSize/1KB, 2)) KB)" -ForegroundColor Yellow
        $skippedCount++
        continue
    }
    
    Write-Host "Input:  $inputFile" -ForegroundColor Gray
    Write-Host "Output: $outputFile" -ForegroundColor Gray
    
    try {
        # Run tracefmt using .\ prefix
        $arguments = "`"$inputFile`" -o `"$outputFile`" -p -r $symbolPath"
        
        Write-Host "Executing: .\tracefmt.exe $arguments" -ForegroundColor Gray
        
        $process = Start-Process -FilePath ".\tracefmt.exe" -ArgumentList $arguments -Wait -PassThru -NoNewWindow
        
        # Check result
        if (Test-Path $outputFile) {
            $outputSize = (Get-Item $outputFile).Length
            Write-Host "SUCCESS: Created $outputFile ($([math]::Round($outputSize/1KB, 2)) KB)" -ForegroundColor Green
            $successCount++
            
            # Show first few lines
            if ($outputSize -gt 0) {
                Write-Host "First 3 lines:" -ForegroundColor Yellow
                Get-Content $outputFile -TotalCount 3 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
            } else {
                Write-Host "WARNING: Output file is empty (0 bytes)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "FAILED: Output file not created (Exit code: $($process.ExitCode))" -ForegroundColor Red
            $failCount++
        }
    }
    catch {
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $failCount++
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total files: $($etlFiles.Count)" -ForegroundColor White
Write-Host "Skipped (already parsed): $skippedCount" -ForegroundColor Yellow
Write-Host "Success: $successCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor Red

Write-Host ""
Write-Host "Output files location: $logDir" -ForegroundColor Yellow
Write-Host ""

Read-Host "Press Enter to exit"
