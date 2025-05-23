#powershell
# Background Update of all programs
#Requires -RunAsAdministrator
#Requires -Version 3.0
<#
.SYNOPSIS
    Background Update of all programs
.DESCRIPTION
    Verifies version and function of WinGet and VC++
    Then calls Winget upgrade --all
.NOTES
    Author:    Jason W. Garel
    Version:   1.0.3
    Created :  05-06-25
    Modified : 05-22-25
    Change Log:
        05-22-25 - JWG - Changed log output to exclude the lines of garbage. Added more error checks
        05-20-25 - JWG - Changed final return 0 for EXIT 0.
        05-09-25 - JWG - Set up regions, added winget output to log.
    Dependencies: Write-Log and AppHandling
.OUTPUTS
    0 For lack of critical errors
    1 for critical failure
    -1 for reboot required first
    Logs saved to $Logfile
.FUNCTIONALITY
    This script is unattended; Designed to be deployed, run as a scheduled task or run from the command line.
.COMPONENT
    Applications
#>

#region --={ Initialization }=--
Import-Module "..\Include\Write-Log.psm1"        # Logging via Write-Log function
Import-Module "..\Include\AppHandling.psm1" # Fancy app handling functions
$LogFile = "C:\Temp\Logs\Update-All.log"                                # Logfile name
$CleanupShortcuts = @(                                             # List any undesired desktop shortcuts that get added after updates
    'Audacity',
    'IrfanView 64',
    'VLC media player')
#endregion

#region --={ Functions }=--
<# Cleans up those new desktop shortcuts that appear #>
function DeleteShortcut {
    param ([Parameter(Mandatory=$true)][string]$ShortcutName)
    try {
        $PublicDesktop = "C:\Users\Public\Desktop\"
        $ShortcutLinkName = $ShortcutName + ".lnk"
        $ShortcutPath = Join-Path $PublicDesktop $ShortcutLinkName
        Remove-Item $ShortcutPath -Force
        return 0 }
    catch { Write-Log "Error removing $ShortcutPath $($_.Exception.Message)" "Error!"; return 1 }}
#endregion

#region --={ Main Loop }=--
Write-Host "Log file: $LogFile" # This is to make PSSA stop complaining about the $LogFile not being used
Write-Log "--=( Starting Program Update Script. )=--" "Start!"

try { 
    $InitC = Initialize-VisualC
    if ($InitC -eq -1) { Write-Log "Reboot required after installing VC++, please restart and try again" "Error!"; Exit -1 }
    elseif ($InitC -ne 0) { Write-Log "Error initializing VC++, cannot continue."; EXIT 1 }
    $WingetPath = Initialize-Winget } 
catch { Write-Log "Error initializing update programs! $($_.Exception.Message)" "Error!"; EXIT 1 }
if (!$WingetPath) { Write-Log "Cant find WinGet path, cannot continue." "ERROR!"; EXIT 1 }

Write-Log "Starting Winget Upgrade All, this can take a few minutes..."
try { $WingetOutput = & "$WingetPath" upgrade --all --silent --force --accept-package-agreements --accept-source-agreements }
catch { Write-Log "Error installing updates! $($_.Exception.Message)" "Error!"; EXIT 1 }
if (!$WingetOutput) { Write-Log "Winget Output varible is empty, call likely failed, please reboot and try again" "ERROR!"; EXIT 1 }

Write-Log "Winget call complete. Results to follow:"
foreach ($line in $WingetOutput) {
    if ($line -notmatch '^\s*[-/|\\Γû]*\s*$') {
        Write-Log "Output: $line" "WINGET" }}

Write-Log "Starting clean up."
foreach ($line in $CleanupShortcuts) { DeleteShortcut $line | Out-Null }
Write-Log "Clean up complete."

Write-Log "--=( Completed Program Update Script )=--" "-End!-"
EXIT 0
#endregion