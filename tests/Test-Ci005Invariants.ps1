#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$fixtureItems = @(
    '.ci',
    'ci.cmd',
    'README.md',
    'Roadmap.md',
    'manual',
    'todo.checkpoint.json',
    'todo.current.md',
    'todo.events.jsonl',
    'todo.history.digest.json',
    'todo.master.index.json',
    'todo.state.json',
    'handoff.latest.json',
    'handoff.latest.md'
)

function Assert-True {
    param([bool]$Condition, [string]$Message)

    if (-not $Condition) {
        throw $Message
    }
}

function Copy-FixtureItem {
    param([string]$SourceRoot, [string]$DestinationRoot, [string]$RelativePath)

    $source = Join-Path $SourceRoot $RelativePath
    $destination = Join-Path $DestinationRoot $RelativePath
    Assert-True (Test-Path -LiteralPath $source) ('Fixture source missing: ' + $RelativePath)

    $parent = Split-Path -Parent $destination
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
}

function New-Ci005Fixture {
    param([string]$SourceRoot)

    $fixtureName = 'JobAgent-CI005-' + [guid]::NewGuid().ToString('N')
    $fixture = Join-Path ([IO.Path]::GetTempPath()) $fixtureName
    New-Item -ItemType Directory -Path $fixture -Force | Out-Null

    foreach ($relativePath in $fixtureItems) {
        Copy-FixtureItem $SourceRoot $fixture $relativePath
    }

    Get-ChildItem -LiteralPath $fixture -File -Recurse -Force | ForEach-Object {
        $_.IsReadOnly = $false
    }

    return $fixture
}

function Invoke-FixtureSelfCheck {
    param([string]$Fixture)

    & (Join-Path $Fixture 'ci.cmd') self-check *> $null
    return $LASTEXITCODE
}

function Get-LatestFixtureSelfCheckReport {
    param([string]$Fixture)

    $terminalLogDirectory = Join-Path $Fixture 'logs\terminal'
    $report = Get-ChildItem -LiteralPath $terminalLogDirectory -Filter 'self-check-*.log' -File |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
    Assert-True ($null -ne $report) 'Fixture self-check report missing.'
    return Get-Content -LiteralPath $report.FullName -Raw
}

function Set-FixtureProgramModified {
    param([string]$Fixture)

    $programPath = Join-Path $Fixture 'manual\PROGRAM.md'
    (Get-Item -LiteralPath $programPath -Force).IsReadOnly = $false
    Add-Content -LiteralPath $programPath -Value 'CI-005 negative invariant fixture.'
}

function Remove-FixtureHandoffMarkdownValue {
    param([string]$Fixture, [string]$GitField)

    $handoffPath = Join-Path $Fixture 'handoff.latest.json'
    $handoffMarkdownPath = Join-Path $Fixture 'handoff.latest.md'
    $handoff = Get-Content -LiteralPath $handoffPath -Raw | ConvertFrom-Json
    $value = [string]$handoff.git.$GitField
    Assert-True (-not [string]::IsNullOrWhiteSpace($value)) ('Fixture handoff git.' + $GitField + ' missing.')

    $markdown = Get-Content -LiteralPath $handoffMarkdownPath -Raw
    Assert-True ($markdown.Contains($value)) ('Fixture handoff markdown does not contain git.' + $GitField + '.')
    $updatedMarkdown = $markdown.Replace($value, '')
    Set-Content -LiteralPath $handoffMarkdownPath -Value $updatedMarkdown -NoNewline -Encoding utf8
}

$cases = @(
    [pscustomobject]@{
        Name = 'immutable_modified'
        GitField = $null
        ExpectedIssue = 'immutable_modified: manual\PROGRAM.md'
        Mutate = { param([string]$Fixture) Set-FixtureProgramModified $Fixture }
    },
    [pscustomobject]@{
        Name = 'handoff_branch_missing'
        GitField = 'branch'
        ExpectedIssue = $null
        Mutate = { param([string]$Fixture) Remove-FixtureHandoffMarkdownValue $Fixture 'branch' }
    },
    [pscustomobject]@{
        Name = 'handoff_head_missing'
        GitField = 'head'
        ExpectedIssue = $null
        Mutate = { param([string]$Fixture) Remove-FixtureHandoffMarkdownValue $Fixture 'head' }
    },
    [pscustomobject]@{
        Name = 'handoff_worktree_missing'
        GitField = 'worktree'
        ExpectedIssue = $null
        Mutate = { param([string]$Fixture) Remove-FixtureHandoffMarkdownValue $Fixture 'worktree' }
    }
)

$validatedCases = New-Object System.Collections.Generic.List[string]
foreach ($case in $cases) {
    $fixture = New-Ci005Fixture $projectRoot
    try {
        $baselineExit = Invoke-FixtureSelfCheck $fixture
        Assert-True ($baselineExit -eq 0) ('Fixture baseline self-check failed for ' + $case.Name + '.')

        & $case.Mutate $fixture
        $exitCode = Invoke-FixtureSelfCheck $fixture
        Assert-True ($exitCode -eq 1) ('Fixture self-check must fail for ' + $case.Name + '.')

        $report = Get-LatestFixtureSelfCheckReport $fixture
        if ($case.GitField) {
            $handoff = Get-Content -LiteralPath (Join-Path $fixture 'handoff.latest.json') -Raw | ConvertFrom-Json
            $expectedIssue = 'handoff_invariant: markdown parity missing value ' + [string]$handoff.git.($case.GitField)
        } else {
            $expectedIssue = $case.ExpectedIssue
        }
        Assert-True ($report.Contains($expectedIssue)) ('Expected issue missing for ' + $case.Name + ': ' + $expectedIssue)
        $validatedCases.Add($case.Name)
    } finally {
        if (Test-Path -LiteralPath $fixture) {
            Remove-Item -LiteralPath $fixture -Recurse -Force
        }
    }
}

[pscustomobject]@{
    status = 'ok'
    cases = @($validatedCases)
} | ConvertTo-Json -Compress
