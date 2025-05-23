#powershell
<#
.SYNOPSIS
    Provides functions for checking installation and version of installed programs.
    All functions explained at the bottom of the script
.NOTES
    Author:    Jason W. Garel
    Version:   1.0.5
    Created :  05-02-25
    Modified : 05-20-25
    Change Log:
        05-20-25 - JWG - Multiple bugfixes, removed Get-Version. Complete rewrite of Get-Process to no longer use Get-WmiObject.
                           Added Initialize-Service function to start a service if not running.
        05-13-25 - JWG - Added the uninstall functions, tested, works. Still writing install functions, they currently do not work.
        05-06-25 - JWG - Added Install-Program, fixed bug with wrong brackets on Resolve-Program.
                         Restructured comment block and changed export functions to a variable at the bottom. 
    Requires: PowerShell v3.0 or later (for Get-ItemProperty and Where-Object)
    Requires: Write-Log.psm1 (For logging) 
#>

#region --=( Comparison Functions )=--
function Find-Installed32 {
    param([Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$DisplayName32)

    try { return Get-ItemProperty -Path "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object {$_.DisplayName -like $DisplayName32 }}
    catch { Write-Log "Error finding installed versions of $DisplayName32! $($_.Exception.Message)" "ERROR!"; return $null}}

function Find-Installed64 {
    param([Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$DisplayName64)

    try { return Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object {$_.DisplayName -like $DisplayName64 }}
    catch { Write-Log "Error finding installed versions of $DisplayName64! $($_.Exception.Message)" "ERROR!"; return $null }}

function Find-Installed {
    param([Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$DisplayName)

    $found32 = Find-Installed32 $DisplayName
    $found64 = Find-Installed64 $DisplayName
    return $found32 + $found64 }

function Compare-IsNewer64 {
    param(
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$DisplayName64,
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$ComparisonVersion)

        try { $InstalledProducts = Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object {$_.DisplayName -like $DisplayName64} }
        catch { Write-Log "Error finding installed versions of $DisplayName64! $($_.Exception.Message)" "ERROR!"; return $null }
        try {
            if(!$InstalledProducts) { Write-Log "No products found for $DisplayName64 "; return $null }
            foreach ($product in $InstalledProducts) { # We really only care about the first result if this is for VC++ - I'll have to figure a better way for another program
                if ($product.DisplayVersion) {
                    $CurrentVersion = $($product.DisplayVersion)
                    if ($CurrentVersion -lt $ComparisonVersion) { return $true }
                    else { return $false }}}}
        catch { Write-Log "Error comparing versions! $($_.Exception.Message)" "ERROR!"; return $null }}

function Resolve-Program {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$ProgramName,
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$DisplayName)

    $CimIArgs = @{ ErrorAction = 'SilentlyContinue'; ClassName = 'Win32_Product'; Filter = "Name LIKE '%$ProgramName%'" }
    try { $InstalledVersion = Get-CimInstance @CimIArgs | Select-Object -ExpandProperty Version }
    catch { Write-Log "Error finding installed versions of $DisplayName! $($_.Exception.Message)" "ERROR!"; return $null }

    if ($InstalledVersion) { Write-Log "$ProgramName is installed, version returned: '$InstalledVersion'" "ResPro"; return $InstalledVersion }
    else { Write-Log "$ProgramName is not installed" "ResPro"; return $false }}
#endregion --=( Comparison Functions )=--

#region --=( Installation and Update Functions )=--
function Install-Program {
    [CmdletBinding()][OutputType([System.Boolean])]
    param(
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$ProgramName,
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$DisplayName,
        [string]$Winget = "winget",
        [Boolean]$AcceptSource = $false)

    Write-Log "Starting $ProgramName install"
    $WingetArgs = @("install", $DisplayName, "--silent", "--force", "--nowarn", "--disable-interactivity", "--accept-source-agreements", "--Allow-Reboot")
    if ($AcceptSource) { $WingetArgs += "--accept-package-agreements" }  # sometimes needed, sometimes causes problems.
    try { & $Winget @WingetArgs | Out-Null }
    catch { Write-Log "Error installing $ProgramName : $($_.Exception.Message)"; return $false }

    Write-Log "$ProgramName install command finished, verifying install..."
    if (Resolve-Program $ProgramName $DisplayName) { Write-Log "$ProgramName installed successfully."; return $true }
    else { Write-Log "$ProgramName not found, installation failed." "Error!"; return $false }}

function Update-Program { 
    [CmdletBinding()][OutputType([System.Boolean])]
    param(
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$ProgramName,
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$DisplayName)

    Write-Log "Starting update of $ProgramName with display name $DisplayName"
    try {
        Initialize-VisualC | Out-Null
        $Winget = Initialize-Winget
        if (!$Winget) { Write-Log "Error initializing Winget, function returned '$Winget'" "ERROR!"; return $false }}
    catch { Write-Log "Error initializing Visual C++ or Winget: $($_.Exception.Message)" "ERROR!"; return $false }

    Write-Log "Winget initialized at $Winget successfully. Checking if $DisplayName is installed..."
    $ResolveResult = Resolve-Program $ProgramName $DisplayName

    # Winget install will call Update automatically if it's already installed, so here, Install and Update
    #   basically both do the same thing, except the logging is different.
    $AppResult = $false
    if (!$ResolveResult) {
        Write-Log "Program $ProgramName is not already installed. Proceeding with installation..."
        $AppResult = Install-WithWinget $ProgramName $DisplayName $Winget }
    else {
        Write-Log "Program $ProgramName is already installed. Proceeding with update..."
        $AppResult = Update-WithWinget $ProgramName $DisplayName $Winget }
    return $AppResult }

function Install-WithWinget { 
    [CmdletBinding()][OutputType([System.Boolean])]
    param(
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$ProgramName,
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$DisplayName,
        [string]$Winget)

        Install-Program $ProgramName $DisplayName $Winget | Out-Null
        Write-Log "Checking if $ProgramName is installed after installation attempt..."
        $ResolveResult = Resolve-Program $ProgramName $DisplayName
        if ($ResolveResult) { Write-Log "$ProgramName has been installed. Version '$ResolveResult'"; return $true }

        Write-Log "$ProgramName is not installed, Preparing to install again with Accept Source on..."
        Install-Program $ProgramName $DisplayName $Winget -AcceptSource $true | Out-Null
        Write-Log "Checking if $ProgramName is installed after second installation attempt..."
        $ResolveResult = Resolve-Program $ProgramName $DisplayName
        if ($ResolveResult) { Write-Log "$ProgramName has finally been installed."; return $true }
        Write-Log "Install of $ProgramName has failed twice now. Giving up." "ERROR!"; return $false }

# This function may now be ultimately useless, except for changing the log language
#  as the Install-WithWinget will do basically the same thing automatically.
function Update-WithWinget { 
    [CmdletBinding()][OutputType([System.Boolean])]
    param(
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$ProgramName,
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$DisplayName,
        [string]$Winget)

    try { $ProgramShowOutput = & $Winget "upgrade" 2>&1 | Select-String -Pattern "$DisplayName" }
    catch { Write-Log "Error getting installed Program version using Winget: $($_.Exception.Message)"; return $false }

    # Use winget to apply updates (Winget will attempt to install updates automatically even if you use "install" command, this is more for logging purposes)
    if ($ProgramShowOutput) {
        Write-Log "Update available for $ProgramName. Proceeding with update..."

        # Determine existing version
        $CurrentVersion = Resolve-Program $ProgramName $DisplayName
        if ($CurrentVersion) { Write-Log "$ProgramName is installed with version $CurrentVersion." }
        else { Write-Log "Error getting installed Program version." "ERROR!"; return $false }

        # Find the matching winget package ID
        try { $WingetPackage = & $Winget "list" | Where-Object { $_ -match "$DisplayName" }}
        catch { Write-Log "Error finding matching winget package ID for $DisplayName : $($_.Exception.Message)" "ERROR!"; return $false }
        if ($WingetPackage) {
            try { 
                Write-Log "Found matching winget package for: $DisplayName"
                Stop-Processes $ProgramName | Out-Null
                & $Winget "upgrade" "$DisplayName" "--nowarn" "--disable-interactivity" "--force" "--allow-reboot" "--accept-source-agreements" "--accept-package-agreements" | Out-Null
                if ($LASTEXITCODE -ne 0) { Write-Log "Error occurred while upgrading $DisplayName . Winget returned exit code $LASTEXITCODE." "ERROR!"; return $false }
                Write-Log "Update finished for $ProgramName" }
            catch { Write-Log "Error upgrading $DisplayName : $($_.Exception.Message)" "ERROR!"; return $false }}
        else { Write-Log "Error: Unable to find a matching winget package for $DisplayName" "ERROR!"; return $false }}
    else { Write-Log "No update available for $ProgramName"; return $true}

    # Verify version of upgraded program.
        try{
            $NewVersion = Resolve-Program $ProgramName $DisplayName
            if     ($NewVersion -eq $CurrentVersion) { Write-Log "$ProgramName is still version $CurrentVersion, update failed" "ERROR!"; return $false }
            elseif ($NewVersion -gt $CurrentVersion) { Write-Log "$ProgramName has been updated to version $NewVersion."; return $true }
            elseif ($NewVersion -lt $CurrentVersion) { Write-Log "$ProgramName version somehow decreased from $CurrentVersion to $NewVersion ... update failed" "ERROR!"; return $false }
            else { Write-Log "Error comparing versions of $ProgramName" "ERROR!"; return $false }}
        catch { Write-Log "Error getting installed Program version: $($_.Exception.Message)" "ERROR!"; return $false }}
#endregion --=( Installation and Update Functions )=--

#region --=( Application Removal )=--
function Uninstall-Program {
    [CmdletBinding()][OutputType([System.Boolean])]
    param(
        [Parameter(Mandatory=$true)][string]$ProgramName,
        [Parameter(Mandatory=$true)][string]$DisplayName,
        [string]$Winget)
    try{
        Write-Log "Starting $ProgramName Uninstall"                              
        & $Winget "uninstall" "$DisplayName" "--silent" "--force" "--nowarn" "--disable-interactivity" "--all" | Out-Null
        Write-Log "$ProgramName Uninstall command complete"
        return $true }
    catch { Write-Log "Error uninstalling $ProgramName : $($_.Exception.Message)"; return $false }}

function Remove-Program {
    [CmdletBinding()][OutputType([System.Boolean])]
    param(
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$ProgramName,
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$DisplayName)

    # If the program is not installed, exit early.
    if (!(Resolve-Program $ProgramName $DisplayName)) { return $true } 
    
    # Initialize Visual C++ and Winget
    try {
        Initialize-VisualC | Out-Null
        $Winget = Initialize-Winget
        if (!$Winget) { Write-Log "Error initializing Winget, function returned '$Winget'" "ERROR!"; return $false }}
    catch { Write-Log "Error initializing Visual C++ or Winget: $($_.Exception.Message)" "ERROR!"; return $false }

    # Set up, then call uninstall command
    try { 
        Write-Log "Checking and Stopping any open $ProgramName process"
        Stop-Processes $ProgramName | Out-Null
        Write-Log "Preparing to uninstall $ProgramName ..."
        Uninstall-Program $ProgramName $DisplayName $Winget | Out-Null
        Write-Log "Uninstall command complete, verifying uninstall..." }
    catch { Write-Log "Error in first section of the Remove-Program function: $($_.Exception.Message)" "ERROR!"; return $false }

    # Verify uninstall, if it fails, try uninstalling with Uninstall-Package
    $ResolveResult = Resolve-Program $ProgramName $DisplayName
    if (!$ResolveResult) { Write-Log "$ProgramName uninstall confirmed."; return $true }
    try {
        Write-Log "$ProgramName is still installed, Preparing to attempt uninstall with Uninstall-Package..."
        Uninstall-Package -Name $DisplayName -ErrorAction Stop | Out-Null }
    catch { Write-Log "Error in end section of Remove-Program uninstalling $ProgramName : $($_.Exception.Message)" "ERROR!"; return $false }

    # Verify uninstall, if it fails, try uninstalling with Uninstall-AppxPackage - this is the last resort.
    $ResolveResult = Resolve-Program $ProgramName $DisplayName
    if (!$ResolveResult) { Write-Log "$ProgramName has finally been uninstalled."; return $true }
    try {
        Write-Log "Program is still installed. Attempting to uninstall with Uninstall-AppxPackage..."
        Remove-AppxPackage -AllUsers -Package "$DisplayName" -ErrorAction Stop | Out-Null } # This may need tweaking - it's expecting a package FULL name.
    catch { Write-Log "Error uninstalling '$DisplayName': $($_.Exception.Message)"; return $false }

    $ResolveResult = Resolve-Program $ProgramName $DisplayName
    if (!$ResolveResult) { Write-Log "Uninstall of $ProgramName has finally completed!"; return $true }
    Write-Log "Uninstall of $ProgramName has failed thrice. Giving up."; return $false }
#endregion --=( Application Removal )=--

#region --=( External Functions )=--
function Stop-Processes {
    [CmdletBinding()][OutputType([System.Boolean])]
    param([Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$ProgramName)

    try {
        $Procs = Get-Process -Name $ProgramName -ErrorAction SilentlyContinue
        if ($Procs) {
            foreach ($Proc in $Procs) {
                try {
                    Stop-Process -Id $Proc.Id -Force -ErrorAction SilentlyContinue
                    Write-Log "Stopped $ProgramName process with ID $($Proc.Id)" }
                catch { Write-Log "Failed to stop $ProgramName process with ID $($Proc.Id): $($_.Exception.Message)" "Error!" }}}
        else { Write-Log "No running processes found matching $ProgramName" }}
    catch { Write-Log "Error retrieving processes for $ProgramName : $($_.Exception.Message)" "Error!"; return $false }
    return $true }

# This is a universal version of the Initialize-Spooler function from PrinterHandling.psm1
function Initialize-Service {
    param ([Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$ServiceName)
    try {
        $ServiceStatus = $null # This will hold the service's status
        Write-Log "Checking '$ServiceName' status..." "IntSrv"
        $ServiceStatus = (Get-Service $ServiceName -ErrorAction Stop).Status }
    catch { Write-Log "Error getting '$ServiceName' status: $($_.Exception.Message)" "ERROR!" }

    if ($ServiceStatus -ne "Running") {
        Write-Log "$ServiceName is not running. Attempting start..."
        try {
            Start-Service -Name $ServiceName -ErrorAction Stop
            $ServiceStatus = (Get-Service $ServiceName -ErrorAction Stop).Status }
        catch { Write-Log "Failed to start '$ServiceName': $($_.Exception.Message)" "Error!" }}
    else { Write-Log "$ServiceName is $ServiceStatus"; return $true }}

function Initialize-VisualC {
    [CmdletBinding()][OutputType([System.Int32])]
    $VCInstallFile = "..\..\Packages\Microsoft\Visual C++ Runtime\14.42.34438.0\Microsoft Visual C++ 2015-2022 Redistributable (x64)_14.42.34438.0_Machine_X64_burn_en-US.exe"
    $VCInstallModifiers = "/quiet /passive /norestart"
    $ComparisonVersion = "14.42.34438"                                      # Don't add .0 because Compare-IsNewer64 doesn't pull that part
    $DisplayName = "Microsoft Visual C++*"
    try {
        Write-Log "Verifying Visual C++ installation is up to date..."
        $VersionIsNewer = Compare-IsNewer64 $DisplayName $ComparisonVersion # Is the installer actually a newer version?
        if ($VersionIsNewer -eq $true) {                                    # It's more likely than you think!
            Write-Log "Old version detected, installing $ComparisonVersion "
            $InstallResult = Start-Process -FilePath $VCInstallFile -ArgumentList $VCInstallModifiers -Wait -PassThru -ErrorAction SilentlyContinue # Installs VC++ 
            if ($InstallResult.ExitCode -eq 0) { Write-Log "Installation completed successfully."; return 0 }
            elseif ($InstallResult.ExitCode -eq 3010) { Write-Log "Installation completed successfully, but a reboot is required to complete the install." "-WARN-"; return -1 }
            else { Write-Log "Installation failed with exit code $($InstallResult.ExitCode)." ; return 1 }} 
        elseif ($VersionIsNewer -eq $false) { return 0 }
        else { Write-Log "Error in Initialize-VisualC: VersionIsNewer returned this, or no value: '$VersionIsNewer'"; return 1 }}
    catch { Write-Log "Error in Initialize-VisualC function: $($_.Exception.Message)"; return 1 }}

 function Get-WingetPath {
    try {
        $default = "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_1.25.390.0_x64__8wekyb3d8bbwe\winget.exe"  # It's usually here on our image.
        if (Test-Path $default) { Write-Log "Found winget at default location: $default"; return $default }

        $folders = Get-ChildItem -Path "C:\Program Files\WindowsApps" -Directory -Filter "Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe" -ErrorAction SilentlyContinue
        $latest = $folders | Sort-Object Name -Descending | Select-Object -First 1
        $WingetPath = Join-Path $latest.FullName "winget.exe"
        if (Test-Path $WingetPath) { Write-Log "Found winget at $WingetPath"; return $WingetPath }
        else { Write-Log "Winget not found!" "ERROR!"; return $false }}
    catch { Write-Log "Error finding Winget: $($_.Exception.Message)"; return $false }}
 
function Initialize-Winget {
    # SYSTEM account doesn't see winget, even though it's installed. This is the workaround. 
    Write-Log "Initializing Winget..." "InitWG"
    $Winget = Get-WingetPath
    
    # Intitialize Winget: if winget was never run before AS THAT USER, you have to accept the ToS. List is benign. No harm in running this even if ToS already accepted.
    try { & $Winget list --accept-source-agreements | Out-Null }              
    catch { Write-Log "Error running winget for first call! $($_.Exception.Message)" "Error!"; return $false }

    # This is the actual first test of winget.
    try {                                                                     # See if winget even works, if not, bail.
        $IsWingetWorking = $null                                              # Just in case
        $IsWingetWorking = & "$Winget" source update 2>&1 }                   # Yo dawg I hear you like to update sources while you make sure winget is even functional.
    catch { Write-Log "Error running winget for second call! $($_.Exception.Message)" "ERROR!"; return $false }
    if ($IsWingetWorking) { Write-Log "Winget is ready." "InitWG"; return $Winget }
    else { Write-Log "Error running winget for second call!" "ERROR!"; return $false }} # If this fails, something is wrong with the winget install.
#endregion --=( External Functions )=--

$FunctionsToExport = @(
    'Find-Installed64',  # Compares: Find 64-bit apps in registry
    'Find-Installed32',  # Compares: Find 32-bit apps in registry
    'Find-Installed',    # Compares: Combine both functions above
    'Compare-IsNewer64', # Compares: True for if your version is newer, false if not
    'Resolve-Program',   # Compares: Returns current version if program installed, false if not
    'Install-WithWinget',# AppStuff: Stages the install for a program with verification
    'Install-Program',   # AppStuff: Actually installs a program with verification
    'Initialize-Service',# External: Initializes a service, starts it if not running
    'Uninstall-Program', # AppStuff: Actually uninstalls a program with verification
    'Update-WithWinget', # AppStuff: Actually updates a program with verification
    'Update-Program',    # AppStuff: This is the external function to call for an update or installer - Complete program addition script. Verification built in.
    'Remove-Program',    # AppStuff: This is the external function to call for an uninstaller - Complete program removal script. Verification built in.
    'Stop-Processes',    # External: Stop processes by name
    'Get-WingetPath',    # External: Get the path to the winget executable.
    'Initialize-Winget', # External: Locates, initializes, and validates the Winget package manager.
    'Initialize-VisualC' # External: Installs the specified Visual C++ Redistributable if a newer version is found.
)
Export-ModuleMember -Function $FunctionsToExport