#powershell
# Fix Google Drive sync issues
#Requires -RunAsAdministrator
#Requires -Version 3.0
<#
.SYNOPSIS
    Fix Google Drive sync issues
.DESCRIPTION
    Clear out corrupt Google Drive files - Use this to fix sync issues, usually caused by files located in the user directory named lost_and_found
    Sync issues could also be corruption elsewhere in the user directory.
    This script backs up the lost_and_found directory into the user's Downloads\DriveBackup\ folder
    Warning: This script kills the DriveFS folder for EVERY user on a machine. Usually that will just cause a delay in first sync on login.
.NOTES
    Author:    Jason W. Garel
    Version:   1.0.3
    Created :  04-02-25
    Modified : 05-20-25
    Change Log:
        05-20-25 - JWG - Changed final return 0 for EXIT 0
        05-09-25 - JWG - Finished cleaning up formatting. Changed name of function to Move-GoogleDriveUser and configured as cmdlet.
        05-05-25 - JWG - Cleaned up formatting.
        04-29-25 - JWG - Switched from old Log-Message to new Write-Log script. Added more try/catch loops and errorlevel returns.
        04-22-25 - JWG - Added this improved comment block to better follow standard PowerShell commenting procedure.
        04-08-25 - JWG - Updated Write-Log to use \logs directory.
    External Dependencies: Write-Log.psm1 module
.FUNCTION Move-GoogleDriveUser
    Moves lost_and_found folder, then delete DriveFS folder for specific user
.FUNCTIONALITY
    This script is unattended; Designed to be deployed, run as a scheduled task or run from the command line.
.OUTPUTS
    Returns 0 for lack of critical errors, 1 for critical failure.
#>
#region --={ Initialization }=--
$LogFile = "C:\Temp\Logs\GoogleDrive-FixSync.log"                              # Where to save the log
$TimeoutSeconds = 90                                                           # How long to wait on Google Drive shutting down before calling off this party
Import-Module "..\Include\Write-Log.psm1"     # Allow logging via Write-Log function
Write-Host "Log file: $LogFile" # This is to make PSSA stop complaining about the $LogFile not being set
Write-Log "--=( Google Drive Local Data Delete Script Started )=--" "Start!"
#endregion

#region --={ Functions }=--
<#
.SYNOPSIS
    Backs up lost_and_found folder, then delete DriveFS folder for specific user
.DESCRIPTION
    Backs up the lost_and_found directory into the user's Downloads\DriveBackup\ folder
    Warning: This script kills the DriveFS folder for EVERY user on a machine. Usually that will just cause a delay in first sync on login.
#>
function Move-GoogleDriveUser {
    [CmdletBinding(SupportsShouldProcess)][OutputType([System.Boolean])]
    param ([Parameter(Mandatory=$true, HelpMessage="Username of the user to process")][ValidateNotNullOrEmpty()][String]$UserName)

    try {
# Define source and destination paths
        $DriveBackupFolder = "C:\Users\$UserName\Downloads\DriveBackup"
        $SourceLostAndFound = "C:\Users\$UserName\AppData\Local\Google\DriveFS\lost_and_found"
        $DestinationLostAndFound = "C:\Users\$UserName\Downloads\DriveBackup\lost_and_found"
        $DriveFSFolder = "C:\Users\$UserName\AppData\Local\Google\DriveFS"

# Create destination directory if it doesn't exist
        try { if (-not (Test-Path $DriveBackupFolder)) { New-Item -ItemType Directory -Path $DriveBackupFolder -Force -ErrorAction Stop | Out-Null }}
        catch { Write-Log "Error creating backup folder at $DriveBackupFolder - $($_.Exception.Message)" "ERROR!" }

# Move "lost_and_found" folder if it exists. Warning, could be huge.
        try {
            if (Test-Path $SourceLostAndFound) {
                Move-Item -Path $SourceLostAndFound -Destination $DestinationLostAndFound -Force -ErrorAction Stop |
                 Out-String |
                 ForEach-Object { Write-Log "Processing possible lost_and_found for $UserName $_" }
                Write-Log "Moved lost_and_found for $UserName" }
            else { Write-Log "lost_and_found not found for $UserName, continuing." }}
        catch { Write-Log "Error moving lost_and_found - $($_.Exception.Message)" "ERROR!"; return $false }

# Delete the user's DriveFS folder
        try {
            if (Test-Path $DriveFSFolder) {
                Remove-Item -Path $DriveFSFolder -Recurse -Force -ErrorAction Stop |
                 Out-String |
                 ForEach-Object { Write-Log "Processing possible DriveFS Folder for $UserName $_" }
                Write-Log "Deleted DriveFS folder for $UserName" }
            else { Write-Log "DriveFS folder not found for $UserName, continuing." }}
        catch { Write-Log "Error moving user's DriveFS folder - $($_.Exception.Message)" "ERROR!"; return $false }}
    catch { Write-Log "Directory may still exist: Unknown error in moving and deleting process for $UserName : $($_.Exception.Message)" -Type "ERROR!"; return $false }
    return $true }
#endregion

#region --={ Main Loop }=--
# Get list of user folders (excluding default and admin profiles)
try {
    $UserFolders = Get-ChildItem -Path "C:\Users" -Directory |
    Where-Object { $_.Name -notin "Public", "Default", "Default User", "All Users", "Administrator" }}
catch { Write-Log "Error loading user profiles: $($_.Exception.Message)" "ERROR!"; EXIT 1 }

# Check if GoogleDrive is running, if it is, kill it (we don't want the file removal failing due to them being in use)
try {
    if (Get-Process -Name "GoogleDriveFS" -ErrorAction SilentlyContinue) {
        taskkill /f /im "GoogleDriveFS.exe" | Out-String | ForEach-Object { Write-Log $_ "-DEBUG" } # This will throw "There is no running instance of the task" errors that can be ignored.
        $StartTime = Get-Date
        while (Get-Process -Name "GoogleDriveFS" -ErrorAction SilentlyContinue) { # Making this a while loop might not be the best way, as taskkill will likely kill them all in the first shot. Maybe the only downside to this is console errors.
            Start-Sleep -Seconds 1
            if (((Get-Date) - $StartTime).TotalSeconds -gt $TimeoutSeconds) { Write-Log "GoogleDriveFS.exe took too long to terminate. Aborting." -Type "ERROR!"; EXIT 1 }}
        Write-Log "Google Drive process killed." }
    else { Write-Log "GoogleDriveFS.exe not running. Continuing." }}
catch { Write-Log "Error killing GoogleDriveFS.exe: $($_.Exception.Message)" "ERROR!"; EXIT 1 }
# Process Google Drive for each user
finally {
    foreach ($UserFolder in $UserFolders) { Move-GoogleDriveUser $UserFolder.Name }
    Write-Log "--=( Google Drive Local Data Delete Script Complete )=--" "-End!-" }
#endregion
EXIT 0