#powershell
# List all Per-Machine Named Network Printers
#Requires -Version 3.0
<#
.SYNOPSIS
    List all Per-Machine Named Network Printers
.DESCRIPTION
    This script only lists the printers in a log file, does not change anything.
    This only applies to network named printers, not IP or local.
.NOTES
    Author:    Jason W. Garel
    Version:   1.0.4
    Created :  01-28-25
    Modified : 05-19-25
    Dependencies: Write-Log.psm1, PrinterHandling.psm1
.OUTPUTS
    Returns 1 for critical errors, otherwise 0
    Logs all detected network printers to $LogFile
.FUNCTIONALITY
    This script is unattended; Designed to be deployed, run as a scheduled task or run from the command line.
#>

#region --={ Initialization }=--
Import-Module "..\Include\Write-Log.psm1"
Import-Module "..\Include\PrinterHandling.psm1"
$LogFile    = "C:\Temp\Logs\Printers-NetworkListAll.log"
Write-Host    "The log file is located at $LogFile"
Write-Log     "--=( Starting Network Printer Listing Script )=--" "Start!"
$ErrorLevel = 0
#endregion

#region --={ Main Loop }=--
try {
    $PrinterList = @()
    $PrinterList = Find-NetworkPrinterList
    if ($PrinterList) {
        Write-Log "Found $($PrinterList.Count) printer connections. Listing..." "-List-"
        foreach ($Printer in $PrinterList) { Write-Log "Found Printer: $Printer" "-List-" }
        Write-Log "All detected network printers processed." "-List-" }
    else { Write-Log "No per-machine shared network printer connections found." }}
catch   { Write-Log "Critical error in main loop: $($_.ExceptionMessage)" "ERROR!"; $ErrorLevel = 1 }
finally { Write-Log "--=( Finished Network Printer Listing Script )=--" "-End!-" }

EXIT $ErrorLevel
#endregion