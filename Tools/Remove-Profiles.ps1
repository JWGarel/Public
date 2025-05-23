#powershell
# Removes all AD user profiles
#Requires -RunAsAdministrator
#Requires -Version 3.0
<#
.SYNOPSIS
    Removes all AD user profiles
.DESCRIPTION
    Removes all Active Directory (AD) user profiles from the local machine. 
    Backs up user profiles that have been used within a specified time period before deletion. 
    Call the Altiris Restart function before running this script, and keep the user logged out.
.NOTES
    Author:    Jason W. Garel
    Version:   1.0.0
    Created :  05-22-25
    Modified : 05-22-25
    Change Log:
        05-22-25 - JWG - Created
    Dependencies: Write-Log.psm1, UserRegistry.psm1
.PARAMETER SkipBackup
    Set to skip backing up all user profiles before deleting them
.PARAMETER SkipDelete
    Set to skip deleting the user profiles after backing them up
.PARAMETER Force
    Logs everyone out
.OUTPUTS
    0 for success
    1 unspecified error
    2 for error backing up profiles
    3 for users still logged in and -Force was not set
    Logs are saved in $LogFile
.EXAMPLE
    # Example 1: Back up and delete all AD user profiles
    .\Remove-Profiles.ps1

    # Example 2: Only back up profiles, do not delete
    .\Remove-Profiles.ps1 -SkipDelete

    # Example 3: Only delete profiles, do not back up
    .\Remove-Profiles.ps1 -SkipBackup

    # Example 4: Force log off all users before proceeding
    .\Remove-Profiles.ps1 -Force
.FUNCTIONALITY
    This script is unattended; Designed to be deployed, run as a scheduled task or run from the command line.
#>
param (
    [CmdletBinding(SupportsShouldProcess)]
    [Parameter(HelpMessage="Skip backup user profiles")][Switch]$SkipBackup,
    [Parameter(HelpMessage="Skip deleting of profiles")][Switch]$SkipDelete,
    [Parameter(HelpMessage="Force log off every user.")][Switch]$Force)

#region --=( Initialization )=--
Import-Module "..\Include\Write-Log.psm1"    # Allow logging via Write-Log
Import-Module "..\Include\UserRegistry.psm1" # Needed for Get-UserProfiles and Get-LoggedInSessions
$LogFile = "C:\Temp\Logs\Remove-Profiles.log"
$AddMonths = -2 # Number of months to go back before ignoring a profile to back up (Must be negative)
$ErrorLevel = 0
Write-Host "Log file: $LogFile" # This is to make PSSA stop complaining about the $LogFile not being set
Write-Log "--=( Starting Remove Profiles Script )=--" "Start!"
#endregion --=( Initialization )=--

#region --=( Main Loop )=--
if ($SkipBackup -and $SkipDelete) { Write-Log "Both SkipBackup and SkipDelete have been set, nothing to do." "-LOL-"; EXIT 1 }

#region --=( Log Off Users )=--
$Sessions = Get-LoggedInSessions
if ($Sessions) {
    if (!$Force) { Write-Log "One or more users are still logged in. -Force was not set. Exiting."; EXIT 3 }
    else {
        Write-Log "Force logout switch was enabled, and $($Sessions.Count) users are logged in."
        foreach ($Session in $Sessions) {
            Write-Host "Logging off $($Session.USERNAME) (Session $($Session.ID))"
            if ($PSCmdlet.ShouldProcess("User $($Session.USERNAME)", "Log out user")) {
                try { logoff $Session.ID /V }
                catch { Write-Log "Error logging out user '$($Session.USERNAME)': '$($_.Exception.Message)'" }}}}}
#endregion --=( Log Off Users )=--

#region --=( Get All AD User Profiles and Exclude Administrator ]=--
try { $UserProfiles = Get-UserProfiles }
catch { Write-Log "Error aquiring user profiles! '$($_.ExceptionMessage)'" "ERROR!"; EXIT 1 }
if (!$UserProfiles) { Write-Log "Error aquiring user profiles, Get-UserProfiles returned null."; EXIT 1 }
else {
    Write-Log "Found $($UserProfiles.Count) profiles."
    foreach ($Profile in $UserProfiles) { Write-Log "Found profile: $($Profile.Username)" "FoundU" }}
#endregion --=( Get All AD User Profiles and Exclude Administrator ]=--

#region --=( Backup Profiles )=--
if (!$SkipBackup) {
    $BackedUpProfileCount = 0
    Write-Log "Backing up all recent profiles" "BackUP"
    foreach ($Profile in $UserProfiles) {
        if ($PSCmdlet.ShouldProcess("Profile $($Profile.Username)", "Backup user profile")) {
            $LastWrite = (Get-Item $Profile.HomeDir -ErrorAction SilentlyContinue).LastWriteTime
            if ($LastWrite -and $LastWrite -gt (Get-Date).AddMonths($AddMonths)) {
                $BackupPath = "C:\Temp\ProfileBackups\$($Profile.Username)_$(Get-Date -Format yyyyMMddHHmmss)"
                $RCArgs = @("""$Profile.HomeDir""", """$BackupPath""", "/E", "/COPYALL", "/R:1", "/W:1", "/XJ")
                Write-Log "Starting RoboCopy of $($Profile.Username)" "BackUP"

                try { $RCResult = Start-Process -FilePath "robocopy.exe" -ArgumentList $RCArgs -Wait -NoNewWindow -PassThru }
                catch { Write-Log "Failed to back up $($Profile.Username): $($_.Exception.Message)" "ERROR!"; $ErrorLevel = 1 }

                if ($RCResult.ExitCode -le 3) {
                    Write-Log "Backed up profile: $($Profile.Username) to $BackupPath (with permissions)" "BackUP"
                    $BackedUpProfileCount++

                    # Grant permissions to Administrators group no matter what. Ignore all errors
                    icacls "$BackupPath" /grant Administrators:F /T | Out-Null }
                else {
                    Write-Log "Failed to back up $($Profile.Username) with robocopy. Exit code: $($RCResult.ExitCode)" "ERROR!"; $ErrorLevel = 1 }
 
                Write-Log "RoboCopy of $($Profile.Username) completed with ExitCode '$($RCResult.ExitCode)'" "BackUP" }
            else { Write-Log "Skipped backup for $($Profile.Username) (not used within specified time period or missing)" "BackUP" }}
    if ($ErrorLevel -gt 0) { Write-Log "Backed up $BackedUpProfileCount profiles, but errors were detected!" "ERROR!"; EXIT 2 }}}
else {
    Write-Log "Backed up $BackedUpProfileCount profile(s)"
    if ($ErrorLevel -gt 0) { Write-Log "Errors detected in backup, resolve before continuing, or run script with -SkipBackups" "ERRROR!"; EXIT 2 }}
#endregion --=( Backup Profiles )=--

#region --=( Delete User Profiles )=--
$DeletedProfileCount = 0
foreach ($Profile in $UserProfiles) {
    if ($PSCmdlet.ShouldProcess("Profile $($Profile.Username)", "Delete user profile")) {
        try { $UserProfileCim = Get-CimInstance Win32_UserProfile | Where-Object { $_.LocalPath -eq $Profile.HomeDir }}
        catch { Write-Log "Failed to Get-CimInstance for profile $($Profile.Username): $($_.Exception.Message)" "ERROR!"; $ErrorLevel = 1 }
        if ($UserProfileCim) {
            if (!$SkipDelete) {
                try { Remove-CimInstance -InputObject $UserProfileCim; $DeletedProfileCount++ }
                catch { Write-Log "Failed to delete profile $($Profile.Username): $($_.Exception.Message)" "ERROR!"; $ErrorLevel = 1 }}
            else { Write-Log "Skipped deleting profile: $($Profile.Username)" }}
        else { Write-Log "Profile object not found for $($Profile.Username) at $($Profile.HomeDir)" "Error!" }}}
#endregion --=( Delete User Profiles )=--

if ($DeletedProfileCount -gt 0) { Write-Log "Successfully deleted $DeletedProfileCount of $($UserProfiles.Count) total profiles" }

Write-Log "--=( Completed Remove Profiles Script )=--" "-End!-"
EXIT $ErrorLevel
#endregion --=( Main Loop )=--