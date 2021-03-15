<#
.SYNOPSIS
    Install local printer by IP address through Intune.
    Filename: Install-Printer-Intune.ps1

.DESCRIPTION
    Script found on reddit and was originally written by /u/tommylux (thanks!)
    First you have to download "dpinst64.exe" - it's impossible to find an offical link from MS since all the links are dead... I found it here though: http://originaldll.com/download/24157.exe
    Download the driver files (non-installation version)
    Put dpinst64.exe in the same folder as your driver files, also put this script in the same folder, example "TaskAlfa2553ci.ps1"
    Open the .inf file and look for the name of the print driver you need. Fill in the variables below to match this.
    Test the script and when you've got it working,  wrap it with IntuneWinAppUtil.exe
    Upload the .intunewin file to Intune
    Use this as install command:     PowerShell.exe -ExecutionPolicy Bypass -File .\TaskAlfa2553ci.ps1
    Use this as uninstall command:   PowerShell.exe -ExecutionPolicy Bypass -File .\TaskAlfa2553ci.ps1 -Uninstall
    Detection rule:                  HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Print\Printers\Kyocera TaskAlfa 2553ci

.NOTES
    Version: 1.0
    Author: Andreas Wikström
    Mail: andreas.wikstrom@atea.se
    Twitter: @andreaswkstrm
    Creation Date: 09/09/2020
    Purpose/Change: Initial script development
#>

[CmdletBinding()]
Param
(
[switch]$Uninstall
)

# Printer variables:
$PrinterName = "Kyocera TaskAlfa 2553ci"
$PrinterIP = "192.168.1.5"
$DriverName = "TaskAlfa 2553ci"
$infFile = $PSScriptRoot + "\OEMsetup.inf"
$dppath = $PSScriptRoot + "\dpinst64.exe"

if(!$Uninstall)
{
# Install the driver:
Start-Process -filepath $dppath -ArgumentList "/S /SE /SW"
$procid = (Get-Process DPinst64).id
wait-process -id $procid

# Add the printer driver
Add-PrinterDriver -Name $DriverName

# Create the local printer Port
Add-PrinterPort -Name "TCP:$($PrinterName)" -PrinterHostAddress $PrinterIP

# And then add the printer, using the Port, Driver and Printer name you've chosen
Add-Printer -Name "$($PrinterName)" -PortName "TCP:$($PrinterName)" DriverName $DriverName -Shared:$false

}

else

{

Start-Process -filepath $dppath -ArgumentList ("/S /SE /SW /u " + $infFile)
Remove-printer -Name "$($PrinterName)"
Remove-PrinterPort -Name "TCP:$($PrinterName)"
Remove-PrinterDriver -Name $DriverName

}