#powershell
<#
.SYNOPSIS
    User profile and session management utilities for Windows
.DESCRIPTION
    Both "Get-" functions work. Otherwise...
    UNTESTED AND NOT READY FOR USE IN PRODUCTION 
.NOTES
    Author:    Jason W. Garel
    Version:   0.0.1
    Created :  05-09-25
    Modified : 05-22-25
    Change Log:
        05-22-25 - JWG - Rewrote Get-UserProfiles, added Get-LoggedInSessions
    Requirements: PowerShell v3.0 or later
    Dependencies: Write-Log and Push-RegK
.FUNCTIONALITY
    Unattended; Designed to be used in scripts that are deployed, run as a scheduled task or run from the command line.
.COMPONENT
    UserRegistry
#>

#region --=( Working Functions )=--
function Get-LoggedInSessions {
    try {
        $Sessions = (qwinsta) |
          Select-String "^[\s]*[a-zA-Z0-9]+" |
            ForEach-Object {
                $parts = ($_ -replace '^\s+', '') -split '\s+'
                [PSCustomObject]@{
                    SESSIONNAME = $parts[0]
                    USERNAME    = $parts[1]
                    ID          = $parts[2]
                    STATE       = $parts[3] }} |
                      Where-Object { $_.USERNAME -and $_.USERNAME -ne $env:USERNAME }
        return $Sessions }
    catch { Write-Log "Error Getting logged in sessions: '$($_.Exception.Message)'" "ERROR!"; return $null }}

function Get-UserProfiles {
    try {
        Write-Log "Getting all Usernames, SIDs, and NTUSER.DAT locations using Win32_UserProfile" "Get-UI"
        $Profiles = Get-CimInstance Win32_UserProfile | Where-Object { !$_.Special }
        $ProfileList = @()
        foreach ($Profile in $Profiles) {
            # Extract username from LocalPath (C:\Users\username)
            $Username = ($Profile.LocalPath -split '\\')[-1]
            if ($Username -ne "Administrator") {
                $ProfileList += [PSCustomObject]@{
                    SID  = $Profile.SID
                    UserHive = "$($Profile.LocalPath)\NTUSER.DAT"
                    Username = $Username
                    HomeDir  = $($Profile.LocalPath)
                }}}}
    catch { Write-Log "Unable to get profile list: $($_.Exception.Message)" "ERROR!"; return $null }

    if (!$ProfileList) { Write-Log "ProfileList is empty!" "ERROR!"; return $null }
    else { return $ProfileList }}
#endregion

#region --=( Untested Functions )=--
function Mount-UserRegistryHives {
    [CmdletBinding()][OutputType([PSCustomObject[]])]
    param ([Parameter(Mandatory=$true, HelpMessage="The profile list from Get-UserProfiles of Username, SID, Hive location.")][PSCustomObject[]]$ProfileList)

    # First, find out which user SIDs already have loaded hives in HKEY_USERS
    $PatternSID = 'S-1-5-21-\d+-\d+\-\d+\-\d+$' # Regex pattern for SIDs
    $LoadedHives = @()
    try { $LoadedHives = Get-ChildItem Registry::HKEY_USERS -ErrorAction SilentlyContinue | Where-Object {$_.PSChildname -match $PatternSID } | Select-Object @{name="SID";expression={$_.PSChildName}}}
    catch { Write-Log "Unable to list Loaded Hives: $($_.Exception.Message)" "ERROR!"; return $false }
    Write-Log "Found $($LoadedHives.Count) hives already loaded." "Load-AH"

    # Second, get all SIDs that do not have loaded hives
    $UnloadedHives = @()
    try {
        $ComparisonResult = Compare-Object $ProfileList.SID $LoadedHives.SID -PassThru |
                            Where-Object {$_.SideIndicator -eq "<="}

        foreach ($UnloadedSid in $ComparisonResult) { $MatchingProfile = $ProfileList | Where-Object {$_.SID -ceq $UnloadedSid }
            if ($MatchingProfile) {
                $UnloadedHives += [PSCustomObject]@{
                SID      = $MatchingProfile.SID
                UserHive = $MatchingProfile.UserHive
                Username = $MatchingProfile.Username }}}}
    catch { Write-Log "Unable to list Unloaded Hives: $($_.Exception.Message)" "ERROR!"; return $false }
    Write-Log "Found $($UnloadedHives.Count) hives that are not loaded." "Load-AH"

    # Third, load all unloaded hives
    try {
        foreach ($Profile in $ProfileList) {
            if ($Profile.SID -in $UnloadedHives.SID) {
                reg load HKU\$($Profile.SID) $($Profile.UserHive) | Out-Null }}
                Write-Log "All $($UnloadedHives.Count) hives loaded" "Load-AH"
                return $UnloadedHives }
    catch { Write-Log "Error loading hives! $($_.Exception.Message)" "ERROR!"; return $false }} # Returns an array of the previously UNLOADED hives (format: SID UserHive, Username

function ClearHive {
    param ([Parameter(Mandatory=$true)][string]$NTuserDATpath)

    try {
        $DATPath = Split-Path $NTuserDATpath -Parent
        Get-ChildItem ($DATPath) -Force -ErrorAction SilentlyContinue | Where-Object {
            ($_.psiscontainer -eq $false) -and
            ($_.Name -like "ntuser*") -and
            ($_.name -ne "ntuser.dat") -and
            ($_.name -ne "ntuser.ini") -and
            ($_.Name -ne "ntuser.pol") } |
                Remove-Item -Force -ErrorAction SilentlyContinue
        Write-Log "Cleaned up temporary NTUSER.* files in '$DATPath'" }
    catch { Write-Log "Cleanup failed: $($_.Exception.Message)" "ERROR!" }} # Cleans up temp file trash - Unknown if this will actually work
#endregion

<# 
.PLANS
    Way more verification is needed at the end 
    No testing has been done
    The end has almost no logging
    SID list needs to be sure to include the ones we want (Admin? Default?) and not the ones we dont (class, SYSTEM, Public, etc)  


#region --={ Example "Main Loop" }=--
#region - Prep: Fill Arrays and Load Hives
$ProfileList = @()
$ProfileList = Get-UserProfiles
if (!$ProfileList) { Write-Log "Profile list is empty!" "ERROR!"; return $false }
$UnloadHives = @()
$UnloadHives = Mount-UserRegistryHives $ProfileList
if (!$UnloadHives) { Write-Log "Failed to load hives!" "ERROR!"; return $false }
#endregion

#region - Set Keys for All
try {
    foreach ($Profile in $ProfileList) {
        $FullUserPath = Join-Path "Registry::HKEY_USERS" $($Profile.SID)
        $UserSpecificKeyPath = Join-Path $FullUserPath $Path
        Push-RegK $UserSpecificKeyPath $Key $Value $ValueType }}
catch { Write-Log "Error modifying registry for user '$UserSID': $($_.Exception.Message)" "ERROR!" ; return 1 }
#endregion

#region - Unload and Cleanup
try { 
    foreach ($Profile in $UnloadHives) {
        $HiveFullPath = $Profile.UserHive
        if (Test-Path -Path $HiveFullPath) {
            [gc]::collect()
            [gc]::WaitForPendingFinalizers()
            reg unload "$HiveFullPath" | Out-Null     
            Write-Log "Hive '$HiveFullPath' unloaded."
            ClearHive $HiveFullPath }}}        
catch { Write-Log "Error unloading hive for '$UserSID': $($_.Exception.Message)" "ERROR!" ; return 1 }
return 0
#endregion
#endregion for Example Main Loop
#>

$FunctionsToExport = @(
    'Get-UserProfiles',    # Gets the list of non-special local AD profiles
    'Get-LoggedInSessions' # Gets a list of all users logged in to this computer
)
Export-ModuleMember -Function $FunctionsToExport