#powershell
# List all Per-Machine IP Printers
#Requires -Version 3.0
<#
.SYNOPSIS
    List all Per-Machine IP Printers
.DESCRIPTION
    First verifies the spooler is running, then retrieves a list of all per-machine IP printer connections.
    Records each one to a log file. Does not record any other kind of printer (such as per user or shared network printers)
.NOTES
    Author:    Jason W. Garel
    Version:   1.0.6
    Created :  03-03-25
    Modified : 05-29-25
    Dependencies: Write-Log.psm1 and PrinterHandling.psm1
.OUTPUTS
    Returns 1 for critical errors, otherwise 0
    Logs are saved in $LogFile
.FUNCTIONALITY
    This script is unattended; Designed to be deployed, run as a scheduled task or run from the command line.
.COMPONENT
    Printers
#>

#region --={ Initialization }=--
Import-Module "..\Include\Write-Log.psm1" # Allow logging via Write-Log
Import-Module "..\Include\PrinterHandling.psm1" # Printer handling functions
$LogFile    = "C:\Temp\Logs\Printers-IPListAll.log"
$ErrorLevel = 0
Write-Host    "The logfile is located at $LogFile"
#endregion

#region --={ Main Loop }=--
Write-Log     "--=( Starting IP Printer Listing Script )=--" "Start!"
try   { $null = Initialize-Spooler }
catch { Write-Log "Critical error in Initializing Spooler!  $($_.Exception.Message)" "ERROR!"; $ErrorLevel = 1 }

Write-Log "----------------------------" "------"
try   { $Found = Find-IPPrinterList }
catch { Write-Log "Critical error while finding IP printers $($_.Exception.Message)" "ERROR!"; $ErrorLevel = 1 }

if (!$Found) { Write-Log "----------------------------" "------" }

Write-Log "--=( Finished IP Printer Listing Script )=--" "-END!"
EXIT $ErrorLevel
#endregion