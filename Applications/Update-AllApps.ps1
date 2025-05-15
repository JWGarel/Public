#powershell
# Background Update of all programs
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Background Update of all programs

.DESCRIPTION
    Verifies version and function of WinGet and VC++
    Then calls Winget upgrade --all
    Logs saved to $Logfile

.NOTES
    Author: Jason W. Garel
    Version: 1.0
    Created: 05-06-25
    Permissions: Admin rights
    Dependencies: Write-Log.psm1 and AppHandling.psm1

.OUTPUT
    Returns 0 for lack of critical errors and 1 for critical failure.
#>

#region --={ Initialization }=--
$LogFile = "C:\Temp\Logs\Update-All.log"    # Logfile name
Import-Module "..\Include\Write-Log.psm1"   # Allow logging via Write-Log function
Import-Module "..\Include\AppHandling.psm1" # Allow fancy app handling functions

# List any shortcuts that get added after updates
$CleanupShortcuts = @(
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
        Remove-Item $ShortcutPath -Force -ErrorAction SilentlyContinue
        return 0 }
    catch { Write-Log "Error removing $ShortcutPath $($_.Exception.Message)" "Error!"; return 1 }}
#endregion

#region --={ Main Loop }=--
Write-Host "Log file: $LogFile" # This is to make PSSA stop complaining about the $LogFile not being set
Write-Log "--=( Starting Program Update Script. )=--" "Start!"

Initialize-VisualC # This is better done ahead of time because if it's needed, a reboot might be required (error 3010)
$WingetPath = Initialize-Winget

try { $WingetOutput = & "$WingetPath" upgrade --all --silent --force --accept-package-agreements --accept-source-agreements }
catch { Write-Log "Error installing updates! $($_.Exception.Message)" "Error!"; exit 1 }
foreach ($line in $WingetOutput) { Write-Log "Output: $line" "WINGET" }

Write-Log "Updates complete, cleaning up."
foreach ($line in $CleanupShortcuts) { DeleteShortcut $line }
Write-Log "Cleanup complete."

Write-Log "--=( Completed Program Update Script )=--" "-End!-"
return 0
#endregion