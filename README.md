### These are scripts made for strange conditions; such as when you can't use Group Policy or you need to use an ancient version of Altiris to deploy software or printers to a lot of computers at once.

They're designed to run unattended, locally, and generally do not rely on anything that doesn't come from Microsoft to operate. Works in PowerShell 3.0+ 

### Applications/

Scripts for installing, updating, and uninstalling software using WinGet and other methods.

- **Uninstall-Program.ps1**: Uninstalls any WinGet-supported program by name.
- **Uninstall-Reader.ps1**: Selectively uninstalls Adobe Reader (not Pro).
- **Update-AllApps.ps1**: Updates all installed applications via WinGet.
- **Update-Program.ps1**: Installs or updates a specific program via WinGet.
- **Update-VCPP.ps1**: Updates Microsoft Visual C++ Redistributables.

### GoogleDrive/

Scripts for managing Google Drive installation and user data.

- **GDrive-FixSync.ps1**: Fixes Google Drive sync issues by cleaning user data.
- **GDrive-StartonLogin.ps1**: Sets Google Drive to start on login for all users.
- **GDrive-Uninstall.ps1**: Uninstalls Google Drive using its registry uninstall string.

### Include/

Reusable PowerShell modules providing core functions:

- **AppHandling.psm1**: Functions for program detection, installation, updating, and removal.
- **Push-RegK.psm1**: Functions for registry key management and path creation/removal.
- **UserRegistry.psm1**: Functions for enumerating and modifying user registry hives. (mostly untested)
- **Write-Log.psm1**: Centralized logging function for all scripts.

### Printers/

Scripts for listing and removing printers:

- **Printers-IPDeleteAll.ps1**: Deletes all per-machine IP printers.
- **Printers-IPListAll.ps1**: Lists all per-machine IP printers.
- **Printers-NetworkDeleteAll.ps1**: Deletes all per-machine named network printers.
- **Printers-NetworkListAll.ps1**: Lists all per-machine named network printers.
- **Install-Printer.ps1**: Installs a per-machine printer with PrintUI
- **Uninstall-Printer.ps1**: Uninstalls a per-machine printer with PrintUI

### Tools/

General troubleshooting and utility scripts:

- **Check-Domain.ps1**: Checks if the PC is joined to a domain.
- **Check-Integrity.bat / Check-Integrity.ps1**: Runs DISM and SFC for system integrity checks and cleanup.
- **IPConfigRE.bat**: Resets network settings (DHCP, DNS, ARP, Winsock).
- **Restart-Polite.ps1**: Restarts the computer with user notification and delay.
- **Set-TimeServer.ps1**: Changes and resyncs the system time server.

## Logging

Most scripts use the [`Write-Log`](Include/Write-Log.psm1) module to record actions and errors to log files in `C:\Temp\Logs\`.

## Usage

- Run scripts as Administrator for full functionality.
- Modify parameters at the top of each script as needed for your environment.
- Use the modules in `Include/` for custom scripting or extending functionality.

## Requirements

- Tested on Windows 10 and 11. Theoretically these will work with earlier systems as well.
- PowerShell v3.0 or later (tested on 5.1)
- Administrative privileges for most scripts

## Authors

Scripts and modules by Jason W. Garel.

---

For more details on each script/module, see the inline documentation at the top of each file.
