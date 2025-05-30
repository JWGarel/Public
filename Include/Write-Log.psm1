#powershell
<#
.SYNOPSIS
    Provides Write-Log function along with two other functions to assist with logging, Get-Plural and Exit-Script.
.DESCRIPTION
    This module provides a simple logging function that appends a single line of text to a log file.
    It also includes functions to determine the plural form of a noun based on a count and to exit the script with a specified exit code.
    The Write-Log function outputs to both the log file and the host console, while Get-Plural returns the singular or plural form of a noun.
    Exit-Script allows for standardized script termination with an optional execution policy change to avoid the Altiris call overwriting the error code.
.NOTES
    Author:    Jason W. Garel
    Version:   1.1.0
    Created :  01-06-25
    Modified : 05-29-25
    Requires: PowerShell v3.0 or later
    Permissions: Write to log directory, and 
.FUNCTIONALITY
    Designed to be used in scripts that are unattended, deployed, or run as a scheduled task. Can still be used from the command line.
.COMPONENT
    Logging Utility
#>

<#
.SYNOPSIS
    Provides Write-Log function for small text based logs by appending a single line of text per call.
.DESCRIPTION
    Logging function that appends a single line of text to a log file.
    Creates the log file if it does not exist. Creates the directories if they do not exist.
    Optionally outputs to host as well for transcript and testing purposes
    Adds a line of asterisks below Error! type, and below as well if it's in all caps.
    Make sure to define $LogFile with the full logfile path. This is use of a global variable and not passed as a parameter.
    This function is designed to be used in scripts that are unattended, deployed, or run as a scheduled task.
.EXAMPLE
    This line:
        LogMessage "This is a sample message" "Test"
    Produces this result:
        [25-04-29 07:39:52][Test  ]: This is a sample message

    This line:
        LogMessage "Testing error..." "ERROR!""
    Produces this result:
        [25-04-29 07:39:52][ERROR!]:  ***************************************
        [25-04-29 07:39:52][ERROR!]: Testing error...
        [25-04-29 07:39:52][ERROR!]:  **************************************
.PARAMETER Message
    The message block to be recorded after timestamp and type.
.PARAMETER Type
    A six char 'type' preface to you help sort script sections
.PARAMETER Skip
    Set this flag to not write anything at all to log or host.
.PARAMETER SkipHost
    Set this flag to log, but not output anything to the host.
.OUTPUTS
    Appends a logfile at $LogFile (defined at the start of your script)
.FUNCTIONALITY
    Designed to be used in scripts that are unattended, deployed, or run as a scheduled task. Can still be used from the command line.
.COMPONENT
    Logging Utility
#>
function Write-Log {
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Default', ConfirmImpact = 'Low')][OutputType([void])]
    param(
        [Parameter(Position = 0, HelpMessage="The message block to be recorded after timestamp and type.")][String]$Message = "No message entered",
        [Parameter(Position = 1, HelpMessage="A six char 'type' preface to you help sort script sections")][String]$Type    = " info ",
        [Parameter(              HelpMessage="Set this flag to not write anything at all to log or host.")][Switch]$Skip,
        [Parameter(              HelpMessage="Set this flag to log, but not output anything to the host.")][Switch]$SkipHost )

    if ($Skip) { return $null }

#Region --=( Log File Initialization )=--
    try {
        $ErrorBracket  = "**************************************"    # Set to what the error bracketing text should be
        $Timestamp     = "[$(Get-Date -Format "yy-MM-dd HH:mm:ss")]"      # I like the two chr year to save a little space
        $TypePrefix    = "[{0,-6}]:" -f $Type                                  # Set prefix to constant width, makes logs way neater.
        if (!$LogFile) { $LogFile = "C:\Temp\Logs\Untitled.log" }                  # If no logfile was provided, provide one.
        if (!$LogPath) { $LogPath = Split-Path -Path $LogFile -Parent }                 # Get the path from $LogFile if it was not defined
        if ($PSCmdlet.ShouldProcess($LogFile, "Create directory '$LogPath' for log file")) { # Provison for ShouldProcess
            $null = New-Item $LogPath -ItemType Directory -Force -ErrorAction SilentlyContinue }} # If the path doesn't exist, existify it. That's a word now.
    catch { Write-Warning "Error initializing file '$LogFile'! Error: '$($_.Exception.Message)'" }     # Usually an issue with file permissions
#EndRegion --=( Log File Initialization )=--

#Region --=( Write Input to Log File )=--
    if ($PSCmdlet.ShouldProcess($LogFile, "Write log entry: '$Timestamp$TypePrefix $Message' to '$Logfile'")) {
        try {
            $FileParams =           @{ Path=$LogFile; Encoding='UTF8'; Force=$True                  } 
            if ($Type -eq  "ERROR!") { Add-Content "$Timestamp$TypePrefix$ErrorBracket" @FileParams }
                                       Add-Content "$Timestamp$TypePrefix $Message"     @FileParams
            if (!$SkipHost)          { Write-Host  "$TypePrefix $Message"    -ForegroundColor Green }
            if ($Type -ceq "ERROR!") { Add-Content "$Timestamp$TypePrefix$ErrorBracket" @FileParams }}
        catch      { Write-Warning "Error writing the log file! Exception: $($_.Exception.Message)" }}}
#EndRegion --=( Write Input to Log File )=--

<#
.SYNOPSIS
    Returns the singular or plural form of a noun based on a given count.
.DESCRIPTION
    This function determines whether to use the singular or plural form of a noun
    based on the provided count. It is useful for dynamically generating grammatically
    correct messages. By default, it forms the plural by appending 's' to the singular noun,
    but it allows for custom plural forms for irregular nouns.
.PARAMETER Count
    The integer count to evaluate. If the count is 1, the singular form is returned.
    For any other count the plural form is returned.
.PARAMETER SingularNoun
    The singular form of the noun (e.g., "line", "child", "mouse"). This parameter is mandatory.
.PARAMETER PluralNoun
    The explicit plural form of the noun (e.g., "children", "mice"). If not provided,
    the function defaults to appending 's' to the SingularNoun (e.g., "lines").
    This parameter is optional.
.EXAMPLE
    # Example 1: Basic usage with default pluralization
    Get-PluralNoun -Count 1 -SingularNoun "item"
    # Expected output: item
.EXAMPLE
    # Example 2: Basic usage with default pluralization for multiple items
    Get-PluralNoun -Count 5 -SingularNoun "item"
    # Expected output: items
.EXAMPLE
    # Example 3: Providing a custom plural form for an irregular noun
    Get-PluralNoun -Count 2 -SingularNoun "child" -PluralNoun "children"
    # Expected output: children
.FUNCTIONALITY
    Designed to be used in scripts that are unattended, deployed, or run as a scheduled task. Can still be used from the command line.
#>
function Get-Plural {
    [CmdletBinding()][OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "The count to determine singular or plural form.")]
        [int]$Count,
        [Parameter(Mandatory = $true, Position = 1, HelpMessage = "The singular form of the noun.")][ValidateNotNullOrEmpty()]
        [string]$Singular,
        [Parameter(Mandatory = $false,Position = 2, HelpMessage = "The explicit plural form of the noun. If not specified, appends 's' to the singular noun.")]
        [string]$Plural )

    if (-not $PSBoundParameters.ContainsKey('Plural')) { $Plural = "$($Singular)s" }
    if ($Count -eq 1) { return $Singular }
    else { return $PluralNoun }}

<#
.SYNOPSIS
    Terminates the current PowerShell script with a specified exit code and optionally sets the execution policy.
.DESCRIPTION
    A standardized way to exit a PowerShell script, allowing for a specific exit code to be returned to the
    calling process (e.g., Altiris, a batch file, another script, or a scheduled task).
    By default, after logging the script completion, it attempts to set the PowerShell
    execution policy for the current process to 'Restricted'.
    This behavior can be bypassed using the -DontRestrict switch.
.PARAMETER ExitCode
    The integer value to return as the exit code for the script.
    A value of 0 typically indicates success, while any non-zero value indicates an error or warning.
    If not specified, the default value is 0.
.PARAMETER DontRestrict
    A switch parameter. If this switch is present, the function will skip
    setting the PowerShell execution policy to 'Restricted' for the current process.
.EXAMPLE
    # Exit successfully (exit code 0)
    # Logs completion and sets execution policy to Restricted.
    Exit-Script
.EXAMPLE
    # Exit with an error (exit code 1)
    # Logs completion and sets execution policy to Restricted.
    Exit-Script 1
.EXAMPLE
    # Exit with an error without restricting execution policy
    # Logs completion but does NOT set execution policy to Restricted.
    Exit-Script -ExitCode 1 -DontRestrict
.FUNCTIONALITY
    Designed to be used in scripts that are unattended, deployed, or run as a scheduled task. Can still be used from the command line.
#>
function Exit-Script {
    [CmdletBinding()][OutputType([void])]
    param (
        [Parameter(Position = 0, HelpMessage = "The exit error level to pass to the calling program. Default 0")]
        [int]$ExitCode = 0,
        [Parameter(Position = 1, HelpMessage = "Set this switch to NOT set the execution policy to Restricted.")]
        [Switch]$DontRestrict )
    Write-Log "--=( Script Complete )=--" "-End!-"
    if (!$DontRestrict) { Set-ExecutionPolicy Restricted -Force }
    EXIT $ExitCode }

$FunctionsToExport = @(
    'Write-Log',  # Main logging function
    'Get-Plural', # Get singular or plural form of a noun
    'Exit-Script' # Exit the script with a specified exit code
)
Export-ModuleMember -Function $FunctionsToExport