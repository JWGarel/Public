#powershell
# Background uninstall of any winget program
#Requires -RunAsAdministrator
#Requires -Version 3.0
<# 
.SYNOPSIS
    Background uninstall of any winget supported program
.DESCRIPTION
    Requires $DisplayName and $ProgramName to be set.
    $DisplayName is the name of the program as it appears in the Add/Remove Programs list.
    $ProgramName is the name of the program as it appears in the winget list.
    The script will check for the program in the list of installed programs and uninstall it if found.
    The script will also check for any running processes associated with the program and terminate them before uninstalling.
.NOTES
    Author:    Jason W. Garel
    Version:   1.0.1
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
    .\Uninstall-Program.ps1 -DisplayName "Google Chrome" -ProgramName "Google.Chrome"
    This will uninstall Google Chrome from the system.
.OUTPUTS
    0 returns if uninstall was successful.
    1 returns if uninstall failed.
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
$LogFile = "C:\Temp\Logs\" + $ProgramName + "-Uninstall.log"
Write-Host "Log file: $LogFile" # This is to make PSSA stop complaining about the $LogFile not being set
Write-Log "--=( Starting $ProgramName Uninstall Script. )=--" "Start!"

$UninstallResult = Remove-Program $ProgramName $DisplayName
if (!$UninstallResult) { Write-Log "Uninstall of $ProgramName failed!" "Error"; $ExitCode = 1 }

Write-Log "--=( Completed $ProgramName Uninstall Script )=--" "-End!-"
EXIT $ExitCode