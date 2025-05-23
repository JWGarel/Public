#powershell
# Check if PC is on domain
#Requires -Version 3.0
<# 
.SYNOPSIS
    Check if PC is on domain
.DESCRIPTION
    The function from Write-Log.psm1 module is included so that the domain does not have to be relied on for includes.
    Theoretically you can also kind of test Domain connection by checking if you can even use an include.
    But that takes longer because it has to time out, and something else might be wrong.
.NOTES
    Author:    Jason W. Garel
    Version:   1.0.2
    Created :  05-08-25
    Modified : 05-09-25
    Change Log:
        05-09-25 - JWG - Cleaned up formatting, added regions, added ErrorActions
.OUTPUTS
    0 returns if on domain.
    1 for off domain.
    2 for error 
#>

#region --={ Config Area }=-------------------=-=#
$EnableLogging = $false                       # Turn this to true if you want to make a log file
$LogFile = "C:\Temp\Logs\Check-Domain.log" # Where the log file saved, if logging is enabled
$DomainServer = "EXAMPLE.ORG"           # Set this to the domain server to check
#endregion --------------------------#

#region --={ Functions }=--=#
<#
.SYNOPSIS
    Makes small text based logs by appending a single line of text per call.
.DESCRIPTION
    Saves a single line of timestamped text to $LogFile
    Creates the file if it doesn't exist.
#>
function Write-Log {
    [CmdletBinding(SupportsShouldProcess)][OutputType([System.Boolean])]
    param(
        [Parameter(Position = 0, HelpMessage="The message block to be recorded after the timestamp and type")][String]$Message = "No message entered",
        [Parameter(Position = 1, HelpMessage="A six char 'type' to help sort script sections")][String]$Type = " info ",
        [Parameter(Position = 2, HelpMessage="Set this flag false to not actually write to the log")][Boolean]$DontSkip = $true )

    if (!$EnableLogging) { return $null } # Changed from standard Write-Log to use $EnableLogging to skip the rest of the function if logging is disabled

    #Region --=( Log File Initialization )=--
    # Create the log file if it doesn't exist, and verify the path to the log file
    try {
        $ErrorBracket = "**************************************"  # Set to what the error bracketing text should be
        $Timestamp = "[$(Get-Date -Format "yy-MM-dd HH:mm:ss")]"        # I like the two chr year to save a little space
        $TypePrefix = "[{0,-6}]:" -f $Type                                    # Set prefix to constant width, makes logs way neater.
        if (!$LogFile) { $LogFile = "C:\Temp\Logs\Untitled.log" }                   # If no logfile was provided, provide one.
        if (!$LogPath) { $LogPath = Split-Path -Path $LogFile -Parent }                   # Get the path from $LogFile if it was not defined
        if ($PSCmdlet.ShouldProcess($LogFile, "Create directory '$LogPath' for log file")) {    # Provison for ShouldProcess
            New-Item $LogPath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null }}  # If the path doesn't exist, existify it. That's a word now.
    catch { Write-Warning "Error initializing log file '$LogFile'! Check permissions? Exception: $($_.Exception.Message)" }
    #EndRegion --=( Log File Initialization )=--

    #Region --=( Write Input to Log File )=--
    # Write the input to the log file, and add bracketing asterisks if the type is "Error!"
    if ($PSCmdlet.ShouldProcess($LogFile, "Write log entry: '$Timestamp$TypePrefix $Message' to '$Logfile'")) {
        try {
            $FileParams = @{ FilePath=$LogFile; Append=$true; Encoding='UTF8'; Force=$true } 
            if($Type -eq "ERROR!") { "$Timestamp$TypePrefix$ErrorBracket" | Out-File @FileParams }
            "$Timestamp$TypePrefix $Message" | Out-File @FileParams
            if($Type -ceq "ERROR!") { "$Timestamp$TypePrefix$ErrorBracket" | Out-File @FileParams }}
        catch { Write-Warning "Error writing log file! Check permissions? Exception: $($_.Exception.Message)" }}}
    #EndRegion --=( Write Input to Log File )=--
#endregion

#region --={ Main Loop }=--
try { 
    Write-Log "--=( Starting Domain Check Script. )=--" "Start!"

    try { 
        $DomainResult = $null
        # This test sometimes returns true if it hasn't tried and failed yet, or if the domain was never joined
        $DomainResult = Test-ComputerSecureChannel -ErrorAction SilentlyContinue 
        Write-Log "First check complete, result: $DomainResult" }
    catch { Write-Log "Error processing first secure channel test. $($_.Exception.Message)"; EXIT 2 }

    if ($DomainResult) {
        $OnDomain = $null
        # This test is likely more accurate
        $OnDomain = Test-ComputerSecureChannel -Server $DomainServer -ErrorAction SilentlyContinue
        Write-Log "Second check complete, result: $OnDomain"
        if ($OnDomain) { Write-Log "On Domain" "-Done-"; EXIT 0 }}
        else { Write-Log "Off Domain" "-Done-"; EXIT 1 }}
catch { Write-Log "Error second secure channel test. $($_.Exception.Message)" "-Done-"; EXIT 2 }
finally {
    # This runs even though exit codes are already passed. Neat!
    Write-Log "--=( Completed Domain Check Script )=--" "-End!-"
    Set-ExecutionPolicy Restricted -ErrorAction SilentlyContinue }
#endregion