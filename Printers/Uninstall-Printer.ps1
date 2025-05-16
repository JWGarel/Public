#powershell
# Remove a Per-Machine Named Network Printer
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Remove a Per-Machine Named Network Printer

.DESCRIPTION
    This script will Remove a per-machine named network printer to the system.
    It will also check for any existing printers with the same name.
    Restarts the print spooler service if necessary.

.EXAMPLE
    .\Remove-Printer.ps1 -PrinterPath "\\server\printername"

    This will Remove the printer located at \\server\printername from the system as a Per-Machine Named Network Printer

.NOTES
    Author: Jason W. Garel
    Version: 1.0
    Created: 05-16-25
    Permissions : Admin Rights
    Dependencies: Write-Log

.INPUTS
    Requires the full printer path to be passed in as a parameter.
    The printer path should be in the format of \\server\printername

.OUTPUTS
    Built for Altiris, this script returns 0 for success, 1 for critical errors.

.FUNCTIONALITY
    This script is unattended; Designed to be deployed, run as a scheduled task or run from the command line.
#>
param ([Parameter(Mandatory=$true)][string]$PrinterPath)

#region --={ Initialization }=--
Import-Module "..\Include\Write-Log.psm1"
$LogFile = "C:\Temp\Logs\Uninstall-Printer.log"
#endregion

#region --={ Functions }=--
function Find-NetworkPrinterList {
    $PrinterKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print\Connections"
    try {
        return Get-ChildItem $PrinterKey -ErrorAction SilentlyContinue |
            ForEach-Object {
                try { (Get-ItemProperty -Path $_.PSPath -Name Printer -ErrorAction SilentlyContinue).Printer }
                catch { Write-Log "Error getting printer path for '$($_.PSPath)': $($_.Exception.Message)" "Error!"; continue }}}
    catch { Write-Log "Error loading Network pritners: $($_.Exception.Message)" "ERROR!" }}
#endregion

#region --={ Main Loop }=--
Write-Host "Log file is '$LogFile'" # This is to make PSSA stop complaining about the $LogFile not being set
Write-Log "--=( Starting Network Printer Removal Script )=--" "Start!"
$ExitCode = 0

#Check if path is a valid UNC Path
$PathValid = $PrinterPath -match '^\\\\[^\\]+\\[^\\]+$'
if (!$PathValid) { Write-Log "Invalid printer path: '$PrinterPath' - Path must be in the format of \\server\printername." "ERROR!"; EXIT 1 }

#region --={ Check to see if the spooler service is running }=--
$SpoolerStatus = (Get-Service -Name Spooler -ErrorAction SilentlyContinue).Status
if ($SpoolerStatus -ne "Running") {
    Write-Log "Print Spooler service is not running. Attempting to start it..."
    try {
        Start-Service -Name Spooler -ErrorAction Stop
        Write-Log "Print Spooler service started successfully."
        $SpoolerStatus = (Get-Service -Name Spooler -ErrorAction SilentlyContinue).Status
        if ($SpoolerStatus -ne "Running") { Write-Log "Print Spooler service is not running. Exiting script." "ERROR!"; EXIT 1 }}
    catch { Write-Log "Failed to start Print Spooler service: $($_.Exception.Message)" "ERROR!"; EXIT 1 }}
else { Write-Log "Print spooler is running." }
#endregion

#region --={ Check to see if the printer is installed }=--
$PrinterList = @()
$PrinterList = Find-NetworkPrinterList
try {
    if ($PrinterList) {
        foreach ($Printer in $PrinterList) {
            if ($Printer -eq $PrinterPath) {
                Write-Log "Found '$Printer' in printer list." }}
    else { Write-Log "No per-machine shared network printer connections found."; EXIT 0 }}}    
catch { Write-Log "Critical error checking if printer was already installed: $($_.ExceptionMessage)" "Error!" }
#endregion

#region --={ Uninstall the printer }=--
try {
    Write-Log "Removing printer '$PrinterPath' from this computer..."
    $RunDLL32 = Join-Path $env:windir 'System32\Rundll32.exe'
    $PrinterInstallPath = "printui.dll,PrintUIEntry /gd /n `"$PrinterPath`" /q" # Won't display error messages
    Write-Log "RunDLL32 Arguments: $PrinterInstallPath"
    $PrinterInstall = Start-Process -FilePath $RunDLL32 -ArgumentList $PrinterInstallPath -Wait -PassThru -ErrorAction SilentlyContinue
    if ($PrinterInstall.ExitCode -ne 0) {
        Write-Log "Failed to install printer '$PrinterPath'. Exit code: $($PrinterInstall.ExitCode)" "ERROR!"
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
#endregion

#region --={ Verify the printer was uninstalled }=--
try {
    $PrinterList = @()
    $PrinterList = Find-NetworkPrinterList
    if ($PrinterList) {
        foreach ($Printer in $PrinterList) {
            if ($Printer -eq $PrinterPath) {
                Write-Log "Printer is still installed!" "ERROR!"; EXIT 1 }
            else { Write-Log "Verified, '$Printer' has been uninstalled, printer not found." "--OK--" }}}
    else { Write-Log "No per-machine shared network printer connections found at all." "--OK--" }}    
catch { Write-Log "Critical error checking if printer was installed: $($_.ExceptionMessage)" "ERROR!"; $ExitCode = 1 }
#endregion

#region --={ Restart the spooler service }=--
try {
    Write-Log "Restarting Print Spooler service..."
    Restart-Service -Name Spooler -Force -ErrorAction SilentlyContinue | Out-Null
    Write-Log "Print Spooler service restarted" "SPOOL!"}
catch { Write-Log "Failed to restart Print Spooler service: $($_.Exception.Message)" "ERROR!" }
finally { Write-Log "--=( Finished Network Printer Removal Script )=--" "-End!-" }
return $ExitCode
#endregion 
#endregion