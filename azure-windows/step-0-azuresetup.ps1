<# 
Author:         VGR
Date:           20180528
Script:         step-0-azuresetup.ps1
Version:        n/a 
Twitter:        @VGRSEC
#> 

#Check if Admin because installing powershell tools requires admin
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`

    [Security.Principal.WindowsBuiltInRole] "Administrator"))

{

    Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"

    Break

}

#Update Powershell and install Azure Tools

Write-Host "(Re)Install Azure Tools?" -ForegroundColor Yellow 
    $InstallAzureTools = Read-Host " ( y / n ) " 
    Switch ($InstallAzureTools) 
     { 
       Y {Install-Module PowerShellGet -force -confirm:$false;Install-Module -Name AzureRM -AllowClobber -force -confirm:$false} 
       N {Write-Host "No, Skip Installation"} 
       Default {Write-Host "No, Skip Installation"} 
     } 

#Log into Azure

Import-Module -Name AzureRM
Get-AzureRmContext
$SubscriptionId=(Get-AzureRmContext).SubscriptionId
Write-Host "Log into a different Azure Account?" -ForegroundColor Yellow
    $LoginAzureAccount = Read-Host " ( y / n ) " 
    Switch ($LoginAzureAccount) 
     { 
       Y {Login-AzureRmAccount;$SubscriptionId=(Get-AzureRmContext).SubscriptionId} 
       N {Write-Host "No, Skip Login"} 
       Default {Write-Host "No, Skip Login"} 
     } 

Get-AzureRMSubscription -SubscriptionId $SubscriptionId | Select-AzureRMSubscription >$null 2>&1

Write-Host "Starting..."
#Set region to deploy to and set variables

Get-AzureRMLocation | Where-Object {$_.Providers -eq "Microsoft.OperationalInsights"} | Format-Table -Property Location
$Location = Read-Host -Prompt 'Select a Location to deploy to from above list'
$ResourceGroup = "oms-visible-register"
#workspace names need to be unique - Get-Random helps with this for the example code
$WorkspaceName = "vr-log-analytics-" + (Get-Random -Maximum 99999999) 

#Remove the Resource Group if it exists
try {
    Remove-AzureRmResourceGroup -Name $ResourceGroup -Verbose -Force -ErrorAction Stop
    Write-Host "$ResourceGroup deleted"
} catch {
    Write-Host "$ResourceGroup doesn't exist"
}

#Create the Resource Group
try {
    New-AzureRmResourceGroup -Name $ResourceGroup -Location $Location -Verbose -ErrorAction Stop
} catch {
    Write-Host "$ResourceGroup couldn't be created"
    exit
}

# Remove the workspace
# Note to self, update documentation here: https://github.com/Azure/azure-powershell/blob/preview/src/ResourceManager/OperationalInsights/Commands.OperationalInsights/help/New-AzureRmOperationalInsightsWorkspace.md
# New-AzureRmOperationalInsightsWorkspace : Cannot validate argument on parameter 'Sku'. The argument "Basic" does not belong to the
# set "free,standard,premium,pernode,standalone" specified by the ValidateSet attribute. Supply an argument that is in the set and
# then try the command again. also note the aka documentation states pergb2018 is the sku but only standalone works 

try {
    Get-AzureRmOperationalInsightsWorkspace | Where-Object {$_.Name -like "vr-log-analytics-*"} | For-Each-Object ($_) {Remove-AzureRmOperationalInsightsWorkspace -Verbose -Force -Name $_.Name -ResourceGroupName $_.ResourceGroupName}    
} catch {
    Write-Host "Workspace doesn't exist"
}

# Create the workspace

try {
    New-AzureRmOperationalInsightsWorkspace -Location $Location -Name $WorkspaceName -ResourceGroupName $ResourceGroup -Sku standalone -Verbose
    }
catch {
    Write-Host "$WorkspaceName couldn't be created"
    exit
}

#Get the WorkspaceID and PrimarySharedKey. This is used 
#To install the agent on endpoints.

Write-Host "Setup Endpoint Installation Script"

$WorkspaceID=(Get-AzureRmOperationalInsightsWorkspace -ResourceGroupName $ResourceGroup -Name $WorkspaceName).CustomerId
$WorkspacePrimaryKey=(Get-AzureRmOperationalInsightsWorkspaceSharedKeys -ResourceGroupName $ResourceGroup -Name $WorkspaceName).PrimarySharedKey

#Setup the Endpoint Installation Script

try {
    Remove-Item ".\windows-installer\installer.ps1" -Force
}
catch {
    
}
Copy-Item ".\windows-installer\installer.ps1.orig" -Destination ".\windows-installer\installer.ps1"

(Get-Content .\windows-installer\installer.ps1).replace('WORKSPACEIDVAR', $WorkspaceID) | Set-Content .\windows-installer\installer.ps1

(Get-Content .\windows-installer\installer.ps1).replace('PRIMARYKEYVAR', $WorkspacePrimaryKey) | Set-Content .\windows-installer\installer.ps1

#Set up WorkSpace to record all AppLocker events

New-AzureRmOperationalInsightsWindowsEventDataSource -ResourceGroupName $ResourceGroup -WorkspaceName $WorkspaceName -EventLogName "Microsoft-Windows-AppLocker/EXE and DLL" -CollectErrors -CollectWarnings -CollectInformation -Name "Microsoft-Windows-AppLockerEXE-and-DLL"
New-AzureRmOperationalInsightsWindowsEventDataSource -ResourceGroupName $ResourceGroup -WorkspaceName $WorkspaceName -EventLogName "Microsoft-Windows-AppLocker/MSI and Script" -CollectErrors -CollectWarnings -CollectInformation -Name "Microsoft-Windows-AppLockerMSI-and-Script"
New-AzureRmOperationalInsightsWindowsEventDataSource -ResourceGroupName $ResourceGroup -WorkspaceName $WorkspaceName -EventLogName "Microsoft-Windows-AppLocker/Packaged app-Deployment" -CollectErrors -CollectWarnings -CollectInformation -Name "Microsoft-Windows-AppLockerPackaged-app-Deployment"
New-AzureRmOperationalInsightsWindowsEventDataSource -ResourceGroupName $ResourceGroup -WorkspaceName $WorkspaceName -EventLogName "Microsoft-Windows-AppLocker/Packaged app-Execution" -CollectErrors -CollectWarnings -CollectInformation -Name "Microsoft-Windows-AppLockerPackaged-app-Execution"

#Setup the PowerBI Query

Write-Host "Setup Power BI query for Step 1"

try {
    Remove-Item ".\azure-log-analytics\step-1-powerbi-query.txt" -Force
}
catch {
    
}
Copy-Item ".\azure-log-analytics\step-1-powerbi-query.txt.orig" -Destination ".\azure-log-analytics\step-1-powerbi-query.txt"

(Get-Content ".\azure-log-analytics\step-1-powerbi-query.txt").replace('WORKSPACEIDVAR', $WorkspaceID) | Set-Content ".\azure-log-analytics\step-1-powerbi-query.txt"
