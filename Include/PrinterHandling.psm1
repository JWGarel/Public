#powershell
<#
.SYNOPSIS
    Provides functions for handling printer operations, including managing the Print Spooler service, listing and removing IP printers, and managing network printers.
.DESCRIPTION
    This module includes functions to:
    - Initialize and ensure the Print Spooler service is running.
    - List all installed IP printers.
    - Remove specified IP printers.
    - Find network printers from the Windows registry.
    - Remove specified network printers.
.NOTES
    Author:    Jason W. Garel
    Version:   1.0
    Created :  05-19-25
    Modified : 05-19-25
    Change Log:
        05-19-25 - JWG - Created.
    Requires:
        - The functions that use Get-Printer need PowerShell 3.0 or later
        - Admin rights to manage printers and services
        - Write-Log module for logging messages and errors
.EXAMPLE
    Initialize-Spooler
        Ensures the Print Spooler service is running.

    Find-IPPrinterList
        Returns a list of all IP printers installed on the system.

    Find-NetworkPrinterList
        Returns named per-machine network printers from the specified registry key.

    Remove-NetworkPrinter -Printer "PrinterName"
        Deletes the specified network printer. Either a named printer or an IP address can be specified.
        The function uses the PrintUIEntry command to remove the printer.
#>
function Initialize-Spooler {
    # Check if the Print Spooler service is running
    try {
        $SpoolerStatus = $null # This will hold the spooler's service status
        Write-Log "Checking Print Spooler service status..." "Spool!"
        $SpoolerStatus = (Get-Service -Name Spooler -ErrorAction SilentlyContinue).Status }
    catch { Write-Log "Error getting Print Spooler service status: $($_.Exception.Message)" "ERROR!" }
    
    # If the Print Spooler service is not running, attempt to start it
    try {
        if ($SpoolerStatus -ne "Running") {
            Write-Log "Print Spooler service is not running. Attempting to start it..."
            Start-Service -Name Spooler -ErrorAction SilentlyContinue }
        else { Write-Log "Print spooler is running." "Spool!"; return $true }}
    catch { Write-Log "Error starting Print Spooler service: $($_.Exception.Message)" "ERROR!" }

    # If it was just started, check the Print Spooler service status again
    try {
        Write-Log "Checking Print Spooler service status again..."
        $SpoolerStatus = (Get-Service -Name Spooler -ErrorAction SilentlyContinue).Status 
        if ($SpoolerStatus -ne "Running") { Write-Log "Unable to start Print Spooler service. Exiting script." "ERROR!"; EXIT 1 }
        else { Write-Log "Print Spooler service started successfully." "Spool!"; return $true }}
    catch { Write-Log "Error getting Print Spooler service status after attempting to start it: $($_.Exception.Message)" "ERROR!"; EXIT 1 }}

function Find-IPPrinterList {
    try {
        $Printers = Get-Printer -ErrorAction Stop
        foreach ($Printer in $Printers) {
            $PortName = $Printer.PortName
            if ($PortName -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$") {
                Write-Log "$($Printer.Name)" -Type "-NAME-"
                Write-Log "$PortName" -Type "--IP--"
                Write-Log "----------------------------" "------"
                $IPPrinters += $Printer }}}
    catch { Write-Log "Critical error: $($_.Exception.Message)" "ERROR!"; return $null }
    if ($IPPrinters) { Write-Log "Found $($IPPrinters.Count) local IP printers." "IPList"; return $IPPrinters }
    else { Write-Log "No local IP printers found." "IPList"; return @() }}

function Find-NetworkPrinterList {
    $PrinterKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print\Connections"
    try {
        $Result = Get-ChildItem $PrinterKey -ErrorAction SilentlyContinue |
            ForEach-Object {
                try { (Get-ItemProperty -Path $_.PSPath -Name Printer -ErrorAction SilentlyContinue).Printer }
                catch { Write-Log "Error getting printer path for '$($_.PSPath)': $($_.Exception.Message)" "Error!" }}
        if ($Result) { return $Result } # Returns printer list
        else { return @() }} # No printers found
    catch { Write-Log "Error loading Network printers: $($_.Exception.Message)" "ERROR!" }}

function Remove-NetworkPrinter {
    param([Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$Printer)
    try {
        # Check if $Printer is an IP address
        if ($Printer -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$") { $Arguments = "/dl /n ""$Printer"" /q" } # Args for a local IP printer.
        else { $Arguments = "/gd /n ""$Printer"" /q" } # Args for a network printer.
        Write-Log "PrintUI Arguments: $Arguments" "Delete"

        $Rundll32Path = Join-Path $env:SystemRoot "System32\rundll32.exe" # Path to rundll32.exe
        $Result = Start-Process -FilePath $Rundll32Path -ArgumentList "printui.dll,PrintUIEntry $Arguments" -Wait -PassThru -ErrorAction SilentlyContinue
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

$FunctionsToExport = @(
    'Initialize-Spooler',      # Checks and starts the Print Spooler service if not running.
    'Find-IPPrinterList',      # Lists all IP printers installed on the system.
    'Find-NetworkPrinterList', # Finds network printers from the specified registry key.
    'Remove-NetworkPrinter'    # Deletes a specified network (named or IP) printer using the PrintUIEntry command.
)

Export-ModuleMember -Function $FunctionsToExport