#powershell
# Add a Per-Machine Named Network Printer
#Requires -RunAsAdministrator
#Requires -Version 3.0
<#
.SYNOPSIS
    Add a Per-Machine Named Network Printer
.DESCRIPTION
    This script will add a per-machine named network printer to the system.
    It will also check for any existing printers with the same name.
    Restarts the print spooler service if necessary.
.EXAMPLE
    .\Install-Printer.ps1 -PrinterPath "\\server\printername"

    This will add the printer located at \\server\printername to the system as a Per-Machine Named Network Printer
.NOTES
    Author:    Jason W. Garel
    Version:   1.0.1
    Created :  05-16-25
    Modified : 05-19-25
    Dependencies: Write-Log.psm1 and PrinterHandling.psm1 modules
.INPUTS
    Requires the full printer path to be passed in as a parameter.
    The printer path should be in the format of \\server\printername
.OUTPUTS
    Built for Altiris, this script returns 0 for success, 1 for critical errors.
    Logs are saved in $LogFile
.FUNCTIONALITY
    This script is unattended; Designed to be deployed, run as a scheduled task or run from the command line.
#>
#region --={ Initialization }=--
param ([Parameter(Mandatory=$true, HelpMessage="Full printer path as \\server\printername")][ValidateNotNullOrEmpty()][string]$PrinterPath)
Import-Module "..\Include\Write-Log.psm1"
Import-Module "..\Include\PrinterHandling.psm1"
$LogFile    = "C:\Temp\Logs\Install-Printer.log"
Write-Host    "Log file is '$LogFile'" # This is to make PSSA stop complaining about the $LogFile not being set
Write-Log     "--=( Starting Network Printer Install Script )=--" "Start!"
$ExitCode   = 0
#endregion --={ Initialization }=--

#region --={ Main Loop }=--
#Check if path is a valid UNC Path
$PrinterPath = $PrinterPath.Trim() # Remove leading or trailing whitespace
$IsPathValid = $PrinterPath -match '^\\\\[^\\]+\\[^\\]+$'
if (!$IsPathValid) { Write-Log "Invalid printer path: '$PrinterPath' - Path must be in the format of \\server\printername." "ERROR!"; EXIT 1 }
$null = Initialize-Spooler

#region --={ Check to see if the printer is already installed }=--
try {
    $PrinterList = @() # I never know if initializing this in powershell is necessary, but it doesn't hurt.
    $PrinterList = Find-NetworkPrinterList
    if ($PrinterList) {
        foreach ($Printer in $PrinterList) {
            if ($Printer -eq $PrinterPath) {
                Write-Log "Printer '$Printer' already installed, exiting script."; EXIT 0 }}
    else { Write-Log "No per-machine shared network printer connections found." }}}    
catch { Write-Log "Critical error checking if printer was already installed: $($_.ExceptionMessage)" "Error!" }
#endregion --={ Check to see if the printer is already installed }=--

#region --={ Install the printer }=--
try {
    $PrinterName = ($PrinterPath -split '\\')[-1] # Split-Path does not work with UNC paths reliably, so we do this.
    $RunDLL32 = Join-Path $env:windir 'System32\Rundll32.exe'
    $PrinterInstallPath = "printui.dll,PrintUIEntry /ga /b `"$PrinterName`" /n `"$PrinterPath`" /u /q"
    Write-Log "RunDLL32 Arguments: $PrinterInstallPath"
    $PrinterInstall = Start-Process -FilePath $RunDLL32 -ArgumentList $PrinterInstallPath -Wait -PassThru -ErrorAction SilentlyContinue
    if ($PrinterInstall.ExitCode -ne 0) {
        Write-Log "Failed to install printer '$PrinterPath'. Exit code: $($PrinterInstall.ExitCode)" "ERROR!"
        $ExitCode = 1
        switch ($PrinterInstall.ExitCode) {
            2 { Write-Log "Access denied or (more likely) printer not found for '$PrinterPath'." "ERROR!" }
            5 { Write-Log "Access denied or printer not found for '$PrinterPath'." "ERROR!" }
            123 { Write-Log "Invalid printer name: '$PrinterPath'." "ERROR!" }
            1314 { Write-Log "Access denied while installing '$PrinterPath'." "ERROR!" }
            1703 { Write-Log "RPC_S_INVALID_BINDING. Likely an issue with the spooler for '$PrinterPath'." "ERROR!" }
            1722 { Write-Log "RPC_S_SERVER_UNAVAILABLE. Likely an issue with the spooler for '$PrinterPath'." "ERROR!" }
            2147467259 { Write-Log "Failed to find driver packages to process for '$PrinterPath'." "ERROR!" }
            default { Write-Log "Unknown error ($($PrinterInstall.ExitCode)) while installing '$PrinterPath'." "ERROR!" }}}}
catch { Write-Log "Critical error installing printer: $($_.Exception.Message)" "ERROR!"; $ExitCode = 1 }
#endregion --={ Install the printer }=--

#region --={ Verify the printer was installed }=--
try {
    $PrinterList = @()
    $PrinterList = Find-NetworkPrinterList
    if ($PrinterList -contains $PrinterPath) { Write-Log "Verified: printer '$PrinterPath' installed successfully." "--OK--"; $ExitCode = 0 } # If the printer is in the list, it was installed successfully
    else { Write-Log "Printer '$PrinterPath' not found, install failed!" "ERROR!"; $ExitCode = 1}}
catch { Write-Log "Critical error checking if printer was installed: $($_.ExceptionMessage)" "ERROR!"; $ExitCode = 1 }
#endregion --={ Verify the printer was installed }=--

#region --={ Restart the spooler service }=--
try {
    Write-Log "Restarting Print Spooler service..." "SPOOL!"
    $null = Restart-Service -Name Spooler -Force -ErrorAction SilentlyContinue
    Write-Log "Print Spooler service restarted" "SPOOL!"}
catch { Write-Log "Failed to restart Print Spooler service: $($_.Exception.Message)" "ERROR!" }
finally { Write-Log "--=( Finished Network Printer Install Script )=--" "-End!-" }
EXIT $ExitCode
#endregion --={ Restart the spooler service }=--
#endregion --={ Main Loop }=--