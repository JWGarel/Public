#powershell
# Logs all WiFi Networks, then forgets them
#Requires -RunAsAdministrator
#Requires -Version 3.0
<#
.SYNOPSIS
    Logs all WiFi Networks, then forgets them
.DESCRIPTION
    Removes all remembered WiFi networks from the computer after logging their names.
    The script first ensures the WLAN AutoConfig service is running, retrieves and logs all saved WiFi profiles, then deletes them using netsh.
    Intended for unattended use in automation, deployment, or troubleshooting scenarios where clearing all saved wireless networks is required.
.NOTES
    Author:    Jason W. Garel
    Version:   1.0.0
    Created :  05-20-25
    Modified : 05-20-25
    Change Log:
        05-20-25 - JWG - Created
    Dependencies: Write-Log.psm1
.OUTPUTS
    Returns 1 for critical errors, 0 for success
    Logs are saved in $LogFile
.FUNCTIONALITY
    This script is unattended; Designed to be deployed, run as a scheduled task or run from the command line.
#>

#region --={ Initialization }=--
$LogFile = "C:\Temp\Logs\WiFi-Amnesia.log"
Import-Module "..\Include\Write-Log.psm1" # Allow logging via Write-Log
Import-Module "..\Include\AppHandling.psm1" #Needed for Initialize-Service
$ErrorLevel = 0
Write-Host "Log file: $LogFile" # This is to make PSSA stop complaining about the $LogFile not being set
Write-Log "--=( Starting WiFi Amnesia Script )=--" "Start!"
#endregion

#region --={ Main Loop }=--
try {
    $InitSvc = Initialize-Service wlansvc
    if ($InitSvc) {
        try { $Profiles = netsh wlan show profiles }
        catch { Write-Log "Error calling netsh to show profiles '$($_.Exception.Message)'"}}
    else { Write-Log "Unable to start required service, wlansvc. Exiting." "ERROR!"; $ErrorLevel = 1 }}
catch { Write-Log "Error at start of main loop: $($_.Exception.Message)" "Error!" }

# Log all known networks
if ($Profiles) { 
    Write-Log "Found $($Profiles.Count) WiFi Profiles"
    foreach ($Profile in $Profiles) { Write-Log "$Profile" "-NETSH-"}}
else { Write-Log "No networks found at all. Sus."; $ErrorLevel = 1 }

# Delete all known networks (Except main, which does not allow you to delete it this way)
try { $Result = netsh wlan delete profile * }
catch { Write-Log "Error deleting profiles: $($_.Exception.Message)" "ERROR!"; $ErrorLevel = 1 }
if (!$Result) { Write-Log "Error deleting profiles, netsh returned null." "ERROR"; $ErrorLevel = 1 }
Write-Log "--=( Finished WiFi Amnesia Script )=--" "-END!"
EXIT $ErrorLevel
#endregion