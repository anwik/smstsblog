<#
.SYNOPSIS
    Removes preinstalled bloat from HP
    Filename: Uninstall-HP-Junk.ps1
.NOTES
    Version: 0.1
    Author: Andreas Wikström
    Mail: andreas.wikstrom@atea.se
    Twitter: @andreaswkstrm
    Creation Date: 08/09/2020
    Purpose/Change: Initial script development
#>



# Load all installed software
$Products = Get-WmiObject -Query "select * from win32_product"

#Find and remove HP Sure Recover
$HPSureRecover = $Products | Where-Object { $_.Name -match "HP Sure Recover" }
Invoke-WmiMethod -InputObject $HPSureRecover -Name Uninstall

#Find and remove HP Sure Run
$HPSureRun = $Products | Where-Object { $_.Name -match "HP Sure Run" }
Invoke-WmiMethod -InputObject $HPSureRun -Name Uninstall

#Find and remove HP Sure Click
$HPSureClick = $Products | Where-Object { $_.Name -match "HP Sure Click" }
Invoke-WmiMethod -InputObject $HPSureClick -Name Uninstall

#Find and remove HP Client Security
$HPClientSecurity = $Products | Where-Object { $_.Name -match "HP Client Security" }
Invoke-WmiMethod -InputObject $HPClientSecurity -Name Uninstall