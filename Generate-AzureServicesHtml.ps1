#Requires -Version 5.1
<#
.SYNOPSIS
    Generate a searchable HTML catalog of Azure resource providers and RBAC operations.

.DESCRIPTION
    Reads AzureServices.csv and AzureServiceActions.csv, joined by ProviderName
    (case-insensitively). Creates one section for every distinct provider present
    in either file, including providers that exist only in AzureServiceActions.csv.
    For each provider, displays ProviderNamespace (ProviderName), its description
    when available, and an expandable table of Operation, OperationName,
    ResourceName, Description, and IsDataAction.

    The HTML is self-contained. A live, case-insensitive search matches provider
    namespace/name and operation identifiers/names, including partial matches.

    Input files and the output file default to the current PowerShell working
    directory (Get-Location), not the script directory or System32.
    No Azure credentials or additional PowerShell modules are required.

.EXAMPLE
    .\Generate-AzureServicesHtml.ps1

.EXAMPLE
    .\Generate-AzureServicesHtml.ps1 `
        -ServicesCsv 'docs\AzureServices.csv' `
        -ActionsCsv 'docs\AzureServiceActions.csv' `
        -OutputHtml 'docs\AzureServiceActions.html'
#>
[CmdletBinding()]
param(
    [string]$ServicesCsv = (Join-Path -Path (Get-Location).Path -ChildPath 'docs\AzureServices.csv'),
    [string]$ActionsCsv  = (Join-Path -Path (Get-Location).Path -ChildPath 'docs\AzureServiceActions.csv'),
    [string]$OutputHtml  = (Join-Path -Path (Get-Location).Path -ChildPath 'docs\AzureServiceActions.html')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Encode-Html {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return '' }
    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

foreach ($file in @($ServicesCsv, $ActionsCsv)) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        throw "Input CSV not found: $file"
    }
}

# Load the provider catalog and verify its columns.
$services = @(Import-Csv -LiteralPath $ServicesCsv -Encoding UTF8 | Where-Object {
    -not [string]::IsNullOrWhiteSpace($_.ProviderName) -and
    -not $_.ProviderName.TrimStart().StartsWith('#')
})
if ($services.Count -gt 0) {
    foreach ($column in @('ProviderNamespace', 'ProviderName', 'Description')) {
        if ($null -eq $services[0].PSObject.Properties[$column]) {
            throw "AzureServices.csv is missing the required column '$column'."
        }
    }
}

# Index operations by ProviderName, as requested. The dictionary is case-insensitive.
$actionsByProvider = [System.Collections.Generic.Dictionary[string,System.Collections.Generic.List[object]]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
$actionCount = 0
$actionSchemaChecked = $false

Import-Csv -LiteralPath $ActionsCsv -Encoding UTF8 | ForEach-Object {
    $action = $_
    if (-not $actionSchemaChecked) {
        foreach ($column in @('ProviderNamespace', 'ProviderName', 'Operation', 'OperationName', 'ResourceName', 'Description', 'IsDataAction')) {
            if ($null -eq $action.PSObject.Properties[$column]) {
                throw "AzureServiceActions.csv is missing the required column '$column'."
            }
        }
        $actionSchemaChecked = $true
    }

    if (-not [string]::IsNullOrWhiteSpace($action.ProviderName) -and
        -not $action.ProviderName.TrimStart().StartsWith('#')) {
        $name = $action.ProviderName.Trim()
        if (-not $actionsByProvider.ContainsKey($name)) {
            $actionsByProvider.Add($name, [System.Collections.Generic.List[object]]::new())
        }
        $actionsByProvider[$name].Add($action)
        $actionCount++
    }
}
# Build the union of providers from BOTH CSVs. ProviderName remains the join key.
# A provider appearing only in AzureServiceActions.csv gets a section with a
# namespace from the actions file and no description.
$providersByName = [System.Collections.Generic.Dictionary[string,object]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
foreach ($service in $services) {
    $name = $service.ProviderName.Trim()
    if (-not $providersByName.ContainsKey($name)) {
        $providersByName.Add($name, $service)
    }
    else {
        # If the service file repeats a ProviderName, keep one section and
        # retain nonempty metadata when available.
        $existing = $providersByName[$name]
        if ([string]::IsNullOrWhiteSpace($existing.ProviderNamespace) -and
            -not [string]::IsNullOrWhiteSpace($service.ProviderNamespace)) {
            $existing.ProviderNamespace = $service.ProviderNamespace
        }
        if ([string]::IsNullOrWhiteSpace($existing.Description) -and
            -not [string]::IsNullOrWhiteSpace($service.Description)) {
            $existing.Description = $service.Description
        }
    }
}

$actionOnlyProviderCount = 0
foreach ($name in $actionsByProvider.Keys) {
    # The namespace can be supplied by the first action record with a value.
    $namespace = ''
    foreach ($action in $actionsByProvider[$name]) {
        if (-not [string]::IsNullOrWhiteSpace($action.ProviderNamespace)) {
            $namespace = $action.ProviderNamespace.Trim()
            break
        }
    }

    if (-not $providersByName.ContainsKey($name)) {
        $providersByName.Add($name, [pscustomobject]@{
            ProviderNamespace = $namespace
            ProviderName      = $name
            Description       = ''
        })
        $actionOnlyProviderCount++
    }
    elseif ([string]::IsNullOrWhiteSpace($providersByName[$name].ProviderNamespace)) {
        $providersByName[$name].ProviderNamespace = $namespace
    }
}

$services = @($providersByName.Values | Sort-Object -Property ProviderNamespace, ProviderName)
if ($services.Count -eq 0) { throw 'Neither input CSV contains any provider records.' }

$outputFile = [System.IO.Path]::GetFullPath($OutputHtml)
$outputDir = [System.IO.Path]::GetDirectoryName($outputFile)
if (-not (Test-Path -LiteralPath $outputDir -PathType Container)) {
    throw "Output directory does not exist: $outputDir"
}

# Stream the HTML to disk, avoiding a second copy of the large action catalog.
$utf8 = [System.Text.UTF8Encoding]::new($false)
$writer = [System.IO.StreamWriter]::new($outputFile, $false, $utf8)
try {
    $htmlHeader = @'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Azure Services and RBAC Operations Catalog</title>
<!-- https://awsles.github.io/AzureServices/ -->
<style>
  :root { color-scheme: light; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Arial, sans-serif; }
  * { box-sizing: border-box; }
  body { background: #9cd2eb; color: #182230; margin: 0; line-height: 1.5; }
  .container { max-width: 1500px; margin: 0 auto; padding: 22px; }
  header { margin-bottom: 22px; }
  h1 { font-size: 1.8rem; margin: 0 0 4px; }
  .subtle { color: #304758; margin: 0 0 16px; }
  label { display: block; font-weight: 600; margin-bottom: 6px; }
  #serviceFilter { width: 100%; max-width: 650px; padding: 10px 12px; font-size: 1rem; border: 1px solid #8caac0; border-radius: 6px; }
  .service { background: #fff; border: 1px solid #d7dfe9; border-radius: 8px; margin: 0 0 20px; padding: 16px 20px 18px; }
  h2 { font-size: 1.25rem; margin: 0 0 12px; color: #182c48; overflow-wrap: anywhere; }
  .service-description { margin: -3px 0 14px; color: #344256; white-space: pre-line; overflow-wrap: anywhere; }
  a { color: #075a9e; }
  a:hover { text-decoration: none; }
  details { margin-top: 14px; }
  summary { cursor: pointer; font-weight: 650; padding: 9px 12px; background: #eaf0f7; border-radius: 5px; }
  details[open] summary { margin-bottom: 10px; }
  .table-scroll { overflow-x: auto; }
  table { width: 100%; min-width: 920px; border-collapse: collapse; table-layout: fixed; }
  th, td { border: 1px solid #dce2ea; padding: 8px 10px; text-align: left; vertical-align: top; overflow-wrap: anywhere; }
  th { background: #eaf0f7; }
  tbody tr:nth-child(even) { background: #f8fafc; }
  .actions th:nth-child(1) { width: 24%; }
  .actions th:nth-child(2) { width: 20%; }
  .actions th:nth-child(3) { width: 15%; }
  .actions th:nth-child(4) { width: 32%; }
  .actions th:nth-child(5) { width: 9%; }
  .actions td:nth-child(1) { font-family: Consolas, "Liberation Mono", monospace; font-size: .9em; }
  .missing { color: #6c7682; }
  .no-results { margin: 18px 0; }
  [hidden] { display: none !important; }
  @media (max-width: 700px) {
    .container { padding: 12px; }
    .service { padding: 12px; }
    .actions { font-size: .85rem; }
    .actions th, .actions td { padding: 6px; }
  }
</style>
</head>
<body>
<div class="container">
<header>
  <h1>Azure Services and RBAC Operations Catalog</h1>
'@
    $writer.WriteLine($htmlHeader)

    $writer.WriteLine('  <p class="subtle">' + $services.Count + ' providers · ' + $actionCount + ' operations · Generated ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') + '<br/>See <a href="https://awsles.github.io/AzureServices/" target="_blank" rel="noopener noreferrer">awsles.github.io/AzureServices/</a> for more information and CSV data.</p>')
    $writer.WriteLine('  <label for="serviceFilter">Find a provider or operation</label>')
    $writer.WriteLine('  <input type="search" id="serviceFilter" placeholder="Provider name, namespace, or operation (e.g. Microsoft.Storage/storageAccounts/read)..." autocomplete="off">')
    $writer.WriteLine('</header>')

    foreach ($service in $services) {
        $namespace = [string]$service.ProviderNamespace
        $name = $service.ProviderName.Trim()
        $heading = $namespace + ' (' + $name + ')'
        $encodedHeading = Encode-Html $heading

        $providerActions = @()
        if ($actionsByProvider.ContainsKey($name)) {
            $providerActions = @($actionsByProvider[$name] | Sort-Object -Property Operation, OperationName)
        }

        $writer.WriteLine('<section class="service" data-search="' + (Encode-Html $heading.ToLowerInvariant()) + '">')
        $writer.WriteLine('  <h2>' + $encodedHeading + '</h2>')
        if (-not [string]::IsNullOrWhiteSpace($service.Description)) {
            $writer.WriteLine('  <p class="service-description">' + (Encode-Html $service.Description) + '</p>')
        }

        $writer.WriteLine('  <details>')
        $writer.WriteLine('    <summary>Operations (' + $providerActions.Count + ')</summary>')
        $writer.WriteLine('    <div class="table-scroll"><table class="actions"><thead><tr><th>Operation</th><th>OperationName</th><th>ResourceName</th><th>Description</th><th>IsDataAction</th></tr></thead><tbody>')

        if ($providerActions.Count -eq 0) {
            $writer.WriteLine('      <tr><td colspan="5" class="missing">No operations found for this provider in AzureServiceActions.csv.</td></tr>')
        }
        else {
            foreach ($action in $providerActions) {
                $writer.WriteLine('      <tr><td>' + (Encode-Html $action.Operation) + '</td><td>' +
                    (Encode-Html $action.OperationName) + '</td><td>' +
                    (Encode-Html $action.ResourceName) + '</td><td>' +
                    (Encode-Html $action.Description) + '</td><td>' +
                    (Encode-Html $action.IsDataAction) + '</td></tr>')
            }
        }

        $writer.WriteLine('    </tbody></table></div>')
        $writer.WriteLine('  </details>')
        $writer.WriteLine('</section>')
    }

    $htmlFooter = @'
<p id="noResults" class="no-results" hidden>No matching providers or operations.</p>
</div>
<script>
(function () {
    'use strict';
    const filter = document.getElementById('serviceFilter');
    const noResults = document.getElementById('noResults');

    // Build a search index once. Include only provider headings and the two
    // operation-name columns, not the long description or resource fields.
    const index = Array.from(document.querySelectorAll('section.service'), function (section) {
        const operations = Array.from(
            section.querySelectorAll('table.actions tbody tr'),
            function (row) {
                const cells = row.querySelectorAll('td');
                if (cells.length < 5) return '';
                return (cells[0].textContent + ' ' + cells[1].textContent).toLowerCase();
            }
        );
        return {
            section: section,
            provider: section.dataset.search.toLowerCase(),
            operations: operations
        };
    });

    filter.addEventListener('input', function () {
        const query = filter.value.trim().toLowerCase();
        let matches = 0;
        index.forEach(function (entry) {
            const visible = !query || entry.provider.includes(query) ||
                entry.operations.some(function (operation) { return operation.includes(query); });
            entry.section.hidden = !visible;
            if (visible) matches++;
        });
        noResults.hidden = (matches !== 0);
    });
}());
</script>
</body>
</html>
'@
    $writer.WriteLine($htmlFooter)
}
finally {
    $writer.Dispose()
}

Write-Host "Generated: $outputFile"
Write-Host "Providers: $($services.Count); operations: $actionCount; providers found only in AzureServiceActions.csv: $actionOnlyProviderCount"
