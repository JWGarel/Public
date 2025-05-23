#powershell
<#
.SYNOPSIS
    Provides Write-Log function for small text based logs by appending a single line of text per call.
    Outputs to host as well for transcript and testing purposes
.DESCRIPTION
    Logging module that provides the Write-Log function.
    Adds a line of asterisks below Error! type, and below as well if it's in all caps.
    Make sure to definte $LogFile with the full logfile path
.EXAMPLE
    This line:
        LogMessage "This is a sample message" "Test"
    Produces this result:
        [25-04-29 07:39:52][Test  ]: This is a sample message

    This line:
        LogMessage "Testing error..." -Type ERROR!
    Produces this result:
        [25-04-29 07:39:52][ERROR!]:  ***************************************
        [25-04-29 07:39:52][ERROR!]: Testing error...
        [25-04-29 07:39:52][ERROR!]:  **************************************
.NOTES
    Author:    Jason W. Garel
    Version:   1.0.5
    Created :  01-06-25
    Modified : 05-22-25
    Change Log:
        05-22-25 - JWG - Updated comment block. Added Write-Host for console output. Avoided Tee-Output for return issues.
        05-12-25 - JWG - Added $FileParams with -Force for Out-File section. Added ErrorAction to New-Item.
                         Added regions for clarity. Added PSCmdlet.ShouldProcess for all file operations.
        05-09-25 - JWG - Configured as a cmdlet and added skip function.
        05-04-25 - JWG - Added catch for missing variables. Write-Log will now still function with no input whatsoever.
                         Changed catch errors From Write-Host to Write-Warning
                         You now only need to provide $LogFile and the path will be extracted from that.
        04-29-25 - JWG - Turned existing function into this module, added try/catch blocks for local debug.
                         Updated "ERROR!" bracketing to increase further when entered in all caps.
    Requires: PowerShell v3.0 or later
    Permissions: Write to log directory
.OUTPUTS
    Appends a logfile at $LogFile (defined in your script)
.FUNCTIONALITY
    Designed to be used in scripts that are unattended, deployed, or run as a scheduled task. Can still be used from the command line.
.COMPONENT
    Logging Utility
#>

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
        [Parameter(Position = 0, HelpMessage="The message block to be recorded after timestamp and type.")][String]$Message = "No message entered",
        [Parameter(Position = 1, HelpMessage="A six char 'type' preface to you help sort script sections")][String]$Type = " info ",
        [Parameter(Position = 2, HelpMessage="Set this flag false to not actually write anything to log.")][Boolean]$DontSkip = $true )

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
            "$Timestamp$TypePrefix $Message" | Out-File @FileParams
            Write-Host "$TypePrefix $Message" -ForegroundColor Green
            if($Type -ceq "ERROR!") { "$Timestamp$TypePrefix$ErrorBracket" | Out-File @FileParams }}
        catch { Write-Warning "Error writing log file! Check permissions? Exception: $($_.Exception.Message)" }}}
    #EndRegion --=( Write Input to Log File )=--
    
Export-ModuleMember -Function Write-Log