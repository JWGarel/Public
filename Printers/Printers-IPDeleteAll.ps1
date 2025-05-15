#powershell
# Delete all Per-Machine IP Printers
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Delete all Per-Machine IP Printers

.DESCRIPTION
    First verifies the spooler is running, then retrieves a list of all per-machine IP printer connections.
    Records each one to a log file while attempting to delete each one using PrintUI.dll.
    Logs are saved in $LogFile

.NOTES
    Author: Jason W. Garel
    Version: 1.0
    Creation Date: 03-03-25
    Permissions: Admin rights
    Dependencies: Write-Log.psm1 

.OUTPUT
    Returns $true for lack of critical errors, otherwise $false.
#>
#region --={ Initialization }=--
Import-Module "..\Include\Write-Log.psm1"
$LogFile = "C:\Temp\Logs\Printers-IPDeleteAll.log"
$Rundll32Path = Join-Path $env:SystemRoot "System32\rundll32.exe"

Write-Host "Log file: $LogFile" # This is to make PSSA stop complaining about the $LogFile not being set
Write-Log "--=( Starting IP Printer Delete Script )=--" "Start!"
#endregion

#region --={ Define Functions }=--
function Initialize-Spooler {
    $SpoolerStatus = (Get-Service -Name Spooler -ErrorAction SilentlyContinue).Status
    if ($SpoolerStatus -ne "Running") {
        Write-Log "Print Spooler service is not running. Attempting to start it..."
        try {
            Start-Service -Name Spooler -ErrorAction Stop
            Write-Log "Print Spooler service started successfully."
            $SpoolerStatus = (Get-Service -Name Spooler -ErrorAction SilentlyContinue).Status }
        catch { Write-Log "Failed to start Print Spooler service: $($_.Exception.Message)" "ERROR!"; return $false }}
    else { Write-Log "Print spooler is running."; return $true }}

function Remove-IPPrinter {
    param([Parameter(Mandatory=$true)][System.Management.Automation.PSObject]$Printer)
    try {
        $Arguments = "/dl /n ""$($Printer.Name)"""
        Write-Log "PrintUI Arguments: $Arguments"
        $PrinterDeleteString = Start-Process -FilePath $Rundll32Path -ArgumentList "printui.dll,PrintUIEntry $Arguments" -Wait -PassThru -ErrorAction SilentlyContinue
        if ($PrinterDeleteString.ExitCode -ne 0) {
            Write-Log "Failed to delete printer: $($Printer.Name). Exit code: $($PrinterDeleteString.ExitCode)" "ERROR!"
            switch ($PrinterDeleteString.ExitCode) {
                2 { Write-Log "Access denied or (more likely) printer not found for '$Printer'." "ERROR!" }
                5 { Write-Log "Access denied or printer not found for '$Printer'." "ERROR!" }
                123 { Write-Log "Invalid printer name: '$Printer'." "ERROR!" }
                1314 { Write-Log "Access denied while deleting '$Printer'." "ERROR!" }
                1703 { Write-Log "RPC_S_INVALID_BINDING. Likely an issue with the spooler for '$Printer'." "ERROR!" }
                1722 { Write-Log "RPC_S_SERVER_UNAVAILABLE. Likely an issue with the spooler for '$Printer'." "ERROR!" }
                2147467259 { Write-Log "Failed to find driver packages to process for '$Printer'." "ERROR!" }
                default { Write-Log "Unknown error ($($PrinterDeleteString.ExitCode)) while deleting '$Printer'." "ERROR!" }}}
         else { Write-Log "Deleted printer: $($Printer.Name)" "-Name-" }}
    catch { Write-Log "Critical error deleting printer: $($Printer.Name). $($_.Exception.Message)" "ERROR!"; return $false }}
#endregion

#region --={ Main Loop }=--
# Start Spooler and populate printer list
try {
    Initialize-Spooler
    Write-Log "----------------------------" "------"
    $IPPrinters = @()
    $Printers = Get-Printer }
catch { Write-Log "Critical error indexing printers: $($_.Exception.Message)" "ERROR!"; return $false }

# Start printer delete loop
try {
    foreach ($Printer in $Printers) {
        $PortName = $Printer.PortName
        if ($PortName -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$") {
            Write-Log "----------------------------" "------"
            Write-Log "$PortName" -Type "--IP--"
            $IPPrinters += $Printer
            Remove-IPPrinter $Printer }}}
catch { Write-Log "Critical error deleting printers: $($_.Exception.Message)" "ERROR!"; return $false }

# Close out log file
if ($IPPrinters) { Write-Log "Found $($IPPrinters.Count) local IP printers." }
else { Write-Log "No local IP printers found." }
Write-Log "--=( Local IP Printer Delete Script Finished )=--" "-END!-"
return $true
#endregion