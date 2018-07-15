# Windows

## Tools

  * Microsoft AppLocker
    * AppLocker is an application whitelisting service available from Windows 7/Server 2008 to Windows 10/Server 2016 (With  SKU restrictions.  https://docs.microsoft.com/en-us/windows/security/threat-protection/windows-defender-application-control/applocker/requirements-to-use-applocker#operating-system-requirements)
  * Microsoft Monitoring Agent (MMA)
    * MMA is an agent from Microsoft which is designed to ship logs from a Windows client to System Center Operations Manager (SCOM) and the Operations Management Suite/Azure Logs Analytics (OMS).
  * Azure Log Analytics
    * Azure Log Analytics provides log processing, metrics and reporting capabilities.  

## Step 0 - Setup

### Azure - Logging Infrastructure 
  * Run `step-0-azuresetup.ps1` to build the cloud infrastructure and configure the client install script.
    0. Asks for Azure Admin Credentials to function
    0. Asks what region to build endpoint monitoring environment
    0. Creates an Azure Resource group
    0. Creates an Azure WorkSpace within the previously created resource group
    0. Copies the client installer template `.\windows-installer\installer.ps1.orig`
    0. Records WorkSpaceID and WorkSpace Primary Key to the client installer `.\windows-installer\installer.ps1`
    0. Configures Azure Log Analytics to record all events related to AppLocker
    0. Creates the PowerBI query necessary to pull reports.

### Endpoint - Logging Client
  * Run `.\windows-installer\installer.ps1` to configure an device to log to the Azure Infrastructure setup in step 0
    0. Downloads MMA
    0. Installs and configures MMA

### Active Directory - GPO    
  * Create GPO and apply to all devices to be monitored. (Instructions here: https://docs.microsoft.com/en-us/windows/security/threat-protection/windows-defender-application-control/applocker/edit-an-applocker-policy#a-href-idbkmk-editapppolingpoaediting-an-applocker-policy-by-using-group-policy)
    0. Import `.\windows-applocker\step-1-policy.xml` which contains rules to deny all except Microsoft Windows signed executables and dlls.  
      * This rule set is set to allow all Microsoft signed certificates for: 
        * Executables
        * Installers
        * Scripts
        * DLLs
        ```
        Note:  While it's true there are many application whitelist bypasses involving Microsoft signed binaries this is designed as an initial audit policy.
        ```

## Step 1 - Monitor

The following will setup your monitoring environment for monitoring AppLocker across all devices configured in **Step 0**

  * Install PowerBI https://powerbi.microsoft.com/en-us/desktop/
  * Download .\azure-log-analytics\valiant-rampart-winazure-dashboards.pbix
  * On the **Home Tab** on the ribbon click `Edit Queries` which will launch the **Query Editor**
  * On the **Home Tab** on the ribbon click `Advanced Editor` 
  * Select all and delete existing query
  * Open .\azure-log-analytics\step-1-powerbi-query.txt and paste the content into the `Advanced Editor`
  * Click `Done`
  * On the **Home Tab** of the **Query Editor** ribbon click `Close and Apply`
  * The Step-1 Tab will show analytics for Both Allowed and Blocked certificates and applications.
  * Save `valiant-rampart-winazure-dashboards.pbix` to a location to be used in future steps.


## Step 2 - Audit

After a period of time has elapsed where monitored devices have performed all actions they're expected to perform (including Microsoft Patch Tuesday updates) perform the following.

  * Open `valiant-rampart-winazure-dashboards.pbix` 

## Step 3 - Baseline (not done)
Deploy santa.db to endpoints (this contains all approved apps from Step 2 - Audit) Review AWS ElasticSearch Step 3 Baseline dashboard for denies. Ensure all denies are expected.
If update of santa.db is required download AWS ElasticSearch Step 3 Baseline csv and run step-3-santaconfigupdater.sh to approve binaries missed in Step 2 and redeploy santa.db

## Step 4 - Enforce (not done)
Run step-4-santaconfigupdater.sh to generate santa.conf in enforce mode to deploy to enterprise.
Continuously Monitor AWS ElasticSearch Enforcement Denies


## Notes
###Agent Install 
https://gallery.technet.microsoft.com/scriptcenter/Install-OMS-Agent-with-2c9c99ab

https://blogs.technet.microsoft.com/bulentozkir/2017/07/03/install-oms-log-analytics-agent-and-oms-dependency-agent-to-all-windows-vms-in-the-subscription-using-powershell/

https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-quick-create-workspace

https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-agent-manage

https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-powershell-workspace-configuration


http://www.florisvanderploeg.com/available-vm-sizes-and-images-in-azure-per-location/

https://www.verboon.info/2017/02/oms-log-analytics-http-data-collector-api-work-notes/

https://docs.microsoft.com/en-us/rest/api/loganalytics/workspaces/getsharedkeys

https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-quick-collect-windows-computer

Power BI
https://www.youtube.com/watch?v=h69BFI4GVzc

powershell file manipulation

http://pleasework.robbievance.net/howto-easily-convert-block-of-text-into-an-array-in-powershell/


xml parsing
http://dinventive.com/blog/2016/02/20/powershell-ways-to-update-xml-data/
http://ilovepowershell.com/2015/09/11/searching-xml-nodes-by-attribute-name-with-select-xml/
https://stackoverflow.com/questions/35149361/append-new-child-item-to-specific-node
http://srichallagolla.blogspot.com/2012/08/xml-powershell-creating-new-child.html

GUID
http://toreaurstad.blogspot.com/2013/04/using-powershell-to-generate-new-guids.html