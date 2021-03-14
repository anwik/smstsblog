<#
.SYNOPSIS
    Creates collections to be used with IPU Installer from Onevinn AB - https://onevinn.schrewelius.it/index.html
    Change the variables on rows 19-24 to suite your needs. If you don't change them you will get the same naming standard as Johan describes in the documentation.
    Filename: CreateIPUInstallerCollections.ps1
.NOTES
    Version: 1.0
    Author: Andreas Wikström
    Mail: andreas.wikstrom@atea.se
    Twitter: @andreaswkstrm
    Creation Date: 13/3/2021
    Purpose/Change: Initial script development
#>
$PathToScript = Switch ($Host.name){
    'Visual Studio Code Host' { split-path $psEditor.GetEditorContext().CurrentFile.Path }
    'Windows PowerShell ISE Host' {  Split-Path -Path $psISE.CurrentFile.FullPath }
    'ConsoleHost' { $PSScriptRoot }
}
Set-Location $PathToScript
.\NewScriptFunction.ps1
Set-location C:


# Variables
$SiteCode = (Get-WMIObject -ComputerName "$ENV:COMPUTERNAME" -Namespace "root\SMS" -Class "SMS_ProviderLocation").SiteCode
$LimitingCollection = 'All Systems'
$RefreshType = 'Continuous'
$CollectionFolder = 'OSD Upgrade IPU Installer' # This folder will be created if not exists and then the IPU collections will be placed here.
$CollectionMain = 'Windows 10 Build < 20H2' # This is the main collection that will have the required deployment for the upgrade application. Change the name to suite your needs.
$CollectionIPUFailed = 'IPU Failed' # This is the collection that will collect the computers that have failed the IPU.
$CollectionIPUPendingReboot = 'IPU Pending Reboot' # This collection will contain all computers with a pending reboot.
$CollectionIPUSuccess = 'IPU Success' # This collection will contain all computers that have successfully been upgraded.
$CollectionWin1020H2Completed = 'IPU Windows 10 20H2 x64' # This collection will contain all computers that have been successfully upgraded.
$ClientSettingName = 'IPU Policy'

Write-Host "Automatic creation of collections has been initiated. After the script has been successfully run, you will find your newly created collections under the $CollectionFolder folder." -ForegroundColor Green

try {
Write-Host "Importing SCCM PS Module" -ForegroundColor Yellow
Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
Write-Host "SCCM PS Module imported" -ForegroundColor Green
Write-Host "Setting location to $SiteCode" -ForegroundColor Yellow
Set-Location "$($SiteCode):"
Write-Host "Location successfully set" -ForegroundColor Green

# Create main collection
    Write-Host "Creating collection $CollectionMain" -ForegroundColor Yellow
    $CollId1 = (New-CMDeviceCollection -Name "$CollectionMain" -LimitingCollectionName $LimitingCollection -RefreshType $RefreshType).CollectionID
    Add-CMDeviceCollectionQueryMembershipRule -CollectionName "$CollectionMain" -RuleName "$CollectionMain" -QueryExpression 'select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_OPERATING_SYSTEM on SMS_G_System_OPERATING_SYSTEM.ResourceId = SMS_R_System.ResourceId where SMS_G_System_OPERATING_SYSTEM.BuildNumber < "19042" and SMS_G_System_OPERATING_SYSTEM.Caption = "Microsoft Windows 10 Enterprise"'
    Write-Host "Collection created successfully" -ForegroundColor Green

# Create IPUFailed collection
    Write-Host "Creating collection $CollectionIPUFailed" -ForegroundColor Yellow
    $CollId2 = (New-CMDeviceCollection -Name "$CollectionIPUFailed" -LimitingCollectionName $LimitingCollection -RefreshType $RefreshType).CollectionID
    Add-CMDeviceCollectionQueryMembershipRule -CollectionName "$CollectionIPUFailed" -RuleName "$CollectionIPUFailed" -QueryExpression 'select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_IpuResult on SMS_G_System_IpuResult.ResourceId = SMS_R_System.ResourceId where SMS_G_System_IpuResult.LastStatus = "Failure"'
    Write-Host "Collection created successfully" -ForegroundColor Green

# Create IPUPendingReboot collection
    Write-Host "Creating collection $CollectionIPUPendingReboot" -ForegroundColor Yellow
    $CollId3 = (New-CMDeviceCollection -Name "$CollectionIPUPendingReboot" -LimitingCollectionName $LimitingCollection -RefreshType $RefreshType).CollectionID
    Add-CMDeviceCollectionQueryMembershipRule -CollectionName "$CollectionIPUPendingReboot" -RuleName "$CollectionIPUPendingReboot" -QueryExpression 'select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_IpuResult on SMS_G_System_IpuResult.ResourceId = SMS_R_System.ResourceId where SMS_G_System_IpuResult.LastStatus = "PendingReboot"'
    Write-Host "Collection created successfully" -ForegroundColor Green

# Create CollectionIPUSuccess collection
    Write-Host "Creating collection $CollectionIPUSuccess" -ForegroundColor Yellow
    $CollId4 = (New-CMDeviceCollection -Name "$CollectionIPUSuccess" -LimitingCollectionName $LimitingCollection -RefreshType $RefreshType).CollectionID
    Add-CMDeviceCollectionQueryMembershipRule -CollectionName "$CollectionIPUSuccess" -RuleName "$CollectionIPUSuccess" -QueryExpression 'select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_IpuResult on SMS_G_System_IpuResult.ResourceId = SMS_R_System.ResourceId where SMS_G_System_IpuResult.LastStatus = "Success"'
    Write-Host "Collection created successfully" -ForegroundColor Green

# Create CollectionWin1020H2Completed collection
    Write-Host "Creating collection $CollectionWin1020H2Completed" -ForegroundColor Yellow
    $CollId5 = (New-CMDeviceCollection -Name "$CollectionWin1020H2Completed" -LimitingCollectionName $CollectionMain -RefreshType $RefreshType).Collectionid
    Write-Host "Adding exclude rule for $CollectionIPUFailed to $CollectionWin1020H2Completed" -ForegroundColor Yellow
    Add-CMDeviceCollectionExcludeMembershipRule -CollectionName $CollectionWin1020H2Completed -ExcludeCollectionName "$CollectionIPUFailed"
    Write-Host "Adding exclude rule for $CollectionIPUPendingReboot to $CollectionWin1020H2Completed" -ForegroundColor Yellow
    Add-CMDeviceCollectionExcludeMembershipRule -CollectionName $CollectionWin1020H2Completed -ExcludeCollectionName "$CollectionIPUPendingReboot"
    Write-Host "Adding exclude rule for $CollectionIPUSuccess to $CollectionWin1020H2Completed" -ForegroundColor Yellow
    Add-CMDeviceCollectionExcludeMembershipRule -CollectionName $CollectionWin1020H2Completed -ExcludeCollectionName "$CollectionIPUSuccess"
    Write-Host "Exclude rules added successully" -ForegroundColor Green

# Moving collections to the correct folder
    Set-Location \
    Set-Location .\DeviceCollection
    Write-Host "Creating Collection folder $CollectionFolder" -ForegroundColor Green
    New-item -Name "$CollectionFolder" -ErrorAction SilentlyContinue | Out-Null
    $CMCol1 = Get-CMDeviceCollection -Id $CollId1
    $CMCol2 = Get-CMDeviceCollection -Id $CollId2
    $CMCol3 = Get-CMDeviceCollection -Id $CollId3
    $CMCol4 = Get-CMDeviceCollection -Id $CollId4
    $CMCol5 = Get-CMDeviceCollection -Id $CollId5

    
    Write-Host 'Moving collection' $($CMCol1).Name -ForegroundColor Yellow
    Move-CMObject -FolderPath ".\$CollectionFolder" -InputObject $CMCol1 | Out-Null
    Write-Host "Done" -ForegroundColor Green
    Write-Host 'Moving collection' $($CMCol2).Name -ForegroundColor Yellow
    Move-CMObject -FolderPath ".\$CollectionFolder" -InputObject $CMCol2 | Out-Null
    Write-Host "Done" -ForegroundColor Green
    Write-Host 'Moving collection' $($CMCol3).Name -ForegroundColor Yellow
    Move-CMObject -FolderPath ".\$CollectionFolder" -InputObject $CMCol3 | Out-Null
    Write-Host "Done" -ForegroundColor Green
    Write-Host 'Moving collection' $($CMCol4).Name -ForegroundColor Yellow
    Move-CMObject -FolderPath ".\$CollectionFolder" -InputObject $CMCol4 | Out-Null
    Write-Host "Done" -ForegroundColor Green
    Write-Host 'Moving collection' $($CMCol5).Name -ForegroundColor Yellow
    Move-CMObject -FolderPath ".\$CollectionFolder" -InputObject $CMCol5 | Out-Null
    Write-Host "Done" -ForegroundColor Green


# Asking to import Configuration.mof file
 Write-Host "Now it's time to edit the configuration.mof file. For now you will have to do this manually. Press Y when you're ready to continue with the next step" -ForegroundColor Green
 $response = Read-Host 'Are you done, editing the configuration.mof file? [y/N]'
if ($response -ne 'y') {
    Write-Host 'Exiting script'
    return
}

# Creating client setting to be able to run hardware inventory on the IPU collections
    Write-Host 'Creating Custom Client Setting named:' $ClientSettingName -ForegroundColor Yellow
    $HWInvSched = New-CMSchedule -RecurCount '30' -RecurInterval 'Minutes' # This is the schedule for the hardware inventory cycle in the custom client setting that we're creating
    New-CMClientSetting -Name "$ClientSettingName" -Description "Hardware inventory settings for IPU Computers" -Type 1
    Set-CMClientSettingHardwareInventory -Name 'IPU Policy' -MaxRandomDelayMins '5' -Schedule $HWInvSched -Enable $True
    Write-Host 'Client Setting:' $($ClientSettingName) 'created' -ForegroundColor Green
# Deploy client setting to IPUPendingReboot and IPU Windows 10 20H2 x64 collections
    Write-Host 'Deploying:' $($ClientSettingName) 'to collection:' $($CollectionIPUPendingReboot) -ForegroundColor Yellow
    Start-CMClientSettingDeployment -ClientSettingName $ClientSettingName -CollectionName "$CollectionIPUPendingReboot"
    Write-Host 'Done' -ForegroundColor Green
    Write-Host 'Deploying:' $($ClientSettingName) 'to collection:' $($CollectionWin1020H2Completed) -ForegroundColor Yellow
    Start-CMClientSettingDeployment -ClientSettingName $ClientSettingName -CollectionName "$CollectionWin1020H2Completed"
    Write-Host 'Done' -ForegroundColor Green

# Create the script in CM console

$Script = {$IpuResultPath = "HKLM:\SOFTWARE\Onevinn\IpuResult"

New-ItemProperty -Path $IpuResultPath -Name 'LastStatus' -Value "Unknown" -Force -EA SilentlyContinue | Out-Null

Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000001}" | Out-Null

$folderPath = "$($env:SystemDrive)\`$WINDOWS.~BT"

if (Test-Path -Path "$folderPath") {
    Remove-Item -Path "$folderPath" -Force -EA SilentlyContinue | Out-Null
}
}
Write-Host 'Importing console script: Reset_IPU_Status.ps1' -ForegroundColor Yellow
$CreateScript = New-CMPowershellScript -ScriptName "IPU Reset" -Script $Script
Write-Host 'Done' -ForegroundColor Green





Write-Host "Setting location back to local disk" -ForegroundColor Yellow
Set-Location C:
}
catch {
    $_
}
Write-Host "Script execution complete :)" -ForegroundColor Green
