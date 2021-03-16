<#
.SYNOPSIS 
        Download and import IPU Installer solution by Johan Schrewelius.


.DESCRIPTION
    The script will do the following:
        - Download and extract the zip-file https://onevinn.schrewelius.it/Files/IPUInstaller/IPUInstaller.zip
        - Import IPU Application, Deployment Scheduler to ConfigMgr
        - Create collection folder
        - Create collections (Windows 10 Build < 20H2, IPU Windows 10 20H2 x64, IPU Success, IPU Failed, IPU Pending Reboot)
        - Create and deploy new client setting (HW-inventory schedule, Powershell executionpolicy ByPass) 
        - Deploy IPU App to IPU Collection
        - Deploy Deployment Scheduler to IPU Collection
        - Create Maintenance Window for IPU Collection
        - Import ".\IPUInstaller\ConsoleScript\Reset_IPU_Status.ps1" script to the console
    
    IMPORTANT, this script will not edit your Configuration.mof or import SMS.mof automatically. You will have to do this step manually!
    The script will check if your ConfigMgr's hardware inventory is capable of collecting the information needed according to the documentation for IPU Installer.
    If not, the script will exit and tell you to do the edit and import of .mof. Run the script again after you're done with this step and it will take care of the rest!

    
    

.NOTES
    FileName:    IPUInstallerAutomated.ps1
	Author:      Andreas Wikström / Gary Blok
    Contact:     @andreaswkstrm / @gwblok
    Created:     2021-03-13
    Updated:     2021-03-16
    Version:     1.0.1

Version history:
1.0.1 - (2021-03-16) - Borrowed/stole some of Gary's codea. Added import and deployment of "Deployment Scheduler" app.
1.0.0 - (2021-03-13) - Script created
   
#>






# Function for importing Powershell-script to CM-console
<#

.SYNOPSIS
    Creates a script in CM Console. Originally written by Ken Wygant - https://pfe.tips/import-powershell-scripts-into-configuration-manager/
    Filename: NewScriptFunction.ps1
.NOTES
    Version: 1.0
    Author: Ken Wygant
    Purpose/Change: Initial script development
#>




function convert-texttobase64{
    param([Parameter(Position = 0, Mandatory = $true, ValuefromPipeline = $true)][string]$rawtext)
    $1  = [System.Text.Encoding]::UTF8.GetBytes($rawtext)
    [System.Convert]::ToBase64String($1)
}


function New-CMPowershellScript{
param(
    [Parameter(Mandatory = $true)][string]$ScriptName,
    [Parameter()][string]$comment,
    [Parameter(Mandatory = $true)][string]$Script
)
$systemvar = @("Verbose","Debug","WarningAction","ErrorAction","InformationAction","ErrorVariable","WarningVariable","InformationVariable","OutVariable","OutBuffer","PipelineVariable")

$tempscriptpath = "$($env:TEMP)\temp.ps1"
$script | out-file $tempscriptpath
$ParameterList = ((Get-Command -name $tempscriptpath).Parameters).Values | ?{$_.Name -notin $systemvar}
Remove-Item $tempscriptpath -Force

if($ParameterList.count -gt 0){
    [xml]$Doc = New-Object System.Xml.XmlDocument

    #create declaration
    $dec = $Doc.CreateXmlDeclaration("1.0","utf-16",$null)
    #append to document
    $doc.AppendChild($dec) | Out-Null

    $root = $doc.CreateNode("element","ScriptParameters",$null)
    $root.SetAttribute("SchemaVersion",1) | Out-Null

    ForEach($Parameter in $ParameterList){
        [string]$IsRequired=$Parameter.Attributes.Mandatory
        [string]$IsHidden=$Parameter.Attributes.DontShow
        [string]$description=$Parameter.Attributes.HelpMessage
        
        $P = $doc.CreateNode("element","ScriptParameter",$null)
        $P.SetAttribute("Name",$Parameter.Name) | Out-Null
        $P.SetAttribute("FriendlyName",$Parameter.Name) | Out-Null
        $P.SetAttribute("Type",$Parameter.ParameterType.FullName) | Out-Null
        $P.SetAttribute("Description",$description) | Out-Null
        $P.SetAttribute("IsRequired",$IsRequired.ToLower()) | Out-Null
        $P.SetAttribute("IsHidden",$IsHidden.ToLower()) | Out-Null

        if($Parameter.Attributes.ValidValues){
            $Values = $doc.CreateElement("Values")
            ForEach($value in $Parameter.Attributes.ValidValues){
                $V = $doc.CreateElement("Value")
                $V.InnerText = $value | Out-Null
                $Values.AppendChild($v)
            }
            $p.AppendChild($values)

        }

        $root.AppendChild($P) | Out-Null
    }

    $doc.AppendChild($root) | Out-Null

    $tempfile = "$($env:TEMP)\paramtemp.xml"
    $doc.save($tempfile)
    [String]$params = Get-Content -Path $tempfile -Raw
    Remove-Item $tempfile -Force

}

if($null -eq (Get-Module ConfigurationManager)) {Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"}
$psdrive = Get-PSDrive -PSProvider CMSite

if($psdrive){
    $sitecode = $psdrive.SiteCode

    [string]$Script64 = convert-texttobase64 $Script
    if($Params){[string]$Params64 = convert-texttobase64 $Params}

    $NewGUID = ([guid]::NewGuid()).GUID
    $Arguments = @{
        ScriptGUID = $NewGUID;
        ScriptVersion = [string]'1';
        ScriptName = $ScriptName;
        Author = "$($env:userdomain)\$($env:username)";
        ScriptType = [uINT32]0;
        ApprovalState = [uINT32]0;
        Approver = $null;
        Comment = $null;
        ParamsDefinition = $Params64;
        ParameterlistXML = $null;
        Script = $Script64
    };


    Invoke-CimMethod -Namespace "root\SMS\site_$($sitecode)" -ClassName SMS_Scripts -MethodName CreateScripts -Arguments $Arguments
}
else{write-error "No CM provider loaded"}
}

# Variables for app creation
$SourceServer = "\\sccm01.domain.com\source$" # UNC path to source share
$Release = "20H2" #Used for Collection Names & App Names

# IPU App
$IPUAppName = "Windows 10 $Release Upgrade"
$IPUAppSourceLocation = "$SourceServer\Applications\IPUApplication\$Release\" #This will be the App Source on your Server
$IPUAppImageIconURL = "https://upload.wikimedia.org/wikipedia/commons/0/08/Windows_logo_-_2012_%28dark_blue%29.png"
$IPUAppDownloadURL = "https://onevinn.schrewelius.it/Files/IPUInstaller/IPUInstaller.zip"
$IPUAppExtractPath = "$SourceServer\Applications\Onevinn\IPUApplicationExtract" #Where you want to keep the extracted Source (NOT THE APP ITSELF)
$UpgradeMediaPath = "$SourceServer\OSD\OS Upgrade Packages\Windows 10 Enterprise x64 2009 19042.804"  #Where you keep your Upgrade Media currently
$DeadlineDateTime = '12/25/2021 20:00:00' # Last day the user can schedule an upgrade on.



# Variables for collections and client setting
$SiteCode = (Get-WMIObject -ComputerName "$ENV:COMPUTERNAME" -Namespace "root\SMS" -Class "SMS_ProviderLocation").SiteCode
$LimitingCollection = 'All Systems'
$RefreshType = 'Continuous'
$CollectionFolder = 'OSD Upgrade IPU Installer' # This folder will be created if it doesn't exist and then the IPU collections will be placed here.
$CollectionLessThan20H2 = 'Windows 10 Build < 20H2' # This collection will collect all computers with anything less than 20H2 installed.
$CollectionIPUFailed = 'IPU Failed' # This is the collection that will collect the computers that have failed the IPU.
$CollectionIPUPendingReboot = 'IPU Pending Reboot' # This collection will contain all computers with a pending reboot.
$CollectionIPUSuccess = 'IPU Success' # This collection will contain all computers that have successfully been upgraded.
$CollectionIPUDeployment = 'IPU Windows 10 20H2 x64' # This is where you put the computers that you want to upgrade.
$ClientSettingName = 'IPU Policy'

$DetectionMethod = {

$BuildNumber = "19042"

$statusOk = $false

try {
    $statusOk = (Get-ItemProperty -Path HKLM:\SOFTWARE\Onevinn\IPUStatus -Name 'IPURestartPending' -ErrorAction Stop).IPURestartPending -eq "True"
}
catch {}

if ($statusOk) {
    Set-ItemProperty -Path HKLM:\SOFTWARE\Onevinn\IPUStatus -Name 'IPURestartPending' -Value "False" -Force | Out-Null
}
else {
    $statusOk = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name 'CurrentBuild').CurrentBuild -eq $BuildNumber
}

if ($statusOk) {
    Write-Output "Installed"
}
}


#Test Extract Path
Write-Host "Starting Build of Onevinn IPUApplication Build" -ForegroundColor Yellow
Set-Location -Path "c:\"
if (!(Test-Path $IPUAppExtractPath))
{
Write-Host "Creating Folder $IPUAppExtractPath" -ForegroundColor Green
$NewFolder = New-Item -Path $IPUAppExtractPath -ItemType directory -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Write-Host " Downloading Requirements from Internet" -ForegroundColor Green
#Download IPUApplication from OneVinn
Invoke-WebRequest -Uri $IPUAppDownloadURL -UseBasicParsing -OutFile "$env:TEMP\IPUApp.zip"
#Download Icon for Application in Software Center
Invoke-WebRequest -Uri $IPUAppImageIconURL -OutFile "$IPUAppExtractPath\AppIcon.png"
Unblock-File "$env:TEMP\IPUApp.zip"
Write-Host " Extract Download" -ForegroundColor Green
Expand-Archive -Path "$env:TEMP\IPUApp.zip" -DestinationPath $IPUAppExtractPath
}

# Deployment Scheduler App
$DSAppName = Get-ChildItem -Path $IPUAppExtractPath | Where-Object -Property Name -like "*DeploymentScheduler*" | Select-Object Name
$DSAppSourceLocation = "$SourceServer\Applications\$($DSAppName.Name)"
$DSAppVersionRaw = "$($DSAppName.Name)"
$DSAppVersionSplit=$DSAppVersionRaw.Split(" ")
$DSAppVersionNumber = $DSAppVersionSplit[1]


# Find MSI Product Code of Deployment Scheduler App
$path = "$IPUAppExtractPath\$($DSAppName.Name)\$($DSAppName.Name).msi"

$comObjWI = New-Object -ComObject WindowsInstaller.Installer
$MSIDatabase = $comObjWI.GetType().InvokeMember("OpenDatabase","InvokeMethod",$Null,$comObjWI,@($Path,0))
$Query = "SELECT Value FROM Property WHERE Property = 'ProductCode'"
$View = $MSIDatabase.GetType().InvokeMember("OpenView","InvokeMethod",$null,$MSIDatabase,($Query))
$View.GetType().InvokeMember("Execute", "InvokeMethod", $null, $View, $null)
$Record = $View.GetType().InvokeMember("Fetch","InvokeMethod",$null,$View,$null)
$DSAppProductCode = $Record.GetType().InvokeMember("StringData","GetProperty",$null,$Record,1)




# Import CM-module
try {
Write-Host "Importing SCCM PS Module" -ForegroundColor Yellow
Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
Write-Host "Setting location to $SiteCode" -ForegroundColor Yellow
Set-Location "$($SiteCode):"
}
catch {
$_
}

#Create IPU App
if (Get-CMApplication -Fast -Name $IPUAppName)
{
Write-Host "Application: $IPUAppName already exist" -ForegroundColor Green
}
else
{
Write-Host "Creating Application: $IPUAppName" -ForegroundColor Green
$NewIPUApp = New-CMApplication -Name $IPUAppName -Publisher "Onevinn" -LocalizedName $IPUAppName -LocalizedDescription "Upgrades PC to $Release.  There will be several reboots, but you will be prompted.  It is still recommended you save your work before installing."
if (!($IPUAppUserCat = Get-CMCategory -Name "IPUApplication" -CategoryType CatalogCategories))
    {
    $IPUAppUserCat = New-CMCategory -CategoryType CatalogCategories -Name "IPUApplication"
    }
Set-CMApplication -InputObject $NewIPUApp -AddUserCategory $IPUAppUserCat
Set-CMApplication -InputObject $NewIPUApp -SoftwareVersion $Release
Write-Host " Completed" -ForegroundColor Gray
 #Set Icon for Software Center
Set-Location "$($SiteCode):\"
Set-CMApplication -InputObject $NewIPUApp -IconLocationFile $IPUAppExtractPath\AppIcon.png
Write-Host " Set App SC Icon on: $IPUAppName" -ForegroundColor Green
}


#Create IPU AppDT Base
Set-Location -Path "C:"
if (Test-Path $IPUAppSourceLocation){}
else 
    {               
    Write-host " Creating Source Folder Structure: $IPUAppSourceLocation" -ForegroundColor Green
    $NewFolder = New-Item -Path $IPUAppSourceLocation -ItemType directory -ErrorAction SilentlyContinue      
    Write-Host " Starting Copy of Content, App & Media" -ForegroundColor Green
    Copy-Item -Path "$IPUAppExtractPath\IPUApplication\*" -Destination $IPUAppSourceLocation -Recurse -Force
    Copy-Item -Path "$UpgradeMediaPath\*" -Destination "$IPUAppSourceLocation\Media" -Recurse -Force
    }
Set-Location -Path "$($SiteCode):"
if (Get-CMDeploymentType -ApplicationName $IPUAppName -DeploymentTypeName $IPUAppName)
    {
    Write-Host " AppDT already Created" -ForegroundColor Green
    }
else
    {
    Write-Host " Starting AppDT Creation" -ForegroundColor Green
    $NewIPUAppDT = Add-CMScriptDeploymentType -ApplicationName $IPUAppName -DeploymentTypeName $IPUAppName -ContentLocation $IPUAppSourceLocation -InstallCommand "IPUInstaller.exe" -InstallationBehaviorType InstallForSystem -Force32Bit:$true -EstimatedRuntimeMins "60" -MaximumRuntimeMins "120" -ScriptLanguage PowerShell -ScriptText $DetectionMethod
    Write-Host "  Created AppDT: $IPUAppName" -ForegroundColor Green
    #Distribute Content
    Get-CMDistributionPointGroup | foreach { Start-CMContentDistribution -ApplicationName $IPUAppName -DistributionPointGroupName $_.Name}
    }


#Create DS App
if (Get-CMApplication -Fast -Name "$($DSAppName.Name)")
{
Write-Host "Application: "$($DSAppName.Name)" already exist" -ForegroundColor Green
}
else
{
Write-Host "Creating Application: "$($DSAppName.Name)"" -ForegroundColor Green
$NewDSApp = New-CMApplication -Name "$($DSAppName.Name)" -Publisher "Onevinn" -LocalizedName "$($DSAppName.Name)"
Set-CMApplication -InputObject $NewDSApp -SoftwareVersion $Release
Write-Host " Completed" -ForegroundColor Gray
 #Set Icon for Software Center
Set-Location "$($SiteCode):\"
}


#Create ds AppDT Base
Set-Location -Path "C:"
if (Test-Path $DSAppSourceLocation){}
else 
    {               
    Write-host " Creating Source Folder Structure: $DSAppSourceLocation" -ForegroundColor Green
    $NewFolder = New-Item -Path $DSAppSourceLocation -ItemType directory -ErrorAction SilentlyContinue      
    Write-Host " Starting Copy of Content" -ForegroundColor Green
    Copy-Item -Path "$IPUAppExtractPath\$($DSAppName.Name)\$($DSAppName.Name).msi" -Destination $DSAppSourceLocation -Recurse -Force
    }
Set-Location -Path "$($SiteCode):"
if (Get-CMDeploymentType -ApplicationName $($DSAppName.Name) -DeploymentTypeName $($DSAppName.Name))
    {
    Write-Host " AppDT already Created" -ForegroundColor Green
    }
else
    {
    Write-Host " Starting AppDT Creation" -ForegroundColor Green
    $DSAppDetectionMethod = New-CMDetectionClauseWindowsInstaller -ProductCode $DSAppProductCode -Value -ExpressionOperator GreaterEquals -ExpectedValue "$DSAppVersionNumber"
    $NewDSAppDT = Add-CMMsiDeploymentType -ApplicationName $($DSAppName.Name) -DeploymentTypeName $($DSAppName.Name) -ContentLocation "$DSAppSourceLocation\$($DSAppName.Name).msi" -InstallCommand "msiexec /i $($DSAppName.Name).msi /qn" -InstallationBehaviorType InstallForSystem -Force32Bit:$true -EstimatedRuntimeMins "15" -MaximumRuntimeMins "30" -AddDetectionClause $DSAppDetectionMethod
    #$NewDSAppDT = Add-CMScriptDeploymentType -ApplicationName $DSAppName -DeploymentTypeName $DSAppName -ContentLocation $DSAppSourceLocation -InstallCommand "IPUInstaller.exe" -InstallationBehaviorType InstallForSystem -Force32Bit:$true -EstimatedRuntimeMins "60" -MaximumRuntimeMins "120" -ScriptLanguage PowerShell -ScriptText $DetectionMethod
    Write-Host "  Created AppDT: $($DSAppName.Name)" -ForegroundColor Green
    #Distribute Content
    Get-CMDistributionPointGroup | foreach { Start-CMContentDistribution -ApplicationName $($DSAppName.Name) -DistributionPointGroupName $_.Name}
    }


#Set Schedule to Evaluate Weekly (from the time you run the script)
$Schedule = New-CMSchedule -Start (Get-Date).DateTime -RecurInterval Days -RecurCount 7

#Create Test Collection and QUery, if Fails, Exit Script asking for Hardware Inv to be Extended
New-CMDeviceCollection -Name "TestHWInvQuery" -Comment "Used to test if Hardware Inv Settings have been added yet, See Section 7 in PDF Doc" -LimitingCollectionName "All Systems" -RefreshSchedule $Schedule -RefreshType 2 |Out-Null
$TestQuery = @" 
select
SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from
SMS_R_System inner join SMS_G_System_IpuResult on SMS_G_System_IpuResult.ResourceId = SMS_R_System.ResourceId where SMS_G_System_IpuResult.LastStatus = "Test"
"@
Add-CMDeviceCollectionQueryMembershipRule -RuleName "Query TestHWInvQuery" -CollectionName "TestHWInvQuery" -QueryExpression $TestQuery -ErrorAction SilentlyContinue | Out-Null
$TestQueryResult = Get-CMCollectionQueryMembershipRule -CollectionName "TestHWInvQuery"

if (!($TestQueryResult))
{
Remove-CMCollection -Name "TestHWInvQuery" -Force
Clear-Host
Write-Host "========================================================================================================================================================================" -ForegroundColor Cyan
Write-Host "Hardware Inv not setup properly to allow creation of query based collections, please read the docs, section 7, and finish the setup of the inventory, then re-run script" -ForegroundColor Yellow
Write-Host "========================================================================================================================================================================" -ForegroundColor Cyan

}
else
{
Write-Host "Hardware INV appears to be setup, continuing..." -ForegroundColor Green
Remove-CMCollection -Name "TestHWInvQuery" -Force
   
# Creating collections
Write-Host "Automatic creation of collections has been initiated. After the script has been successfully run, you will find your newly created collections under the $CollectionFolder folder." -ForegroundColor Green



# Create main collection
Write-Host "Creating collection $CollectionLessThan20H2" -ForegroundColor Yellow
$CollectionLessThan20H2Query = @"
select
SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from
SMS_R_System inner join SMS_G_System_OPERATING_SYSTEM on
SMS_G_System_OPERATING_SYSTEM.ResourceId = SMS_R_System.ResourceId where
SMS_G_System_OPERATING_SYSTEM.BuildNumber < "19042" and
SMS_G_System_OPERATING_SYSTEM.Caption = "Microsoft Windows 10 Enterprise"
"@
$CollId1 = (New-CMDeviceCollection -Name "$CollectionLessThan20H2" -LimitingCollectionName $LimitingCollection -RefreshType $RefreshType).CollectionID
Add-CMDeviceCollectionQueryMembershipRule -CollectionName "$CollectionLessThan20H2" -RuleName "$CollectionLessThan20H2" -QueryExpression $CollectionLessThan20H2Query

# Create IPUFailed collection
Write-Host "Creating collection $CollectionIPUFailed" -ForegroundColor Yellow
$CollectionIPUFailedQuery = @"
select
SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.
SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from
SMS_R_System inner join SMS_G_System_IpuResult on SMS_G_System_IpuResult.ResourceId = SMS_R_System.ResourceId where SMS_G_System_IpuResult.LastStatus = "Failed"
"@
$CollId2 = (New-CMDeviceCollection -Name "$CollectionIPUFailed" -LimitingCollectionName $LimitingCollection -RefreshType $RefreshType).CollectionID
Add-CMDeviceCollectionQueryMembershipRule -CollectionName "$CollectionIPUFailed" -RuleName "$CollectionIPUFailed" -QueryExpression $CollectionIPUFailedQuery

# Create IPUPendingReboot collection
Write-Host "Creating collection $CollectionIPUPendingReboot" -ForegroundColor Yellow
$CollectionIPUPendingRebootQuery = @"
select
SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from
SMS_R_System inner join SMS_G_System_IpuResult on SMS_G_System_IpuResult.ResourceId = SMS_R_System.ResourceId where SMS_G_System_IpuResult.LastStatus = "PendingReboot"
"@
$CollId3 = (New-CMDeviceCollection -Name "$CollectionIPUPendingReboot" -LimitingCollectionName $LimitingCollection -RefreshType $RefreshType).CollectionID
Add-CMDeviceCollectionQueryMembershipRule -CollectionName "$CollectionIPUPendingReboot" -RuleName "$CollectionIPUPendingReboot" -QueryExpression $CollectionIPUPendingRebootQuery

# Create CollectionIPUSuccess collection
Write-Host "Creating collection $CollectionIPUSuccess" -ForegroundColor Yellow
$CollectionIPUSuccessQuery = @"
select
SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from
SMS_R_System inner join SMS_G_System_IpuResult on SMS_G_System_IpuResult.ResourceId = SMS_R_System.ResourceId where SMS_G_System_IpuResult.LastStatus = "Success"
"@
$CollId4 = (New-CMDeviceCollection -Name "$CollectionIPUSuccess" -LimitingCollectionName $LimitingCollection -RefreshType $RefreshType).CollectionID
Add-CMDeviceCollectionQueryMembershipRule -CollectionName "$CollectionIPUSuccess" -RuleName "$CollectionIPUSuccess" -QueryExpression $CollectionIPUSuccessQuery

# Create CollectionIPUDeployment collection
Write-Host "Creating collection $CollectionIPUDeployment" -ForegroundColor Yellow
$CollId5 = (New-CMDeviceCollection -Name "$CollectionIPUDeployment" -LimitingCollectionName $CollectionLessThan20H2 -RefreshType $RefreshType).Collectionid
Write-Host "Adding exclude rule for $CollectionIPUFailed to $CollectionIPUDeployment" -ForegroundColor Yellow
Add-CMDeviceCollectionExcludeMembershipRule -CollectionName $CollectionIPUDeployment -ExcludeCollectionName "$CollectionIPUFailed"
Write-Host "Adding exclude rule for $CollectionIPUPendingReboot to $CollectionIPUDeployment" -ForegroundColor Yellow
Add-CMDeviceCollectionExcludeMembershipRule -CollectionName $CollectionIPUDeployment -ExcludeCollectionName "$CollectionIPUPendingReboot"
Write-Host "Adding exclude rule for $CollectionIPUSuccess to $CollectionIPUDeployment" -ForegroundColor Yellow
Add-CMDeviceCollectionExcludeMembershipRule -CollectionName $CollectionIPUDeployment -ExcludeCollectionName "$CollectionIPUSuccess"
$CollectionIPUDeployment = Get-CMCollection -Name $CollectionIPUDeployment

# Create Collection Folder if it doesn't exists
Set-Location \
Set-Location .\DeviceCollection
If (-not (Test-Path -Path (".\$CollectionFolder"))) {
Write-Host "Device collection folder $CollectionFolder was not found. Creating folder" -ForegroundColor Green    
New-item -Name "$CollectionFolder" | Out-Null
}
elseif (Test-Path -Path (".\$CollectionFolder"))
{
Write-host "Device collection folder name $CollectionFolder already exists. Moving collections to this folder." -ForegroundColor Yellow
$CollectionFolder = ".\$CollectionFolder"
}    



# Move collections to $CollectionFolder    

$CMCol1 = Get-CMDeviceCollection -Id $CollId1
$CMCol2 = Get-CMDeviceCollection -Id $CollId2
$CMCol3 = Get-CMDeviceCollection -Id $CollId3
$CMCol4 = Get-CMDeviceCollection -Id $CollId4
$CMCol5 = Get-CMDeviceCollection -Id $CollId5


Write-Host 'Moving collection' $($CMCol1).Name -ForegroundColor Yellow
Move-CMObject -FolderPath "$CollectionFolder" -InputObject $CMCol1 | Out-Null
Write-Host 'Moving collection' $($CMCol2).Name -ForegroundColor Yellow
Move-CMObject -FolderPath "$CollectionFolder" -InputObject $CMCol2 | Out-Null
Write-Host 'Moving collection' $($CMCol3).Name -ForegroundColor Yellow
Move-CMObject -FolderPath "$CollectionFolder" -InputObject $CMCol3 | Out-Null
Write-Host 'Moving collection' $($CMCol4).Name -ForegroundColor Yellow
Move-CMObject -FolderPath "$CollectionFolder" -InputObject $CMCol4 | Out-Null
Write-Host 'Moving collection' $($CMCol5).Name -ForegroundColor Yellow
Move-CMObject -FolderPath "$CollectionFolder" -InputObject $CMCol5 | Out-Null
}





#region ScriptBody - Create and deploy new client setting, Deploy App to IPU Collection, create Maintenance Window, import script to console

if ($TestQueryResult)
{
# Creating client setting to be able to run hardware inventory on the IPU collections
Write-Host 'Creating Custom Client Setting named:' $ClientSettingName -ForegroundColor Yellow
$HWInvSched = New-CMSchedule -RecurCount '30' -RecurInterval 'Minutes' # This is the schedule for the hardware inventory cycle in the custom client setting that we're creating
New-CMClientSetting -Name "$ClientSettingName" -Description "IPU Deployment - Increased HW-inventory cycle and PowerShell -ByPass" -Type 1 | Out-Null
Set-CMClientSettingHardwareInventory -Name "$ClientSettingName" -MaxRandomDelayMins '5' -Schedule $HWInvSched -Enable $True
Set-CMClientSettingComputerAgent -Name "$ClientSettingName" -PowerShellExecutionPolicy Bypass

# Deploy client setting to IPUPendingReboot and IPU Windows 10 20H2 x64 collections
Write-Host 'Deploying:' $($ClientSettingName) 'to collection:' $($CollectionIPUPendingReboot) -ForegroundColor Yellow
Start-CMClientSettingDeployment -ClientSettingName $ClientSettingName -CollectionName "$CollectionIPUPendingReboot"
Write-Host 'Deploying:' $($ClientSettingName) 'to collection:' "$($CollectionIPUDeployment.Name)" -ForegroundColor Yellow
Start-CMClientSettingDeployment -ClientSettingName $ClientSettingName -CollectionName "$($CollectionIPUDeployment.Name)"
Write-Host "Deployming apps & Maintenance Window" -ForegroundColor Magenta
write-Host " Creating Deployment for $IPUAppName to Collection $($CollectionIPUDeployment.name)" -ForegroundColor Green
$IPUAppDeployment = New-CMApplicationDeployment -Name $IPUAppName -CollectionId $CollectionIPUDeployment.CollectionID -DeployAction Install -DeployPurpose Required -UserNotification DisplayAll -DeadlineDateTime $DeadlineDateTime
$DSAppDeployment = New-CMApplicationDeployment -Name $($DSAppName.Name) -CollectionId $CollectionIPUDeployment.CollectionID -DeployAction Install -DeployPurpose Required -UserNotification DisplayAll 
# Example - Every Monday @ 8PM for 8 Hours
#$MWSchedule = New-CMSchedule -DayOfWeek Monday -DurationCount 8 -DurationInterval Hours -RecurCount 1 -Start "10/12/2013 20:00:00"
# Set to Daily @ 8PM for 8 hours
write-host " Creating MW for $($CollectionIPUDeployment.name) that runs daily @ 8PM" -ForegroundColor Green
$MWSchedule = New-CMSchedule -DurationCount 8 -DurationInterval Hours -RecurCount 1 -Start "10/12/2013 20:00:00" -RecurInterval Days
$DeploymentMW = New-CMMaintenanceWindow  -CollectionId $CollectionIPUDeployment.CollectionID -IsEnabled:$true -Schedule $MWSchedule -Name "Windows Upgrades"
}




# Create the script in CM console

$Script = {$IpuResultPath = "HKLM:\SOFTWARE\Onevinn\IpuResult"
New-ItemProperty -Path $IpuResultPath -Name 'LastStatus' -Value "Unknown" -Force -EA SilentlyContinue | Out-Null
Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000001}" | Out-Null
$folderPath = "$($env:SystemDrive)\`$WINDOWS.~BT"
if (Test-Path -Path "$folderPath") {
Remove-Item -Path "$folderPath" -Force -EA SilentlyContinue | Out-Null
}
}

Write-Host 'Importing console script: .\ConsoleScript\Reset_IPU_Status.ps1' -ForegroundColor Yellow
$CreateScript = New-CMPowershellScript -ScriptName "IPU Reset" -Script $Script
Write-Host "Import complete. Don't forget to approve it!" -ForegroundColor Green





Write-Host 'Setting location back to local disk' -ForegroundColor Yellow
Set-Location C:

Write-Host 'Script execution complete. Exiting.' -ForegroundColor Green
