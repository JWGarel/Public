#powershell
# Uninstall Only Adobe Reader (Not Pro)
#Requires -RunAsAdministrator
#Requires -Version 3.0
<# 
.SYNOPSIS
    Uninstall Only Adobe Reader (Not Pro)
.DESCRIPTION
    There once was a script, so sharp and so keen, to uninstall Reader, a task so routine!
    It sought through the list (Where packages exist) For "Adobe Acrobat" to be seen.
    If "Reader" it found in the name, Uninstall-Package became its game.
    But if "64-bit" showed, A registry code, Determined if Pro shared the same.

    For Pro, it would halt and take heed,
        "No touch!" was the script's firm creed.
    So Reader would flee,
        While Pro stayed carefree,
            A selective uninstaller, indeed!
.NOTES
    Author:    Jason W. Garel
    Version:   1.0.4
    Created :  03-14-25
    Modified : 05-05-25
    Dependencies: Write-Log.psm1
.OUTPUTS
    Returns 0 for lack of critical errors, 1 for critical failure.
#>


Import-Module "..\Include\Write-Log.psm1"  # Allow logging via Write-Log function
$LogFile    = "C:\Temp\Logs\AdobeReader-Uninstall.log"                      # Path to log file
$SCAKey     = "HKLM:\SOFTWARE\Adobe\Adobe Acrobat\DC\Installer"             # Current SCA key location 4-29-25
Write-Host    "Log file is located at $LogFile" 
Write-Log     "--=( Adobe Reader Uninstall Script started )=--" "Start!"

# Find all installed packages that look readerish. 
try { $AcrobatPackages = Get-Package -Name "Adobe Acrobat*" -ErrorAction SilentlyContinue }
catch { Write-Log "Critical error with Get-Package: $($_.Exception.Message)" "ERROR!"; EXIT 1 }

try { # Process all installed packages that met previous criteria
    if ($AcrobatPackages) {
        Write-Log "Found Adobe Acrobat packages"
        foreach ($package in $AcrobatPackages) {
            Write-Log "Working on $($package.Name)"
            if ($package.Name -eq "Adobe Acrobat Reader") {
                try { # All standards met for standard version, uninstall it.
                    Write-Log "Uninstalling Adobe Acrobat Reader..."
                    Uninstall-Package -Name "Adobe Acrobat Reader" -Force -Confirm:$false -OutVariable uninstallOutput
                    foreach ($line in $uninstallOutput) { Write-Log  "Uninstall Output: $line" }
                    Write-Log  "Adobe Acrobat Reader uninstalled successfully." }
                catch { Write-Log "Error uninstalling Adobe Acrobat Reader: $($_.Exception.Message)" "ERROR!" }}
        elseif ($package.Name -eq "Adobe Acrobat (64-bit)") {
            Write-Log  "Adobe Acrobat 64-bit found, checking registry key to verify if Pro version"
            $AdobeKey = Get-ItemPropertyValue -Path $SCAKey -Name "SCAPackageLevel" -ErrorAction SilentlyContinue
            if ($AdobeKey -eq 1) { 
                try { # All standards met for 64-bit Reader, uninstall it.
                    Write-Log  "SCAPackageLevel = $AdobeKey - Indicates Adobe Acrobat Reader 64-bit. Uninstalling..."
                    Uninstall-Package -Name "Adobe Acrobat (64-Bit)" -Force -Confirm:$false -OutVariable uninstallOutput
                    foreach ($line in $uninstallOutput) { Write-Log "Uninstall Output: $line" }
                    Write-Log  "Adobe Acrobat (64-bit) uninstalled successfully." }
                catch { Write-Log "Error uninstalling Adobe Acrobat (64-bit): $($_.Exception.Message)" -Type "ERROR!" }}
            elseif ($AdobeKey) { Write-Log "SCAPackageLevel = $AdobeKey - Indicates Acrobat Pro. Leaving this alone." }
            else { Write-Log "SCAPackageLevel Key not found in $SCAKey" "-Warn-" }}
        else { Write-Log "No known Adobe Reader packages identified" }}}
    else { Write-Log "No Adobe packages found." }}
catch { Write-Log "Critical error with uninstall operation! $($_.Exception.Message)" "ERROR!"; EXIT 1 }

# Find all still installed packages that look readerish. Again.
try { $readerPackagesFinalCheck = Get-Package -Name "Adobe Acrobat*" -ErrorAction SilentlyContinue }
catch { Write-Log "Critical error with Get-Package for final check: $($_.Exception.Message)" "ERROR!"; EXIT 1 }

try { # Verification step: Process all still installed packages that met previous criteria to see what the deal is.
    if ($readerPackagesFinalCheck) {
        foreach ($package in $readerPackagesFinalCheck) {
            if ($package.Name -like "Adobe Acrobat Reader*") {
                Write-Log "Adobe Acrobat Reader (Package Name: $($package.Name)) may still be present after attempted uninstall." "-Warn-" }
            elseif ($package.Name -like "Adobe Acrobat (64-bit)*") {
                $AdobeKey = Get-ItemPropertyValue -Path $SCAKey -Name "SCAPackageLevel" -ErrorAction SilentlyContinue
                if ($AdobeKey -eq 1) { Write-Log  "Adobe Acrobat (64-bit) version of reader may still be present after attempted uninstall." "-Warn-" }
                else { Write-Log  "$($package.Name) is likely Adobe Acrobat Pro or another non-reader version." }}
            else { Write-Log  "$($package.Name) is not a version of Adobe Reader this script explicitly checks for." "-Warn-" }}}
    else { Write-Log  "Final check for Acrobat Reader did not find it listed under installed apps." }}
catch { Write-Log "Critical error with final check: $($_.Exception.Message)" "ERROR!"; EXIT 1 }
finally { Write-Log  "--=( Adobe Reader Uninstall Script Completed )=--" "-END!-" }

EXIT 0