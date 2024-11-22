# AzureServices
List of Azure service providers, operations (actions), and feature control switches.

As of 04-May-22, 13526 operations were discovered across 280 Azure service providers (66 of which have no operations defined).
As of 22-Nov-24, 20996 operations were discovered across 426 Azure service providers (143 of which have no operations defined).

## Description
This repository contains three CSV files which document the various Azure service providers (services) as well as the
service provider operations (actions) used in policy permissions. This is quite useful when doing policy and role planning
to be able to see all actions in one place. 

Comment lines in the CSV (including the header at the top) start with a hastag (#).
The date when the data was scraped and the row count may be found at the bottom of each CSV.

## Purpose
The purpose of this data is for Azure administrators who manage resource permissions. 
As wildcards can be used in permissions, it is important to monitor the set of permissions available for each Azure resource type.

## Usage
``
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
``

## Anomalies
In retrieving the data, a few anomalies have been observed with the original source data and/or documentation:

* You will only see permissions and services which have been feature-enabled (registered) within the current Azure subscription.
* Some Azure service providers do not correctly report their available operations (i.e., valid permissions may not be listed).
* There are inconsistencies in the services and provider names reported by each provider.

---
# Script
The data is generated using a PowerShell script which outputs the data for the three CSVs. 
The script simply restructures data that is returned by  existing PowerShell cmdlets
(Get-AzureRmProviderOperation and Get-AzureRmProviderFeature).
The code isn't fancy but it is functional.

### Script Parameters

* **-ServicesOnly**
  If indicated, then only the services are returned. At this time, no descriptions are available.

* **-FeaturesOnly**
	If indicated, then the available feature switches is returned.
  
* **-AddNote**
	If indicated, then a note row is added to the structure as the first item (useful if piping to a CSV).

### Next Steps
The progress bar in the script is not fully functional yet. Beyond that, the next step is to put some
automation around my script so that this repository is automatically
updated regularly or when any changes are detected. I also plan to start tracking additions & deletions
to the actions and mark them accordingly (handy to see what's new and what has been depricated).

