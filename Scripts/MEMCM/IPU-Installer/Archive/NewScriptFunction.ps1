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