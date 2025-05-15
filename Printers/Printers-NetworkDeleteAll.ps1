#powershell
# Delete all Per-Machine Named Network Printers
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Delete all Per-Machine Named Network Printers

.DESCRIPTION
    This script retrieves a list of all per-machine named network printer connections
    from the Windows registry and then attempts to delete each one using PrintUI.dll.
    This only applies to network named printers, not IP or local.
    Logs are saved in $LogFile

.NOTES
    Author: Jason W. Garel
    Version: 1.0
    Creation Date: 01-28-25
    Permissions: Admin rights
    Dependencies: Write-Log.psm1

.OUTPUT
    Returns $true for lack of critical errors, otherwise $false.
#>

#region --={ Initialization }=--
Import-Module "..\Include\Write-Log.psm1" # Allow logging via Write-Log
$LogFile = "C:\Temp\Logs\Printers-NetworkDeleteAll.log"
$Rundll32Path = Join-Path $env:SystemRoot "System32\rundll32.exe"
$PrinterKeyLocation = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print\Connections"

Write-Host "Log file: $LogFile" # This is to make PSSA stop complaining about the $LogFile not being set
Write-Log "--=( Starting Network Printer Removal Script )=--" "Start!"
#endregion

#region --={ Functions }=--
function FindNetworkPrinters {
    param([Parameter(Mandatory=$true)][string]$PrinterKey)
    try { return Get-ChildItem $PrinterKey -ErrorAction SilentlyContinue | ForEach-Object {
            try { (Get-ItemProperty -Path $_.PSPath -Name Printer -ErrorAction SilentlyContinue).Printer }
            catch { Write-Log "Error getting printer path for '$($_.PSPath)': $($_.Exception.Message)" "Error!"; continue }}}
    catch { Write-Log "Error loading Network pritners: $($_.Exception.Message)" "ERROR!" }}

function DeleteNetworkPrinter {
    param([Parameter(Mandatory=$true)][string]$Printer)
    try {
        $Arguments = "/gd /n ""$Printer"""
        Write-Log "PrintUI Arguments: $Arguments" "Delete"
        $Result = Start-Process -FilePath $Rundll32Path -ArgumentList "printui.dll,PrintUIEntry $Arguments" -Wait -PassThru -ErrorAction Stop
        if ($Result.ExitCode -ne 0) {
            Write-Log "Failed to delete printer: $Printer. Exit code: $($Result.ExitCode)" "ERROR!"
            switch ($Result.ExitCode) {
                2 { Write-Log "Access denied or (more likely) printer not found for '$Printer'." "ERROR!" }
                5 { Write-Log "Access denied or printer not found for '$Printer'." "ERROR!" }
                123 { Write-Log "Invalid printer name: '$Printer'." "ERROR!" }
                1314 { Write-Log "Access denied while deleting '$Printer'." "ERROR!" }
                1703 { Write-Log "RPC_S_INVALID_BINDING. Likely an issue with the spooler for '$Printer'." "ERROR!" }
                1722 { Write-Log "RPC_S_SERVER_UNAVAILABLE. Likely an issue with the spooler for '$Printer'." "ERROR!" }
                2147467259 { Write-Log "Failed to find driver packages to process for '$Printer'." "ERROR!" }
                default { Write-Log "Unknown error ($($Result.ExitCode)) while deleting '$Printer'." "ERROR!" }}}
        else { Write-Log "Deleted printer: $Printer" "Delete" }}
    catch { Write-Log "Exception occurred while deleting printer '$Printer': $($_.Exception.Message)" "ERROR!" }}
#endregion

#region --={ Main Loop }=--
try {
    $PrinterList = FindNetworkPrinters $PrinterKeyLocation
    if ($PrinterList) {
        Write-Log "Found $($PrinterList.Count) printer connections. Removing..."
        foreach ($Printer in $PrinterList) { DeleteNetworkPrinter($Printer) }
        Write-Log "All detected network printers processed." }
    else { Write-Log "No network printer connections found." }}
catch { Write-Log "Critical error: $($_.ExceptionMessage)" "ERROR!"; return $false }
finally { Write-Log "--=( Finished Network Printer Removal Script )=--" "-END!-" }
return $true
#endregion