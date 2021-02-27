<#
.DESCRIPTION
    Completely remove MECM-client and all the files and folders that came with it. After running the script,
    reinstall MECM-client manually or from the console.
    Filename: ForceRemoveMECMClient.ps1
.NOTES
    Version: 1.0
    Author: Andreas Wikström
    Mail: andreas.wikstrom@atea.se
    Twitter: @andreaswkstrm
    Creation Date: 18/12/2019
    Purpose/Change: Initial script development
#>
# Stop Services
Stop-Service -Name ccmsetup -Force
Stop-Service -Name CcmExec -Force
Stop-Service -Name smstsmgr -Force
Stop-Service -Name CmRcService -Force

# Wait 30 seconds just to be sure...
Start-Sleep -Seconds 30

# Uninstall SCCM-client
Set-Location "C:\Windows\ccmsetup"
.\ccmsetup.exe /uninstall

# Remove the cache folder
Remove-Item -Path $env:WinDir\ccmcache -Force -Recurse

# Rename the CCM folder
Rename-Item -Path $env:WinDir\CCM -NewName CCM.bak -Force

# Remove Services from Registry
$HKLM = "HKLM:\SYSTEM\CurrentControlSet\Services"
Remove-Item -Path $HKLM\CCMSetup -Force -Recurse
Remove-Item -Path $HKLM\CcmExec -Force -Recurse
Remove-Item -Path $HKLM\smstsmgr -Force -Recurse
Remove-Item -Path $HKLM\CmRcService -Force -Recurse

# Remove SCCM-client from Registry
$HKLM = "HKLM:\SOFTWARE\Microsoft"
Remove-Item -Path $HKLM\CCM -Force -Recurse
Remove-Item -Path $HKLM\CCMSetup -Force -Recurse
Remove-Item -Path $HKLM\SMS -Force -Recurse

# Remove WMI Namespaces
Get-WmiObject -Query "SELECT * FROM __Namespace WHERE Name='ccm'" -Namespace root | Remove-WmiObject
Get-WmiObject -Query "SELECT * FROM __Namespace WHERE Name='sms'" -Namespace root\cimv2 | Remove-WmiObject

# Remove the CCMSetup folder
Remove-Item -Path $env:WinDir\ccmsetup -Force -Recurse