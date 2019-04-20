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
		.\Get-AzureServices.ps1 -AddNote | Export-Csv -Path 'AzureActions.csv' -force

	TO SEE A LIST OF SERVICES:
		.\Get-AzureServices.ps1 -ServicesOnly

.NOTES
	Author: Lester W.
	Version: v0.01
	Date: 20-Apr-19
	Repository: https://github.com/lesterw1/AzureServices
	License: MIT License
	
.LINK
	https://docs.microsoft.com/en-us/powershell/module/azurerm.resources/get-azurermprovideroperation?view=azurermps-6.13.0
	https://docs.microsoft.com/en-us/powershell/module/azurerm.resources/get-azurermproviderfeature?view=azurermps-6.13.0

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
# |  CONSTANTS																						|
# +=================================================================================================+


# +=================================================================================================+
# |  LOGIN		              																		|
# +=================================================================================================+
# Needed to ensure default credentials are in place for Proxy
$browser = New-Object System.Net.WebClient
$browser.Proxy.Credentials =[System.Net.CredentialCache]::DefaultNetworkCredentials 


# +=================================================================================================+
# |  MAIN Body																						|
# +=================================================================================================+
$Results = @()
$Today = (Get-Date).ToString("dd-MMM-yyyy")
$Activity	= "Retrieving Azure Providers and Actions..."
Write-Progress -Activity $Activity -PercentComplete 5 -ID 1 -Status "Get Provider Operations"

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
$ProviderOperations = Get-AzureRMProviderOperation

# Extract SERVICES and FEATURES List
$Services = @()
$Features = @()
$ServiceList = ($ProviderOperations | Select-Object -Property ProviderNameSpace -Unique | Sort-Object -Property ProviderNameSpace).ProviderNamespace
foreach ($service in $ServiceList)
{
	# For each service, grab one entry so we can extract the provider name
	$ProviderOp		= ($ProviderOperations | Where-Object {$_.ProviderNamespace -like $service } | Select-Object -First 1).Operation
	$ProviderName	= $ProviderOp.SubString(0,$ProviderOp.IndexOf('/'))
	
	$Entry = New-Object AzureService
	$Entry.ProviderNamespace	= $service			# Friendly Name
	$Entry.ProviderName			= $ProviderName 	# Microsoft.Compute
	$Entry.Description			= ""				# TBD
	$Services += $Entry
	
	# Get the Provider features
	if ($FeaturesOnly)
	{
		Write-Progress -Activity $Activity -PercentComplete 25 -ID 1 -Status "Get Provider Features"		# TO DO - Fix Progress Bar percentage
		$ProviderFeatures = Get-AzureRMProviderFeature -ProviderNamespace $ProviderName -ListAvailable 

		foreach ($feature in $ProviderFeatures)
		{
			Write-Progress -Activity $Activity -PercentComplete 30 -ID 1 -Status $ProviderName

			$Entry = New-Object AzureServiceFeature
			$Entry.ProviderNamespace	= $service			# Friendly Name
			$Entry.ProviderName			= $ProviderName 	# Microsoft.Compute
			$Entry.FeatureName			= $feature.featureName
			$Entry.RegistrationState	= $feature.RegistrationState
			$Entry.Description			= ""				# TBD
			$Features += $Entry
		}
	}
}

Write-Progress -Activity $Activity -PercentComplete 100 -Completed -ID 1

# If we're done, then exit...
if ($ServicesOnly)
	{ Return $Services }
elseif ($FeaturesOnly)
	{ Return $Features }


# +-----------------------------------------+
# |  Get Service Provider Operations		|
# +-----------------------------------------+
$ServiceActions = @()
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
	$ServiceActions += $Entry
}


write-Progress -Activity $Activity -PercentComplete 100 -Completed -ID 1
return $ServiceActions
	
