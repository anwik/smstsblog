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
 
  $local_key     = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
  $machine_key32 = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
  $machine_key64 = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
 
  $keys = @($local_key, $machine_key32, $machine_key64)
 
  Get-ItemProperty -Path $keys -ErrorAction 'SilentlyContinue' | Where-Object { ($_.DisplayName -like "*$Name*") -or ($_.PsChildName -like "*$Name*") } | Select-Object PsPath,DisplayVersion,DisplayName,UninstallString,InstallSource,InstallLocation,QuietUninstallString,InstallDate
}
## end of function

