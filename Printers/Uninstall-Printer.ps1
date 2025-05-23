#powershell
# Remove a Per-Machine Named Network Printer
#Requires -RunAsAdministrator
#Requires -Version 3.0
<#
.SYNOPSIS
    Remove a Per-Machine Named Network Printer
.DESCRIPTION
    This script will Remove a per-machine named network printer to the system.
    It will also check for any existing printers with the same name.
    Restarts the print spooler service if necessary.
.PARAMETER PrinterPath
    Full printer path as \\server\printername
.EXAMPLE
    .\Remove-Printer.ps1 -PrinterPath "\\server\printername"

    This will Remove the printer located at \\server\printername from the system as a Per-Machine Named Network Printer
.NOTES
    Author:    Jason W. Garel
    Version:   1.0.1
    Created :  05-16-25
    Modified : 05-19-25
    Change Log:
        1.0.1 - JWG - Updated error handling and logging. Changed final "return" to "exit" to ensure proper exit behavior with Altiris.
                      Exported Find-NetworkPrinterList and Initialize-Spooler to PrinterHandling module for easier reuse.
    Dependencies: Write-Log.psm1 and PrinterHandling.psm1
.INPUTS
    Requires the full printer path to be passed in as a parameter.
    The printer path should be in the format of \\server\printername
.OUTPUTS
    Built for Altiris, this script returns 0 for success, 1 for critical errors.
    Logs are saved in $LogFile
.FUNCTIONALITY
    This script is unattended; Designed to be deployed, run as a scheduled task or run from the command line.
#>
param ([Parameter(Mandatory=$true, HelpMessage="Full printer path as \\server\printername")][ValidateNotNullOrEmpty()][string]$PrinterPath)

#region --={ Initialization }=--
Import-Module "..\Include\Write-Log.psm1"
Import-Module "..\Include\PrinterHandling.psm1"
$LogFile  = "C:\Temp\Logs\Uninstall-Printer.log"
$ExitCode = 0
#endregion

function Find-InstalledPrinter {
    param([Parameter(Mandatory=$true, HelpMessage="Full printer path as \\server\printername")][ValidateNotNullOrEmpty()][string]$PrinterPath)

    $PrinterList = Find-NetworkPrinterList
    if (!$PrinterList -or $PrinterList.Count -eq 0) { Write-Log "No per-machine shared network printer connections found at all."; return $false }
    if ($PrinterList -contains $PrinterPath) { Write-Log "Found '$PrinterPath' in printer list" return $true }
    else { Write-Log "Printer '$PrinterPath' not found in printer list. Nothing to uninstall."; return $false }}


#region --={ Main Loop }=--
Write-Host "Log file is '$LogFile'" # This is to make PSSA stop complaining about the $LogFile not being set
Write-Log "--=( Starting Network Printer Removal Script )=--" "Start!"

#Check if path is a valid UNC Path
$PathValid = $PrinterPath -match '^\\\\[^\\]+\\[^\\]+$'
if (!$PathValid) { Write-Log "Invalid printer path: '$PrinterPath' - Path must be in the format of \\server\printername." "ERROR!"; EXIT 1 }

# Check to see if the printer is installed and log it
Initialize-Spooler | Out-Null
if (Find-InstalledPrinter $PrinterPath) { Write-Log "Printer '$PrinterPath' is already installed. Proceeding to uninstall..." } 
else { Write-Log "Printer '$PrinterPath' not found. Nothing to uninstall."; EXIT 0 }

# Remove, then verify the printer was uninstalled
Remove-NetworkPrinter $PrinterPath | Out-Null
if (Find-InstalledPrinter $PrinterPath) { Write-Log "Failed to remove printer '$PrinterPath'." "ERROR!" $ExitCode = 1 }
else { Write-Log "Successfully removed printer '$PrinterPath'." $ExitCode = 0 }

# Restart the spooler service
try {
    Write-Log "Restarting Print Spooler service..." "Spool!"
    Restart-Service -Name Spooler -Force -ErrorAction SilentlyContinue | Out-Null
    Write-Log "Print Spooler service restarted" "Spool!"}
catch { Write-Log "Failed to restart Print Spooler service: $($_.Exception.Message)" "ERROR!" }
finally { Write-Log "--=( Finished Network Printer Removal Script )=--" "-End!-"; EXIT $ExitCode }
#endregion --={ Main Loop }=--