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
    Version:   2.0.1
    Created :  01-23-25
    Modified : 05-20-25
    Change Log:
        05-20-25 - JWG - Changed out final return 0 for EXIT 0 to prevent Altiris issues.
        05-15-25 - JWG - Changed from batch file to PowerShell script. Added logging and error handling.
                           Now compatible with Windows 11 as well as 10.
    Requires: Write-Log.psm1, AppHandling.psm1, Push-RegK.psm1
.OUTPUTS
    Logs are saved in $LogFile along with additional, more verbose logs in C:\Windows\Logs\DISM and C:\Windows\Logs\CBS
.FUNCTIONALITY
    This script is unattended; Designed to be deployed, run as a scheduled task or run from the command line.
#>
Import-Module "..\Include\Write-Log.psm1"  # Allow logging via Write-Log function
Import-Module "..\Include\AppHandling.psm1" # Allow fancy app handling functions
Import-Module "..\Include\Push-RegK.psm1"  # Allow fancy registry and directory handling functions

$LogFile = "C:\Temp\Logs\Check-Integrity.log"

Write-Log "--=( Starting Integrity Check and Cleanup )=--" "Start!"
Write-Host "Log file: $LogFile" # This is to make VBSC stop complaining about the $LogFile not being set

#region --=( Integrity Check )=--
try {
    Write-Log "Part 1 of 3: DISM Online Cleanup-Image RestoreHealth..." "-DISM-"
    $Output = DISM /Online /Cleanup-Image /RestoreHealth # Scan for corruption and attempt repair of image
    $Output | Where-Object { ($_.Trim() -ne '') -and ($_ -notlike "*%*") } |
     ForEach-Object { Write-Log $_ "-DISM-" } # Output to log and filter out progress percentage
    if ($LASTEXITCODE -ne 0) { Write-Log "DISM RestoreHealth failed with exit code $LASTEXITCODE" "ERROR!"; $LASTEXITCODE = 0 }}
catch { Write-Log "DISM RestoreHealth failed with error: $($_.Exception.Message)" "ERROR!" }
finally { Write-Log "More complete logs available at C:\Windows\Logs\DISM\dism.log" "-DISM-"}

try {
    Write-Log "Starting SFC Repair" "SFC-Rp"
    $Output = SFC /ScanNow
    foreach ($Line in $Output) {
        if ($Line.Trim() -ne '' -and $Line -notlike "*%*") {
            $OutputString = ""
            for ($i = 1; $i -lt $Line.Length; $i += 2) { $OutputString += $Line[$i] } # Remove SFC's spaces between each character
            Write-Log "$OutputString" "SFC-SN" }}
    if ($LASTEXITCODE -ne 0) { Write-Log "SFC failed with exit code $LASTEXITCODE" "SFC-Rp"; $LASTEXITCODE = 0 }}
catch { Write-Log "SFC failed with error: $($_.Exception.Message)" "ERROR!" }
finally { Write-Log "More complete logs available at C:\Windows\Logs\CBS\CBS.log" "SFC-Rp" }

try {
    Write-Log "Starting DSIM Cleanup" "-DISM-"
    $Output = DISM /Online /Cleanup-Image /StartComponentCleanup
    $Output | Where-Object { ($_.Trim() -ne '') -and ($_ -notlike "*%*") } |
     ForEach-Object { Write-Log $_ "-DISM-" } # Output to log and filter out progress percentage
    if ($LASTEXITCODE -ne 0) { Write-Log "DISM Cleanup failed with exit code $LASTEXITCODE" "-DISM-"; $LASTEXITCODE = 0 }}
catch { Write-Log "DISM failed with error: $($_.Exception.Message)" "ERROR!" }
finally { Write-Log "More complete logs available at C:\Windows\Logs\DISM\dism.log" "-DISM-" }
#endregion --=( Integrity Check )=--

#region --=( Cleanup )=--
Write-Log "Stopping Windows Update services..." "Clean "
try {
    Stop-Service -Name wuauserv -Force
    Stop-Service -Name bits -Force
    Stop-Service -Name AppIDSvc -Force
    Stop-Service -Name CryptSvc -Force
    Write-Log "Windows Update services stopped. Starting Windows Update related temp file cleanup." "Clean " }
catch { Write-Log "Failed to stop Windows Update services: $($_.Exception.Message)" "ERROR!" }

Remove-Path "C:\Windows\System32\catroot2"           | Out-Null
Remove-Path "C:\Windows\SoftwareDistribution\Temp"   | Out-Null
Remove-Path "C:\Windows\SoftwareDistribution\WuTemp" | Out-Null
Get-ChildItem -Path $WUDownloadCachePath -Force      | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

Write-Log "Cleanup complete, starting Windows Update services..." "Start-"
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