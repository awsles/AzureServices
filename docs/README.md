
 **Click ➡️[HERE](AzureServices.html)⬅️ to go directly to the catalog!** 

# Azure Services and Operations Catalog
List of Azure service providers, operations (actions), and feature control switches.

This repository contains a comprehensive, searchable catalog of **Azure Services, Operations, and Feature Control options** in a convenient, consolidated reference for Azure access management. 

The output includes service names, service prefixes, ARN formats, and individual actions (such as `sts:AssumeRole`), along with their descriptions and access levels (List, Read, Write, Permissions Management, and Tagging). The script extracts information from AWS JavaScript assets, enriching it with AWS documentation, and scanning documentation for additional actions missing from the generator. Results are published in CSV, formatted text, and (soon) browsable HTML formats.

This catalog is particularly valuable to **Azure administrators, cloud architects, security engineers, DevOps teams, and IAM governance professionals** responsible for designing, reviewing, or troubleshooting access permissions. Having Azure operations consolidated into a readily searchable reference simplifies the development of roles and permissions. It also supports least-privilege security reviews, permission discovery, auditing, and identifying unfamiliar or newly introduced actions without having to navigate hundreds of individual Azure documentation pages. 

The catalog is updated periodically and usually includes a DIFF (what is new, different, and obsoleted) from the previous time it was run.

**LAST CATALOG UDATE:** `18-Oct-26`

* [AzureServices.html](AzureServices.html) - List of Azure services and actions in expandable and searchable HTML format
* [AzureServiceActions.csv](azureserviceactions.csv) - List of Azure services and actions in CSV format (~1.6MB)
* [AzureServiceFeatures.csv](azureservicefeatures.csv) - List of Azure service features
* [AzureServices.csv](azureservices.csv) - List of Azure services only
* [AzureServices.txt](azureservices.txt) - List of Azure Services as formatted text


**FUN FACTS:**

* 18-Oct-26 : 24,899 operations were discovered across 550 Azure service providers (252 of which have no operations defined)
* 22-Nov-24 : 20,996 operations were discovered across 426 Azure service providers (143 of which have no operations defined)
* 04-May-22 : 13,526 operations were discovered across 280 Azure service providers (66 of which have no operations defined)


## Example outputs

### AzureServices.html
This is the complete Azure service and operations catalog in HTML format [here](AzureServices.html) with search capability.

TBD - SCREENSHOT HERE

### AzureServices.csv
This is a complete list of Azure Services in CSV format. There is also a formatted text version: [AzureServices.txt](azureservices.txt).
NOTE: Due to an API change, the descriptions are apparently no longer being returned `[TO BE INVESTIGATED]`.

EXAMPLE:

|ProviderNamespace|ProviderName|Description|
|---|---|---|
|Microsoft Compute|Microsoft.Compute|-|
|Microsoft Azure Attestation|Microsoft.Attestation|-|
|Microsoft Storage|Microsoft.Storage|-|
|-|Microsoft.Storage.ActionsRP|-|


### AzureServiceActions.csv
This is a complete list of Azure Services and Actions in CSV format.

EXAMPLE:

|ProviderNamespace|ProviderName|Operation|OperationName|ResourceName|Description|IsDataAction|
|---|---|---|---|---|---|---|
|GitHub.Network|GitHub.Network|GitHub.Network/Operations/read|read_Operations|Operations|read Operations|False"
|Microsoft API Management|Microsoft.ApiManagement|Microsoft.ApiManagement/service/backup/action|Backup API Management Service|Service|Backup API Management Service to the specified container in a user provided storage account|False|
|Microsoft Apps|microsoft.app|microsoft.app/connectedenvironments/storages/delete|Delete a Connected Environment Storage|Connected Environment Storage|Delete a storage of Connected Environment.|False|
|Microsoft Network|Microsoft.Network|Microsoft.Network/virtualNetworks/subnets/joinViaServiceEndpoint/action|Join Service to a Subnet.|Virtual Network Subnet|Joins resource such as storage account or SQL database to a subnet. Not alertable.|False|


### AzureServiceFeatures.csv
This indicates the Azure service features that have been enabled (registered) within the *current* Azure subscription.

EXAMPLE:

"ProviderNameSpace|ProviderName|FeatureName|RegistrationState"
|---|---|---|---|
|Microsoft DB for MariaDB|Microsoft.DBForMariaDB|orcasconfignopdl|NotRegistered|
|Microsoft DB for MySQL|Microsoft.DBForMySQL|flexibleServerGeoRestore|NotRegistered|
|Microsoft.Discovery|Microsoft.Discovery|DataAssetMountAuth|NotRegistered|
|Microsoft Compute|Microsoft.Compute|FastPathForced_asiaeast|Registered"
|-|Microsoft.CostManagementBeta|TenantRegistration|Pending|
|Microsoft Storage|Microsoft.Storage|ContainerSoftDelete|Registered|
|Microsoft Compute|Microsoft.Compute|EncryptionAtHost|Registered|


## Anomalies
In retrieving the data, a few anomalies have been observed with the original source data and/or documentation:

* You will only see permissions and services which have been feature-enabled (registered) within the current Azure subscription.
* Some Azure service providers do not correctly report their available operations (i.e., valid permissions may not be listed).
* There are inconsistencies in the services and provider names reported by each provider.


# PowerShell script
If you want to generate the data yourself, you can use the PowerShell script in [https://github.com/awsles/AzureServices/](https://github.com/awsles/AzureServices/). The script outputs the data for the three CSVs. The script simply restructures data that is returned by existing PowerShell cmdlets (Get-AzureRmProviderOperation and Get-AzureRmProviderFeature).
The code isn't fancy but it is functional.

### Script Parameters

* **-ServicesOnly**
  If indicated, then only the services are returned. At this time, no descriptions are available.

* **-FeaturesOnly**
	If indicated, then the available feature switches is returned.
  
* **-AddNote**
	If indicated, then a note row is added to the structure as the first item (useful if piping to a CSV).

### Usage

```
	TO SEE A QUICK VIEW:
		.\Get-AzureServices.ps1 | Out-GridView

	TO GET JUST A LIST OF SERVICES:
		.\Get-AzureServices.ps1 -ServicesOnly | Export-Csv -Path 'AzureServices.csv' -Encoding utf8 -force
	TO CONVERT AzureServices.CSV TO FORMATTED TEXT: 
		"{0,-56} {1,-40} {2}" -f 'ProviderNamespace','ProviderName','Description' | out-file -FilePath 'AzureServices.txt' -Encoding utf8 -force -width 210 ;
		"{0,-56} {1,-40} {2}" -f '=================','============','===========' | out-file -FilePath 'AzureServiceFeatures.txt' -Encoding utf8 -force -width 210 -Append;
		Import-Csv -Path 'AzureServices.csv' | foreach { ("{0,-56} {1,-40} {2}" -f $_.ProviderNamespace, $_.ProviderName, $_.Description) } | out-file -FilePath 'AzureServices.txt' -width 210 -Encoding utf8 -Append

	TO GET A CSV OF ALL RBAC ACTIONS:
		.\Get-AzureServices.ps1 -AddNote | Export-Csv -Path 'AzureServiceActions.csv' -Encoding utf8 -force
	TO CONVERT AzureServiceActions.CSV TO FORMATTED TEXT:
		"{0,-60} {1,-100} {2,-100} {3}" -f 'ProviderNamespace','Operation','OperationName','IsDataAction' | out-file -FilePath 'AzureServiceActions.txt' -Encoding utf8 -force -width 275 ;
		Import-Csv -Path 'AzureServiceActions.csv' | foreach { ("{0,-60} {1,-100} {2,-100} {3}" -f $_.ProviderNamespace, $_.Operation, $_.OperationName, $_.IsDataAction) } | out-file -FilePath 'AzureServiceActions.txt' -width 210 -Encoding utf8 -Append
	
	TO GET A LIST OF FEATURES ONLY AS A CSV:
		.\Get-AzureServices.ps1 -FeaturesOnly | Export-Csv -Path 'AzureServiceFeatures.csv' -Encoding utf8 -force		
	TO CONVERT AzureServiceFeatures.CSV TO FORMATTED TEXT: 
		"{0,-56} {1,-40} {2}" -f 'ProviderNamespace','ProviderName','FeatureName' | out-file -FilePath 'AzureServiceFeatures.txt' -Encoding utf8 -force -width 210 ;
		"{0,-56} {1,-40} {2}" -f '=================','============','===========' | out-file -FilePath 'AzureServiceFeatures.txt' -Encoding utf8 -force -width 210 -Append;
		Import-Csv -Path 'AzureServiceFeatures.csv' | foreach { ("{0,-56} {1,-40} {2}" -f $_.ProviderNamespace, $_.ProviderName, $_.FeatureName) } | out-file -FilePath 'AzureServiceFeatures.txt' -width 210 -Encoding utf8 -Append
```

### Next Steps

* Put someautomation around my script so that this repository is automatically updated regularly or when any changes are detected.

