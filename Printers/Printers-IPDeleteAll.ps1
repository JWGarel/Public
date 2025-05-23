#powershell
# Delete all Per-Machine IP Printers
#Requires -RunAsAdministrator
#Requires -Version 3.0
<#
.SYNOPSIS
    Delete all Per-Machine IP Printers
.DESCRIPTION
    First verifies the spooler is running, then retrieves a list of all per-machine IP printer connections.
    Records each one to a log file while attempting to delete each one using PrintUI.dll.
.NOTES
    Author:    Jason W. Garel
    Version:   1.0.5
    Created :  03-03-25
    Modified : 05-19-25
    Change Log:
        05-19-25 - JWG - Added error handling for the Print Spooler service. Added more error handling for the printer delete loop.
                         Added verification of the printer deletion loop.
                         Added more error handling for the printer delete function. Added more logging.
                         Changed final "return" to "exit" to ensure proper exit behavior with Altiris.
                         Exported functions to PrinterHandling module for easier reuse.
        05-09-25 - JWG - Finished formatting cleanup, added regions, added ErrorAction, changed Verify-Spooler to Intitialize-Spooler
        05-04-25 - JWG - Revised some error logging and cleaned up formatting. Minor bugfixes.
        04-29-25 - JWG - Switched from old Log-Message to new Write-Log script. Added more try/catch loops and errorlevel returns.
                         Fixed printer count error by adding missing $($IPPrinters.Count)
        04-22-25 - JWG - Added this improved comment block to better follow standard PowerShell commenting procedure.
        04-08-25 - JWG - Updated Write-Log to use \logs directory. Restructured script into modular functions.
    Dependencies: Write-Log.psm1 and PrinterHandling.psm1
.OUTPUTS
    Returns 0 for success and 1 for error state.
    Logs are saved in $LogFile
.FUNCTIONALITY
    This script is unattended; Designed to be deployed, run as a scheduled task or run from the command line.
#>
#region --={ Initialization }=--
Import-Module "..\Include\Write-Log.psm1"
Import-Module "..\Include\PrinterHandling.psm1"
$ErrorLevel = 0
$LogFile = "C:\Temp\Logs\Printers-IPDeleteAll.log"
#endregion --={ Initialization }=--

#region --={ Main Loop }=--
Write-Host "Log file: $LogFile" # This is to make PSSA stop complaining about the $LogFile not being set
Write-Log "--=( Starting IP Printer Delete Script )=--" "Start!"

# Start Spooler and populate printer list
Initialize-Spooler | Out-Null
Write-Log "----------------------------" "------"
$IPPrinters = Find-IPPrinterList 

# Check if any printers were found ( Currently this is just a modified version of Find-IPPrinterList )
if ($IPPrinters.Count -eq 0) { Write-Log "No local IP printers found." }
else {
    Write-Log "Found $($IPPrinters.Count) local IP printers."

    # Start printer delete loop
    try {
        $IPPrintersRemoved = 0
        foreach ($IPPrinter in $IPPrinters) {
            Write-Log "Removing $($Printer.Name)" "Delete"
            $IPPrintersRemoved += 1
            Remove-NetworkPrinter $($Printer.Name) | Out-Null }
        Write-Log "Removed $($IPPrintersRemoved) local IP printers." }
    catch { Write-Log "Critical error deleting printers: $($_.Exception.Message)" "ERROR!" }
    
    #Verify that the printers were deleted
    Write-Log "Making sure all IP printers were deleted..." "Verify"
    $IPPrinters = @() # Clear the array to hold IP printers
    $IPPrinters = Find-IPPrinterList
    if ($IPPrinters) { Write-Log "Found $($IPPrinters.Count) local IP printers."; $ErrorLevel = 1 }
    else { Write-Log "No local IP printers found." $ErrorLevel = 0 }}

Write-Log "--=( Local IP Printer Delete Script Finished )=--" "-END!-"
EXIT $ErrorLevel
#endregion --={ Main Loop }=--