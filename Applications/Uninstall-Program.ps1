#powershell
# Background uninstall of any winget program
#Requires -RunAsAdministrator
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
    Author: Jason W. Garel
    Version: 1.0
    Creation Date: 05-13-25
    Permissions: Admin rights
    Dependencies: Write-Log.psm1 and AppHandling.psm1

#>

param(
    [Parameter(Mandatory=$true)][string]$ProgramName,
    [Parameter(Mandatory=$true)][string]$DisplayName)

Import-Module "..\Include\Write-Log.psm1"   # Allow logging via Write-Log function
Import-Module "..\Include\AppHandling.psm1" # Allow fancy app handling functions

$ExitCode = 0 # Altiris sees 0 as success
$LogFile = "C:\Temp\Logs\" + $ProgramName + "-Uninstall.log"
Write-Host "Log file: $LogFile" # This is to make PSSA stop complaining about the $LogFile not being set
Write-Log "--=( Starting $ProgramName Uninstall Script. )=--" "Start!"

$UninstallResult = Remove-Program $ProgramName $DisplayName
if (!$UninstallResult) { Write-Log "Uninstall of $ProgramName failed!" "Error"; $ExitCode = 1 }

Write-Log "--=( Completed $ProgramName Uninstall Script )=--" "-End!-"
return $ExitCode