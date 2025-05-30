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
    Version:   1.1.0
    Created :  04-02-25
    Modified : 05-29-25
    Dependencies: Write-Log.psm1 (for Write-Log) and AppHandling.psm1 (For Stop-Processess)
.FUNCTIONALITY
    This script is unattended; Designed to be deployed, run as a scheduled task or run from the command line.
.OUTPUTS
    Returns 0 for lack of critical errors, 1 for critical failure.
#>
#region --={ Initialization }=--
Import-Module "..\Include\Write-Log.psm1"   # Allow logging via Write-Log function
Import-Module "..\Include\AppHandling.psm1" # Fancy app handling functions
$LogFile    = "C:\Temp\Logs\GoogleDrive-FixSync.log"                         # Where to save the log
Write-Host    "Your log file is located at $LogFile"
Write-Log     "--=( Google Drive Local Data Delete Script Started )=--" "Start!"
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

    # Define source and destination paths
    $UserHome = Join-Path "C:\Users" $UserName                     # User's home directory
    $BakFoldr = Join-Path $UserHome "Downloads\DriveBackup"        # Buckup folder location
    $FSFolder = Join-Path $UserHome "AppData\Local\Google\DriveFS" # DriveFS folder location
    $LandFBak = Join-Path $BakFoldr "lost_and_found"               # Location to back up lost_and_found to
    $LandFSrc = Join-Path $FSFolder "lost_and_found"               # Source for lost_and_found folder
    
    Write-Log "Part 1 of 3: Create destination directory if it doesn't exist" "MvUsr."
    if (!(Test-Path $Bakfoldr)) {
        try   { $null = New-Item -ItemType Directory -Path $Bakfoldr -Force -ErrorAction Stop }
        catch { Write-Log "Error creating backup folder at $Bakfoldr - $($_.Exception.Message)" "ERROR!" }}

    Write-Log "Part 2 of 3: Move 'lost_and_found' folder if it exists. Warning, could be huge." "MvUsr."
    try {
        if (Test-Path $LandFSrc) {
            Write-Log "Attempting to move '$LandFSrc' to '$DestinationLostAndFound' for $UserName" "MvUsr."
            Move-Item -Path $LandFSrc -Destination $LandFBak -Force -ErrorAction Stop
            Write-Log "Move command of lost_and_found completed for $UserName" }
        else { Write-Log "lost_and_found not found for $UserName, continuing." }}
    catch { Write-Log "Error moving lost_and_found: $($_.Exception.Message)" "ERROR!"; return $false }

    Write-Log "Part 3 of 3: Finally, delete the user's DriveFS folder" "MvUsr."
    try {
        if (Test-Path $FSFolder) {
            Write-Log "Attempting to delete DriveFS folder at $FSFolder for $UserName" "MvUsr."
            Remove-Item -Path $FSFolder -Recurse -Force -ErrorAction Stop
            Write-Log "DriveFS folder deleted for $UserName" "MvUsr." }
        else { Write-Log "DriveFS folder not found for $UserName, continuing." "MvUsr." }}
    catch { Write-Log "Error moving user's DriveFS folder - $($_.Exception.Message)" "ERROR!"; return $false }
    return $true }
#endregion

#region --={ Main Loop }=--
Write-Log "Getting list of user folders (excluding default and admin profiles)"
try {
    $UserFolders = Get-ChildItem -Path "C:\Users" -Directory |
        Where-Object { $_.Name -notin "Public", "Default", "Default User", "All Users", "Administrator" }}
catch { Write-Log "Error loading user profiles: $($_.Exception.Message)" "ERROR!"; EXIT 1 }
Write-Log "Found $($UserFolders.Count) user profiles."

Write-Log "Stopping Google DriveFS processes for all users."
try {
    $Stopped = Stop-Processes "GoogleDriveFS" 
    if (!$Stopped) {
        Write-Log "Waiting a minute and a half for processes to stop, then trying again."
        Start-Sleep -Seconds 90
        $Stopped = Stop-Processes "GoogleDriveFS" }
    if (!$Stopped) { Write-Log "Failed to stop the Google DriveFS processes after two attempts." "ERROR!"; EXIT 1 }}
catch { Write-Log "Terminating error stopping Google DriveFS processes: $($_.Exception.Message)" "ERROR!"; EXIT 1 }

Write-Log "Processing all user profiles..."
try {
    foreach ($UserFolder in $UserFolders) {
        Write-Log "Processing user profile: $($UserFolder.Name)" "MvUsr."
        $MvResult = Move-GoogleDriveUser $UserFolder.Name
        Write-Log "Move-GoogleDriveUser result for $($UserFolder.Name): $MvResult" "MvUsr" }}
catch { Write-Log "Terminating error moving user profiles: $($_.Exception.Message)" "ERROR!"; EXIT 1}

Write-Log "--=( Google Drive Local Data Delete Script Complete )=--" "-End!-"
EXIT 0
#endregion