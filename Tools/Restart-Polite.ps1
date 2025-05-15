#powershell
# Restart, 5m delay w/ notice if users logged in.
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Check for logged in users and notify with 5 minute delay. Otherwise restart instantly

.DESCRIPTION
    Checks for any logged in users and warns them the computer is going to restart.
    After timer expires, logs them out and kills explorer, then restarts.
    Early reboot fails, for Altiris; error seen. Patience was the key.

.NOTES
    Author: Jason W. Garel
    Version: 1.0
    Creation Date: 04-02-25
    Permissions: Admin privileges
    Dependencies: None

.OUTPUT
    User reboots early, Altiris shows failure.
#>
#region --={ Configure This }=-----------------=#
$WarningTime = "300"                                # Time until reboot in seconds
$RestartTime = (Get-Date).AddSeconds($WarningTime)      # Time to wait for the restart.
$RestartTimeString = $RestartTime.ToString("HH:mm")         # Set this for how you want the time displayed.
$WarningMsg = "This computer has a scheduled restart at exactly $RestartTimeString - Please save your work now."
#endregion }=------------------------------------------------------=#

#region --={ Functions }=------------------------------------------=#
function Restart-Polite {
    [CmdletBinding(SupportsShouldProcess)][OutputType([System.Int32])]
    param()                                                         # Someday I can set this to accept inputs directly like a proper function.
    $users = $null                                                  #
    try { $users = quser | Where-Object { $_ -match '\s\d+\s' }}    # Poll if anyone is logged in
    catch { return 1 }                                              # Quser has failed! Bail.
    if ($users.Count -gt 0) {                                       # Users logged in ? Notify all logged-in users.
        foreach ($user in $users) {                                 # Cycle through all logged in users.
            $username = ($user -split '\s+')[1]                     # Split quser output into something usable.
            msg "$username" $WarningMsg }                           # Messages the user
        Start-Sleep -Seconds $WarningTime                           # Users logged in, they have been messaged, delay starts now.
                                                                    # During this wait period you can kill the script to stop the reboot.
        $users = $null                                              # Runs after time is up.
        try { $users = quser | Where-Object { $_ -match '\s\d+\s' }}# Poll if anyone is still logged in
        catch { return 1 }                                          # Quser has failed! Bail.
        if ($users.Count -gt 0) {                                   # Users still logged in? Log them out.
            foreach ($user in $users) {                             # Cycle through all logged in users.
               $username = ($user -split '\s+')[1]                  # Split quser output into something usable.
                Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
                logoff $username }}}
    Restart-Computer -Force -Confirm:$false -ErrorAction SilentlyContinue }
#endregion }=------------------------------------------------------=#

#region --={ Main Loop }=------------------------------------------=#
Restart-Polite
#endregion }=-------------------------------------------------------#