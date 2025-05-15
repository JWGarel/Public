@ECHO OFF
REM Reset DHCP connection - JWG 5-12-25

ECHO ...Releasing current IP address...
IPCONFIG /RELEASE

ECHO ...Flushing DNS resolver cache...
IPCONFIG /FLUSHDNS

ECHO ...Renewing IP address...
IPCONFIG /RENEW

ECHO ...Registering DNS...
IPCONFIG /REGISTERDNS

REM Optional: Uncomment the following lines if you need to

REM ECHO ..Restarting DHCP Client service...
REM net stop dhcp
REM ping localhost -n 2 > nul
REM net start dhcp

REM ECHO ..Restarting DNS Client service...
REM net stop dnscache
REM ping localhost -n 2 > nul
REM net start dnscache

REM ECHO ..Clearing ARP cache...
REM ARP -D *

REM ECHO ..Resetting Winsock...
REM NetSH winsock reset

REM ECHO ..Resetting IPv4 stack... (this rebuilds the entire TCP/IP stack)
REM NetSH int IPv4 reset 

ECHO.
ECHO Network reset complete.