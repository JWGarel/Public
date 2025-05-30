#powershell
<#
.SYNOPSIS
    Provides functions for setting registry keys.
.DESCRIPTION
    Push-RKey:   Push a single registry key with verification
    New-Path:    Creates a local or registry path with verification
    Remove-Path: Removes a local or registry path with verification
.NOTES
    Author:    Jason W. Garel
    Version:   2.0.1
    Created :  04-29-25
    Modified : 05-23-25
    Requires: Admin rights
    Dependencies: Write-Log.psm1
.FUNCTIONALITY
    This script is unattended; Designed to be deployed, run as a scheduled task or run from the command line.
#>

<#
.SYNOPSIS
    Create a directory or container.
.DESCRIPTION
    Creates a new directory at the specified path. Can be used for registry or file system.
.PARAMETER Path
    The full path (either container or directory) to create.
.EXAMPLE
    New-Path "C:\Egg\Ultra\Red\Goggles\Bacon"
    Creates every directory even if C:\Egg didn't exist.
#>
function New-Path {
    [CmdletBinding(SupportsShouldProcess)][OutputType([System.Boolean])]
    param ([Parameter(Mandatory=$true, HelpMessage="Enter the full path to create.")][ValidateNotNullOrEmpty()][String]$Path)

    $ItemType = if ($Path -like "*:*") { "Containter" } else { "Directory" } # Registry uses "Container"
    Write-Log "Creating $ItemType $Path" "NwPath"

    try { $null = New-Item -Path $Path -Force -ItemType $ItemType -ErrorAction SilentlyContinue }
    catch { Write-Log "Error creating '$Path' - $($_.Exception.Message)" "ERROR!"; return $false }

    if (Test-Path $Path) { Write-Log "Successful creation of $Path" "NwPath"; return $true }
    else { Write-Log "Failed to create '$Path'" "ERROR!"; return $false }} # Creates a path, either in the registry or the filesystem

<#
.SYNOPSIS
    Removes a specified directory or registry path.
.DESCRIPTION
    The Remove-Path function deletes a specified directory or registry path. 
    It verifies the existence of the path before attempting removal and logs the operation's success or failure.
.PARAMETER Path
    Full path you want removed, can be either a directory or a reg container. Mandatory.
.EXAMPLE
    Remove-Path "C:\Egg\"
    Removes C:\Egg and everything in it.
#>
function Remove-Path {
    param ([Parameter(Mandatory = $true, HelpMessage = "Enter the full path to remove.")][ValidateNotNullOrEmpty()][String]$Path)

    $ItemType = if ($Path -like "*:*") { "Container" } else { "Directory" } # Registry uses "Container"
    Write-Log "Removing $ItemType $Path" "RmPath"

    if (-not (Test-Path $Path)) { Write-Log "$ItemType $Path does not exist." "RmPath"; return $true } # Success if it's already gone
    
    try { $null = Remove-Item -Path $Path -Force -Recurse -ErrorAction SilentlyContinue }
    catch { Write-Log "Error removing '$Path' - $($_.Exception.Message)" "ERROR!"; return $false }

    if (-not (Test-Path $Path)) { Write-Log "Successfully removed $Path" "RmPath"; return $true}
    else { Write-Log "Failed to remove '$Path'" "ERROR!"; return $false }}

<#
.SYNOPSIS
    Change a single registry key.
.DESCRIPTION
    Changes a registry key (except for HKCU for users who are not logged in) Default type is DWORD
.PARAMETER Path
    Full path where the new directory should be created. Mandatory.
.PARAMETER Key
    The specific key name. Mandatory.
.PARAMETER Value
    The value to set the key to. Mandatory.
.PARAMETER ValueType
    The type of value to assign the key. Default is Dword.
.EXAMPLE
    Push-Rkey "HKLM:\Software\Google\DriveFS" "AutoStartOnLogin" 1
    Sets or creates a key HKLM:\Software\Google\DriveFS\AutoStartOnLogin to DWORD 1
#>
function Push-RKey {
    [CmdletBinding(SupportsShouldProcess)][OutputType([System.Boolean])]
    param(
        [Parameter(Mandatory=$true, Position=0, HelpMessage="Path to modify, without the key.")][ValidateNotNullOrEmpty()][String]$Path,
        [Parameter(Mandatory=$true, Position=1, HelpMessage="Key to modify, without the path.")][ValidateNotNullOrEmpty()][String]$Key,
        [Parameter(Mandatory=$true, Position=2, HelpMessage="Desired value for key to be set.")][ValidateNotNullOrEmpty()][String]$Value,
        [Parameter(Mandatory=$false,Position=3, HelpMessage="Optional type, default is DWord.")][String]$ValueType = "DWord")

    if (!$ValueType) { $ValueType = "DWord" } # Fixes some weirdness with passing null variables
    $Path = $Path.Trim(); $Key = $Key.Trim(); $Value = $Value.Trim(); $ValueType = $ValueType.Trim() # Remove any leading or trailing whitespace from input parameters

    Write-Log "Setting '$Path\$Key' to '$Value' type '$ValueType'" "KeySet"
    try { # First, check initial value or existance of key before changing it
        $FullPath = Join-Path $Path $Key
        $null = $CurrentValue
        if (Test-Path $Path) {
            $CurrentValue = Get-ItemProperty -Path $Path -Name $Key -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $Key
            Write-Log "Path '$Path' already exists. Current value of '$Key' is '$CurrentValue'" }
        else {
            Write-Log "$Path does not exist, creating it..." "KeyChk"
            $null = New-Path $Path }} # Small chance New-ItemProperty may still create this path if this line fails.
    catch { Write-Log "Error checking registry key: $($_.Exception.Message)" "ERROR!"; return $false }

    try { # Second, record any existing value and set as needed.
        if ($Value -eq $CurrentValue) { Write-Log "Value of $FullPath is already $CurrentValue." "KeySet"; return $true }
        else {
            Write-Log "Setting $FullPath to '$Value' instead of '$CurrentValue'" "KeySet"
            try {
                if (!$CurrentValue) {
                    Write-Log "Key '$Key' does not currently exist at path '$Path', creating it with value '$Value' and type '$ValueType'"
                    New-ItemProperty -Path $Path -Name $Key -Value $Value -PropertyType $ValueType -Force -ErrorAction Stop }}
            catch { Write-Log "Error creating registry key: $($_.Exception.Message)" "ERROR!"; return $false }

            # Creates item if it doesn't exist and overwrites if it does, vs New-ItemProperty, but cannot set type
            Set-ItemProperty -Path $Path -Name $Key -Value $Value -Force -ErrorAction Stop }}
    catch { Write-Log "Error setting '$FullPath' to '$Value' : $($_.Exception.Message)" "ERROR!"; return $false }

    try { # Third, verify that the key was actually changed
            $null = $VerifyValue
            $VerifyValue = Get-ItemProperty -Path $Path -Name $Key -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $Key
            if ($VerifyValue -eq $Value) { Write-Log "$Key was $CurrentValue, now changed to '$Value' for '$Path'" "KeySet"; return $true }
            else { Write-Log "Key modification failed! Expected '$Value', but found '$VerifyValue' at '$FullPath'." "ERROR!"; return $false }}
    catch { Write-Log "Error verifying $FullPath : $($_.Exception.Message)" "ERROR!"; return $false }} # Set (or create) a registry key value

$FunctionsToExport = @(
    'Push-RKey',  # Push a single registry key with verification
    'New-Path',   # Creates a local or registry path with verification
    'Remove-Path' # Removes a local or registry path with verification
)
Export-ModuleMember -Function $FunctionsToExport