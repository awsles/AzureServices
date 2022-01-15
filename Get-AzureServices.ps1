#Requires -Version 5.1
<#
.SYNOPSIS
	Returns Azure services and actions as a structure.
	This SHOULD match the documented list of resource provider operations at:
	https://docs.microsoft.com/en-us/azure/role-based-access-control/resource-provider-operations
	
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
	
	TO GET JUST A LIST OF SERVICES:
		.\Get-AzureServices.ps1 -ServicesOnly | Export-Csv -Path 'AzureServices.csv' -Encoding utf8 -force
		
	TO GET A CSV OF ALL RBAC ACTIONS:
		.\Get-AzureServices.ps1 -AddNote | Export-Csv -Path 'AzureServiceActions.csv' -Encoding utf8 -force

	TO CONVERT AzureServiceActions.CSV TO FORMATTED TEXT:
		"{0,-60} {1,-100} {2,-100} {3}" -f 'ProviderNamespace','Operation','OperationName','IsDataAction' | out-file -FilePath 'AzureServiceActions.txt' -Encoding utf8 -force -width 275 ;
		Import-Csv -Path 'AzureServiceActions.csv' | foreach { ("{0,-60} {1,-100} {2,-100} {3}" -f $_.ProviderNamespace, $_.Operation, $_.OperationName, $_.IsDataAction) } | out-file -FilePath 'AzureServiceActions.txt' -width 210 -Encoding utf8 -Append
	
	TO CONVERT AzureServices.CSV TO FORMATTED TEXT:                                                                                                                                      
		"{0,-56} {1,-40} {2}" -f 'ProviderNamespace','ProviderName','Description' | out-file -FilePath 'AzureServices.txt' -Encoding utf8 -force -width 210 ;
		Import-Csv -Path 'AzureServices.csv' | foreach { ("{0,-56} {1,-25} {2}" -f $_.ProviderNamespace, $_.ProviderName, $_.Description) } | out-file -FilePath 'AzureServices.txt' -width 210 -Encoding utf8 -Append

.NOTES
	Author: Les Waters
	Version: v0.12
	Date: 15-Jan-22
	Repository: https://github.com/leswaters/AzureServices
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

class AzureOperation
{
	[string] $ProviderNamespace 	# Friendly Name
	[string] $ProviderName			# Microsoft.Compute
	[string] $Operation				# RBAC Permission
	[string] $OperationName			# Friendly name for operation
	[string] $ResourceName 			# Associated resource friendly name
	[string] $Description			# Detailed Description
	[switch] $IsDataAction			
	# [string] $DocLink
	# [datetime] $AsofDate			# Timestamp when data was gathered
	# [int] $CRC32					# hash(Description); used to detect changes 
}


# +=================================================================================================+
# |  MODULES																						|
# +=================================================================================================+
Import-Module Az.Resources



# +=================================================================================================+
# |  FUNCTIONS																						|
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
$Services	= @()
$Operations	= @()
$Today		= (Get-Date).ToString("dd-MMM-yyyy")
$Activity	= "Retrieving Azure Providers and Actions..."

if ($AddNote)
{
	# 1st entry with notes
	$Entry = New-Object AzureOperation
	$Entry.ProviderNamespace= ""
	$Entry.Description		= "### NOTE ### `nThe data contained herein was gathered on $Today."
	$Entry.Operation		= ""
	$Operations += $Entry
}


# +-----------------------------------------+
# |  Get Service Providers and Operations	|
# +-----------------------------------------+
Write-Progress -Activity $Activity -PercentComplete 1 -ID 1 -Status "Retrieving List of Provider Operations"
$ProviderOperations = Get-AzProviderOperation

# Get provider feature list
# This has undocumented and provide providers within it.
Write-Progress -Activity $Activity -PercentComplete 1 -ID 1 -Status "Retrieving Service Provider Feature List"
$ProviderFeatures = Get-AzProviderFeature -ListAvailable 
$ProviderNamesFromFeatures = ($ProviderFeatures | Select-Object -Property ProviderName -Unique | Sort-Object -Property ProviderName).ProviderName

# Extract list of SERVICE names (provider name spaces)
Write-Progress -Activity $Activity -PercentComplete 1 -ID 1 -Status "Extracting Service Names"
$ServiceList = ($ProviderOperations | Select-Object -Property ProviderNameSpace -Unique | Sort-Object -Property ProviderNameSpace).ProviderNamespace

# Extract the provider names (e.g., Microsoft.Compute)
$ctr = 0
Write-Progress -Activity $Activity -PercentComplete 1 -ID 1 -Status "Extracting Provider Names"
foreach ($serviceName in $ServiceList)
{
	write-verbose "Service: $service"
	$pctComplete = [string] ([math]::Truncate((++$ctr / $ServiceList.Count)*100))
	Write-Progress -Activity $Activity -PercentComplete $pctComplete  -Status "$ServiceName - $pctComplete% Complete  ($ctr of $($ServiceList.Count))" -ID 1

	# For each service, grab one entry so we can extract the provider name
	$ProviderEntry	= ($ProviderOperations | Where-Object {$_.ProviderNamespace -like $serviceName } | Select-Object -First 1)
	$ProviderOp		= $ProviderEntry.Operation
	$ProviderName	= $ProviderOp.SubString(0,$ProviderOp.IndexOf('/'))    # e.g., "Microsoft.Compute"
	
	# Knock out any duplicates in ProviderNameFromFeatures
	$ProviderNamesFromFeatures = $ProviderNamesFromFeatures | where {$_ -NotLike $ProviderName}
	
	$Entry = New-Object AzureService
	$Entry.ProviderNamespace	= $serviceName					# Service Name
	$Entry.ProviderName			= $ProviderName 				# Microsoft.Compute
	$Entry.Description			= ""							# No Service Descriptions available yet...
	$Services += $Entry
}

# At this point, $ProviderNamesFromFeatures has any providers that didn't show up in Get-AzProviderOperation
# Drop out Private.* and Providers.Test
Write-Progress -Activity $Activity -PercentComplete 100 -ID 1 -Status "Integrate additional Providers"
$ProviderNamesFromFeatures = $ProviderNamesFromFeatures | where {$_ -NotLike 'Private.*'}
$ProviderNamesFromFeatures = $ProviderNamesFromFeatures | where {$_ -NotLike 'Providers.Test'}
# Knock out similar names (case-insensitive and trimmed)
$ProviderNamesFromFeatures = $ProviderNamesFromFeatures | Sort-Object -Property @{Expression={$_.Trim()}} -Unique

# Now add these providers into the services list
foreach ($providerName in $ProviderNamesFromFeatures)
{
	$Entry = New-Object AzureService
	$Entry.ProviderNamespace	= '-'							# Service Name
	$Entry.ProviderName			= $ProviderName 				# Microsoft.Compute
	$Entry.Description			= ""							# No Service Descriptions available yet...
	$Services += $Entry
}

# Sort Services List and exit if only services were requested
$Services = $Services | Sort-Object -Property ProviderName
if ($ServicesOnly)
	{ Return $Services }


# +-----------------------------------------+
# |  Get Service Provider Operations		|
# +-----------------------------------------+
$Activity = "Organizing Provider Operations"
$ctr = 0
foreach ($operation in $ProviderOperations)
{
	$pctComplete = [string] ([math]::Truncate((++$ctr / $ProviderOperations.Count)*100))
	Write-Progress -Activity $Activity -PercentComplete $pctComplete  -Status "$($operation.Operation) - $pctComplete% Complete  ($ctr of $($ProviderOperations.Count))" -ID 1
	
	$Entry = New-Object AzureOperation
	$Entry.ProviderNamespace	= $operation.ProviderNameSpace 
	$Entry.ProviderName			= $operation.Operation.SubString(0,$operation.Operation.IndexOf('/'))    # e.g., "Microsoft.Compute"
	$Entry.Operation			= $operation.Operation.Trim()
	$Entry.OperationName		= $operation.OperationName
	$Entry.ResourceName			= $operation.ResourceName
	$Entry.IsDataAction			= $operation.IsDataAction
	$Entry.Description			= $operation.Description
	# $Entry.$DocLink = TBD
	$Operations += $Entry
}

# Add in any providers that don't have operations
foreach ($s in $Services)
{
	if ($Operations.ProviderName -NotContains $s.ProviderName)
	{
		# Create a dummy entry for the unknown provider
		$Entry = New-Object AzureOperation
		$Entry.ProviderNamespace	= $s.ProviderNameSpace 
		$Entry.ProviderName			= $s.ProviderName
		$Entry.Operation			= ""
		$Entry.OperationName		= "** No operations discovered **"
		$Entry.ResourceName			= ""
		$Entry.IsDataAction			= $false
		$Entry.Description			= "Provider name discovered via Get-AzProviderFeatures"
		# $Entry.$DocLink = ""
		$Operations += $Entry
	}		
}

# Sort results by ProviderName, Operation
$Operations = $Operations | Sort-Object -Property ProviderName,Operation

$CountNoOps = ($Operations | Where-Object {$_.Operation -eq ""}).Count
$CountOps	= $Operations.Count - $CountNoOps
write-host -ForegroundColor Yellow "$CountOps operations discovered across $($Services.Count) Azure service providers ($CountNoOps of which have no operations defined)"
write-Progress -Activity $Activity -PercentComplete 100 -Completed -ID 1
return $Operations

