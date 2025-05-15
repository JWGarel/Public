#powershell
# Background Update of VC++
#Requires -RunAsAdministrator
<#___________________________________________________.
   .SYNOPSIS                                          \
       Background Update of VC++                       \
________________________________________________________\
   .DESCRIPTION                               ||        \
       Sometimes VC++ requires a restart.     ||         \
       Logs saved to $Logfile                 ||          \
______________________________________________||           \
   .NOTES                                     || Weeee  .-. \
       Author: Jason W. Garel                 ||        o.o  \
       Version: 1.0                           ||        \-/   \
       Creation Date: 05-06-25                ||       __|__   \
                                              ||================\
______________________________________________||_________________\_
    Requires: PowerShell v3.0 or later                             #\
    Permissions: Admin rights                                       #\
    Dependencies:                                                    #\
        Write-Log.psm1, AppHandling.psm1, Restart-Polite.ps1          #\
.OUTPUT                                                                #\
    Returns 0 for lack of critical errors and 1 for critical failure.   #>
#region --={ Configure }=--==============================================#\
$LogFile = "C:\Temp\Logs\Update-VCPP.log"                                 #\ Logfile name
Import-Module "..\Include\Write-Log.psm1"                                  #\ Write-Log function
Import-Module "..\Include\AppHandling.psm1"                                 #\ Fancy app handling functions
$YayRestart = "..\Restart-Polite.ps1"                                        #\ Polite script in case restart is needed
#endregion                                                                    #\
#region --={ Main Loop }=-- ------------------------------------------------=-=#>
Write-Log "--=( Starting VC ++ Update Script. )=--" "Start!"                    #\
$ErrorLevel = Initialize-VisualC                                                 #\ Returns 1 for error, 0 for installed, -1 for reboot needed
Write-Log "Install program returned errorlevel $ErrorLevel"                       #\
if ($ErrorLevel -eq -1) { Write-Log "Restart required..."; . $YayRestart  }        #| Restart condition
elseif ($ErrorLevel -eq 1) { Write-Log "VC++ not installed!" "ERROR!"; return 1 } #/ Error condition
Write-Log "--=( Completed VC ++ Update Script )=--" "-End!-"                     #/
Write-Host "Find the log file at '$LogFile'"                                    #/ Make PSSA stop complaining about $LogFile not being set
#endregion o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-#/