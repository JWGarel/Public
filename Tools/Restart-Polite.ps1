#powershell
# Restart, 5m delay w/ notice if users logged in.
#Requires -RunAsAdministrator
#Requires -Version 3.0
<#
.SYNOPSIS
    Check for logged in users and notify with 5 minute delay. Otherwise restart instantly
.DESCRIPTION
    Checks for any logged in users and warns them the computer is going to restart.
    After timer expires, logs them out and kills explorer, then restarts.
.NOTES
    Author:    Jason W. Garel
    Version:   1.0.5
    Created :  04-02-25
    Modified : 05-20-25
    Change Log:
        05-20-25 - JWG - Rewrote script to poll for explorer process instead of just waiting. This should solve the issue of
                          Altiris showing a failure when the user reboots early.
        05-09-25 - JWG - Cleaned up formatting, added regions and ErrorAction, set Restart-Polite to be a cmdlet
        05-06-25 - JWG - Added back as a function (other scripts now call this one) and split variables out for easy config
        05-05-25 - JWG - Revised and cleaned up formatting. Minor bugfixes.
        04-29-25 - JWG - Restructured to remove function, greatly simplified script, added return codes, added try block for quser failures.
.OUTPUTS
    Nothing. Write-Host is used in case of system transcript.
.FUNCTIONALITY
    This script is unattended; Designed to be deployed, run as a scheduled task or run from the command line.
#>
#region --={ Configure This }=-----------------------=#
$WarningTime = 300                                    # Time until reboot in seconds
$RestartTime = (Get-Date).AddSeconds($WarningTime)    # Time to wait for the restart.
$RestartTimeString = $RestartTime.ToString("HH:mm")   # Set this for how you want the time displayed.
$WarningMsg = "This computer has a scheduled restart at exactly $RestartTimeString - Please save your work now."
#endregion #=----------------------------------------=#
#region --={ Functions }=----------------------------=#
function Restart-Polite {
    Write-Host "Checking for logged in users..."
    $Users = quser | Where-Object { $_ -match '\s\d+\s' }
    $Users = @($Users)
    if ($Users.Count -gt 0) {
        Write-Host "$($Users.Count) Users are logged in, sending warning message and delaying $WarningTime seconds..."
        foreach ($User in $Users) {
            $Columns = $User -split '\s+'
            $SessionId = $Columns[2]
            msg $SessionId $WarningMsg }

        # Wait in small increments, checking if explorer is still running
        # If explorer is gone, assume user logged off or rebooted
        $Elapsed = 0
        while ($Elapsed -lt $WarningTime) {
            Start-Sleep -Seconds 5
            $Elapsed += 5
            if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
                Write-Host "Explorer process is gone, assuming user logged off or rebooted."
                Write-Host "Sending restart just in case and exiting with success."
                Restart-Computer -Force -Confirm:$false -ErrorAction SilentlyContinue | Out-Null 
                EXIT 0 }}
            Write-Host "Warning time expired, logging out users and restarting..."
            Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue | Out-Null
            Restart-Computer -Force -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
            EXIT 0 }
    else {
        Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue | Out-Null
        Restart-Computer -Force -Confirm:$false -ErrorAction SilentlyContinue | Out-Null }}
#endregion
#region --={ Main Loop }=--
Restart-Polite | Out-Null
EXIT 0
#endregion