#powershell
# Uninstall Google Drive
#Requires -RunAsAdministrator
<# 
.SYNOPSIS
    Generic script to Uninstall a Windows Application - this one uninstalls Google Drive

.DESCRIPTION
    This script finds and attempts to uninstall an application based on its display name in the registry.
    It includes retry logic for uninstall failures.
    It doesn't use Uninstall-Package for ease of passing switches for this specific use case, but theoretically it could if you wanted.
    Google Drive's uninstaller is in a different directory for each different version.
    I made this script generic so you could use it to uninstall anything with an entry that would show up in $UninstallString by modifying the "EDIT THIS" box below.
    It searches the key HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\
    Theoretically you could have it handle params instead.

.NOTES
    Author: Jason W. Garel
    Version: 1.0
    Creation Date: 04-04-25
    Permissions: Admin rights
    Dependencies: Write-Log.psm1

.OUTPUT
    Returns 0 for lack of critical errors, 1 for critical failure.
#>

# ----------EDIT THIS FOR EACH APP----------------- #-
$ApplicationName = "Google Drive"                   #- Name of whatever you want to uninstall, it will have an asterisk added to the end (e.g., "Microsoft Office*", "Adobe Reader*")
$ApplicationSilentSwitch = "--silent --force_stop"  #- Silent switches recognized by the uninstaller (e.g., "/S" "/VerySilent")
# ------------------------------------------------- #- You can likely leave everything below this line alone, or set assuming the slowest computer this job will run on, or a little slower than the fastest computer and add more retries to compensate.
$RetryDelaySeconds = 160                            #- How long in seconds to wait on uninstaller before considering it failed and trying again. 
$MaxRetries = 3                                     #- How many times to check on the uninstaller result before considering it failed and trying again. 
# ------------------------------------------------- #-

$ApplicationDisplayName = $ApplicationName + "*"                               # Add an asterisk to find all versions (comment out this line if needed)
$LogFileName = $ApplicationName.Replace(" ", "") + "-Uninstall.log"            # Remove spaces for log file name 
$LogPath = "C:\Temp\Logs\"                                                     # Change this to the directory where you want your log files
$LogFile = Join-Path $LogPath $LogFileName                                     #
Write-Host "Log file: $LogFile"                                                # This is to make PSSA stop complaining about the $LogFile not being set
$SoftwareStore = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" # Show me where the uninstall strings are kept
Import-Module "..\Include\Write-Log.psm1"                                      # Allow logging via Write-Log function

# MAIN { ------------------------------------------
try { # Aquire Uninstall string
    Write-Log "--=( $ApplicationName Uninstall Script Started )=--" "Start!"
    Write-Log "Searching for uninstall string for application with display name: '$ApplicationDisplayName'"
    $UninstallString = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
    Where-Object {$_.DisplayName -like $ApplicationDisplayName}).UninstallString }
catch { Write-Log "Critical error aquiring UninstallString: $($_.Exception.Message)" "ERROR!"; return 1 }

if ($UninstallString) {
    Write-Log "Found uninstall string: '$UninstallString'"
    for ($Retry = 1; $Retry -le $MaxRetries; $Retry++) {
        try {
            Write-Log "Attempting to uninstall (Attempt $Retry of $MaxRetries)."
            Start-Process -FilePath $UninstallString -ArgumentList "$ApplicationSilentSwitch" -Wait -PassThru | Out-Null
            Write-Log "Uninstall process started, waiting $RetryDelaySeconds for uninstall to complete"
            Start-Sleep -Seconds $RetryDelaySeconds
            if (-not (Get-ItemProperty $SoftwareStore | Where-Object {$_.DisplayName -like $ApplicationDisplayName})) {
                Write-Log "Application uninstalled successfully."; return 0 }
            else {
                Write-Log "Uninstall may not have completed successfully (uninstall string still found)." "-Warn-"
                if ($Retry -lt $MaxRetries) {
                    Write-Log "Waiting $RetryDelaySeconds seconds before retrying..."
                    Start-Sleep -Seconds $RetryDelaySeconds }
                else { Write-Log "Maximum uninstall retries reached. Application may still be installed." "ERROR!"; return 1 }}}
        catch { Write-Log  "Error occurred during uninstallation ( Attempt: $Retry ): $($_.Exception.Message)""ERROR!"
            if ($Retry -lt $MaxRetries) {
                Write-Log "Waiting $RetryDelaySeconds seconds before retrying after error..." "-Warn-"
                Start-Sleep -Seconds $RetryDelaySeconds }
            else { Write-Log "Maximum uninstall retries reached after errors. Application may still be installed." "ERROR!"; return 1 }}}}
else { Write-Log "No uninstall string found in registry for application with display name: '$ApplicationDisplayName'." "-Warn-" }

Write-Log "--=( $ApplicationName Uninstall Script Finished )=--"
return 0