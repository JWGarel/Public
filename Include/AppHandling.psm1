#powershell
<#
.SYNOPSIS
    Provides functions for checking installation and version of installed programs.
    All functions explained at the bottom of the script
.NOTES
    Author:    Jason W. Garel
    Version:   1.0.7
    Created :  05-02-25
    Modified : 05-27-25
    Requires: PowerShell v3.0 or later
    Requires: Write-Log.psm1
    ToDo: Can probably merge all update and install functions into one function.
#>

#region --=( Comparison Functions )=--
<#
.SYNOPSIS
    Verifies that a program is installed, and if it is, returns the installed version
.DESCRIPTION
    Finds the installed program with the ProgramName. Will find the first one that matches the partial name,
     so Zoo will return the result for Zoom, but Zoom.Zoom will return $false.
.PARAMETER ProgramName
    The Win32_Product name (not the program ID).
.EXAMPLE
    Resolve-Program "Zoom W"
    Returns 6.4.64378

    Resolve-Program Zoom.Zoom
    Returns False (Because that's not the Win32_Product ID or Name)

    Resolve-Program "Microsoft .NET"
    Returns False (Because a bunch are likely installed)
#>
function Resolve-Program {
    [CmdletBinding()][OutputType([System.Boolean],[System.Int16])]
    param([Parameter(Mandatory=$true, HelpMessage="The Win32_Product ID")][ValidateNotNullOrEmpty()][string]$ProgramName)

    # Find version from name. This takes WAY less time than using | Select-Object.
    $CimIArgs = @{ ErrorAction = 'SilentlyContinue'; ClassName = 'Win32_Product'; Filter = "Name LIKE '%$ProgramName%'" }
    try   { $CimInstance = Get-CimInstance @CimIArgs }
    catch { Write-Log "Error calling Get-CimInstance $ProgramName - '$($_.Exception.Message)'" "ERROR!"; return $null }
    $InstalledVersion = $CimInstance.Version

    # Make sure everything is kosher
    if ($($InstalledVersion.Count) -gt 1) {
        Write-Log "Multiple programs returned! Use a more specific Win32_Product name. Found $($InstalledVersion.Count) programs:" "Error!"
        foreach ($CimLine in $CimInstance) { Write-Log "CimInstance found: $($CimLine.Name)" "-CimI-" }
        return $null }
    if (!$InstalledVersion) { Write-Log "$ProgramName is not installed" "ResPro"; return $false }

    # Success!
    Write-Log "'$($CimInstance.Name)' version '$InstalledVersion' is installed." "ResPro"; return $InstalledVersion }
#endregion --=( Comparison Functions )=--

#region --=( Installation and Update Functions )=--
function Install-Program {
    [CmdletBinding()][OutputType([System.Boolean])]
    param(
        [Parameter(Mandatory=$true,  HelpMessage="The Win32_Product name (not the program ID).")][ValidateNotNullOrEmpty()][string]$ProgramName,
        [Parameter(Mandatory=$true,  HelpMessage="The display name or program ID, eg Zoom.Zoom")][ValidateNotNullOrEmpty()][string]$DisplayName,
        [Parameter(Mandatory=$false, HelpMessage="Full path to winget application src")][string]$Winget = "winget",
        [Parameter(Mandatory=$false, HelpMessage="Switch to accept package agreements")][switch]$AcceptSource)

    Write-Log "Starting $ProgramName install"
    $WingetArgs = @("install", $DisplayName, "--silent", "--force", "--nowarn", "--disable-interactivity", "--accept-source-agreements", "--Allow-Reboot")
    if ($AcceptSource) { $WingetArgs += "--accept-package-agreements" }  # sometimes needed, sometimes causes problems.
    try { $null = & $Winget @WingetArgs }
    catch { Write-Log "Error installing $ProgramName : $($_.Exception.Message)"; return $false }

    Write-Log "$ProgramName install command finished, verifying install..."
    if (Resolve-Program $ProgramName) { Write-Log "$ProgramName installed successfully."; return $true }
    else { Write-Log "$ProgramName not found, installation failed." "Error!"; return $false }}

function Update-Program { 
    [CmdletBinding()][OutputType([System.Boolean])]
    param(
        [Parameter(Mandatory=$true, HelpMessage="The Win32_Product name (not the program ID).")][ValidateNotNullOrEmpty()][string]$ProgramName,
        [Parameter(Mandatory=$true, HelpMessage="The display name or program ID, eg Zoom.Zoom")][ValidateNotNullOrEmpty()][string]$DisplayName)

    Write-Log "Starting update of $ProgramName with display name $DisplayName"
    try {
        $null = Initialize-VisualC
        $Winget = Initialize-Winget
        if (!$Winget) { Write-Log "Error initializing Winget, function returned '$Winget'" "ERROR!"; return $false }}
    catch { Write-Log "Error initializing Visual C++ or Winget: $($_.Exception.Message)" "ERROR!"; return $false }

    Write-Log "Winget initialized at $Winget successfully. Checking if $DisplayName is installed..."
    $ResolveResult = Resolve-Program $ProgramName

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
        [Parameter(Mandatory=$true, HelpMessage="The Win32_Product name (not the program ID).")][ValidateNotNullOrEmpty()][string]$ProgramName,
        [Parameter(Mandatory=$true, HelpMessage="The display name or program ID, eg Zoom.Zoom")][ValidateNotNullOrEmpty()][string]$DisplayName,
        [String]$Winget)

        Install-Program $ProgramName $DisplayName $Winget | Out-Null
        Write-Log "Checking if $ProgramName is installed after installation attempt..."
        $ResolveResult = Resolve-Program $ProgramName
        if ($ResolveResult) { Write-Log "$ProgramName has been installed. Version '$ResolveResult'"; return $true }

        Write-Log "$ProgramName is not installed, Preparing to install again with Accept Source on..."
        $null = Install-Program $ProgramName $DisplayName $Winget -AcceptSource
        Write-Log "Checking if $ProgramName is installed after second installation attempt..."
        $ResolveResult = Resolve-Program $ProgramName
        if ($ResolveResult) { Write-Log "$ProgramName has finally been installed."; return $true }
        Write-Log "Install of $ProgramName has failed twice now. Giving up." "ERROR!"; return $false }

# This function may now be ultimately useless, except for changing the logging language
#  as the Install-WithWinget will do basically the same thing automatically.
function Update-WithWinget { 
    [CmdletBinding()][OutputType([System.Boolean])]
    param(
        [Parameter(Mandatory=$true, HelpMessage="The Win32_Product name (not the program ID).")][ValidateNotNullOrEmpty()][string]$ProgramName,
        [Parameter(Mandatory=$true, HelpMessage="The display name or program ID, eg Zoom.Zoom")][ValidateNotNullOrEmpty()][string]$DisplayName,
        [string]$Winget)

    try { $ProgramShowOutput = & $Winget "upgrade" 2>&1 | Select-String -Pattern "$DisplayName" }
    catch { Write-Log "Error getting installed Program version using Winget: $($_.Exception.Message)"; return $false }

    # Use winget to apply updates (Winget will attempt to install updates automatically even if you use "install" command, this is more for logging purposes)
    if ($ProgramShowOutput) {
        Write-Log "Update available for $ProgramName. Proceeding with update..."

        # Determine existing version
        $CurrentVersion = Resolve-Program $ProgramName
        if ($CurrentVersion) { Write-Log "$ProgramName is installed with version $CurrentVersion." }
        else { Write-Log "Error getting installed Program version." "ERROR!"; return $false }

        # Find the matching winget package ID
        try { $WingetPackage = & $Winget "list" | Where-Object { $_ -match "$DisplayName" }}
        catch { Write-Log "Error finding matching winget package ID for $DisplayName : $($_.Exception.Message)" "ERROR!"; return $false }
        if ($WingetPackage) {
            try { 
                Write-Log "Found matching winget package for: $DisplayName"
                $null = Stop-Processes $ProgramName
                $null = & $Winget "upgrade" "$DisplayName" "--nowarn" "--disable-interactivity" "--force" "--allow-reboot" "--accept-source-agreements" "--accept-package-agreements"
                if ($LASTEXITCODE -ne 0) { Write-Log "Error occurred while upgrading $DisplayName . Winget returned exit code $LASTEXITCODE." "ERROR!"; return $false }
                Write-Log "Update finished for $ProgramName" }
            catch { Write-Log "Error upgrading $DisplayName : $($_.Exception.Message)" "ERROR!"; return $false }}
        else { Write-Log "Error: Unable to find a matching winget package for $DisplayName" "ERROR!"; return $false }}
    else { Write-Log "No update available for $ProgramName"; return $true}

    # Verify version of upgraded program.
        try{
            $NewVersion = Resolve-Program $ProgramName
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
        [Parameter(Mandatory=$true, HelpMessage="The Win32_Product name (not the program ID).")][ValidateNotNullOrEmpty()][string]$ProgramName,
        [Parameter(Mandatory=$true, HelpMessage="The display name or program ID, eg Zoom.Zoom")][ValidateNotNullOrEmpty()][string]$DisplayName,
        [string]$Winget)
    try{
        Write-Log "Starting $ProgramName Uninstall"                              
        $null = & $Winget "uninstall" "$DisplayName" "--silent" "--force" "--nowarn" "--disable-interactivity" "--all"
        Write-Log "$ProgramName Uninstall command complete"
        return $true }
    catch { Write-Log "Error uninstalling $ProgramName : $($_.Exception.Message)"; return $false }}

function Remove-Program {
    [CmdletBinding()][OutputType([System.Boolean])]
    param(
        [Parameter(Mandatory=$true, HelpMessage="The Win32_Product name (not the program ID).")][ValidateNotNullOrEmpty()][string]$ProgramName,
        [Parameter(Mandatory=$true, HelpMessage="The display name or program ID, eg Zoom.Zoom")][ValidateNotNullOrEmpty()][string]$DisplayName)

    $IsItEvenInstalled = Resolve-Program $ProgramName
    if (!$IsItEvenInstalled) { return $true } 
    
    try {
        $null   = Initialize-VisualC
        $Winget = Initialize-Winget
        if (!$Winget) { Write-Log "Error initializing Winget, function returned '$Winget'" "ERROR!"; return $false }}
    catch { Write-Log "Error initializing Visual C++ and Winget : $($_.Exception.Message)" "ERROR!"; return $false }

    # Set up, then call uninstall command
    try { 
        Write-Log "Checking and Stopping any open $ProgramName process"
        $null = Stop-Processes $ProgramName
        Write-Log "Preparing to uninstall $ProgramName ..."
        $null = Uninstall-Program $ProgramName $DisplayName $Winget
        Write-Log "Uninstall command complete, verifying uninstall..." }
    catch { Write-Log "Error in first section of the Remove-Program function: $($_.Exception.Message)" "ERROR!"; return $false }

    # Verify uninstall, if it fails, try uninstalling with Uninstall-Package
    $ResolveResult = Resolve-Program $ProgramName
    if (!$ResolveResult) { Write-Log "$ProgramName uninstall confirmed."; return $true }
    try {
        Write-Log "$ProgramName is still installed, Preparing to attempt uninstall with Uninstall-Package..."
        $null = Uninstall-Package -Name $DisplayName -ErrorAction Stop }
    catch { Write-Log "Error in end section of Remove-Program uninstalling $ProgramName : $($_.Exception.Message)" "ERROR!"; return $false }

    # Verify uninstall, if it fails, try uninstalling with Uninstall-AppxPackage - this is the last resort.
    $ResolveResult = Resolve-Program $ProgramName
    if (!$ResolveResult) { Write-Log "$ProgramName has finally been uninstalled."; return $true }
    try {
        Write-Log "Program is still installed. Attempting to uninstall with Uninstall-AppxPackage..."
        $null = Remove-AppxPackage -AllUsers -Package "$DisplayName" -ErrorAction Stop } # This may need tweaking - it's expecting a package FULL name.
    catch { Write-Log "Error uninstalling '$DisplayName': $($_.Exception.Message)"; return $false }

    $ResolveResult = Resolve-Program $ProgramName
    if (!$ResolveResult) { Write-Log "Uninstall of $ProgramName has finally completed!"; return $true }
    Write-Log "Uninstall of $ProgramName has failed thrice. Giving up."; return $false }
#endregion --=( Application Removal )=--

#region --=( External Functions )=--
function Stop-Processes {
    [CmdletBinding()][OutputType([System.Boolean])]
    param([Parameter(Mandatory=$true, HelpMessage="The Win32_Product name (not the program ID).")][ValidateNotNullOrEmpty()][String]$ProgramName)
    
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
    param ([Parameter(Mandatory=$True, HelpMessage="The service name of the program to verify")][ValidateNotNullOrEmpty()][String]$ServiceName)

    $ServiceStatus = Get-ServiceStatus $ServiceName
    $ServiceParams = @{ Name = $ServiceName; ErrorAction = "Stop"; PassThru = $true }

    if ($ServiceStatus -in @('StartPending', 'StopPending', 'PausePending', 'ContinuePending')) {
        Write-Log "$ServiceName is $ServiceStatus. Waiting 60 seconds and rechecking..." "IntSrv"
        Start-Sleep -Seconds 60
        $ServiceStatus = Get-ServiceStatus $ServiceName

        if ($ServiceStatus -in @('StartPending', 'StopPending', 'PausePending', 'ContinuePending')) {
            Write-Log "$ServiceName is $ServiceStatus after 60 seconds, attempting to restart it..." "IntSrv"
            try { $ServiceStatus = (Stop-Service @ServiceParams -Force).Status }
            catch { Write-Log "Failed to stop '$ServiceName': $($_.Exception.Message)" "Error!"; return $false }
            Start-Sleep -Seconds 20
            
            if ($ServiceStatus -eq "Stopped") {
                Write-Log "$ServiceName stopped. Attempting to start it." "IntSrv"
                try { $ServiceStatus = (Start-Service @ServiceParams).Status }
                catch { Write-Log "Failed to start '$ServiceName': $($_.Exception.Message)" "Error!"; return $false }}}

        if ($ServiceStatus -in @('StartPending', 'StopPending', 'PausePending', 'ContinuePending')) {
            Write-Host "Unable to resolve pending state for $ServiceName, reccomend killing process or restarting." "ERROR!"; return $false }}

    Write-Host "$ServiceName is $ServiceStatus" "IntSrv"
    if ($ServiceStatus -eq "Running") { Write-Log "$ServiceName is running." "IntSrv"; return $true }
    elseif ($ServiceStatus -eq "Stopped") {
        Write-Log "$ServiceName is Stopped. Attempting to start it..."
        try { $ServiceStatus = (Start-Service @ServiceParams -PassThru).Status }
        catch { Write-Log "Failed to start '$ServiceName': $($_.Exception.Message)" "Error!"; return $false }}
    elseif ($ServiceStatus -eq "Paused")  { $ServiceStatus = Resume-Service @ServiceParams }
    
    if ($ServiceStatus -eq "Running") { Write-Log "$ServiceName is now running." "IntSrv"; return $true }
    else { Write-Log "Failed to start '$ServiceName'. Status is now $ServiceStatus" "Error!"; return $false }}

<#
.SYNOPSIS
    Get the status of a service
.DESCRIPTION
    gets the status of a service by name, returns the status as a string.
.PARAMETER ServiceName
    The name of the service to check the status of.
.OUTPUTS
    Returns string of service status (such as "Running", "Stopped", etc). Otherwise returns $false for error.   
#>
function Get-ServiceStatus {
    param([Parameter(Mandatory=$true, HelpMessage="The service name of the program to check the status on")][String]$ServiceName)

    Write-Log "Checking '$ServiceName' status..." "GetSrvS"
    try { $ServiceStatus = (Get-Service $ServiceName -ErrorAction Stop).Status }
    catch { Write-Log "Error getting '$ServiceName' status: $($_.Exception.Message)" "Error!"; return $false }

    Write-Log "$ServiceName is $ServiceStatus" "GetServS"
    return $ServiceStatus }

<#
.SYNOPSIS
    Verifies that the Visual C++ Redistributable is ready to support winget.
.DESCRIPTION
    Verifies that the Visual C++ Redistributable is at least version 14.42.34438
    If not, it will attempt to install that version from our distribution server
.OUTPUTS
    Returns -1: Reboot is needed first.
    Returns +0: Program is ready to go.
    Returns +1: Install attempt failed.    
#>
function Initialize-VisualC {
    [CmdletBinding()][OutputType([System.Int32])]
    $VCInstallParams = @{
        FilePath     = "..\Packages\Microsoft\Visual C++ Runtime\14.42.34438.0\Microsoft Visual C++ 2015-2022 Redistributable (x64)_14.42.34438.0_Machine_X64_burn_en-US.exe";
        ArgumentList = "/quiet /passive /norestart";
        Wait         = $true;
        PassThru     = $true;
        ErrorAction  = "SilentlyContinue" }
    $ComparisonVersion = [System.Version]"14.42.34438"  # Don't add the .0
    $DisplayName = "Microsoft Visual C++*"
    $AttemptInstall = $false

    Write-Log "Verifying $DisplayName install is at least $ComparisonVersion" "InitVC"

    try   { $InstalledProducts = Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction Stop }
    catch { Write-Log "Error finding installed versions of $DisplayName! $($_.Exception.Message)" "ERROR!"; $AttemptInstall = $true }
    if (!$InstalledProducts) { Write-Log "Unable to find any installed versions of $DisplayName " "InitVC"; $AttemptInstall = $true }

    foreach ($Product in $InstalledProducts) {
            if ($Product.DisplayName -like $DisplayName) {
                $InstalledVersion  = [System.Version]$Product.DisplayVersion
                if ($InstalledVersion -lt $ComparisonVersion) { $AttemptInstall = $true }
                else { $AttemptInstall = $false }}}

    Write-Log "Installed version of $DisplayName is $InstalledVersion" "InitVC"               
    if ($AttemptInstall -eq   $false) { return 0 }
    if ($AttemptInstall -isnot $true) {
        Write-Log "Error in function 'Initialize-VisualC' VersionIsNewer returned : '$VersionIsNewer'" "ERROR!"; return +1 }
    else   { Write-Log "Installing $ComparisonVersion" "InitVC" }
    try    { $InstallResult = Start-Process @VCInstallParams    }
    catch  { Write-Log "Unable to launch $DisplayName installer! Check Path?  $($_.Exception.Message)" "ERROR!"; return +1 }
    if     ($InstallResult.ExitCode -eq 0)    { Write-Log "Installation of $DisplayName has completed" "InitVC"; return +0 }
    elseif ($InstallResult.ExitCode -eq 3010) { Write-Log "Reboot required before using $DisplayName." "InitVC"; return -1 }
    else   { Write-Log "Install of $DisplayName has failed! Exit code is: $($InstallResult.ExitCode)." "ERROR!"; return +1 }}

<#
.SYNOPSIS
    Does its best to get winget ready for use.
.DESCRIPTION
    There are several issues with running winget on our Win10 image that this will attempt to resolve:
    First , the "SYSTEM" account doesn't "see" winget, so this function finds and returns a valid path
    Second, if winget was never run on a machine AS THAT SPECIFIC USER, the ToS must be accepted first
    Third , the function will test to make sure winget is fully functional by running a source update.
.OUTPUTS
    Returns the path to the winget executable if successful, or $false if it failed.
#>
function Initialize-Winget {
    Write-Log "Initializing Winget..." "InitWG"
    $Winget = "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_1.25.390.0_x64__8wekyb3d8bbwe\winget.exe"  # It's usually here on our image.
    if   (Test-Path $Winget) { Write-Log "Found winget at default location" "InitWG"}
    else {
        Write-Log "Could not find the winget app at the default location" "InitWG"
        try {
            $Folders = Get-ChildItem -Path "C:\Program Files\WindowsApps" -Directory -Filter "Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe" -ErrorAction SilentlyContinue
            $Latest = $Folders | Sort-Object Name -Descending | Select-Object -First 1
            $Winget = Join-Path $Latest.FullName "winget.exe"
            if (Test-Path $Winget) { Write-Log "Found winget at: $Winget" "InitWG" }
            else { Write-Log "Error: can not find the Winget executable." "ERROR!"; return $false }}
        catch { Write-Log "Error finding Winget: $($_.Exception.Message)" "ERROR!"; return $false }}

    try   { $null = & "$Winget" list --accept-source-agreements }
    catch { Write-Log "Error running winget for first call!  $($_.Exception.Message)" "Error!"; return $false }
    try   { $IsWingetWorking = & "$Winget" source update 2>&1 }
    catch { Write-Log "Error running winget for second call! $($_.Exception.Message)" "ERROR!"; return $false }
    if    ($IsWingetWorking) { Write-Log "Winget is now ready." "InitWG"; return $Winget }
    else  { Write-Log "Error running winget for a second call!" "ERROR!"; return $false }}

function Restart-Polite {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0, HelpMessage="Time until reboot in seconds")]
        [Int16]$Time = 300,
        [Parameter(Position = 1, HelpMessage="Message to show to your user")]
        [String]$Message = "Please save your work now, this computer has a scheduled restart at exactly")

    try {
        # This will be the message displayed to the user:
        $TimeMessage = "$Message $((Get-Date).AddSeconds($Time).ToString("HH:mm"))"

        Write-Host "Checking for logged in users..."
        $Users = quser | Where-Object { $_ -match '\s\d+\s' }
        $Users = @($Users)
        if ($Users.Count -gt 0) {
            Write-Host "$($Users.Count) Users are logged in, sending warning message and delaying $Time seconds..."
            foreach ($User in $Users) {
                $Columns = $User -split '\s+'
                $SessionId = $Columns[2]
                msg $SessionId $TimeMessage }

            # Wait, while checking if explorer is running. If explorer is gone, assume user logged off or rebooted
            $Elapsed = 0
            while ($Elapsed -lt $Time) {
                Start-Sleep -Seconds 5
                $Elapsed += 5
                $ExplorerRunning = Get-Process -Name explorer -ErrorAction SilentlyContinue
                if (!$ExplorerRunning) {
                    Write-Host "Explorer process is gone, assuming user logged off or rebooted."
                    Write-Host "Sending restart just in case and exiting with success." }}

            Write-Host "Warning time expired or explorer closed, logging out users and restarting..." }}
    catch { Write-Warning "Something went wrong, abandoning the polite route and triggering restart now." }
    finally { 
        $null = Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
        $null = Restart-Computer -Force -Confirm:$false -ErrorAction SilentlyContinue
        EXIT 0 }}
#endregion --=( External Functions )=--

$FunctionsToExport = @(
    'Resolve-Program',   # Compares: Returns current version if program installed, false if not
    'Install-WithWinget',# AppStuff: Stages the install for a program with verification
    'Install-Program',   # AppStuff: Actually installs a program with verification
    'Initialize-Service',# External: Initializes a service, starts it if not running
    'Get-ServiceStatus', # External: Find the status of a Windows Service
    'Uninstall-Program', # AppStuff: Actually uninstalls a program with verification
    'Update-WithWinget', # AppStuff: Actually updates a program with verification
    'Update-Program',    # AppStuff: This is the external function to call for an update or installer - Complete program addition script. Verification built in.
    'Remove-Program',    # AppStuff: This is the external function to call for an uninstaller - Complete program removal script. Verification built in.
    'Stop-Processes',    # External: Stop processes by name
    'Initialize-Winget', # External: Locates, initializes, and validates the Winget package manager.
    'Initialize-VisualC',# External: Installs the specified Visual C++ Redistributable if a newer version is found.
    'Restart-Polite'     # External: Restarts with a warning and a delay first.
)
Export-ModuleMember -Function $FunctionsToExport