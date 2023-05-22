#Requires -Version 5.1
<#
.SYNOPSIS
	Returns Azure policy actions as a structure and records the history
	of what differs from the previous data.
	
.DESCRIPTION
	This script calls Get-AzureServices.ps1 and compares the results with the previous
	results from the input CSV. New and deprecated Azures service actions are identified.

.PARAMETER InputFile
	Name of the input file. Default is 'AzureServiceActions.csv'
	
.PARAMETER OutputFile
	Name of the input file. Default is the InputFile name.
	
.PARAMETER HistoryFile
	Name of the history text file to append differences to.\
	The default is 'AzureHistory.txt'
	
.PARAMETER Update
	If specified, then the OutputFile is updated.
	
.EXAMPLE	
	TO SEE A QUICK VIEW:
		.\Get-AzureServicesWithHistory.ps1  -Update
	
	TO CONVERT AzureServiceActions.CSV TO FORMATTED TEXT:
		"{0,-60} {1,-100} {2,-100} {3}" -f 'ProviderNamespace','Operation','OperationName','IsDataAction' | out-file -FilePath 'AzureServiceActions.txt' -Encoding utf8 -force -width 275 ;
		Import-Csv -Path 'AzureServiceActions.csv' | foreach { ("{0,-60} {1,-100} {2,-100} {3}" -f $_.ProviderNamespace, $_.Operation, $_.OperationName, $_.IsDataAction) } | out-file -FilePath 'AzureServiceActions.txt' -width 210 -Encoding utf8 -Append


.NOTES
	Author: Lester W.
	Version: v0.08
	Date: 09-May-23
	Repository: https://github.com/leswaters/AzureServices
	License: MIT License
	
	TO DO:
	* Update service list CSV and TXT as well.
	* $Warnings are not propagated back up... to be fixed.
	
.LINK
	https://www.leeholmes.com/blog/2015/01/05/extracting-tables-from-powershells-invoke-webrequest/

#>


# +=================================================================================================+
# |  PARAMETERS																						|
# +=================================================================================================+
[cmdletbinding()]   #  Add -Verbose support; use: [cmdletbinding(SupportsShouldProcess=$True)] to add WhatIf support
Param
(
	[string] $InputFile			= 'AzureServiceActions.csv',
	[string] $OutputFile		= $InputFile,	
	[string] $HistoryFile		= 'AzureHistory.txt',
	[switch] $Update			= $false
)


# +=================================================================================================+
# |  CLASSES																						|
# +=================================================================================================+

# +=================================================================================================+
# |  CONSTANTS																						|
# +=================================================================================================+

# +=================================================================================================+
# |  LOGIN		              																		|
# +=================================================================================================+
# REQUIRED

# +=================================================================================================+
# |  MAIN Body																						|
# +=================================================================================================+
$Results = @()
$Today = (Get-Date).ToString("dd-MMM-yyyy")
$Activity	= "Extracting Azure service provider actions..."

# Read in existing Inputfile, sorted by Action (Operation), dropping any notes
#    ProviderNamespace, ProviderName, Operation, OperationName, ResourceName, Description, IsDataAction
$PreviousData = Import-Csv -Path $InputFile | Where-Object {$_.Operation.Length -gt 0} | Sort-Object -Property Operation

# Determine Previous Services
$PreviousServices = $PreviousData.ProviderName | Select-Object -Unique | Sort-Object

# Get new data, sorted by Action (operation), dropping any notes
$CurrentData = .\Get-AzureServices.ps1 -WarningVariable $Warnings | Where-Object {$_.Operation.Length -gt 0} | Sort-Object -Property Operation 
if ($Warnings)
{
	write-warning $Warnings
}

# Determine Current Services
$CurrentServices = $CurrentData.ProviderName | Select-Object -Unique | Sort-Object

# Compare old & new services
$NewServices = (Compare-Object -ReferenceObject $CurrentServices -DifferenceObject $PreviousServices | Where-Object {$_.SideIndicator -eq '<='}).InputObject
$DeprecatedServices = (Compare-Object -ReferenceObject $CurrentServices -DifferenceObject $PreviousServices | Where-Object {$_.SideIndicator -eq '=>'}).InputObject
$ServiceNameChanges = "There are $($NewServices.Count) new provider names and $($DeprecatedServices.Count) deprecated provider names.`n"
if ($NewServices) { $ServiceNameChanges += "NEW :`n  $($NewServices -join ""`n  "")`n" }
if ($DeprecatedServices) { $ServiceNameChanges += "DEPRECATED :`n  $($DeprecatedServices -join ""`n  "")`n" }
Write-host $ServiceNameChanges


# Loop through current list
$Results = Compare-Object -ReferenceObject $CurrentData -DifferenceObject $PreviousData -Property Action -PassThru | Sort-Object -Property Action

### OLD
#$i = 0  # Index into $PreviousData, which MUST be sorted!
#foreach ($entry in $CurrentData)
#{
#	# Skip anything that may be deprecated
#	while ($i -lt $PreviousData.Count -And $PreviousData[$i].Operation -lt $entry.Operation)
#	{ 
#		$PreviousData[$i] | Add-Member -NotePropertyName 'Status' -NotePropertyValue 'Deprecated' -Force
#		$Results += $PreviousData[$i]
#		$i++
#	} 
#
#	# If we have a match, then skip past it
#	# Otherwise, we have a new entry
#	if ($i -lt $PreviousData.Count -And $PreviousData[$i].Operation -eq $entry.Operation)
#	{ 
#		$i++
#	} 
#	else
#	{
#		$entry | Add-Member -NotePropertyName 'Status' -NotePropertyValue 'New' -Force
#		$Results += $entry
#	}
#}

# Extract ServiceNames
$ServiceNames = $CurrentData | Select-Object -Property ServiceName -Unique | Sort-Object

# If HistoryFile does not exist, then we will create it with a new header
if ((Test-Path -Path $HistoryFile) -eq $false)
{
	# Add the timestamp and summary
	"$('=' * 25) $HistoryFile $('=' * 25)`nThis file contains the observed history of Azure Services and Actions.`nWhere previous results are provided, a comparison is displayed with observed changes.`n`n" `
		| out-file -FilePath $HistoryFile -Encoding UTF8 -Append -width 400
}

# At this point, $Results has all of the differences...
# Update the history file
if ($HistoryFile)
{
	$DeprecatedActions	= @($Results | Where-Object {$_.SideIndicator -eq '=>'})
	$NewActions	= @($Results | Where-Object {$_.SideIndicator -eq '<='})

	# Add a divider
	'=' * 100 | out-file -FilePath $HistoryFile -Encoding UTF8 -Append -width 400
	
	# Add the timestamp and summary
	"$Today : There are $($CurrentData.Actions.Count) actions across $($ServiceNames.Count) Azure services.`n              $($Results.Count) changes have been detected: $($NewActions.Count) new; $($DeprecatedActions.Count) deprecated." `
		| out-file -FilePath $HistoryFile -Encoding UTF8 -Append 
		
	if ($Warnings)
	{
		"`n$Warnings" | out-file -FilePath $HistoryFile -Encoding UTF8 -Append -width 400
	}
	
	# Output the service name changes
	$ServiceNameChanges | out-file -FilePath $HistoryFile -Encoding UTF8 -Append 
	
	# Output the deprecated actions
	if ($DeprecatedActions)
	{
		"`nDEPRECATED:" | out-file -FilePath $HistoryFile -Encoding UTF8 -Append
		"  {0,-80} {1,-14} {2}" -f 'Provider Operation (Action)','IsDataAction','Description' | out-file -FilePath $HistoryFile -Encoding UTF8 -Append -width 400
		"  {0,-80} {1,-14} {2}" -f '---------------------------','------------','-----------' | out-file -FilePath $HistoryFile -Encoding UTF8 -Append -width 400
		$DeprecatedActions | foreach { ("  {0,-80} {1,-14} {2}" -f $_.Operation, $_.IsDataAction, $_.Description) | out-file -FilePath $HistoryFile -Encoding UTF8 -Append -width 400}
	}
	
	# Output the new actions	
	if ($NewActions)
	{
		"`nNEW ACTIONS:" | out-file -FilePath $HistoryFile -Encoding UTF8 -Append
		"  {0,-80} {1,-14} {2}" -f 'Provider Operation (Action)','IsDataAction','Description' | out-file -FilePath $HistoryFile -Encoding UTF8 -Append -width 400
		"  {0,-80} {1,-14} {2}" -f '---------------------------','------------','-----------' | out-file -FilePath $HistoryFile -Encoding UTF8 -Append -width 400
		$NewActions | foreach { ("  {0,-80} {1,-14} {2}" -f $_.Operation, $_.IsDataAction, $_.Description) | out-file -FilePath $HistoryFile -Encoding UTF8 -Append -width 400}
	}
	"`n" | out-file -FilePath $HistoryFile -Encoding UTF8 -Append 
}
	
if ($Update)
{
	# Update CSV
	$CurrentData | Export-Csv -Path $OutputFile -encoding UTF8 -force
	
	# Update TXT
	$TxtFile = $OutputFile.Replace('.csv', '.txt')
	"{0,-60} {1,-100} {2,-100} {3}" -f 'ProviderNamespace','Operation','OperationName','IsDataAction' | out-file -FilePath 'AzureServiceActions.txt' -Encoding utf8 -force -width 400
	$CurrentData | foreach { ("{0,-60} {1,-100} {2,-100} {3}" -f $_.ProviderNamespace, $_.Operation, $_.OperationName, $_.IsDataAction) } | out-file -FilePath $TxtFile -width 400 -Encoding UTF8 -Append

	# TBD - Update services files...
}

