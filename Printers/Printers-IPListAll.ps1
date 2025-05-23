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
    Version:   1.0.5
    Created :  03-03-25
    Modified : 05-22-25
    Change Log:
        05-22-25 - JWG - Added no printers found line and .COMPONENT section.
        05-19-25 - JWG - Updated error handling and logging. Changed final "return" to "exit" to ensure proper exit behavior with Altiris.
                          Exported functions to Include/PrinterHandling.psm1
        05-09-25 - JWG - Finished formatting cleanup, added regions, added ErrorAction, changed Verify-Spooler to Intitialize-Spooler
        05-04-25 - JWG - Revised some error logging and cleaned up formatting
        04-29-25 - JWG - Switched from old Log-Message to new Write-Log script. Added more try/catch loops.
                          Fixed printer count error by adding missing $($IPPrinters.Count)
        04-22-25 - JWG - Added this improved comment block to better follow standard PowerShell commenting procedure.
        04-08-25 - JWG - Updated Log-Message to use \logs directory. Restructured script into modular functions.
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
$LogFile = "C:\Temp\Logs\Printers-IPListAll.log"
Import-Module "..\Include\Write-Log.psm1" # Allow logging via Write-Log
Import-Module "..\Include\PrinterHandling.psm1" # Printer handling functions
$ErrorLevel = 0
Write-Host "Log file: $LogFile" # This is to make PSSA stop complaining about the $LogFile not being set
Write-Log "--=( Starting IP Printer Listing Script )=--" "Start!"
#endregion

#region --={ Main Loop }=--
try {
    Initialize-Spooler | Out-Null
    Write-Log "----------------------------" "------"
    $Found = Find-IPPrinterList
    if (!$Found) { Write-Log "----------------------------" "------" }}
catch { Write-Log "Critical error in main loop: $($_.Exception.Message)" "ERROR!"; $ErrorLevel = 1 }

Write-Log "--=( Finished IP Printer Listing Script )=--" "-END!"
EXIT $ErrorLevel
#endregion