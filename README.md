# AzureServices
List of Azure service providers, operations (actions), and feature control switches.

## Description
This repository contains three CSV files which document the various Azure service providers (services) as well as the
service provider operations (actions) used in policy permissions. This is quite useful when doing policy and role planning
to be able to see all actions in one place. 

Comment lines in the CSV (including the header at the top) start with a hastag (#).  The date
when the data was scraped along with the row count may be found at the bottom of each CSV.

## Anomalies
In scraping the data, a few anomalies have been observed with the original source data and/or documentation:

* You will only see services which have been feature-enabled within the current Azure subscription.
* In the past, several Azure service providers have not correctly reported their available operations.

---
# Script
The data is generated using a PowerShell script which outputs the data for the three CSVs. 
The script simply restructures data that is returned by  existing PowerShell cmdlets
(Get-AzureRmProviderOperation and Get-AzureRmProviderFeature).
The code isn't fancy but it is functional. Enhancement suggestions are welcomed!

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

