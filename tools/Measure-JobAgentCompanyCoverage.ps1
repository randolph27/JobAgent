#requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter()][string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [Parameter()][string]$DataRoot = 'data/jobagent',
    [Parameter()][string]$LogRoot = 'logs/jobagent',
    [Parameter()][string]$HtmlRoot = 'html/jobagent',
    [Parameter()][string]$SourceRegistryPath = 'data/jobagent/company-discovery.sources.json',
    [Parameter()][string]$HintStorePath = 'data/jobagent/company-discovery.hints.json',
    [Parameter()][ValidateRange(1, 3650)][int]$StaleAfterDays = 7,
    [Parameter()][ValidateRange(1, 1000)][int]$MaxPriorityItems = 25
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$projectRoot = [IO.Path]::GetFullPath($ProjectRoot)

Import-Module (Join-Path $repoRoot 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $repoRoot 'src\JobAgent.Coverage.psm1') -Force -DisableNameChecking

function Resolve-ToolPath {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Path
    )

    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }
    return [IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function ConvertTo-ToolHtmlText {
    param([Parameter()][AllowNull()][object]$Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return 'UNKNOWN'
    }
    return [Net.WebUtility]::HtmlEncode(([string]$Value).Trim())
}

function ConvertTo-ToolMarkdownText {
    param([Parameter()][AllowNull()][object]$Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return 'UNKNOWN'
    }
    return (([string]$Value).Trim() -replace '\|', '\|' -replace "`r?`n", ' ')
}

function Add-ToolMarkdownCounts {
    param(
        [Parameter(Mandatory)][object]$Lines,
        [Parameter(Mandatory)][string]$Title,
        [Parameter()][AllowNull()][object]$Counts
    )

    [void]$Lines.Add("### $Title")
    [void]$Lines.Add('| Wert | Anzahl |')
    [void]$Lines.Add('|---|---:|')
    if ($null -eq $Counts) {
        [void]$Lines.Add('| UNKNOWN | 0 |')
        return
    }
    foreach ($property in @($Counts.PSObject.Properties | Sort-Object Name)) {
        [void]$Lines.Add(('| {0} | {1} |' -f (ConvertTo-ToolMarkdownText $property.Name), $property.Value))
    }
}

function ConvertTo-ToolCoverageMarkdown {
    param([Parameter(Mandatory)][object]$Coverage)

    $lines = [System.Collections.Generic.List[string]]::new()
    [void]$lines.Add('# JobAgent Firmen-Coverage-Audit')
    [void]$lines.Add('')
    [void]$lines.Add("- Generiert: $($Coverage.generated_at)")
    [void]$lines.Add("- Hinweis: $($Coverage.approximation_notice)")
    [void]$lines.Add('')
    [void]$lines.Add('## Kernmetriken')
    [void]$lines.Add('| Metrik | Wert |')
    [void]$lines.Add('|---|---:|')
    foreach ($metric in @('companies_total', 'career_url_verified', 'company_domain_verified', 'unverified', 'manual_review_required', 'retry_required', 'duplicate_groups', 'discovery_hints_total', 'unverified_discovery_hints')) {
        [void]$lines.Add(('| {0} | {1} |' -f $metric, $Coverage.metrics.$metric))
    }
    [void]$lines.Add('')
    Add-ToolMarkdownCounts -Lines $lines -Title 'Reviewstatus' -Counts $Coverage.dimensions.by_inventory_state
    [void]$lines.Add('')
    Add-ToolMarkdownCounts -Lines $lines -Title 'Zielgebiet' -Counts $Coverage.dimensions.by_target_area
    [void]$lines.Add('')
    Add-ToolMarkdownCounts -Lines $lines -Title 'Branche' -Counts $Coverage.dimensions.by_industry
    [void]$lines.Add('')
    Add-ToolMarkdownCounts -Lines $lines -Title 'Quellenursprung' -Counts $Coverage.dimensions.by_discovery_origin
    [void]$lines.Add('')
    [void]$lines.Add('## Importwellen')
    foreach ($wave in @($Coverage.import_waves.waves)) {
        [void]$lines.Add('')
        [void]$lines.Add("### Welle $($wave.wave_id): $($wave.title)")
        [void]$lines.Add("- Abhaengigkeit: $($wave.dependency)")
        [void]$lines.Add("- Meilenstein: $($wave.milestone)")
        [void]$lines.Add("- Prioritaetsscore: $($wave.priority_score)")
        [void]$lines.Add('| Typ | Firma | Zielgebiet | Branche | Status | Naechster Schritt |')
        [void]$lines.Add('|---|---|---|---|---|---|')
        foreach ($candidate in @($wave.candidates)) {
            [void]$lines.Add(('| {0} | {1} | {2} | {3} | {4} | {5} |' -f
                    (ConvertTo-ToolMarkdownText $candidate.kind),
                    (ConvertTo-ToolMarkdownText $candidate.company),
                    (ConvertTo-ToolMarkdownText $candidate.target_area),
                    (ConvertTo-ToolMarkdownText $candidate.industry),
                    (ConvertTo-ToolMarkdownText $candidate.review_status),
                    (ConvertTo-ToolMarkdownText $candidate.next_step)))
        }
    }
    [void]$lines.Add('')
    [void]$lines.Add('## Backlog')
    [void]$lines.Add('| Score | Typ | Firma | Begruendung | Naechster Schritt |')
    [void]$lines.Add('|---:|---|---|---|---|')
    foreach ($item in @($Coverage.backlog | Select-Object -First 25)) {
        [void]$lines.Add(('| {0} | {1} | {2} | {3} | {4} |' -f
                $item.priority_score,
                (ConvertTo-ToolMarkdownText $item.kind),
                (ConvertTo-ToolMarkdownText $item.company),
                (ConvertTo-ToolMarkdownText $item.reason),
                (ConvertTo-ToolMarkdownText $item.next_step)))
    }
    return ($lines.ToArray() -join "`n")
}

function Add-ToolHtmlCounts {
    param(
        [Parameter(Mandatory)][object]$Lines,
        [Parameter(Mandatory)][string]$Title,
        [Parameter()][AllowNull()][object]$Counts
    )

    [void]$Lines.Add('<section><h2>' + (ConvertTo-ToolHtmlText $Title) + '</h2><div class="table-wrap"><table><thead><tr><th>Wert</th><th>Anzahl</th></tr></thead><tbody>')
    foreach ($property in @($Counts.PSObject.Properties | Sort-Object Name)) {
        [void]$Lines.Add('<tr><td>' + (ConvertTo-ToolHtmlText $property.Name) + '</td><td>' + (ConvertTo-ToolHtmlText $property.Value) + '</td></tr>')
    }
    [void]$Lines.Add('</tbody></table></div></section>')
}

function ConvertTo-ToolCoverageHtml {
    param([Parameter(Mandatory)][object]$Coverage)

    $lines = [System.Collections.Generic.List[string]]::new()
    [void]$lines.Add('<!DOCTYPE html><html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">')
    [void]$lines.Add('<title>JobAgent Firmen-Coverage-Audit</title><style>')
    [void]$lines.Add(':root { color-scheme: light; --bg: #eef2f5; --surface: #ffffff; --surface-alt: #f6f8fa; --line: #c8d1dc; --text: #17202a; --muted: #52616f; --accent: #0f6b6d; --accent-alt: #8a5a00; }')
    [void]$lines.Add('* { box-sizing: border-box; } body { margin: 0; font-family: "Segoe UI", Tahoma, sans-serif; background: var(--bg); color: var(--text); } main { max-width: 1440px; margin: 0 auto; padding: 24px 16px 40px; } section { background: var(--surface); border: 1px solid var(--line); border-radius: 8px; padding: 16px; margin-bottom: 16px; } h1, h2, h3 { margin: 0 0 12px; line-height: 1.2; letter-spacing: 0; } h1 { font-size: 2rem; color: var(--accent); } h2 { font-size: 1.25rem; } p { line-height: 1.5; } .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); gap: 10px; } .metric { background: var(--surface-alt); border: 1px solid var(--line); border-radius: 6px; padding: 10px; min-width: 0; } .label { display: block; color: var(--muted); font-size: .86rem; } .value { display: block; font-weight: 700; overflow-wrap: anywhere; } .table-wrap { overflow-x: auto; } table { width: 100%; min-width: 760px; border-collapse: collapse; } th, td { text-align: left; vertical-align: top; padding: 9px 10px; border-bottom: 1px solid var(--line); overflow-wrap: anywhere; } th { background: #e8eef3; } .wave { border-left: 4px solid var(--accent-alt); } @media (max-width: 800px) { main { padding: 14px 10px 28px; } section { padding: 12px; } table { min-width: 680px; } }')
    [void]$lines.Add('</style></head><body><main>')
    [void]$lines.Add('<section><h1>JobAgent Firmen-Coverage-Audit</h1><p>' + (ConvertTo-ToolHtmlText $Coverage.approximation_notice) + '</p><div class="summary">')
    foreach ($metric in @('companies_total', 'career_url_verified', 'company_domain_verified', 'unverified', 'manual_review_required', 'retry_required', 'duplicate_groups', 'discovery_hints_total', 'unverified_discovery_hints')) {
        [void]$lines.Add('<div class="metric"><span class="label">' + (ConvertTo-ToolHtmlText $metric) + '</span><span class="value">' + (ConvertTo-ToolHtmlText $Coverage.metrics.$metric) + '</span></div>')
    }
    [void]$lines.Add('</div></section>')
    Add-ToolHtmlCounts -Lines $lines -Title 'Reviewstatus' -Counts $Coverage.dimensions.by_inventory_state
    Add-ToolHtmlCounts -Lines $lines -Title 'Zielgebiet' -Counts $Coverage.dimensions.by_target_area
    Add-ToolHtmlCounts -Lines $lines -Title 'Branche' -Counts $Coverage.dimensions.by_industry
    [void]$lines.Add('<section><h2>Importwellen</h2>')
    foreach ($wave in @($Coverage.import_waves.waves)) {
        [void]$lines.Add('<div class="wave"><h3>Welle ' + (ConvertTo-ToolHtmlText $wave.wave_id) + ': ' + (ConvertTo-ToolHtmlText $wave.title) + '</h3><p>Abhaengigkeit: ' + (ConvertTo-ToolHtmlText $wave.dependency) + ' | Meilenstein: ' + (ConvertTo-ToolHtmlText $wave.milestone) + ' | Score: ' + (ConvertTo-ToolHtmlText $wave.priority_score) + '</p>')
        [void]$lines.Add('<div class="table-wrap"><table><thead><tr><th>Typ</th><th>Firma</th><th>Zielgebiet</th><th>Branche</th><th>Status</th><th>Naechster Schritt</th></tr></thead><tbody>')
        foreach ($candidate in @($wave.candidates)) {
            [void]$lines.Add('<tr><td>' + (ConvertTo-ToolHtmlText $candidate.kind) + '</td><td>' + (ConvertTo-ToolHtmlText $candidate.company) + '</td><td>' + (ConvertTo-ToolHtmlText $candidate.target_area) + '</td><td>' + (ConvertTo-ToolHtmlText $candidate.industry) + '</td><td>' + (ConvertTo-ToolHtmlText $candidate.review_status) + '</td><td>' + (ConvertTo-ToolHtmlText $candidate.next_step) + '</td></tr>')
        }
        [void]$lines.Add('</tbody></table></div></div>')
    }
    [void]$lines.Add('</section></main></body></html>')
    return ($lines.ToArray() -join "`n")
}

$sourceRegistry = $null
$sourceRegistryResolved = Resolve-ToolPath -Root $projectRoot -Path $SourceRegistryPath
if (Test-Path -LiteralPath $sourceRegistryResolved -PathType Leaf) {
    $sourceRegistry = Get-Content -Raw -LiteralPath $sourceRegistryResolved | ConvertFrom-Json -Depth 100
}

$hintStore = $null
$hintStoreResolved = Resolve-ToolPath -Root $projectRoot -Path $HintStorePath
if (Test-Path -LiteralPath $hintStoreResolved -PathType Leaf) {
    $hintStore = Get-Content -Raw -LiteralPath $hintStoreResolved | ConvertFrom-Json -Depth 100
}

$generatedAt = [datetime]::UtcNow
$document = Read-JobAgentStore -ProjectRoot $projectRoot -DataRoot $DataRoot
$coverage = New-JobAgentCoverageReport -Document $document -SourceRegistry $sourceRegistry -HintStore $hintStore -Now $generatedAt -StaleAfterDays $StaleAfterDays -MaxPriorityItems $MaxPriorityItems
$stamp = $generatedAt.ToString('yyyyMMdd-HHmmss', [Globalization.CultureInfo]::InvariantCulture)

$logRootPath = Resolve-ToolPath -Root $projectRoot -Path $LogRoot
$htmlRootPath = Resolve-ToolPath -Root $projectRoot -Path $HtmlRoot
New-Item -ItemType Directory -Path $logRootPath -Force | Out-Null
New-Item -ItemType Directory -Path $htmlRootPath -Force | Out-Null

$jsonPath = Join-Path $logRootPath "company-coverage-$stamp.json"
$markdownPath = Join-Path $logRootPath "company-coverage-$stamp.md"
$htmlPath = Join-Path $htmlRootPath 'company-coverage.html'

$coverage | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
ConvertTo-ToolCoverageMarkdown -Coverage $coverage | Set-Content -LiteralPath $markdownPath -Encoding UTF8
ConvertTo-ToolCoverageHtml -Coverage $coverage | Set-Content -LiteralPath $htmlPath -Encoding UTF8

[pscustomobject]@{
    status = 'ok'
    generated_at = $coverage.generated_at
    json_path = $jsonPath
    markdown_path = $markdownPath
    html_path = $htmlPath
    companies_total = $coverage.metrics.companies_total
    backlog_items = @($coverage.backlog).Count
    duplicate_groups = $coverage.metrics.duplicate_groups
    import_waves = @($coverage.import_waves.waves).Count
} | ConvertTo-Json -Depth 6
