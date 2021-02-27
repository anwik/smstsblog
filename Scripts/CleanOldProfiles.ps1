<#
.SYNOPSIS
    Remove userprofiles that are older than X days.
    Filename: LocalCleanOldProfiles.ps1
.DESCRIPTION
    This script is executed locally on a computer on which you want to remove old profiles.
    You will see some output in the console and for more comprehensive information you can check the logfile "DeleteOldProfiles.log"
    which will be written to the share you specify on row 20.
.NOTES
    Version: 1.0
    Author: Andreas Wikström
    Mail: andreas.wikstrom@atea.se
    Twitter: @andreaswkstrm
    Creation Date: 17/06/2020
    Purpose/Change: Initial script development
#>

# Variables
$ComputerName = $env:computername
$LogFile = "\\server.se\share\$($ComputerName).log"
$NumberofDays = "120"   # Userprofiles older than this value (days) will be removed.

# Timestamp function for logging
Function TimeStamp {$(Get-Date –f "yyyy-MM-dd HH:mm:ss")} 



# Begin script
"$(TimeStamp) INIT: Delete Old Profiles Script started" | Out-File -Append $LogFile
"$(TimeStamp) INFO: Will search for user profiles that are older than $NumberofDays old and delete them" | Out-File -Append $LogFile



"$(TimeStamp) INFO: Checking number of profiles and their age" | Out-File -Append $LogFile
$UserProfiles = Get-ChildItem C:\Users | ? {$_.name -notlike '*Public*' -and $_.name -notlike '*Default*' -and $_.name -notlike '*Admin*' -and $_.LastWriteTime -le (Get-Date).AddDays(-$NumberofDays)} -ErrorAction SilentlyContinue | Where-Object {$_.PSIsContainer}
$NumberofUserProfiles = $UserProfiles.count
"$(TimeStamp) INFO: $ComputerName has $NumberofUserProfiles profiles that will be removed -> ($Userprofiles)" | Out-File -Append $LogFile
$DiskBefore = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'" | Select-Object Size,FreeSpace
$RoundedBefore = [Math]::Round($DiskBefore.Freespace / 1GB)
"$(TimeStamp) INFO: $ComputerName has $Roundedbefore GB free on C: before running the cleanup" | Out-File -Append $LogFile
Write-Host "$ComputerName has $RoundedBefore gb free before running the cleanup" -ForegroundColor Yellow
                
# Remove all userprofiles that are older than X days
    Foreach ($UserProfile in $UserProfiles) {
        try { "$(TimeStamp) INFO: $ComputerName Attempting to remove the profile for $UserProfile" | Out-File -Append $LogFile
            Write-Host "Removing user $Userprofile on $Computer" -ForegroundColor Yellow
            Get-WMIObject -class Win32_UserProfile | Where {$_.localpath -eq 'c:\users\' + $userprofile.name} | Remove-WmiObject
            "$(TimeStamp) OK: $ComputerName userprofile $Userprofile successfully removed" | Out-File -Append $LogFile
            Write-Host "$ComputerName $Userprofile successfully removed" -ForegroundColor Green  }
        catch {
            Write-Host "Could not remove the $userprofile" -ForegroundColor Red
            "$(TimeStamp) ERROR: Could not remove $userprofile" | Out-File -Append $LogFile
            "$(TimeStamp) ERROR: $_" | Out-File -Append $LogFile 
            }
                       
            
    

   } 


# Clean temp folders
"$(TimeStamp) INFO: $Computer Cleaning temp folders" | Out-File -Append $LogFile
Get-ChildItem C:\Users\*\AppData\Local\Temp\* | remove-item -Force -recurse -ErrorAction SilentlyContinue
Get-ChildItem C:\Users\*\AppData\Local\CrashDumps\* | remove-item -Force -recurse -ErrorAction SilentlyContinue
Get-ChildItem C:\Users\*\AppData\Local\Microsoft\Windows\WER* | remove-item -Force -recurse -ErrorAction SilentlyContinue


# Check disk space after cleanup
$DiskAfter = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'" | Select-Object Size,FreeSpace
$RoundedAfter = [Math]::Round($DiskAfter.Freespace / 1GB)
"$(TimeStamp) INFO: $ComputerName has $RoundedAfter GB free on C: after running the cleanup" | Out-File -Append $LogFile
Write-Host "$ComputerName has $RoundedAfter gb free after running the cleanup" -ForegroundColor Yellow 

"$(TimeStamp) INFO: Script finished!" | Out-File -Append $LogFile