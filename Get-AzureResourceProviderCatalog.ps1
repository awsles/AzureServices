#requires -Version 5.1
<#
.SYNOPSIS
    Exports the resource-provider overview on Microsoft Learn to CSV.
.DESCRIPTION
    Creates one row per provider/Azure-service combination. A provider with no
    linked service still gets one row. The page's h2 headings supply Category.
.EXAMPLE
    .\Get-AzureResourceProviderCatalog.ps1 -OutputPath docs\AzureResourceProviders.csv
#>
[CmdletBinding()]
param(
    [string]$Url = 'https://learn.microsoft.com/en-us/azure/role-based-access-control/resource-provider-operations',
    [string]$OutputPath = 'docs\AzureResourceProviders.csv'
)

$ErrorActionPreference = 'Stop'
$baseUri = [Uri]$Url

function Get-PlainText {
    param([AllowEmptyString()][string]$Html)
    $value = $Html -replace '(?is)<(?:script|style)\b[^>]*>.*?</(?:script|style)>', ' '
    $value = $value -replace '(?is)<[^>]+>', ' '
    $value = [System.Net.WebUtility]::HtmlDecode($value)
    return ($value -replace '[\s\u00A0]+', ' ').Trim()
}

function Resolve-HtmlLink {
    param([string]$Href)
    if ([string]::IsNullOrWhiteSpace($Href)) { return '' }
    $decoded = [System.Net.WebUtility]::HtmlDecode($Href)
    try { return ([Uri]::new($baseUri, $decoded)).AbsoluteUri }
    catch { Write-Warning "Skipping invalid URL: $decoded"; return '' }
}

function Get-HtmlAnchors {
    param([AllowEmptyString()][string]$Html)
    $pattern = '(?is)<a\b[^>]*?\bhref\s*=\s*(?:"(?<href>[^"]*)"|''(?<href>[^'']*)''|(?<href>[^\s>]+))[^>]*>(?<text>.*?)</a>'
    foreach ($match in [regex]::Matches($Html, $pattern)) {
        $label = Get-PlainText $match.Groups['text'].Value
        if ($label) {
            [pscustomobject]@{
                Text = $label
                Url  = Resolve-HtmlLink $match.Groups['href'].Value
            }
        }
    }
}

Write-Verbose "Fetching $Url"
$response = Invoke-WebRequest -Uri $Url -UseBasicParsing -ErrorAction Stop
$html = [string]$response.Content

# Scan headings in document order so each following table keeps its category.
$headings = [regex]::Matches($html, '(?is)<h2\b[^>]*>(?<title>.*?)</h2>')
$results = [System.Collections.Generic.List[object]]::new()

for ($i = 0; $i -lt $headings.Count; $i++) {
    $heading = $headings[$i]
    $category = Get-PlainText $heading.Groups['title'].Value
    $start = $heading.Index + $heading.Length
    $end = if ($i + 1 -lt $headings.Count) { $headings[$i + 1].Index } else { $html.Length }
    $sectionHtml = $html.Substring($start, $end - $start)

    $table = [regex]::Match($sectionHtml, '(?is)<table\b[^>]*>(?<body>.*?)</table>')
    if (-not $table.Success) { continue }

    foreach ($tr in [regex]::Matches($table.Groups['body'].Value, '(?is)<tr\b[^>]*>(?<body>.*?)</tr>')) {
        $cells = [regex]::Matches($tr.Groups['body'].Value, '(?is)<td\b[^>]*>(?<body>.*?)</td>')
        if ($cells.Count -lt 3) { continue } # Ignore header rows.

        $providerCell = $cells[0].Groups['body'].Value
        $description = Get-PlainText $cells[1].Groups['body'].Value
        $serviceCell = $cells[2].Groups['body'].Value

        $providerLinks = @(Get-HtmlAnchors $providerCell)
        $resourceProvider = if ($providerLinks.Count) { $providerLinks[0].Text } else { Get-PlainText $providerCell }
        $providerUrl = if ($providerLinks.Count) { $providerLinks[0].Url } else { '' }
        if (-not $resourceProvider) { continue }

        $services = @(Get-HtmlAnchors $serviceCell)
        if ($services.Count -eq 0) {
            # Handles unlinked values such as "core", or an empty Azure service.
            $services = @([pscustomobject]@{ Text = (Get-PlainText $serviceCell); Url = '' })
        }

        foreach ($service in $services) {
            $results.Add([pscustomobject][ordered]@{
                ResourceProvider     = $resourceProvider
                Description          = $description
                AzureService         = $service.Text
                Category             = $category
                ResourceProviderLink = $providerUrl
                AzureServiceLink     = $service.Url
            })
        }
    }
}

if ($results.Count -eq 0) {
    throw 'No resource-provider rows found. The Microsoft Learn page structure may have changed.'
}

$destination = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
$parent = Split-Path -Parent $destination
if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}
$results | Export-Csv -LiteralPath $destination -NoTypeInformation -Encoding UTF8
Write-Host "Exported $($results.Count) rows to $destination"
