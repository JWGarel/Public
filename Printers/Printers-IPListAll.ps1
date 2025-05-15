#powershell
# List all Per-Machine IP Printers
<#
.SYNOPSIS
    List all Per-Machine IP Printers

.DESCRIPTION
    First verifies the spooler is running, then retrieves a list of all per-machine IP printer connections.
    Records each one to a log file. Does not record any other kind of printer (such as per user or shared network printers)
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
$LogFile = "C:\Temp\Logs\Printers-IPListAll.log"
Import-Module "..\Include\Write-Log.psm1" # Allow logging via Write-Log

Write-Host "Log file: $LogFile" # This is to make PSSA stop complaining about the $LogFile not being set
Write-Log "--=( Starting IP Printer Listing Script )=--" "Start!"
#endregion

#region --={ Functions }=--
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

function ListIPPrinters {
    try {
        $IPPrinters = @()
        $Printers = Get-Printer -ErrorAction Stop
        foreach ($Printer in $Printers) {
            $PortName = $Printer.PortName
            if ($PortName -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$") {
                Write-Log "$($Printer.Name)" -Type "-NAME-"
                Write-Log "$PortName" -Type "--IP--"
                Write-Log "----------------------------" "------"
                $IPPrinters += $Printer }}}
    catch { Write-Log "Critical error: $($_.Exception.Message)" "ERROR!"; return $false }
    finally {
        if ($IPPrinters) { Write-Log "Found $($IPPrinters.Count) local IP printers." }
        else { Write-Log "Found no IP printers." }}}
#endregion

#region --={ Main Loop }=--
try {
    Initialize-Spooler
    Write-Log "----------------------------" "------"
    ListIPPrinters
    Write-Log "--=( Local IP Printer Listing Script Finished )=--" "-End!-" }
catch { Write-Log "Critical error: $($_.Exception.Message)" "ERROR!"; return $false }
return $true
#endregion