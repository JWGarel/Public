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
    Version:   1.0.2
    Created :  05-16-25
    Modified : 05-19-25
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
$LogFile    = "C:\Temp\Logs\Uninstall-Printer.log"
$ExitCode   = 0
#endregion

#region --={ Main Loop }=--
Write-Host "Your logfile is located at $LogFile"
Write-Log  "--=( Starting Network Printer Removal Script )=--" "Start!"

#Check if path is a valid UNC Path
$PathValid = $PrinterPath -match '^\\\\[^\\]+\\[^\\]+$'
if (!$PathValid) { Write-Log "Invalid printer path: '$PrinterPath' - Path must be in the format of \\server\printername." "ERROR!"; EXIT 1 }

# Check to see if the printer is installed and log it
$null = Initialize-Spooler
if (Find-InstalledPrinter $PrinterPath) { Write-Log "Printer '$PrinterPath' is already installed. Proceeding to uninstall..." } 
else { Write-Log "Printer '$PrinterPath' not found. Nothing to uninstall."; EXIT 0 }

# Remove, then verify the printer was uninstalled
$null = Remove-NetworkPrinter $PrinterPath
if (Find-InstalledPrinter $PrinterPath) { Write-Log "Failed to remove printer '$PrinterPath'." "ERROR!" $ExitCode = 1 }
else { Write-Log "Successfully removed printer '$PrinterPath'." $ExitCode = 0 }

# Restart the spooler service
try {
    Write-Log "Restarting Print Spooler service..." "Spool!"
    $null = Restart-Service -Name Spooler -Force -ErrorAction SilentlyContinue
    Write-Log "Print Spooler service restarted" "Spool!"}
catch { Write-Log "Failed to restart Print Spooler service: $($_.Exception.Message)" "ERROR!" }
finally { Write-Log "--=( Finished Network Printer Removal Script )=--" "-End!-"; EXIT $ExitCode }
#endregion --={ Main Loop }=--