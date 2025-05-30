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
    Version:   1.0.1
    Created :  05-20-25
    Modified : 05-29-25
    Dependencies: Write-Log.psm1
.OUTPUTS
    Returns 1 for critical errors, 0 for success
    Logs are saved in $LogFile
.FUNCTIONALITY
    This script is unattended; Designed to be deployed, run as a scheduled task or run from the command line.
#>

#region --={ Initialization }=--
Import-Module "..\Include\Write-Log.psm1" # Allow logging via Write-Log
Import-Module "..\Include\AppHandling.psm1" #Needed for Initialize-Service
$LogFile    = "C:\Temp\Logs\WiFi-Amnesia.log"
$ErrorLevel = 0
Write-Host    "The log file is located at $LogFile"
Write-Log     "--=( Starting WiFi Amnesia Script )=--" "Start!"
#endregion

#region --={ Main Loop }=--
Write-Log "Checking for required service, wlansvc." "-Serv-"
try   { $InitSvc = Initialize-Service wlansvc }
catch { Write-Log "Error with initializing service wlansvc $($_.Exception.Message)" "ERROR!"; EXIT 1 }
if    (!$InitSvc) { Write-Log "Unable to start required service, wlansvc. Exiting." "ERROR!"; EXIT 1 }

Write-Log "Service wlansvc is running, fetching WiFi profiles." "Net-SH"
try   { $Profiles = netsh wlan show profiles }
catch { Write-Log "Error calling netsh to show profiles: '$($_.Exception.Message)'" "ERROR!"; EXIT 1 }
if    (!$Profiles) { Write-Log "No WiFi networks found at all. Exiting script now." "ERROR!"; EXIT 1 }
if    ($LASTEXITCODE -ne 0) { Write-Log "NetSH Fail with exit code: $LASTEXITCODE." "ERROR!"; EXIT 1 }

Write-Log "Found $($Profiles.Count) WiFi profiles... " "-WiFi-"
foreach ($Profile in $Profiles) { Write-Log "$Profile" "-WiFi-"}

Write-Log "Deleting all WiFi profiles using netsh." "Net-SH"
try   { $Result = netsh wlan delete profile * }
catch { Write-Log "Failure, NetSh terminated with $($_.Exception.Message)" "ERROR!"; $ErrorLevel = 1 }
if    (!$Result) { Write-Log "Failure deleting profiles null var returned" "ERROR!"; $ErrorLevel = 1 }
if    ($LASTEXITCODE -ne 0) { Write-Log "NetSH cmd returned this exit code: $LASTEXITCODE." "-Note-" }

Write-Log "--=( Finished WiFi Amnesia Script )=--" "-End!-"
EXIT $ErrorLevel
#endregion