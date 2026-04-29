# Detailed PLS (Port Link State) Analysis for XHCI
# Based on XHCI Specification Section 5.4.8 - Bits 5-8
# Usage: .\analyze_pls_details.ps1 -LogPath "C:\wpplog\log\typeC\XhciTrace.etl.001.txt"

param(
    [Parameter(Mandatory = $true)]
    [string]$LogPath
)

# Port Link State (PLS) definitions from XHCI Spec Section 5.4.8
$plsDefinitions = @{
    0 = @{
        Name = "U0"
        Description = "Normal operation state. Port is enabled and operational."
        USB2 = "L0 - Active state"
        USB3 = "U0 - Active state"
    }
    1 = @{
        Name = "U1"
        Description = "Low power link state (USB 3.0 only)"
        USB2 = "N/A"
        USB3 = "U1 - Low power state with fast exit"
    }
    2 = @{
        Name = "U2"
        Description = "Deeper low power link state (USB 3.0 only)"
        USB2 = "N/A"
        USB3 = "U2 - Lower power state with slower exit"
    }
    3 = @{
        Name = "U3"
        Description = "Suspended state. Port is in suspend mode."
        USB2 = "L2 - Suspend"
        USB3 = "U3 - Suspend"
    }
    4 = @{
        Name = "Disabled"
        Description = "Port is disabled. No traffic allowed."
        USB2 = "Disabled"
        USB3 = "SS.Disabled"
    }
    5 = @{
        Name = "RxDetect"
        Description = "Receiver detection. Port is detecting if device is attached."
        USB2 = "N/A"
        USB3 = "Rx.Detect - Checking for device presence"
    }
    6 = @{
        Name = "Inactive"
        Description = "Port is inactive (USB 3.0 only)"
        USB2 = "N/A"
        USB3 = "SS.Inactive - Port inactive"
    }
    7 = @{
        Name = "Polling"
        Description = "Link training in progress. Negotiating link parameters."
        USB2 = "N/A"
        USB3 = "Polling - Link training and speed negotiation"
    }
    8 = @{
        Name = "Recovery"
        Description = "Link recovery. Attempting to recover from error."
        USB2 = "N/A"
        USB3 = "Recovery - Error recovery state"
    }
    9 = @{
        Name = "Hot Reset"
        Description = "Hot reset in progress"
        USB2 = "Reset"
        USB3 = "Hot Reset"
    }
    10 = @{
        Name = "Compliance Mode"
        Description = "Compliance testing mode (USB 3.0 only)"
        USB2 = "N/A"
        USB3 = "Compliance Mode - For electrical testing"
    }
    11 = @{
        Name = "Test Mode"
        Description = "Test mode for compliance testing"
        USB2 = "Test Mode"
        USB3 = "Loopback - Test mode"
    }
    15 = @{
        Name = "Resume"
        Description = "Resume signaling in progress"
        USB2 = "Resume (K-state)"
        USB3 = "Resume - Exiting from suspend"
    }
}

function Get-PLSFromPortSC {
    param([uint32]$PortSC)
    return ($PortSC -shr 5) -band 0x0F
}

function Get-SpeedFromPortSC {
    param([uint32]$PortSC)
    return ($PortSC -shr 10) -band 0x0F
}

function Get-AllBitsFromPortSC {
    param([uint32]$PortSC)
    
    return @{
        CCS  = ($PortSC -band 0x00000001) -ne 0  # Bit 0
        PED  = ($PortSC -band 0x00000002) -ne 0  # Bit 1
        OCA  = ($PortSC -band 0x00000004) -ne 0  # Bit 3
        PR   = ($PortSC -band 0x00000010) -ne 0  # Bit 4
        PLS  = ($PortSC -shr 5) -band 0x0F       # Bits 5-8
        PP   = ($PortSC -band 0x00000200) -ne 0  # Bit 9
        PS   = ($PortSC -shr 10) -band 0x0F      # Bits 10-13
        CSC  = ($PortSC -band 0x00020000) -ne 0  # Bit 17
        PEC  = ($PortSC -band 0x00040000) -ne 0  # Bit 18
        WRC  = ($PortSC -band 0x00080000) -ne 0  # Bit 19
        OCC  = ($PortSC -band 0x00100000) -ne 0  # Bit 20
        PRC  = ($PortSC -band 0x00200000) -ne 0  # Bit 21
        PLC  = ($PortSC -band 0x00400000) -ne 0  # Bit 22
        CEC  = ($PortSC -band 0x00800000) -ne 0  # Bit 23
        WPR  = ($PortSC -band 0x80000000) -ne 0  # Bit 31
    }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "XHCI Port Link State (PLS) Analysis" -ForegroundColor Cyan
Write-Host "Bits 5-8 of PortSC Register" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Show PLS definitions
Write-Host "=== PLS (Port Link State) Definitions ===" -ForegroundColor Yellow
Write-Host ""
foreach ($key in 0..11 + 15 | Sort-Object) {
    if ($plsDefinitions.ContainsKey($key)) {
        $def = $plsDefinitions[$key]
        Write-Host ("PLS {0,2} (0x{0:X}): {1}" -f $key, $def.Name) -ForegroundColor Cyan
        Write-Host ("           {0}" -f $def.Description) -ForegroundColor Gray
        Write-Host ("           USB 2.0: {0}" -f $def.USB2) -ForegroundColor DarkGray
        Write-Host ("           USB 3.0: {0}" -f $def.USB3) -ForegroundColor DarkGray
        Write-Host ""
    }
}

# Extract and analyze log
Write-Host "=== Analyzing Log File ===" -ForegroundColor Yellow
Write-Host "Log: $LogPath" -ForegroundColor Gray
Write-Host ""

$pattern = 'RootHub_DumpPortData::PortRegister\s+(0x[0-9A-Fa-f]+)\s+PortSC\s+(0x[0-9A-Fa-f]+)'
$matches = Select-String -Path $LogPath -Pattern $pattern

if ($matches.Count -eq 0) {
    Write-Host "No PortSC entries found!" -ForegroundColor Red
    exit 1
}

Write-Host "Found $($matches.Count) PortSC register dumps" -ForegroundColor Green
Write-Host ""

# Parse entries
$entries = @()
foreach ($match in $matches) {
    if ($match.Line -match '\[.*?\]\[(.*?)\].*?PortRegister\s+(0x[0-9A-Fa-f]+)\s+PortSC\s+(0x[0-9A-Fa-f]+)') {
        $timestamp = $Matches[1]
        $portAddr = $Matches[2]
        $portSC = [Convert]::ToUInt32($Matches[3], 16)
        
        $pls = Get-PLSFromPortSC -PortSC $portSC
        $speed = Get-SpeedFromPortSC -PortSC $portSC
        $bits = Get-AllBitsFromPortSC -PortSC $portSC
        
        $plsInfo = if ($plsDefinitions.ContainsKey($pls)) { $plsDefinitions[$pls] } else { 
            @{ Name = "Reserved"; Description = "Reserved/Unknown state" }
        }
        
        $speedName = switch ($speed) {
            0 { "Undefined" }
            1 { "Full Speed (12 Mbps)" }
            2 { "Low Speed (1.5 Mbps)" }
            3 { "High Speed (480 Mbps)" }
            4 { "Super Speed (5 Gbps)" }
            5 { "Super Speed Plus (10 Gbps)" }
            default { "Unknown($speed)" }
        }
        
        $entries += [PSCustomObject]@{
            LineNumber = $match.LineNumber
            Timestamp = $timestamp
            PortAddress = $portAddr
            PortSC_Hex = "0x{0:X8}" -f $portSC
            PortSC_Binary = [Convert]::ToString($portSC, 2).PadLeft(32, '0')
            PLS_Value = $pls
            PLS_Name = $plsInfo.Name
            PLS_Description = $plsInfo.Description
            Speed_Value = $speed
            Speed_Name = $speedName
            CCS = $bits.CCS
            PED = $bits.PED
            PP = $bits.PP
            PR = $bits.PR
            CSC = $bits.CSC
            PEC = $bits.PEC
            PRC = $bits.PRC
            PLC = $bits.PLC
        }
    }
}

# PLS Statistics
Write-Host "=== PLS State Statistics ===" -ForegroundColor Yellow
$plsGroups = $entries | Group-Object PLS_Value | Sort-Object Name
foreach ($group in $plsGroups) {
    $plsNum = [int]$group.Name
    $plsInfo = if ($plsDefinitions.ContainsKey($plsNum)) { $plsDefinitions[$plsNum].Name } else { "Unknown" }
    Write-Host ("{0,3} occurrences of PLS {1,2} ({2})" -f $group.Count, $plsNum, $plsInfo) -ForegroundColor Cyan
}

# PLS Transitions
Write-Host "`n=== PLS State Transitions ===" -ForegroundColor Yellow
$portGroups = $entries | Group-Object PortAddress
foreach ($portGroup in $portGroups) {
    Write-Host "`nPort: $($portGroup.Name)" -ForegroundColor Cyan
    
    $portEntries = $portGroup.Group | Sort-Object LineNumber
    $prevPLS = $null
    $transitionCount = 0
    
    foreach ($entry in $portEntries) {
        if ($null -ne $prevPLS -and $prevPLS -ne $entry.PLS_Value) {
            $transitionCount++
            $prevInfo = if ($plsDefinitions.ContainsKey($prevPLS)) { $plsDefinitions[$prevPLS].Name } else { "Unknown" }
            Write-Host ("  Line {0,6}: {1} -> PLS {2} ({3}) to PLS {4} ({5})" -f `
                $entry.LineNumber, $entry.Timestamp, $prevPLS, $prevInfo, $entry.PLS_Value, $entry.PLS_Name) -ForegroundColor White
        }
        $prevPLS = $entry.PLS_Value
    }
    
    if ($transitionCount -eq 0) {
        Write-Host "  No PLS transitions detected" -ForegroundColor Gray
    }
}

# Detailed view of each unique PLS state
Write-Host "`n=== Detailed PLS State Examples ===" -ForegroundColor Yellow
$uniquePLS = $entries | Select-Object -Property PLS_Value -Unique | Sort-Object PLS_Value
foreach ($pls in $uniquePLS) {
    $plsNum = $pls.PLS_Value
    $plsInfo = if ($plsDefinitions.ContainsKey($plsNum)) { $plsDefinitions[$plsNum] } else { 
        @{ Name = "Unknown"; Description = "Unknown state" }
    }
    
    Write-Host ("`n--- PLS {0}: {1} ---" -f $plsNum, $plsInfo.Name) -ForegroundColor Cyan
    Write-Host "Description: $($plsInfo.Description)" -ForegroundColor Gray
    
    $examples = $entries | Where-Object { $_.PLS_Value -eq $plsNum } | Select-Object -First 3
    foreach ($ex in $examples) {
        Write-Host ("  Line {0}: {1}" -f $ex.LineNumber, $ex.Timestamp) -ForegroundColor White
        Write-Host ("    PortSC: {0}" -f $ex.PortSC_Hex) -ForegroundColor Gray
        Write-Host ("    Binary: {0}" -f $ex.PortSC_Binary) -ForegroundColor DarkGray
        Write-Host ("    Bits 5-8 (PLS): {0:D4} = {1}" -f [Convert]::ToString($plsNum, 2).PadLeft(4, '0'), $plsNum) -ForegroundColor Yellow
        Write-Host ("    Connected: {0}, Enabled: {1}, Power: {2}, Speed: {3}" -f `
            $ex.CCS, $ex.PED, $ex.PP, $ex.Speed_Name) -ForegroundColor Gray
    }
}

# Export detailed CSV
$csvPath = $LogPath -replace '\.txt$', '_pls_detailed.csv'
$entries | Select-Object LineNumber, Timestamp, PortAddress, PortSC_Hex, PLS_Value, PLS_Name, PLS_Description, `
    Speed_Value, Speed_Name, CCS, PED, PP, PR, CSC, PEC, PRC, PLC | 
    Export-Csv -Path $csvPath -NoTypeInformation

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Analysis Complete" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Detailed CSV exported to: $csvPath" -ForegroundColor Yellow
