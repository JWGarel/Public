#powershell
# List all Per-Machine Named Network Printers
<#
.SYNOPSIS
    List all Per-Machine Named Network Printers

.DESCRIPTION
    This script only lists the printers in a log file, does not change anything.
    This only applies to network named printers, not IP or local.
    Logs are saved in $LogFile

.NOTES
    Author: Jason W. Garel
    Version: 1.0
    Creation Date: 2025-01-28
    Permissions : None
    Dependencies: Write-Log

.OUTPUT
    Returns 0 for lack of critical errors, 1 for failure.
#>

#region --={ Initialization }=--
Import-Module "..\Include\Write-Log.psm1"
$LogFile = "C:\Temp\Logs\Printers-NetworkListAll.log"
$PrinterKeyLocation = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print\Connections"

Write-Host "Log file: $LogFile" # This is to make PSSA stop complaining about the $LogFile not being set
Write-Log "--=( Starting Network Printer Listing Script )=--" "Start!"
#endregion

#region --={ Functions }=--
function FindNetworkPrinters {
    param([Parameter(Mandatory=$true)][string]$PrinterKey)
    try { return Get-ChildItem $PrinterKey -ErrorAction SilentlyContinue | ForEach-Object {
            try { (Get-ItemProperty -Path $_.PSPath -Name Printer -ErrorAction SilentlyContinue).Printer }
            catch { Write-Log "Error getting printer path for '$($_.PSPath)': $($_.Exception.Message)" "Error!"; continue }}}
    catch { Write-Log "Error loading Network pritners: $($_.Exception.Message)" "ERROR!" }}
#endregion

#region --={ Main Loop }=--
try {
    $PrinterList = FindNetworkPrinters $PrinterKeyLocation
    if ($PrinterList) {
        Write-Log "Found $($PrinterList.Count) printer connections. Listing..."
        foreach ($Printer in $PrinterList) { Write-Log "Found Printer: $Printer" }
        Write-Log "All detected network printers processed." }
    else { Write-Log "No per-machine shared network printer connections found." }
    return $true }
catch { Write-Log "Critical error: $($_.ExceptionMessage)" "ERROR!"; return $false }
finally { Write-Log "--=( Finished Network Printer Listing Script )=--" "-End!-" }
return $true
#endregion