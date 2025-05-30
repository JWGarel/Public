#powershell
# Install Company Portal Appx Package
#Requires -RunAsAdministrator
#Requires -Version 3.0
<#
.SYNOPSIS
    Installs the Company Portal Appx package on Windows 10/11 devices.
    This script provisions the Company Portal app for all users on the system.
.DESCRIPTION
    This script installs the Company Portal Appx package from a specified network share.
    It provisions the app for all users on the system, ensuring that it is available for use.
    The script logs its actions and any errors encountered during the installation process.
.NOTES
    Author:    Jason W. Garel
    Version:   0.0.0 # This version is untested and not ready for production use
    Created :  05-29-25
    Modified : 05-29-25
    Change Log:
        05-23-25 -JwG- Created
.OUTPUTS
    Returns 0 for success, 1 for error state, 2 for already installed.
    Appends a logfile at $LogFile (defined at the start of your script)
.FUNCTIONALITY
    This script is unattended; Designed to be deployed, run as a scheduled task or run from the command line.
.COMPONENT
    Application Deployment
#>
#region --=( Configuration )=--
$ServPath = ".."
Import-Module "$ServPath\Scripts\Include\Write-Log.psm1"
$LogFile = "C:\Temp\Logs\CompanyPortalInstall.log"; Write-Host "Find the log file at $LogFile"
$PackageRoot = "$ServPath\Microsoft\CompanyPortal_11"
$PackagePathMain = Join-Path -Path $PackageRoot -ChildPath "Microsoft.CompanyPortal_11.1.523.0_neutral___8wekyb3d8bbwe.AppxBundle"
$LicensePath = Join-Path -Path $CompanyPortalRoot -ChildPath "Microsoft.CompanyPortal_8wekyb3d8bbwe_58a1808e-9398-4976-1a05-fc884e16f609.xml"
$PackagePathDep = @(
    (Join-Path -Path $PackageRoot -ChildPath "Microsoft.UI.Xaml.2.7_7.2208.15002.0_x64__8wekyb3d8bbwe.Appx"),
    (Join-Path -Path $PackageRoot -ChildPath "Microsoft.NET.Native.Framework.2.2_2.2.29512.0_x64__8wekyb3d8bbwe.Appx"),
    (Join-Path -Path $PackageRoot -ChildPath "Microsoft.NET.Native.Runtime.2.2_2.2.28604.0_x64__8wekyb3d8bbwe.Appx"),
    (Join-Path -Path $PackageRoot -ChildPath "Microsoft.VCLibs.140.00_14.0.30704.0_x64__8wekyb3d8bbwe.Appx"),
    (Join-Path -Path $PackageRoot -ChildPath "Microsoft.Services.Store.Engagement_10.0.19011.0_x64__8wekyb3d8bbwe.Appx"))
$AppxProvParams = @{
    Online                = $true
    PackagePath           = $PackagePathMain
    DependencyPackagePath = $PackagePathDep
    LicensePath           = $LicensePath
    ErrorAction           = 'Stop'
}
#endregion

#region --=( Main Loop )=--
Write-Log "--=( Company Portal Install Start )=--" "Start!"
if (!(Test-Path $LogFile)) { Write-Host "Log file not found, PC is likely not on the domain"; EXIT 2 }


Write-Log "Checking to see if Company Portal is already installed..." "-Appx-"

try   { $VerificationResult = Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like "Microsoft.CompanyPortal*" }}
catch { Write-Log "Error verifying Appx package: $($_.Exception.Message)" "ERROR!"}
if ($VerificationResult) { Write-Log "Company Portal AppX package is already installed." "-Appx-"; Exit-Script 2 }
else  { Write-Log "Company Portal not installed, proceeding with installation..." "-Appx-" }


Write-Log "Installing Company Portal AppX package..." "-Appx-"

try   { Add-AppxProvisionedPackage @AppxProvParams }
catch { Write-Log "Error provisioning Appx package: $($_.Exception.Message)" "ERROR!"; Exit-Script 1 }


Write-Log "Appx Install complete, verifying package..." "-Appx-"

try   { $VerificationResult = Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like "Microsoft.CompanyPortal*" }}
catch { Write-Log "Error verifying Appx package: $($_.Exception.Message)" "ERROR!"}
if ($VerificationResult) { Write-Log "Company Portal AppX package successfully provisioned and verified." "-Appx-"; Exit-Script 0 }
else  { Write-Log "Company Portal not installed." "ERROR!"; Exit-Script 1 }
#endregion