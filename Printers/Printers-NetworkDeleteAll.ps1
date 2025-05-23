#powershell
# Delete all Per-Machine Named Network Printers
#Requires -RunAsAdministrator
#Requires -Version 3.0
<#
.SYNOPSIS
    Delete all Per-Machine Named Network Printers
.DESCRIPTION
    This script retrieves a list of all per-machine named network printer connections
    from the Windows registry and then attempts to delete each one using PrintUI.dll.
    This only applies to network named printers, not IP or local.
.NOTES
    Author:    Jason W. Garel
    Version:   1.0.4
    Created :  01-28-25
    Modified : 05-19-25
    Change Log:
        05-19-25 - JWG - Updated error handling and logging. Changed final "return" to "exit" to ensure proper exit behavior with Altiris.
                         Exported functions to Include/PrinterHandling.psm1
        05-09-25 - JWG - Added -ErrorAction to functions that needed it. Finished cleanup of formatting, added regions.
        05-04-25 - JWG - Revised some error logging and cleaned up formatting
        04-29-25 - JWG - Switched from old Log-Message to new Write-Log script. Added more try/catch loops.
        04-22-25 - JWG - Added this improved comment block to better follow standard PowerShell commenting procedure.
        04-08-25 - JWG - Updated Log-Message to use \logs directory. Restructured script into modular functions.
    Dependencies: Write-Log.psm1 and PrinterHandling.psm1
.OUTPUTS
    Returns 1 for critical errors, otherwise 0
    Logs are saved in $LogFile
.FUNCTIONALITY
    This script is unattended; Designed to be deployed, run as a scheduled task or run from the command line.
.COMPONENT
    Printer
#>

#region --={ Initialization }=--
Import-Module "..\Include\Write-Log.psm1"       # Allow logging via Write-Log
Import-Module "..\Include\PrinterHandling.psm1" # Printer handling functions
$LogFile = "C:\Temp\Logs\Printers-NetworkDeleteAll.log"
$ErrorLevel = 0
Write-Host "Log file: $LogFile" # This is to make PSSA stop complaining about the $LogFile not being set
Write-Log "--=( Starting Network Printer Removal Script )=--" "Start!"
#endregion

#region --={ Main Loop }=--
try {
    $PrinterList = Find-NetworkPrinterList
    if ($PrinterList) {
        Write-Log "Found $($PrinterList.Count) printer connections. Removing..."
        foreach ($Printer in $PrinterList) { Remove-NetworkPrinter($Printer) }
        Write-Log "All detected network printers processed, verifying removal..."
        $PrinterList = Find-NetworkPrinterList
        if ($PrinterList) { Write-Log "Found $($PrinterList.Count) network printer connections after removal!" "ERROR!"; $ErrorLevel = 1 }
        else { Write-Log "No network printer connections found after removal." }}
    else { Write-Log "No network printer connections found." }}
catch { Write-Log "Critical error in main loop: $($_.ExceptionMessage)" "ERROR!"; $ErrorLevel = 1 }
finally { Write-Log "--=( Finished Network Printer Removal Script )=--" "-END!-" }
EXIT $ErrorLevel
#endregion --={ Main Loop }=--