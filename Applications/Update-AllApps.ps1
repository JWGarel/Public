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
    Version:   1.1.0
    Created :  05-06-25
    Modified : 05-29-25
    Dependencies: Write-Log and AppHandling
.OUTPUTS
    +0 Lack of critical errors
    +1 Critical failure
    -1 Reboot required first
    Logs saved to $Logfile
.FUNCTIONALITY
    This script is unattended; Designed to be deployed, run as a scheduled task or run from the command line.
.COMPONENT
    Applications
#>

#region --=( Initialization )=--
Import-Module "..\Include\Write-Log.psm1"   # Logging via Write-Log function
Import-Module "..\Include\AppHandling.psm1" # Fancy app handling functions
$LogFile    = "C:\Temp\Logs\Update-All.log"
Write-Host    "The log file is located at $LogFile"

# List any undesired desktop shortcuts that get added after updates
$CleanupLnk = @(
    'Audacity',
    'IrfanView 64',
    'VLC media player')
#endregion

#region --=( Main Loop )=--
Write-Log  "--=( Starting Program Update Script. )=--" "Start!"

try   { $InitC = Initialize-VisualC } # Initialize Visual C++ Redistributables
catch { Write-Log "Error initializing Visual C++ App! $($_.Exception.Message)" "Error!"; EXIT +1 }
if ($InitC -eq -1) { Write-Log "Reboot required for VC++ before continuing..." "REBOOT"; EXIT -1 }
elseif ($InitC -ne  0) { Write-Log "Initializing VC++ failed, cannot continue" "ERROR!"; EXIT +1 }

try   { $WingetPath = Initialize-Winget } # Initialize Winget itself to run as SYSTEM
catch { Write-Log "Error initializing the Winget app! $($_.Exception.Message)" "Error!"; EXIT +1 }
if (!$WingetPath) { Write-Log "Can not find WinGet path! Unable to continue!!" "ERROR!"; EXIT +1 }

Write-Log "Starting Winget Upgrade All, this can take a few minutes..." "Winget"
$LASTEXITCODE = 0; $WingetOutput = @()
$WingetArgs = "upgrade", "--all", "--silent", "--force", "--accept-package-agreements", "--accept-source-agreements"
try   { $WingetOutput = @(& $WingetPath @WingetArgs 2>&1) }
catch { Write-Log "Error or termination from Winget : $($_.Exception.Message)" "Error!"; EXIT +1 }
if ($LASTEXITCODE -ne 0) { Write-Log "For reference the last exit code: $LASTEXITCODE." "Winget" }

Write-Log "Winget upgrade complete, processing output." "Winget"
if ($WingetOutput) {
    $ProgPattern = '\s*\d+\.\d+\s*(?:KB|MB|GB)\s*/\s*\d+\.\d+\s*(?:KB|MB|GB)\s*$' # This can miss some, like the first line, which often starts at 0 B
    $LoadPattern = '^\s*[-/|\\]*\s*$' # This matches the loading bar lines, which are often a bunch of dashes, slashes, pipes or backslashes
    $CombPattern = "$ProgPattern|$LoadPattern"
    $WarningLine = @(
        "This application is licensed to you by its owner.",
        "Microsoft is not responsible for, nor does it grant any licenses to, third-party packages." )
    $FilteredLine = 0
    foreach ($Line in $WingetOutput) {
        if  ($Line -notmatch $CombPattern -and $Line -notin $WarningLine) { Write-Log "Output: $line" "WINGET" }
        else { $FilteredLine++ }}
    Write-Log "Winget output processing complete, filtered $FilteredLine lines of $($WingetOutput.Count) lines of output." "Winget" }
else { Write-Log "WingetOutput varible is empty" "ERROR!" }

Write-Log "Starting shortcut clean up." "Clean "
foreach ($Shortcut in $CleanupLnk) {
    try   { Remove-Item "C:\Users\Public\Desktop\$Shortcut.lnk" -Force -ErrorAction SilentlyContinue }
    catch { Write-Log "Removing the shortcut $ShortCut.lnk failed! $($_.Exception.Message)" "Error!" }}
Write-Log "Shortcut clean up complete." "Clean "

Write-Log "--=( Completed Program Update Script )=--" "-End!-"
EXIT 0
#endregion