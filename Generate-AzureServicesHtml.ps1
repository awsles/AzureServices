#Requires -Version 5.1
<#
.SYNOPSIS
    Generate a searchable HTML catalog of Azure resource providers and RBAC operations.

.DESCRIPTION
    Reads AzureServices.csv and AzureServiceActions.csv, joined by ProviderName
    (case-insensitively). Creates a main section only for providers with one or
    more operations in AzureServiceActions.csv. Each main section displays
    ProviderNamespace (ProviderName), its description (when available), and an
    expandable table of Operation, OperationName, ResourceName, Description,
    and IsDataAction. Providers in either CSV without operations appear in a
    separate, expandable "Other Providers" table at the bottom of the page.

    The HTML is self-contained. A live, case-insensitive search matches provider
    namespace/name and operation identifiers/names, including partial matches;
    it can also find providers listed in "Other Providers".

    Input files and the output file default to the current PowerShell working
    directory (Get-Location), not the script directory or System32.
    No Azure credentials or additional PowerShell modules are required.

.EXAMPLE
    .\Generate-AzureServicesHtml.ps1

.EXAMPLE
    .\Generate-AzureServicesHtml.ps1 `
        -ServicesCsv 'docs\AzureServices.csv' `
        -ActionsCsv 'docs\AzureServiceActions.csv' `
        -OutputHtml 'docs\AzureServices.html'
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
        # A row without an Operation is not a discernable operation. Keep its
        # ProviderName in the union, but list it under Other Providers unless
        # another row provides a real operation for that name.
        if (-not [string]::IsNullOrWhiteSpace($action.Operation)) {
            $actionsByProvider[$name].Add($action)
            $actionCount++
        }
    }
}
# Build the union of providers from BOTH CSVs. ProviderName remains the join key.
# A provider appearing only in AzureServiceActions.csv gets a namespace from
# that file and no description. Providers without operations appear at the end.
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

# Split the union into providers with operations and those without. The main
# catalog contains only providers whose action lists are nonempty.
$allProviders = @($providersByName.Values | Sort-Object -Property ProviderNamespace, ProviderName)
if ($allProviders.Count -eq 0) { throw 'Neither input CSV contains any provider records.' }
$services = @($allProviders | Where-Object {
    $actionsByProvider.ContainsKey($_.ProviderName.Trim()) -and
    $actionsByProvider[$_.ProviderName.Trim()].Count -gt 0
})
$otherProviders = @($allProviders | Where-Object {
    -not $actionsByProvider.ContainsKey($_.ProviderName.Trim()) -or
    $actionsByProvider[$_.ProviderName.Trim()].Count -eq 0
} | Sort-Object -Property ProviderName, ProviderNamespace)

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
  .section-divider { border: 0; border-top: 2px solid #6a9fb8; margin: 26px 0 20px; }
  table.other-providers { min-width: 700px; }
  .other-providers th:nth-child(1) { width: 25%; }
  .other-providers th:nth-child(2) { width: 28%; }
  .other-providers th:nth-child(3) { width: 47%; }
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

    $writer.WriteLine('  <p class="subtle">' + $services.Count + ' providers with operations · ' + $otherProviders.Count + ' other providers · ' + $actionCount + ' operations · Generated ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') + '<br/>See <a href="https://awsles.github.io/AzureServices/" target="_blank" rel="noopener noreferrer">awsles.github.io/AzureServices/</a> for more information and CSV data.</p>')
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

        foreach ($action in $providerActions) {
            $writer.WriteLine('      <tr><td>' + (Encode-Html $action.Operation) + '</td><td>' +
                (Encode-Html $action.OperationName) + '</td><td>' +
                (Encode-Html $action.ResourceName) + '</td><td>' +
                (Encode-Html $action.Description) + '</td><td>' +
                (Encode-Html $action.IsDataAction) + '</td></tr>')
        }

        $writer.WriteLine('    </tbody></table></div>')
        $writer.WriteLine('  </details>')
        $writer.WriteLine('</section>')
    }

    # The remaining providers appear in one expandable table at the end.
    $writer.WriteLine('<hr id="otherProvidersDivider" class="section-divider">')
    $writer.WriteLine('<section id="otherProviders" class="service">')
    $writer.WriteLine('  <h2>Other Providers</h2>')
    $writer.WriteLine('  <p class="service-description">Below are provider names that were discovered (i.e., via Get-AzProviderFeatures) but which have no discernable operations.</p>')
    $writer.WriteLine('  <details id="otherProvidersDetails">')
    $writer.WriteLine('    <summary>Providers (' + $otherProviders.Count + ')</summary>')
    $writer.WriteLine('    <div class="table-scroll"><table class="other-providers"><thead><tr><th>ProviderName</th><th>ProviderNamespace</th><th>Description</th></tr></thead><tbody>')
    foreach ($provider in $otherProviders) {
        $writer.WriteLine('      <tr><td>' + (Encode-Html $provider.ProviderName) + '</td><td>' +
            (Encode-Html $provider.ProviderNamespace) + '</td><td>' +
            (Encode-Html $provider.Description) + '</td></tr>')
    }
    $writer.WriteLine('    </tbody></table></div>')
    $writer.WriteLine('  </details>')
    $writer.WriteLine('</section>')

    $htmlFooter = @'
<p id="noResults" class="no-results" hidden>No matching providers or operations.</p>
</div>
<script>
(function () {
    'use strict';
    const filter = document.getElementById('serviceFilter');
    const noResults = document.getElementById('noResults');

    // Index main sections separately from the single Other Providers table.
    // Main searches include provider headings and operation identifiers/names.
    const index = Array.from(document.querySelectorAll('section.service[data-search]'), function (section) {
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

    const otherSection = document.getElementById('otherProviders');
    const otherDivider = document.getElementById('otherProvidersDivider');
    const otherDetails = document.getElementById('otherProvidersDetails');
    const otherRows = Array.from(otherSection.querySelectorAll('tbody tr'), function (row) {
        return { row: row, searchable: row.textContent.toLowerCase() };
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

        let otherMatches = 0;
        otherRows.forEach(function (entry) {
            const visible = !query || entry.searchable.includes(query);
            entry.row.hidden = !visible;
            if (visible) otherMatches++;
        });
        otherSection.hidden = Boolean(query) && otherMatches === 0;
        otherDivider.hidden = otherSection.hidden;
        // Expand the table when a search matches a provider listed only here.
        if (query && otherMatches > 0) otherDetails.open = true;
        noResults.hidden = matches > 0 || otherMatches > 0;
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
Write-Host "Providers with operations: $($services.Count); other providers: $($otherProviders.Count); operations: $actionCount; providers found only in AzureServiceActions.csv: $actionOnlyProviderCount"
