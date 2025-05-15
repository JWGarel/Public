#powershell
<#
.SYNOPSIS
    Provides functions for polling AD users and for setting user registry keys.

.DESCRIPTION
    UNTESTED AND NOT READY FOR USE IN PRODUCTION 

.NOTES
    Author: Jason W. Garel
    Version: 0.0 (This does not exist yet)
    Creation Date: 05-09-25
    Permissions : Admin rights
    Dependencies: Write-Log and Push-RegK

.PLANS
    Way more verification is needed at the end 
    No testing has been done
    The end has almost no logging
    SID list needs to be sure to include the ones we want (Admin? Default?) and not the ones we dont (class, SYSTEM, Public, etc)  
#>

#region --={ Functions }=--
function Get-UserInfo {
    [CmdletBinding()][OutputType([PSCustomObject[]])]
    param ()

  # REMINDER: Add any other desired hives such as default, administrator, etc

    try {
        Write-Log "Getting all Usernames, SIDs, and NTUSER.DAT locations" "Get-UI"
        $PatternSID = 'S-1-5-21-\d+-\d+\-\d+\-\d+$' # Regex pattern for SIDs
        $ProfileListKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*'
        $ProfileList = @()
        $ProfileList = Get-ItemProperty $ProfileListKey -ErrorAction SilentlyContinue |
        Where-Object {$_.PSChildName -match $PatternSID} | 
        Select-Object @{name="SID";expression={$_.PSChildName}}, 
                      @{name="UserHive";expression={"$($_.ProfileImagePath)\ntuser.dat"}}, 
                      @{name="Username";expression={$_.ProfileImagePath -replace '^(.*[\\\/])', ''}}}
    catch { Write-Log "Unable to get profile list: $($_.Exception.Message)" "ERROR!"; return $null }
    if (!$ProfileList) { Write-Log "ProfileList is empty!" "ERROR!"; return $null } 
    else { return $ProfileList }} # Returns Username, SID, and NTUSER.DAT location all users that match the pattern 

function Load-AllHives {
    [CmdletBinding()][OutputType([PSCustomObject[]])]
    param ([Parameter(Mandatory=$true, HelpMessage="The profile list from Get-UserInfo of Username, SID, Hive location.")][PSCustomObject[]]$ProfileList)

    # First, find out which user SIDs already have loaded hives in HKEY_USERS
    $PatternSID = 'S-1-5-21-\d+-\d+\-\d+\-\d+$' # Regex pattern for SIDs
    $LoadedHives = @()
    try { $LoadedHives = Get-ChildItem Registry::HKEY_USERS -ErrorAction SilentlyContinue | Where-Object {$_.PSChildname -match $PatternSID } | Select @{name="SID";expression={$_.PSChildName}}}
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

#region --={ Example "Main Loop" }=--
#region - Prep: Fill Arrays and Load Hives
$ProfileList = @()
$ProfileList = Get-UserInfo
if (!$ProfileList) { Write-Log "Profile list is empty!" "ERROR!"; return $false }
$UnloadHives = @()
$UnloadHives = Load-AllHives $ProfileList
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