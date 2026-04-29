# ETL Log Analysis Tools - Complete Guide

## Overview
This directory contains tools for analyzing USB XHCI ETL (Event Trace Log) files. All tools parse WPP traces and decode PortSC register values for USB debugging.

**Location:** C:\wpplog\log\typeC

---

## Files in This Directory

### Scripts
1. **parse_etl_local.ps1** - ETL to text converter
   - Automatically parses all ETL files in directory
   - Skips already-parsed files (if .txt exists)
   - Filters out .sum and .txt files
   - Uses tracefmt.exe with proper symbol paths

2. **final_portsc.ps1** - PortSC register analyzer (MAIN TOOL)
   - Parses PortSC register values from ETL logs
   - Outputs CSV with all bit fields as 0/1
   - Searches for power events and inserts them into CSV in timestamp sequence
   - Skips power event patterns not found in log and continues to next
   - Accepts -LogFile parameter to analyze any log file
   - **This is the primary analysis tool**

3. **analyze_pls_details.ps1** - Detailed PLS state analysis
   - Analyzes Port Link State (bits 5-8)
   - Shows PLS transitions and statistics
   - Includes binary representation

### Output Files
- **XhciTrace.etl.001_portsc_complete.csv** - Complete PortSC analysis
  - All bit fields decoded as 0 or 1
  - Ready for Excel/analysis tools

### Documentation
- **README.md** - This file

---

## Quick Start

### Step 1: Parse ETL Files
`powershell
cd C:\wpplog\log\typeC
.\parse_etl_local.ps1
`
This converts all .etl files to .txt format.

### Step 2: Analyze PortSC Registers
```powershell
powershell -ExecutionPolicy Bypass -File "C:\wpplog\log\typeC\final_portsc.ps1" -LogFile "XhciTrace.etl.001.txt"
```
This creates XhciTrace.etl.001_portsc_complete.csv with all bit fields.

### Step 3: Open CSV in Excel
The CSV file is ready for analysis with all PortSC bits decoded.

---

## CSV Output Format

### Columns (19 total):
`
LineNumber, Timestamp, PortAddress, PortSC, CCS, PED, OCA, PR, PLS, PP, PS, CSC, PEC, WRC, OCC, PRC, PLC, CEC, WPR
`

### Column Descriptions:

**Metadata:**
- **LineNumber** - Line number in the ETL log
- **Timestamp** - Event timestamp
- **PortAddress** - USB port register address, or power event name if row is a power event
- **PortSC** - Raw PortSC value (hex), empty for power event rows

**Status Bits:**
- **CCS** (Bit 0) - Current Connect Status (1=connected, 0=disconnected)
- **PED** (Bit 1) - Port Enabled/Disabled (1=enabled, 0=disabled)
- **OCA** (Bit 3) - Over-current Active (1=over-current, 0=normal)
- **PR** (Bit 4) - Port Reset (1=resetting, 0=not resetting)
- **PLS** (Bits 5-8) - Port Link State (0=U0, 3=U3, 5=RxDetect, 7=Polling)
- **PP** (Bit 9) - Port Power (1=powered, 0=not powered)
- **PS** (Bits 10-13) - Port Speed (0=Undefined, 1=Full, 3=High, 4=Super)

**Change Bits (Write 1 to Clear):**
- **CSC** (Bit 17) - Connect Status Change
- **PEC** (Bit 18) - Port Enabled/Disabled Change
- **WRC** (Bit 19) - Warm Port Reset Change
- **OCC** (Bit 20) - Over-current Change
- **PRC** (Bit 21) - Port Reset Change
- **PLC** (Bit 22) - Port Link State Change
- **CEC** (Bit 23) - Port Config Error Change
- **WPR** (Bit 31) - Warm Port Reset

---

## Port Link State (PLS) Values

| Value | Name | Description |
|-------|------|-------------|
| 0 | U0 | Normal operation, port enabled |
| 1 | U1 | Low power state (USB 3.0) |
| 2 | U2 | Deeper low power state (USB 3.0) |
| 3 | U3 | Suspended |
| 4 | Disabled | Port disabled |
| 5 | RxDetect | Detecting device presence |
| 6 | Inactive | Port inactive (USB 3.0) |
| 7 | Polling | Link training in progress |
| 8 | Recovery | Error recovery |
| 9 | Hot Reset | Hot reset in progress |
| 10 | Compliance | Compliance testing mode |
| 11 | Test Mode | Test mode |
| 15 | Resume | Resume signaling |

---

## Port Speed (PS) Values

| Value | Speed | Description |
|-------|-------|-------------|
| 0 | Undefined | Speed not determined |
| 1 | Full Speed | 12 Mbps (USB 1.1/2.0) |
| 2 | Low Speed | 1.5 Mbps (USB 1.0) |
| 3 | High Speed | 480 Mbps (USB 2.0) |
| 4 | Super Speed | 5 Gbps (USB 3.0) |
| 5 | Super Speed Plus | 10 Gbps (USB 3.1) |

---

## Common USB Issues and Diagnosis

### Issue 1: Repeated Connect/Disconnect
**Symptoms:** Multiple CSC=1 events, rapid PLS transitions

**CSV Pattern:**
`
CCS changes: 0 -> 1 -> 0 -> 1
PLS pattern: 5 (RxDetect) -> 7 (Polling) -> 5 (RxDetect)
`

**Possible Causes:**
- Loose cable/connector
- Power delivery issues
- Signal integrity problems

### Issue 2: Link Training Failure
**Symptoms:** Stuck in PLS=7 (Polling), never reaches PLS=0 (U0)

**CSV Pattern:**
`
PLS=7 for extended time
CCS=1, PED=0
`

**Possible Causes:**
- USB 3.0 signal quality issues
- Cable not USB 3.0 compliant
- Device/host incompatibility

### Issue 3: Device Not Detected
**Symptoms:** Port stuck in PLS=5 (RxDetect)

**CSV Pattern:**
`
PLS=5 continuously
CCS=0
PP=1
`

**Possible Causes:**
- No device connected
- Device not drawing power
- VBUS not present

---

## Advanced Analysis

### Detailed PLS Analysis
For detailed Port Link State analysis with transitions:
`powershell
.\analyze_pls_details.ps1 -LogPath XhciTrace.etl.001.txt
`

This provides:
- PLS state statistics
- State transition tracking
- Binary representation of PortSC
- Detailed examples of each state

---

## Symbol Paths

The tools use the following symbol paths for trace resolution:
`
CACHE*c:\SymCache
SRV*http://mssymbolproxy:80
SRV*http://msdl.microsoft.com/download/symbols
SRV*http://windowssymbols.qualcomm.com/symbols/
`

---

## Requirements

- **tracefmt.exe** - Must be in the same directory or in PATH
  - Part of Windows Driver Kit (WDK)
  - Download: https://docs.microsoft.com/en-us/windows-hardware/drivers/download-the-wdk

- **PowerShell** - Windows PowerShell 5.1 or later

---

## Troubleshooting

### Error: tracefmt.exe not found
**Solution:** Copy tracefmt.exe to C:\wpplog\log\typeC or install WDK

### Error: Script execution policy
**Solution:** Run with bypass:
`powershell
powershell -ExecutionPolicy Bypass -File script.ps1
`

### Empty CSV output
**Solution:** Ensure ETL file has been parsed to .txt first using parse_etl_local.ps1

---

## Today'\''s Accomplishments

### What Was Created:
1. ✅ Complete ETL parsing workflow
2. ✅ PortSC register decoder with all 32 bits
3. ✅ CSV output with 0/1 values (not TRUE/FALSE)
4. ✅ Exact column order as specified
5. ✅ Cleaned up old/unused scripts
6. ✅ Comprehensive documentation

### Key Features:
- **Automatic file detection** - Finds all ETL files
- **Smart skip logic** - Avoids reprocessing
- **Complete bit decoding** - All PortSC bits as 0/1
- **Excel-ready output** - CSV format for easy analysis
- **Persistent skills** - Saved for future sessions

---

## Reference

### XHCI Specification
- **Document:** extensible-host-controler-interface-usb-xhci.pdf
- **Key Section:** 5.4.8 - Port Status and Control Register (PortSC)
- **Location:** C:\Users\jiawwang\OneDrive - Qualcomm\study\

### Key Functions in Logs
- **HUBPDO_CreatePdoInternal** - Creates Physical Device Object
- **RootHub_DumpPortData** - Dumps port register data
- **DsmState*** - Device State Machine functions
- **Psm*State*** - Port State Machine functions

---

## Support

For issues or questions about these tools, refer to:
- This README
- ETL_ANALYSIS_SKILL.md (in project root)
- XHCI specification section 5.4.8

---

## Version History

**v1.0 - 2026-04-29**
- Initial release
- Complete PortSC analysis with all bit fields
- CSV output with 0/1 values
- Comprehensive documentation

**v1.1 - 2026-04-29**
- Added power event detection to final_portsc.ps1
- Power events inserted into CSV in timestamp sequence
- Supported: Entering Hibernate, Resuming from Hibernate, Entering Modern Standby, Exiting Modern Standby
- Skips patterns not found in log and continues to next
- Added -LogFile parameter to support any log file

---

**Last Updated:** April 29, 2026 (v1.1)
**Location:** C:\wpplog\log\typeC
