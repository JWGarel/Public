#powershell
# Rejoin domain
#Requires -RunAsAdministrator
#Requires -Version 3.0
<#
.SYNOPSIS
    Rejoins a remote computer to the the domain. Can run locally or remotely.
.DESCRIPTION
    This script will rename a remote computer and rejoin it to the domain.
    It will prompt for credentials for both the local administrator on the remote computer and the AD credentials to create the computer object.
    If the new name is left blank, it will just rejoin the domain without renaming.
    The script will wait for the computer to come back online after renaming.
.NOTES
    Author:    Jason W. Garel
    Version:   0.0.0 (This does not exist yet)
    Created :  05-28-25
    Modified : 05-28-25
    Change Log:
        05-28-25 -JwG- Created.
    Dependencies: Write-Log.psm1 and AppHandling.psm1
.OUTPUTS
    Returns 0 for lack of critical errors and 1 for critical failure.
    Logs are saved in $LogFile
.FUNCTIONALITY
    This script is attended since there is not currently a safe way (for me personally) to hand it credentials.
.COMPONENT
    Domain Management
#>
<#
Curent plan for outline:

1) Prompt
	A) Needs My AD creds because that cannot be saved
	B) Already knows local admin creds, on fail, tries older creds, on third fail, tries LAPPS
	C) Needs remote computer name or IP address
	D) Needs desired computer name or IP address (could be the same thing)
2) Set computer name first
	A) If on domain, remove from domain.
	B) If name is different, change name.
	C) Reboot remote. Local script waits a set amount of time, polling for when remote PC wakes up.
	D) Search for existing AD object, if it exists, delete it.
	E) Create new AD object
3) Join computer back to domain 
4) Yet another reboot, then verify connection

#>
#region --=( Initialization )=--
[CmdletBinding()]
param()

Import-Module "..\Include\Write-Log.psm1"
Import-Module "..\Include\AppHandling.psm1"
$LogFile = "C:\Temp\Logs\NTS-TimeSync.log"
Write-Host "Logfile is located at $LogFile" -ForegroundColor Green
Write-Log  "--=( Starting Remote Computer Rename\Rejoin. )=--" "Start!"
#endregion

#region --=( Main Loop )=--
#region --=( User Input )=--
Write-Host "Please enter credentials with local administrator rights on the remote computer." -ForegroundColor Cyan
try { $AdminCredential = Get-Credential -Message "Remote Computer Admin Credentials" -ErrorAction Stop }
catch { Write-Host "Credential input cancelled or failed. Exiting." -ForegroundColor Red; EXIT 1 }
Write-Log "Credentials recieved for remote computer." "-Cred-"

Write-Host "Please enter AD credentials that can create the computer object and join it to the domain." -ForegroundColor Cyan
try { $ADCredential = Get-Credential -Message "AD credentials. Leave blank if identical to local credential in the last entry" -ErrorAction Stop }
catch { Write-Host "Credential input cancelled or failed. Exiting." -ForegroundColor Red; EXIT 1 }
if ($null = $ADCredential) { $ADCredential = $AdminCredential } 
Write-Log "Credentials recieved for AD computer." "-Cred-"

try { $OldComputerName = Read-Host "Enter the remote computer's CURRENT name or IP (Currently does not support IP)" }
catch { Write-Host "Remote computer name or IP entry canceled or failed. Exiting." -ForegroundColor Red; EXIT 1 }
if ([string]::IsNullOrWhiteSpace($OldComputerName)) { Write-Host "Current computer name cannot be empty. Exiting." -ForegroundColor Red; EXIT 1 }
Write-Log "Current computer name recieved: $OldComputerName" "-Name-"

try { $NewComputerName = Read-Host "Enter the remote computer's NEW name or leave blank to just rejoin to domain" }
catch { Write-Host "Remote computer new name canceled or failed. Exiting." -ForegroundColor Red; EXIT 1 }
Write-Log "New computer name recieved: $NewComputerName" "-Name-"

if ($NewComputerName -eq $OldComputerName -or [string]::IsNullOrWhiteSpace($NewComputerName)) { Write-Host "Name change not needed, skipping to rejoin" "-Name" } #Just rejoin w/o name change
else { $Renanmed = Set-ComputerName $OldComputerName $NewComputerName $AdminCredential }
#endregion

function Set-ComputerName {
    param (
        [Parameter(Mandatory=$true, Position = 0, HelpMessage="Old computer name to connect to")][ValidateNotNullOrEmpty()][string]$OldComputerName,
        [Parameter(Mandatory=$true, Position = 1, HelpMessage="Name to assign to the computer.")][ValidateNotNullOrEmpty()][string]$NewComputerName,
        [Parameter(Mandatory=$true, Position = 3, HelpMessage="Local administrator credentials")][ValidateNotNullOrEmpty()][pscredential]$AdminCredential
    )
    Write-Log "Attempting to rename '$OldComputerName' to '$NewComputerName'..." "ReName"
    Write-Host "This will reboot the remote computer." -ForegroundColor Yellow

    try { Rename-Computer -ComputerName $OldComputerName -NewName $NewComputerName -Credential $AdminCredential -Restart -Force -ErrorAction Stop }
    catch {
        Write-Log  "ERROR renaming computer: $($_.Exception.Message)" "ERROR!"
        Write-Host "Common reasons for failure:" -ForegroundColor Red
        Write-Host "  - Incorrect old computer name." -ForegroundColor Red
        Write-Host "  - Incorrect credentials (not local admin on remote PC)." -ForegroundColor Red
        Write-Host "  - Remote computer not online or WinRM not enabled." -ForegroundColor Red
        Write-Host "  - Firewall blocking WinRM or network connectivity." -ForegroundColor Red
        return 1 }
    Write-Host "Rename command sent successfully to '$OldComputerName'." -ForegroundColor Green; return 0 }

Write-Host "Waiting for '$NewComputerName' to come back online (up to 5 minutes)..." -ForegroundColor Yellow
try {
    # --- Wait for the computer to come back online (using the NEW name) ---
    $timeoutSeconds = 300 # 5 minutes timeout
    $intervalSeconds = 5
    $elapsedTime = 0

    while ($elapsedTime -lt $timeoutSeconds) {
        try {
            # Test-Connection will try to ping the computer. -ErrorAction Stop will throw if no response.
            if (Test-Connection -ComputerName $NewComputerName -Count 1 -ErrorAction Stop -Quiet) {
                Write-Host "Computer '$NewComputerName' is online." -ForegroundColor Green
                break # Exit the loop, computer is online
            }
        }
        catch {
            # Ping failed, computer not yet online or network issue - just continue waiting
        }
        Write-Host "  Still waiting for '$NewComputerName' ($elapsedTime/$timeoutSeconds s)..." -ForegroundColor DarkYellow
        Start-Sleep -Seconds $intervalSeconds
        $elapsedTime += $intervalSeconds
    }

    if ($elapsedTime -ge $timeoutSeconds) {
        Write-Host "ERROR: Computer '$NewComputerName' did not come online within $timeoutSeconds seconds." -ForegroundColor Red
        Write-Host "The rename operation might have succeeded, but the computer did not respond." -ForegroundColor Red
    } else {
        Write-Host "`nComputer '$NewComputerName' has been successfully renamed and is back online." -ForegroundColor Green
    }
}
catch {}
Write-Host "`nScript finished." -ForegroundColor White

Write-Log  "--=( Completed Remote Computer Rename\Rejoin )=--" "-End!-"
#endregion