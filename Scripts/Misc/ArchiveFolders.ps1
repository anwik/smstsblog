<#
.SYNOPSIS
    <Overview of the script>
    Filename: ArchiveFolders.ps1
.DESCRIPTION
    A fairly simple script that will move folders from one folder to another. This script assumes that the folder names are based on project numbers which it will
    read from an Excel spreadsheet (thanks to the amazing module ImportExcel). 
    Make sure that the variables are correctly configured and then just run the script. It will install the needed module automatically if you don't already have it
    and it will ask you before doing the actual move, just in case the folders found aren't the folders you want.
.NOTES
    Version: 1.0
    Author: Andreas Wikström
    Mail: andreas.wikstrom@atea.se
    Twitter: @andreaswkstrm
    Creation Date: 27/02/2021
    Purpose/Change: Initial script development
.EXAMPLE
    No example needed since the script doesn't have any parameters. Just do .\ArchiveFolders.ps1 :)
#>

# Variables

# Log directory
$Logfile = "C:\Scripts\ArchivedFolders.log"

# Root folder, where are the folders that you want to move?
$Root = 'C:\Project_Folder'

# Archive folder, where do you want to move the folders?
$Archive = 'C:\Archive_Folder'

# Checking for module Import-Excel
if (Get-Module -ListAvailable -Name "ImportExcel") {
    Write-Host "Module ImportExcel already installed, continuing..."
} 
else {
    try {
        Write-Host "Module ImportExcel not installed, trying to install it..."
        Install-Module -Name "ImportExcel" -AllowClobber -Confirm:$False -Force  
    }
    catch [Exception] {
        $_.message 
        exit
    }
}



# The Excel file which contains the list of folders that should be archived. Expecting 
$Projects = Import-Excel "C:\Temp\ProjectList.xlsx" | Select-Object PXID
# To check if there is any white space in the $Projects object you can do "$Projects[0].PSObject.Properties.Name | ForEach-Object { '"{0}"' -f $_ }"
# if you found white space you can use the below command to create the object without any white space:
# $Projects = Import-Excel "C:\Temp\ProjectList.xlsx" | Where-Object { -not [String]::IsNullOrWhiteSpace($_.PXID) }

# Start logging
Start-Transcript -Path $Logfile

# Read the spreadsheet and check the Root folder if it contains a folder with PXID in the folder name. If so, add the folder to the object $FoldersToBeMoved

        $FoldersToBeMoved = ForEach ($Project in $Projects) {
           Write-Host "Searching for $($Project.PXID)*"
           Get-ChildItem -Path $Root -Filter "$($Project.PXID)*"
            }
        $FoldersToBeMoved


 # Pause the script and present a list of the found folders including a count that will make it easier to see if everything is allright. Ask the user to continue or cancel.     
 Write-Host "Found "$FoldersToBeMoved.Count" folders that will be moved, continue?" -ForegroundColor Green
 $response = Read-Host 'Do you want to continue [y/N]'
if ($response -ne 'y') {
    Write-Host 'Exiting script'
    return
}

try
{
    $FoldersToBeMoved | Move-Item -Destination $Archive -ErrorAction Continue
}
catch
{
    $ErrorMessage = $_.Exception.Message
    
}

 Write-Host "Moved the following folders to $Archive" -ForegroundColor Green
($($FoldersToBeMoved) | Select-Object FullName)