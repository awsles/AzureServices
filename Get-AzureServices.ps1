#Requires -Version 5.1
<#
.SYNOPSIS
	Returns Azure services and actions as a structure.
	
.DESCRIPTION
	Return a structure containing an entry for each service and action.

.PARAMETER ServicesOnly
	If indicated, then only the services are returned along with a (guessed) documentation URL.
	
.PARAMETER FeaturesOnly
	If indicated, then service provider features are returned.
	
.PARAMETER ScanDocumentation
	If indicated, then the documentation page is scanned for actions [NOT IMPLEMENTED].
	
.PARAMETER AddNote
	If indicated, then a note row is added to the structure as the first item (useful if piping to a CSV).

.EXAMPLE	
	TO SEE A QUICK VIEW:
		.\Get-AzureServices.ps1 | Out-GridView
	
	TO GET A CSV:
		.\Get-AzureServices.ps1 -AddNote | Export-Csv -Path 'AzureServiceActions.csv' -encoding utf8 -force

	TO GET A LIST OF SERVICES:
		.\Get-AzureServices.ps1 -ServicesOnly | Export-Csv -Path 'AzureServices.csv' -Encoding utf8 -force
		
	TO GET A LIST OF FEATURES:
		.\Get-AzureServices.ps1 -FeaturesOnly | Export-Csv -Path 'AzureServiceFeatures.csv' -Encoding utf8 -force
		
	TO CONVERT AzureServiceActions.CSV TO FORMATTED TEXT:
		"{0,-60} {1,-100} {2,-100} {3}" -f 'ProviderNamespace','Operation','OperationName','IsDataAction' | out-file -FilePath 'AzureServiceActions.txt' -Encoding utf8 -force -width 275 ;
		Import-Csv -Path 'AzureServiceActions.csv' | foreach { ("{0,-60} {1,-100} {2,-100} {3}" -f $_.ProviderNamespace, $_.Operation, $_.OperationName, $_.IsDataAction) } | out-file -FilePath 'AzureServiceActions.txt' -width 210 -Encoding utf8 -Append
	
	TO CONVERT AzureServices.CSV TO FORMATTED TEXT:                                                                                                                                      
		"{0,-56} {1,-40} {2}" -f 'ProviderNamespace','ProviderName','Description' | out-file -FilePath 'AzureServices.txt' -Encoding utf8 -force -width 210 ;
		Import-Csv -Path 'AzureServices.csv' | foreach { ("{0,-56} {1,-25} {2}" -f $_.ProviderNamespace, $_.ProviderName, $_.Description) } | out-file -FilePath 'AzureServices.txt' -width 210 -Encoding utf8 -Append

	TO CONVERT AzureServiceFeatures.CSV TO FORMATTED TEXT:                                                                                                                                      
		"{0,-75} {1,-65} {2}" -f 'ProviderNamespace','ProviderName','FeatureName' | out-file -FilePath 'AzureServices.txt' -Encoding utf8 -force -width 210 ;
		Import-Csv -Path 'AzureServiceFeatures.csv' | foreach { ("{0,-75} {1,-65} {2}" -f $_.ProviderNamespace, $_.ProviderName, $_.FeatureName) } | out-file -FilePath 'AzureServiceFeatures.txt' -width 210 -Encoding utf8 -Append


.NOTES
	Author: Lester W.
	Version: v0.11
	Date: 26-Dec-21
	Repository: https://github.com/lesterw1/AzureServices
	License: MIT License
	
.LINK

#>


# +=================================================================================================+
# |  PARAMETERS																						|
# +=================================================================================================+
[cmdletbinding()]   #  Add -Verbose support; use: [cmdletbinding(SupportsShouldProcess=$True)] to add WhatIf support
Param
(
	[switch] $ServicesOnly		= $false,		# If true, then the services are returned as a structure
	[switch] $FeaturesOnly		= $false,		# If true, then the provider features are returned
	[switch] $ScanDocumentation	= $false,		# If true, then scan documentation pages
	[switch] $AddNote			= $false		# If true, add a note description as the 1st item
)



# +=================================================================================================+
# |  CLASSES																						|
# +=================================================================================================+

class AzureService
{
	[string] $ProviderNamespace 	# Friendly Name
	[string] $ProviderName			# Microsoft.Compute
	[string] $Description 
}

class AzureServiceFeature
{
	[string] $ProviderNamespace 	# Friendly Name
	[string] $ProviderName			# Microsoft.Compute
	[string] $FeatureName
	[string] $RegistrationState
	[string] $Description 
}

class AzureOperations
{
	[string] $ProviderNamespace 
	[string] $Operation				# Action
	[string] $OperationName
	[string] $ResourceName 
	[string] $IsDataAction
	[string] $Description
	# [string] $DocLink
}


# +=================================================================================================+
# |  MODULES																						|
# +=================================================================================================+
Import-Module Az.Resources


# +=================================================================================================+
# |  LOGIN		              																		|
# +=================================================================================================+
# Needed to ensure default credentials are in place for Proxy
$browser = New-Object System.Net.WebClient
$browser.Proxy.Credentials =[System.Net.CredentialCache]::DefaultNetworkCredentials 


# +=================================================================================================+
# |  MAIN Body																						|
# +=================================================================================================+
$Results	= @()
$Services	= @()
$Features	= @()
$Today		= (Get-Date).ToString("dd-MMM-yyyy")
$Activity	= "Retrieving Azure Providers and Actions..."
Write-Progress -Activity $Activity -PercentComplete 1 -ID 1 -Status "Get Provider Operations"

if ($AddNote)
{
	# 1st entry with notes
	$Entry = New-Object AzureOperations
	$Entry.ProviderNamespace= ""
	$Entry.Description		= "### NOTE ### `nThe data contained herein was gathered on $Today."
	$Entry.Operation		= ""
	$Results += $Entry
}


# +-----------------------------------------+
# |  Get Service Providers and Operations	|
# +-----------------------------------------+
$ProviderOperations = Get-AzProviderOperation

# Extract SERVICES and FEATURES List
$ServiceList = ($ProviderOperations | Select-Object -Property ProviderNameSpace -Unique | Sort-Object -Property ProviderNameSpace).ProviderNamespace
foreach ($serviceName in $ServiceList)
{
	write-verbose "Service: $service"
	$pctComplete = [string] ([math]::Truncate((++$ctr / $ServiceList.Count)*100))
	Write-Progress -Activity $Activity -PercentComplete $pctComplete  -Status "$ServiceName - $pctComplete% Complete  ($ctr of $($ServiceList.Count))" -ID 1

	# For each service, grab one entry so we can extract the provider name
	$ProviderEntry	= ($ProviderOperations | Where-Object {$_.ProviderNamespace -like $serviceName } | Select-Object -First 1)
	$ProviderOp		= $ProviderEntry.Operation
	$ProviderName	= $ProviderOp.SubString(0,$ProviderOp.IndexOf('/'))
	
	$Entry = New-Object AzureService
	$Entry.ProviderNamespace	= $serviceName					# Service Name
	$Entry.ProviderName			= $ProviderName 				# Microsoft.Compute
	$Entry.Description			= ""							# No Service Descriptions available yet...
	$Services += $Entry
	
	# Get the Provider features by Service
	if ($FeaturesOnly)
	{
		Write-Progress -Activity $Activity -PercentComplete $pctComplete -ID 1 -Status "Get $serviceName Provider Features"
		$ProviderFeatures = Get-AzProviderFeature -ProviderNamespace $ProviderName -ListAvailable 

		foreach ($feature in $ProviderFeatures)
		{
			Write-Progress -Activity $Activity -PercentComplete $pctComplete -ID 1 -Status "Get $serviceName Provider Features for $ProviderName"

			$Entry = New-Object AzureServiceFeature
			$Entry.ProviderNamespace	= $serviceName					# Service Name
			$Entry.ProviderName			= $ProviderName 				# Microsoft.Compute
			$Entry.FeatureName			= $feature.featureName
			$Entry.RegistrationState	= $feature.RegistrationState
			$Entry.Description			= $feature.Description			# Feature Description
			$Features += $Entry
		}
	}
}

Write-Progress -Activity $Activity -PercentComplete 100 -ID 1 -Completed

# If we're done, then exit...
if ($ServicesOnly)
	{ Return $Services }
elseif ($FeaturesOnly)
	{ Return $Features }


# +-----------------------------------------+
# |  Get Service Provider Operations		|
# +-----------------------------------------+
$Activity = "Organizing provider operations"
Write-Progress -Activity $Activity -PercentComplete 5 -ID 1
foreach ($operation in $ProviderOperations)
{
	Write-Progress -Activity $Activity -PercentComplete 5 -ID 1 -Status $operation.Operation	# TODO: Fix percentage
	
	$Entry = New-Object AzureOperations
	$Entry.ProviderNamespace	= $operation.ProviderNameSpace 
	$Entry.Operation			= $operation.Operation
	$Entry.OperationName		= $operation.OperationName
	$Entry.IsDataAction			= $operation.IsDataAction
	$Entry.Description			= $operation.Description
	# [string] $DocLink
	$Results += $Entry
}


write-Progress -Activity $Activity -PercentComplete 100 -Completed -ID 1
return $Results
	
