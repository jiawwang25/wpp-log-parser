param([string]$LogFile = 'XhciTrace.etl.001.txt')

$LogPath = Join-Path 'C:\wpplog\log\typeC' $LogFile
$csvPath = $LogPath -replace '\.txt$', '_portsc_complete.csv'

Write-Host ('Analyzing ' + $LogFile + '...') -ForegroundColor Cyan

$powerPatterns = @('Entering Hibernate', 'Resuming from Hibernate', 'Entering Modern Standby', 'Exiting Modern Standby')
$powerEvents = @()
foreach ($pattern in $powerPatterns) {
    $found = Select-String -Path $LogPath -Pattern $pattern -AllMatches -ErrorAction SilentlyContinue
    if ($found) {
        foreach ($match in $found) {
            if ($match.Line -match '\[.*?\]\[(.*?)\]') { $timestamp = $Matches[1] } else { $timestamp = 'N/A' }
            $powerEvents += [PSCustomObject]@{ LineNumber = $match.LineNumber; Timestamp = $timestamp; PortAddress = $pattern }
            Write-Host ('  Found: ' + $pattern + ' at line ' + $match.LineNumber) -ForegroundColor Green
        }
    } else {
        Write-Host ('  Skipped: ' + $pattern + ' (not found)') -ForegroundColor Yellow
    }
}

$portscPattern = 'RootHub_DumpPortData::PortRegister\s+(0x[0-9A-Fa-f]+)\s+PortSC\s+(0x[0-9A-Fa-f]+)'
$portscMatches = Select-String -Path $LogPath -Pattern $portscPattern
$entries = @()
foreach ($m in $portscMatches) {
    if ($m.Line -match '\[.*?\]\[(.*?)\].*?PortRegister\s+(0x[0-9A-Fa-f]+)\s+PortSC\s+(0x[0-9A-Fa-f]+)') {
        $ts = $Matches[1]; $pa = $Matches[2]; $ps = [Convert]::ToUInt32($Matches[3], 16)
        $entries += [PSCustomObject]@{
            LineNumber = $m.LineNumber; Timestamp = $ts; PortAddress = $pa
            PortSC = '0x' + $ps.ToString('X8')
            CCS = if (($ps -band 0x00000001) -ne 0) { 1 } else { 0 }
            PED = if (($ps -band 0x00000002) -ne 0) { 1 } else { 0 }
            OCA = if (($ps -band 0x00000008) -ne 0) { 1 } else { 0 }
            PR  = if (($ps -band 0x00000010) -ne 0) { 1 } else { 0 }
            PLS = ($ps -shr 5) -band 0x0F
            PP  = if (($ps -band 0x00000200) -ne 0) { 1 } else { 0 }
            PS  = ($ps -shr 10) -band 0x0F
            CSC = if (($ps -band 0x00020000) -ne 0) { 1 } else { 0 }
            PEC = if (($ps -band 0x00040000) -ne 0) { 1 } else { 0 }
            WRC = if (($ps -band 0x00080000) -ne 0) { 1 } else { 0 }
            OCC = if (($ps -band 0x00100000) -ne 0) { 1 } else { 0 }
            PRC = if (($ps -band 0x00200000) -ne 0) { 1 } else { 0 }
            PLC = if (($ps -band 0x00400000) -ne 0) { 1 } else { 0 }
            CEC = if (($ps -band 0x00800000) -ne 0) { 1 } else { 0 }
            WPR = if (($ps -band 0x80000000) -ne 0) { 1 } else { 0 }
        }
    }
}

foreach ($pe in $powerEvents) {
    $entries += [PSCustomObject]@{
        LineNumber = $pe.LineNumber; Timestamp = $pe.Timestamp; PortAddress = $pe.PortAddress
        PortSC = ''; CCS = ''; PED = ''; OCA = ''; PR = ''; PLS = ''; PP = ''; PS = ''
        CSC = ''; PEC = ''; WRC = ''; OCC = ''; PRC = ''; PLC = ''; CEC = ''; WPR = ''
    }
}

$entries = $entries | Sort-Object LineNumber
$entries | Export-Csv -Path $csvPath -NoTypeInformation
Write-Host 'Complete!' -ForegroundColor Green
Write-Host ('Total entries : ' + $entries.Count) -ForegroundColor Cyan
Write-Host ('Power events  : ' + $powerEvents.Count) -ForegroundColor Cyan
Write-Host ('CSV saved to  : ' + $csvPath) -ForegroundColor Yellow