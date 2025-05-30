#powershell
# Restart, 5m delay w/ notice if users logged in.
#Requires -RunAsAdministrator
#Requires -Version 3.0
<#
.SYNOPSIS
    Check for logged in users and notify with 5 minute delay. Otherwise restart instantly
.DESCRIPTION
    Checks for any logged in users and warns them the computer is going to restart.
    After timer expires, logs them out and kills explorer, then restarts.
.NOTES
    Author:    Jason W. Garel
    Version:   1.0.5
    Created :  04-02-25
    Modified : 05-23-25
    Dependencies: AppHandling.psm1 for Restart-Polite function
.OUTPUTS
    Nothing, or 0. Write-Host is used in case of system transcript.
.FUNCTIONALITY
    This script is unattended; Designed to be deployed, run as a scheduled task or run from the command line.
#>

#region --=( Initialization )=--
Import-Module "..\Include\AppHandling.psm1" # Allow fancy app handling functions
$Time = 300   # Time until reboot in seconds
$Message = "Please save your work now, this computer has a scheduled restart at exactly" # Message to show your user
#endregion

#region --=( Main Loop )=--
$null = Restart-Polite -Time $Time -Message $Message
EXIT 0 # This will never be reached, but it feels wrong to leave it out...
#endregion