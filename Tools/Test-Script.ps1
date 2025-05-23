#powershell
# Just a little test platform for Altiris
<#
.SYNOPSIS
    Just a little test platform for Altiris
.DESCRIPTION
    This is a test platform for Altiris
#>
function Write-Log {
    [CmdletBinding(SupportsShouldProcess)][OutputType([System.Boolean])]
    param(
        [Parameter(Position = 0, HelpMessage="The message block to be recorded after the timestamp and type")][String]$Message = "No message entered",
        [Parameter(Position = 1, HelpMessage="A six char 'type' to help sort script sections")][String]$Type = " info ",
        [Parameter(Position = 2, HelpMessage="Set this flag false to not actually write to the log")][Boolean]$DontSkip = $true )

    if (!$DontSkip) { return $null }

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
            $FileParams = @{ FilePath=$LogFile; Append=$true; Encoding='UTF8' } 
            if($Type -eq "ERROR!") { "$Timestamp$TypePrefix$ErrorBracket" | Out-File @FileParams }
            "$Timestamp$TypePrefix $Message" | Tee-Object @FileParams
            if($Type -ceq "ERROR!") { "$Timestamp$TypePrefix$ErrorBracket" | Out-File @FileParams }}
        catch { Write-Warning "Error writing log file! Check permissions? Exception: $($_.Exception.Message)" }}}
    #EndRegion --=( Write Input to Log File )=--
    


$LogFile = "C:\Temp\Logs\Test-Script.log" # Logfile name
Write-Host "Log file: $LogFile" # This is to make PSSA stop complaining about the $LogFile not being used
try {
    Write-Log "--=( Starting Test Script )=--" "Start!" }
catch { Write-Host "Error writing to log file: $($_.Exception.Message)" }



Write-Log "--=( Test Script Completed )=--" "-End!-"
EXIT 0 # Scripts cannot return, they must "exit" to pass the code to Altiris