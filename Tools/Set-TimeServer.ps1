#powershell
# Resync NTS Time Server
#Requires -RunAsAdministrator
#Requires -Version 3.0
<#
.SYNOPSIS
    Resync NTS Time Server locally (instead of with domain server, might be temporary due to GPO)
.DESCRIPTION
    This is based on Al's NTS script from his Bad Ideas folder.
    The keys that are being changed are mostly located in HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters
.NOTES
    Author:    Jason W. Garel
    Version:   1.0.2
    Created :  05-08-25
    Modified : 05-20-25
    Change Log:
        05-20-25 - JWG - Minor bugfixes (logging arrays), cleanup, and moved Initialize-Service to AppHandling.psm1
        05-09-25 - JWG - Cleaned up formatting, added -ErrorAction and regions, changed function verbs.
    Dependencies: Write-Log.psm1 (for logging) and AppHandling.psm1 (for Initialize-Service)
.OUTPUTS
    Returns 0 for lack of critical errors and 1 for critical failure.
    Logs are saved in $LogFile
.FUNCTIONALITY
    This script is unattended; Designed to be deployed, run as a scheduled task or run from the command line.
.COMPONENT
    Time
#>
Import-Module "..\Include\Write-Log.psm1"
Import-Module "..\Include\AppHandling.psm1"
#region --={ Config Area }=---------------=-=#
$LogFile = "C:\Temp\Logs\NTS-TimeSync.log" # Log file location
$TimeServer = "8.8.8.8"                  # Pick a time server
$AlsSwitches   = @(                    # Command from Al's script to change NTS from domain server to our internal one
    "/configure", "/update",         #
    "/manualpeerlist:$TimeServer", #
    "/syncfromflags:manual")     #
#endregion                     #
#region --={ Functions }=---=#
function Set-W32Time {
    param ([Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string[]]$Switches)
    try {
        $ConfigureOutput=$null;$ConfigureOutput2=$null;$RestartOutput=$null
        $ConfigureOutput = W32tm @($Switches)
        Write-Log "W32Time result: $ConfigureOutput" }
    catch {
        Write-Log "Failed to W32Time service with error '$ConfigureOutput' - Exception: $($_.Exception.Message)" "Error!"
        Write-Log "Attempting to restart W32Time service again..."
        $RestartOutput = Restart-Service w32time -ErrorAction Stop
        Write-Log "Restart service result: $RestartOutput"
        $ConfigureOutput2 = W32tm @($Switches)
        Write-Log "Second configure attempt result: $ConfigureOutput2" }}

function Restart-W32Time {
    try {
        $RestartOutput2=$null;$ResyncOutput=$null
        Write-Log "Restarting W32Time service to apply changes..."
        $RestartOutput2 = Restart-Service w32time -ErrorAction Stop
        Write-Log "Restart complete, forcing an immediate resyncing now. Restart result: $RestartOutput2"
        $ResyncOutput = W32tm /resync /nowait
        Write-Log "Resync complete, result: $ResyncOutput"
        return 0 }
    catch { Write-Log "Error restarting time service! $($_.Exception.Message)" "ERROR!"; return 1 }}
#endregion

#region --={ Main Loop }=--
Write-Log  "--=( Starting NTS Time Sync Switch Script. )=--" "Start!"
Write-Host "Log file: $LogFile"                 # This is to make PSSA stop complaining about the $LogFile not being set
Initialize-Service W32Time                   # Start service if it's not running
$TimeSrc = W32tm /query /source           # Query current time source
Write-Log "Current source is $TimeSrc" # Log current time source
Set-W32Time @("/register")          # Unregisters then reregisters time service keys and service
Set-W32Time $AlsSwitches       # Change NTS from domain server to our internal one
$ErrorLevel = Restart-W32Time       # Apply all changes and resync time instantly
Initialize-Service W32Time             # Start service if it's not running
Start-Sleep 30                            # Wait 30 seconds (less and it will just say "CMOS Clock" when queried)
$TimeSrc2 = W32tm /query /source             # Query current time source again
Write-Log "Current time source is $TimeSrc2"    # Log newest time source
Write-Log  "--=( Completed NTS Time Sync Switch Script )=--" "-End!-"
EXIT $ErrorLevel
#endregion