#powershell
# Background install or update of any winget program
#Requires -RunAsAdministrator
<# 
.SYNOPSIS
    Background install or update of any winget supported program

.DESCRIPTION
    Requires $DisplayName and $ProgramName to be set.
    $DisplayName is the name of the program as it appears in the Add/Remove Programs list.
    $ProgramName is the name of the program as it appears in the winget list.
 
.NOTES
    Author: Jason W. Garel
    Version: 1.0
    Creation Date: 05-13-25
    Dependencies: Write-Log.psm1 and AppHandling.psm1
    Permissions: Admin rights
#>

param(
    [Parameter(Mandatory=$true)][string]$ProgramName,
    [Parameter(Mandatory=$true)][string]$DisplayName)

Import-Module "..\Include\Write-Log.psm1"   # Allow logging via Write-Log function
Import-Module "..\Include\AppHandling.psm1" # Allow fancy app handling functions

$ExitCode = 0 # Altiris sees 0 as success
$LogFile = "C:\Temp\Logs\" + $ProgramName + "-InstallUpdate.log"
Write-Host "Log file: $LogFile" # This is to make PSSA stop complaining about the $LogFile not being set
Write-Log "--=( Starting $ProgramName Install/Update Script. )=--" "Start!"

$InstallResult = Update-Program $ProgramName $DisplayName
if (!$InstallResult) { Write-Log "Install or update of $ProgramName failed!" "Error"; $ExitCode = 1 }

Write-Log "--=( Completed $ProgramName Install/Update Script )=--" "-End!-"
return $ExitCode