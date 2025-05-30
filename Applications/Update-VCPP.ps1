#powershell
# Background Update of VC++
#Requires -RunAsAdministrator
#Requires -Version 3.0
<#_____________________________________________________.
.SYNOPSIS
       Background Update of VC++                         \
__________________________________________________________\
.DESCRIPTION
       Sometimes VC++ requires a restart.     ||         \
       Logs saved to $Logfile                 ||          \
______________________________________________||           \
.NOTES                                        || Weee!  .-. \ 
       Author:    Jason W. Garel              ||         o.o \
       Version:   1.0.2                       ||        \-/   \
       Created :  05-06-25                    ||      \__|__/  \
       Modified : 05-29-25                    ||================\
______________________________________________||_________________#>
$IP="..\Include"                                                  #\____________
Import-Module "$IP\Write-Log.psm1"; Import-Module "$IP\AppHandling.psm1"       #\
$LogFile  = "C:\Temp\Logs\Update-VCPP.log"; WriH "Find log file at $LogFile"    #\
#region --={ Main Loop }=-- --------------------------------------------------=-=#\
Write-Log "--=( Starting Visual C++ Update Script )=--" "Start!"                  #\
if     (Test-Path $LogFile) { $ErrLv = Initialize-VisualC } else { Exit-Script 3 } #| Off-domain condition
if     ($ErrLv -eq -1) { Write-Log "Restart required..." "-Info-"; Exit-Script 2 } #| Restart condition
elseif ($ErrLv -eq  1) { Write-Log "VC++ not installed!" "ERROR!"; Exit-Script 1 } #| Error condition
else                   { Write-Log "VC++ is up to date!" "-Info-"; Exit-Script 0 } #\ Success condition
#endregion o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o#\