﻿#powershell
# Google Drive - Start on Login
#requires -RunAsAdministrator
#requires -Version 3.0
<#
.SYNOPSIS
    Google Drive - Start on Login
.DESCRIPTION
    Sets a single key for the entire machine to set Google Drive to start on login.
    Logs are saved in $LogFile
    If this key doesn't work, the override location is HKEY_LOCAL_MACHINE\Software\Policies\Google\DriveFS.
    The downside to that approach is that the individual user won't be able to turn it back off.
.NOTES
    Author:    Jason W. Garel
    Version:   1.0.3
    Created :  04-07-25
    Modified : 05-09-25
    Change Log:
        05-20-25 - JWG - Changed final return 0 for EXIT 0
        05-09-25 - JWG - Changed to per-machine vs per-user.
                         Changed script to use Push-RegK module and upgraded functions there. Added regions
    Requires: PowerShell v3.0 or later
    Permissions: Administrator privileges
    External Dependencies: Write-Log module and Push-RegK module
.OUTPUTS
    Returns 0 for lack of critical errors, 1 for failure.
.FUNCTIONALITY
    This script is unattended; Designed to be deployed, run as a scheduled task or run from the command line.
#>

#region --={ Initialization }=--
Import-Module "..\Include\Write-Log.psm1" # Allow logging via Write-Log
Import-Module "..\Include\Push-RegK.psm1" # Allow registry modification
#endregion

#region --={ Configuration }=--
$LogFile  = "C:\Temp\Logs\GoogleDrive-StartonLogin.log"  # This is where the log is recorded
$KeyPath  = "HKLM:\Software\Google\DriveFS"             # Set this to the key you want to change
$KeyName  = "AutoStartOnLogin"                         # AutoStartOnLogin is the current key as of 4/7/25
$KeyValue = 1                                         # 1 means start on login, 0 means don't
#endregion

#region --={ Main Loop }=--
Write-Host "Log file: $LogFile" # This is to make PSSA stop complaining about the $LogFile not being set
Write-Log "--=( Google Drive Start on Login script Started. )=--" "Start!"

Write-Log "Calling Push-RKey with '$KeyPath' '$KeyName' '$KeyValue'"
Push-RKey $KeyPath $KeyName $KeyValue

Write-Log "Completed setting and verifying key, calling Push-RKey again to verify AGAIN."
Write-Log "This has never been needed but it doesn't hurt anything."
Push-RKey $KeyPath $KeyName $KeyValue

write-Log "--=( Google Drive Start on Login script Complete )=--" "-End!-"
EXIT $true
#endregion