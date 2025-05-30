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
    Version:   1.0.6
    Created :  03-03-25
    Modified : 05-29-25
    Dependencies: Write-Log.psm1 and PrinterHandling.psm1
.OUTPUTS
    Returns 0 for success and 1 for error state.
    Logs are saved in $LogFile
.FUNCTIONALITY
    This script is unattended; Designed to be deployed, run as a scheduled task or run from the command line.
#>
#region --=( Initialization )=--
Import-Module "..\Include\Write-Log.psm1"
Import-Module "..\Include\PrinterHandling.psm1"
$LogFile    = "C:\Temp\Logs\Printers-IPDeleteAll.log"
Write-Host    "The log file is located at $LogFile"
$ErrorLevel = 0
#endregion --=( Initialization )=--

#region --=( Main Loop )=--
Write-Log     "--=( Starting IP Printer Delete Script )=--" "Start!"
try   { $null = Initialize-Spooler }
catch { Write-Log "Critical error in Initializing Spooler!  $($_.Exception.Message)" "ERROR!"; $ErrorLevel = 1 }

Write-Log "----------------------------" "------"
try   { $IPPrinters = Find-IPPrinterList }
catch { Write-Log "Critical error while finding IP printers $($_.Exception.Message)" "ERROR!"; $ErrorLevel = 1 }

if ($IPPrinters.Count -ne 0) { 
    Write-Log "Found $($IPPrinters.Count) local IP printers."
    try {
        $IPPrintersRemoved = 0
        foreach ($IPPrinter in $IPPrinters) {
            Write-Log "Removing $($Printer.Name)" "Delete"
            $IPPrintersRemoved += 1
            $null = Remove-NetworkPrinter $($Printer.Name) }
        Write-Log "Removed $($IPPrintersRemoved) local IP printers." }
    catch { Write-Log "Critical error deleting printers: $($_.Exception.Message)" "ERROR!" }
    
    Write-Log "Making sure all IP printers were deleted..." "Verify"
    $IPPrinters = @() # Clear the array to hold IP printers
    $IPPrinters = Find-IPPrinterList
    if ($IPPrinters) { Write-Log "Found $($IPPrinters.Count) local IP printers." "Error!"; $ErrorLevel = 1 }
    else { Write-Log "No local IP printers found." $ErrorLevel = 0 }}
else { Write-Log "No local IP printers found." }

Write-Log "--=( Local IP Printer Delete Script Finished )=--" "-End!-"
EXIT $ErrorLevel
#endregion --=( Main Loop )=--