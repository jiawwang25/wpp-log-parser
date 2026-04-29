$LogPath = 'C:\wpplog\log\typeC\XhciTrace.etl.001.txt'
$csvPath = 'C:\wpplog\log\typeC\XhciTrace.etl.001_portsc_complete.csv'
$pattern = 'RootHub_DumpPortData::PortRegister\s+(0x[0-9A-Fa-f]+)\s+PortSC\s+(0x[0-9A-Fa-f]+)'
$matches = Select-String -Path $LogPath -Pattern $pattern
$entries = @()
foreach ($m in $matches) {
    if ($m.Line -match '\[.*?\]\[(.*?)\].*?PortRegister\s+(0x[0-9A-Fa-f]+)\s+PortSC\s+(0x[0-9A-Fa-f]+)') {
        $ts = $Matches[1]
        $pa = $Matches[2]
        $ps = [Convert]::ToUInt32($Matches[3], 16)
        $entries += [PSCustomObject]@{
            LineNumber = $m.LineNumber
            Timestamp = $ts
            PortAddress = $pa
            PortSC = '0x' + $ps.ToString('X8')
            CCS = if (($ps -band 1) -ne 0) { 1 } else { 0 }
            PED = if (($ps -band 2) -ne 0) { 1 } else { 0 }
            OCA = if (($ps -band 8) -ne 0) { 1 } else { 0 }
            PR = if (($ps -band 16) -ne 0) { 1 } else { 0 }
            PLS = (($ps -shr 5) -band 15)
            PP = if (($ps -band 512) -ne 0) { 1 } else { 0 }
            PS = (($ps -shr 10) -band 15)
            CSC = if (($ps -band 0x20000) -ne 0) { 1 } else { 0 }
            PEC = if (($ps -band 0x40000) -ne 0) { 1 } else { 0 }
            WRC = if (($ps -band 0x80000) -ne 0) { 1 } else { 0 }
            OCC = if (($ps -band 0x100000) -ne 0) { 1 } else { 0 }
            PRC = if (($ps -band 0x200000) -ne 0) { 1 } else { 0 }
            PLC = if (($ps -band 0x400000) -ne 0) { 1 } else { 0 }
            CEC = if (($ps -band 0x800000) -ne 0) { 1 } else { 0 }
            WPR = if (($ps -band 0x80000000) -ne 0) { 1 } else { 0 }
        }
    }
}
$entries | Export-Csv -Path $csvPath -NoTypeInformation
Write-Host 'Complete!' -ForegroundColor Green
