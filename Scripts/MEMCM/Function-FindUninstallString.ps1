<#
.SYNOPSIS
  
  Filename: Function-FindUninstallString.ps1
.DESCRIPTION
  Use this to quickly find uninstall strings from registry. Useful when creating app packages for Intune/SCCM
.NOTES
  Version: 1.0
  Author: Andreas Wikström
  Mail: andreas.wikstrom@atea.se
  Twitter: @andreaswkstrm
  Creation Date: 27/02/2021
  Purpose/Change: Initial script development
.EXAMPLE
  Get-Uninstaller Adobe
#>
function Get-Uninstaller {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $Name
  )
 
  $Local_Key     = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
  $Machine_Key32 = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
  $Machine_Key64 = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
 
  $Keys = @($Local_Key, $Machine_Key32, $Machine_Key64)
 
  Get-ItemProperty -Path $keys -ErrorAction 'SilentlyContinue' | Where-Object { ($_.DisplayName -like "*$Name*") -or ($_.PsChildName -like "*$Name*") } | Select-Object PsPath,DisplayVersion,DisplayName,UninstallString,InstallSource,InstallLocation,QuietUninstallString,InstallDate
}
## end of function

