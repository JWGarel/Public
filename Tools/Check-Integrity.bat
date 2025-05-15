@ECHO OFF
REM Integrity Check and Cleanup (DSIM\SFC)
REM Warning: Very ugly log files ;)

REM Set Variables
SETLOCAL
SET logfile="C:\Temp\IntCheck.log"
FOR /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c-%%a-%%b)
FOR /f "tokens=1-2 delims=/:" %%a in ('time /t') do (set mytime=%%a%%b)

REM Start Logging
ECHO Starting cleanup process... >> %logfile%
ECHO Date: %mydate% Time: %mytime% >> %logfile%
ECHO. >> %logfile%

ECHO Starting DISM Integrity Check >> %logfile%
DISM /Online /Cleanup-Image /RestoreHealth 2>> %logfile%
ECHO. >> %logfile%

ECHO Starting SFC  >> %logfile%
SFC /ScanNow >> %logfile% 2>&1

ECHO Starting DSIM Cleanup >> %logfile%
DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase >> %logfile% 2>&1

ENDLOCAL

@ECHO OFF
REM Stop update services and clear out temp files

REM Set Variables
SETLOCAL
SET logfile="C:\Temp\IntCheck.log"
SET WinUpdateDir=%SystemRoot%\SoftwareDistribution\Download

ECHO Stopping services that could be reserving the files that have issues >> %logfile%
NET STOP wuauserv >> %logfile% 2>&1
NET STOP bits >> %logfile% 2>&1
NET STOP cryptsvc >> %logfile% 2>&1

ECHO Starting Windows Update related temp file cleanup >> %logfile%

ECHO Cleaning catroot2 (May fail if in use) >> %logfile%
RMDIR /s /q %SystemRoot%\System32\catroot2 2>> %logfile%

ECHO Cleaning SoftwareDistribution\Download Folder >> %logfile%
IF EXIST "%WinUpdateDir%\*.*" DEL /f /q "%WinUpdateDir%\*.*" 2>> %logfile%
RD /s /q "%WinUpdateDir%" 2>> %logfile%

ECHO Cleanup finished >> %logfile%
ENDLOCAL

@ECHO OFF
REM Restart services

REM Set Variables
SETLOCAL
SET logfile="C:\Temp\IntCheck.log"

ECHO Starting Windows Update services... >> %logfile%
NET START cryptsvc >> %logfile% 2>&1
NET START bits >> %logfile% 2>&1
NET START wuauserv >> %logfile% 2>&1

ECHO. >> %logfile%
ECHO Job complete >> %logfile%

ENDLOCAL