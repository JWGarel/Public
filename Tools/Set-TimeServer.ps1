#powershell
# Resync NTS Time Server
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Resync NTS Time Server locally (instead of with domain server, might be temporary due to GPO)

.DESCRIPTION
    This script will change the time server from the domain server to a specified time server. It will also restart the W32Time service and resync the time immediately.
    The keys that are being changed are mostly located in HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters
    Logs are saved in $LogFile

.NOTES
    Author: Jason W. Garel
    Version: 1.0
    Creation Date: 05-08-25
    Permissions: Administrator privileges
    Dependencies: Write-Log.psm1

.OUTPUT
    Returns 0 for lack of critical errors and 1 for critical failure. #>

#region --={ Config Area }=-------------------=-=#
Import-Module "..\Include\Write-Log.psm1"
$LogFile  = "C:\Temp\Logs\NTS-TimeSync.log"  # Log file location
$TimeServer = "time.google.com"            # Set to your time server
$AlsSwitches = @(                        # 
    "/configure",                      #
    "/update",                       #
    "/manualpeerlist:$TimeServer", #
    "/syncfromflags:manual")     #
#endregion                     #
#region --={ Functions }=---=#
function Initialize-Service {
    param ([Parameter(Mandatory=$true)][string]$ServiceName)
    $ServiceStatus = $null
    $ServiceStatus = (Get-Service $ServiceName -ErrorAction Stop).Status
    if ($ServiceStatus -ne "Running") {
        Write-Log "$ServiceName service is not running. Attempting start..."
        try {
            Start-Service -Name $ServiceName -ErrorAction Stop
            $ServiceStatus = (Get-Service $ServiceName -ErrorAction Stop).Status }
        catch { Write-Log "Failed to start #ServiceName service: $($_.Exception.Message)" "Error!"; return 1 }}
    else { Write-Log "$ServiceName is $ServiceStatus" }}

function Set-W32Time {
    param ([Parameter(Mandatory=$true)][string[]]$Switches)
    try {
        $ConfigureOutput=$null;$ConfigureOutput2=$null;$RestartOutput=$null
        $ConfigureOutput = W32tm @($Switches)
        Write-Log "W32Time $Switches result: $ConfigureOutput" }
    catch {
        Write-Log "Failed to $switches W32Time service with error $ConfigureOutput - Exception: $($_.Exception.Message)" "Error!"
        $RestartOutput = Restart-Service w32time -ErrorAction Stop  # Restart service and try again
        Write-Log "Restart service result: $RestartOutput"
        $ConfigureOutput2 = W32tm @($Switches)
        Write-Log "Second $Switches attempt result: $ConfigureOutput2" }}

function Restart-W32Time {
    try {
        $RestartOutput2=$null;$ResyncOutput=$null
        Write-Log "Restarting W32Time service..."
        $RestartOutput2 = Restart-Service w32time -ErrorAction Stop # Restart the service to apply changes
        Write-Log "Restart complete, resyncing now. Restart result: $RestartOutput2"
        $ResyncOutput = W32tm /resync /nowait     # This will force an immediate time resync
        Write-Log "Resync complete, result: $ResyncOutput"
        return 0 }
    catch { Write-Log "Error restarting time service! $($_.Exception.Message)" "ERROR!"; return 1 }}
#endregion

#region --={ Main Loop }=--
Write-Host "Log file: $LogFile" # This is to make PSSA stop complaining about the $LogFile not being set
Write-Log  "--=( Starting NTS Time Sync Switch Script. )=--" "Start!"

Initialize-Service W32Time                   # Start service if it's not running
$TimeSrc = w32tm /query /source           # Query current time source
Write-Log "Current source is $TimeSrc" # Log current time source
Set-W32Time "/register"             # Unregisters then reregisters time service keys and service
Set-W32Time $AlsSwitches       # Change NTS from domain server to our internal one
$ErrorLevel = Restart-W32Time       # Apply all changes and resync time instantly
Initialize-Service W32Time             # Start service if it's not running
Start-Sleep 30                            # Wait 30 seconds (or it will just say CMOS Clock when queried)
$TimeSrc2 = w32tm /query /source             # Query current time source again
Write-Log "Current time source is $TimeSrc2"   # Log newest time source

Write-Log  "--=( Completed NTS Time Sync Switch Script )=--" "-End!-"
return $ErrorLevel
#endregion