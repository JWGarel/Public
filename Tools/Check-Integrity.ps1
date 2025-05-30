#powershell
# Background integrity repair and cleanup
#Requires -RunAsAdministrator
#Requires -Version 3.0
<# 
.SYNOPSIS
    Background integrity repair and cleanup
.DESCRIPTION
    Based on the batch file of the same name, which only worked in Windows 10 and made ugly log files,
    This script performs a background integrity check and cleanup of the system.
    It uses DISM and SFC to check for corruption and attempts to repair the image.
    It also cleans up temporary files related to Windows Update.
    When it logs, it leaves out the progress percentage, which is not useful in a log file.
    This is designed to be deployed, run as a scheduled task, or run in person, so it does not require user interaction.
    Tested and works on Windows 10 and Windows 11.    
.NOTES
    Author:    Jason W. Garel
    Version:   2.0.2
    Created :  01-23-25
    Modified : 05-20-25
    Requires: Write-Log.psm1, AppHandling.psm1, Push-RegK.psm1
.OUTPUTS
    Logs are saved in $LogFile along with additional, more verbose logs in C:\Windows\Logs\DISM and C:\Windows\Logs\CBS
.FUNCTIONALITY
    This script is unattended; Designed to be deployed, run as a scheduled task or run from the command line.
#>
#region --=( Initialization )=--
Import-Module "..\Include\Write-Log.psm1"  # Allow logging via Write-Log function
Import-Module "..\Include\AppHandling.psm1" # Allow fancy app handling functions
Import-Module "..\Include\Push-RegK.psm1"  # Allow fancy registry and directory handling functions
$LogFile    = "C:\Temp\Logs\Check-Integrity.log"
$LASTEXITCODE = 0
Write-Log     "--=( Starting Integrity Check and Cleanup )=--" "Start!"
Write-Host    "The log file is located at $LogFile"
#endregion

#region --=( Main Loop )=--
#region --=( Integrity Check )=--
Write-Log "Part 1 of 4: DISM Online Cleanup-Image RestoreHealth..." "-DISM-"
try   { $Output = DISM /Online /Cleanup-Image /RestoreHealth }
catch { Write-Log "DISM RestoreHealth failed with error: $($_.Exception.Message)" "ERROR!" }
if ($LASTEXITCODE -ne 0) { Write-Log "DISM RestoreHealth failed with exit code $LASTEXITCODE" "ERROR!"; $LASTEXITCODE = 0 }
$Output | Where-Object { ($_.Trim() -ne '') -and ($_ -notlike "*%*") } | ForEach-Object { Write-Log $_ "-DISM-" } # Output to log and filter out progress percentage
Write-Log "More complete logs available at C:\Windows\Logs\DISM\dism.log" "-DISM-"

Write-Log "Part 2 of 4: SFC Repair" "SFC-Rp"
try   { $Output = SFC /ScanNow }
catch { Write-Log "SFC failed with error: $($_.Exception.Message)" "ERROR!" }
foreach ($Line in $Output) {
    if ($Line.Trim() -ne '' -and $Line -notlike "*%*") {
        $OutputString = ""
        for ($i = 1; $i -lt $Line.Length; $i += 2) { $OutputString += $Line[$i] } # Remove SFC's spaces between each character
        Write-Log "$OutputString" "SFC-SN" }}
if ($LASTEXITCODE -ne 0) { Write-Log "SFC failed with exit code $LASTEXITCODE" "SFC-Rp"; $LASTEXITCODE = 0 }
Write-Log "More complete logs available at C:\Windows\Logs\CBS\CBS.log" "SFC-Rp"

Write-Log "Part 3 of 4: DSIM Cleanup" "-DISM-"
try { $Output = DISM /Online /Cleanup-Image /StartComponentCleanup }
catch { Write-Log "DISM failed with error: $($_.Exception.Message)" "ERROR!" }
$Output | Where-Object { ($_.Trim() -ne '') -and ($_ -notlike "*%*") } | ForEach-Object { Write-Log $_ "-DISM-" } # Output to log and filter out progress percentage
if ($LASTEXITCODE -ne 0) { Write-Log "DISM Cleanup failed with exit code $LASTEXITCODE" "-DISM-"; $LASTEXITCODE = 0 }
Write-Log "More complete logs available at C:\Windows\Logs\DISM\dism.log" "-DISM-"
#endregion --=( Integrity Check )=--

#region --=( Cleanup )=--
Write-Log "Part 4 of 4: Clearing out Windows Update temp files" "Clean "

Write-Log "Stopping Windows Update services..." "Clean "
try {
    Stop-Service -Name wuauserv -Force
    Stop-Service -Name bits -Force
    Stop-Service -Name AppIDSvc -Force
    Stop-Service -Name CryptSvc -Force
    Write-Log "Windows Update services stopped. Starting Windows Update related temp file cleanup." "Clean " }
catch { Write-Log "Failed to stop Windows Update services: $($_.Exception.Message)" "ERROR!" }

$null = Remove-Path "C:\Windows\System32\catroot2"
$null = Remove-Path "C:\Windows\SoftwareDistribution\Temp"
$null = Remove-Path "C:\Windows\SoftwareDistribution\WuTemp"
Get-ChildItem -Path $WUDownloadCachePath -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

Write-Log "Cleanup complete, starting Windows Update services..." "Clean "
try { 
    Start-Service -Name CryptSvc
    Start-Service -Name AppIDSvc
    Start-Service -Name bits
    Start-Service -Name wuauserv
    Write-Log "Windows Update services started." "Start-" }
catch { Write-Log "Failed to start all Windows Update services: $($_.Exception.Message)" "ERROR!" }
#endregion --=( Cleanup )=--

Write-Log "--=( Integrity Check and Cleanup complete )=--" "End!"
EXIT 0
#endregion