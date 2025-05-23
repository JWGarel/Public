#powershell
# Add a registry key to the system
#Requires -RunAsAdministrator
#Requires -Version 3.0
<#
.SYNOPSIS
    Sets a specified registry key value on the local machine.
.DESCRIPTION
    This script sets a registry key value at a specified path with a given value and value type.
    It logs all actions and errors to a log file and returns an exit code based on the operation's success or failure.
    The script imports required logging and registry manipulation modules.
.NOTES
    Author:    Jason W. Garel
    Version:   1.0.0
    Created :  05-20-25
    Modified : 05-20-25
    Change Log:
        05-20-25 - JWG - Created.
    Requires:
        - The functions that use Get-Printer need PowerShell 3.0 or later
        - Admin rights to manage printers and services
        - Write-Log module for logging messages and errors
.PARAMETER Path
    The registry path where the key is located (excluding the key name itself). This parameter is mandatory.
.PARAMETER Key
    The name of the registry key to modify (excluding the path). This parameter is mandatory.
.PARAMETER Value
    The value to set for the specified registry key. This parameter is mandatory.
.PARAMETER ValueType
    The type of the registry value to set (e.g., DWord, String). Defaults to "DWord" if not specified.
.EXAMPLE
    .\Push-RegKey.ps1 -Path "HKLM:\Software\MyApp" -Key "Setting" -Value "1" -ValueType "DWord"

    Sets the "Setting" key under "HKLM:\Software\MyApp" to the value 1 as a DWord.
.OUTPUTS
    Logs are written to C:\Temp\Logs\Push-RegKey.log.
    Exit codes:
        0 - Success
        1 - Failed to set registry key
        2 - Error occurred during execution
#>

#region --={ Initialization }=--
[CmdletBinding(SupportsShouldProcess)][OutputType([System.Int64])]
param(
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Path to modify, without the key.")][ValidateNotNullOrEmpty()][string]$Path,
    [Parameter(Mandatory=$true, Position=1, HelpMessage="Key to modify, without the path.")][ValidateNotNullOrEmpty()][string]$Key,
    [Parameter(Mandatory=$true, Position=2, HelpMessage="Desired value for key to be set.")][ValidateNotNullOrEmpty()][string]$Value,
    [Parameter(Mandatory=$false,Position=3, HelpMessage="Optional type, default is DWord.")][string]$ValueType = "DWord")

Import-Module "..\Include\Write-Log.psm1"
Import-Module "..\Include\Push-RegK.psm1"
$LogFile = "C:\Temp\Logs\Push-RegKey.log"

Write-Host "Log file is '$LogFile'" # This is to make PSSA stop complaining about the $LogFile not being set
Write-Log "--=( Starting Registry Key Script )=--" "Start!"
$ExitCode = 0
#endregion --={ Initialization }=--

#region --={ Main Loop }=--
Write-Log "Setting '$Path\$Key' to '$Value'..."
try { $ErrorLevel = Push-RKey -Path $Path -Key $Key -Value $Value -ValueType $ValueType }
catch { Write-Log "Error setting '$Path\$Key' to '$Value' - $($_.Exception.Message)" "ERROR!"; $ExitCode = 2 }

if ($ErrorLevel -eq $true) { Write-Log "Successfully set registry key '$Path\$Key' to '$Value'" "Success!"; $ExitCode = 0 }
elseif ($ErrorLevel -eq $false) { Write-Log "Failed to set registry key '$Path\$Key' to '$Value'" "ERROR!"; $ExitCode = 1 }
else { Write-Log "Unknown error occurred: Push-RegKey returned '$ErrorLevel'" "ERROR!"; $ExitCode = 2 }

Write-Log "--=( Finished Registry Key Script )=--" "-End!-"
EXIT $ExitCode
#endregion --={ Main Loop }=--