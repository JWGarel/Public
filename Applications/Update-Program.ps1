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
    Change Log:
        05-20-25 - JWG - Changed final return 0 for EXIT 0 to prevent Altiris issues.
        05-13-25 - JWG - Created
    Dependencies: Write-Log.psm1 and AppHandling.psm1
.INPUTS
    Requires the $DisplayName and $ProgramName to be passed in as parameters.
    The $DisplayName should be the name of the program as it appears in the Add/Remove Programs list.
    The $ProgramName should be the name of the program as it appears in the winget list.
.EXAMPLE
    .\Install-Program.ps1 -DisplayName "Google Chrome" -ProgramName "Google.Chrome"
    This will install or update Google Chrome from the system.
.OUTPUTS
    0 returns if install/update was successful.
    1 returns if install/update failed.
    Logs are saved in $LogFile
.FUNCTIONALITY
    This script is unattended; Designed to be deployed, run as a scheduled task or run from the command line.
#>
param(
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$ProgramName,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$DisplayName)
    
Import-Module "..\Include\Write-Log.psm1"   # Allow logging via Write-Log function
Import-Module "..\Include\AppHandling.psm1" # Allow fancy app handling functions

$ExitCode = 0 # Altiris sees 0 as success
$LogFile = "C:\Temp\Logs\" + $ProgramName + "-InstallUpdate.log"
Write-Host "Log file: $LogFile" # This is to make PSSA stop complaining about the $LogFile not being set
Write-Log "--=( Starting $ProgramName Install/Update Script. )=--" "Start!"

$InstallResult = Update-Program $ProgramName $DisplayName
if (!$InstallResult) { Write-Log "Install or update of $ProgramName failed!" "Error"; $ExitCode = 1 }

Write-Log "--=( Completed $ProgramName Install/Update Script )=--" "-End!-"
EXIT $ExitCode