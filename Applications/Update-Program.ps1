#powershell
# Background install or update of any winget program
#Requires -RunAsAdministrator
#Requires -Version 3.0
<# 
.SYNOPSIS
    Background install or update of any winget supported program
.DESCRIPTION
    Installs or updates a specified program using winget in the background.
    Logs all actions and results, and is designed for unattended use in automation or deployment systems such as Altiris.
    Requires the program’s display name (as shown in Add/Remove Programs) and the winget package name as parameters.
    Uses custom logging and application handling modules for robust error handling and reporting.
.NOTES
    Author:    Jason W. Garel
    Version:   1.0
    Created :  05-13-25
    Modified : 05-20-25
    Dependencies: Write-Log.psm1 and AppHandling.psm1
.INPUTS
    Requires the $DisplayName and $ProgramName to be passed in as parameters.
    The $ProgramName should be the name of the program as it appears in the winget list.
    The $DisplayName should be the name of the program as it appears in the Add/Remove Programs list.
.EXAMPLE
    .\Install-Program.ps1 -DisplayName "Google Chrome" -ProgramName "Google.Chrome"
    This will install or update Google Chrome.
.OUTPUTS
    0 returns if install/update was successful.
    1 returns if install/update failed.
    Logs are saved in $LogFile
.FUNCTIONALITY
    This script is unattended; Designed to be deployed, run as a scheduled task or run from the command line.
#>
param(
    [Parameter(Mandatory=$true, HelpMessage = "Name of the program as it appears in the winget list.")][ValidateNotNullOrEmpty()][string]$ProgramName,
    [Parameter(Mandatory=$true, HelpMessage = "Name of the program as it appears in the Add/Remove Programs list.")][ValidateNotNullOrEmpty()][string]$DisplayName)
Import-Module "..\Include\Write-Log.psm1"   # Allow logging via Write-Log function
Import-Module "..\Include\AppHandling.psm1" # Allow fancy app handling functions

$LogFile  = "C:\Temp\Logs\" + $ProgramName + "-InstallUpdate.log"
$ExitCode = 0
Write-Host  "Your log file is located at $LogFile"
Write-Log   "--=( Starting $ProgramName Install/Update Script. )=--" "Start!"

$InstallResult = Update-Program $ProgramName $DisplayName
if (!$InstallResult) { Write-Log "Install or update of $ProgramName failed!" "Error"; $ExitCode = 1 }

Write-Log  "--=( Completed $ProgramName Install/Update Script )=--" "-End!-"
EXIT $ExitCode