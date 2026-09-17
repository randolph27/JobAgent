#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$verifyLogicPath = Join-Path $projectRoot '.ci\bin\modules\verify-logic.ps1'
$todoEnginePath = Join-Path $projectRoot '.ci\bin\modules\todo-engine.ps1'
$handoffPath = Join-Path $projectRoot 'handoff.latest.json'
$handoffMarkdownPath = Join-Path $projectRoot 'handoff.latest.md'

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)

    if (-not $Condition) { throw $Message }
}

function Assert-Contains {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$Message
    )

    Assert-True -Condition ($Text -match $Pattern) -Message $Message
}

Assert-True -Condition (Test-Path -LiteralPath $verifyLogicPath -PathType Leaf) -Message 'CI-005-Verifikationslogik fehlt.'
Assert-True -Condition (Test-Path -LiteralPath $todoEnginePath -PathType Leaf) -Message 'CI-005-Todo-Engine fehlt.'
Assert-True -Condition (Test-Path -LiteralPath $handoffPath -PathType Leaf) -Message 'CI-005-Handoff-JSON fehlt.'
Assert-True -Condition (Test-Path -LiteralPath $handoffMarkdownPath -PathType Leaf) -Message 'CI-005-Handoff-Markdown fehlt.'

$verifyLogic = Get-Content -LiteralPath $verifyLogicPath -Raw
$todoEngine = Get-Content -LiteralPath $todoEnginePath -Raw
$handoff = Get-Content -LiteralPath $handoffPath -Raw | ConvertFrom-Json -Depth 30
$handoffMarkdown = Get-Content -LiteralPath $handoffMarkdownPath -Raw

Assert-Contains -Text $verifyLogic -Pattern 'function Invoke-SelfCheck' -Message 'CI-005-Self-Check-Einstieg fehlt.'
Assert-Contains -Text $verifyLogic -Pattern 'Read-ImmutablePins' -Message 'CI-005 liest keine Immutable-Pins.'
Assert-Contains -Text $verifyLogic -Pattern 'immutable_modified:' -Message 'CI-005 meldet geänderte Immutable-Dateien nicht.'
Assert-Contains -Text $verifyLogic -Pattern 'immutable_not_readonly:' -Message 'CI-005 prüft ReadOnly-Attribute nicht.'
Assert-Contains -Text $verifyLogic -Pattern 'handoff_invariant: markdown parity missing value' -Message 'CI-005 prüft die Handoff-Markdown-Parität nicht.'
Assert-Contains -Text $verifyLogic -Pattern 'handoff_invariant: capsule mismatch' -Message 'CI-005 prüft die Capsule-Parität nicht.'
Assert-Contains -Text $todoEngine -Pattern 'function Normalize-TodoState' -Message 'CI-005-Todo-Normalisierung fehlt.'
Assert-Contains -Text $todoEngine -Pattern 'function Render-TodoCurrent' -Message 'CI-005-Todo-Ansichtsgenerator fehlt.'

$git = $handoff.git
$capsule = $handoff.capsule
Assert-True -Condition ($null -ne $git) -Message 'CI-005-Handoff enthält keinen Git-Snapshot.'
Assert-True -Condition ($null -ne $capsule) -Message 'CI-005-Handoff enthält keine Capsule.'
foreach ($field in @('branch', 'head', 'upstream', 'ahead', 'behind', 'worktree', 'tracked_changes')) {
    Assert-True -Condition ($git.PSObject.Properties.Name -contains $field) -Message ('CI-005-Handoff-Gitfeld fehlt: ' + $field)
}
foreach ($field in @('active_id', 'status', 'goal', 'next', 'route_ok')) {
    Assert-True -Condition ($handoff.PSObject.Properties.Name -contains $field) -Message ('CI-005-Handofffeld fehlt: ' + $field)
    Assert-True -Condition ($capsule.PSObject.Properties.Name -contains $field) -Message ('CI-005-Capsulefeld fehlt: ' + $field)
    Assert-True -Condition ([string]$handoff.$field -eq [string]$capsule.$field) -Message ('CI-005-Capsule-Parität verletzt: ' + $field)
}
foreach ($value in @([string]$handoff.active_id, [string]$git.branch, [string]$git.head, [string]$git.worktree)) {
    if ($value) { Assert-True -Condition $handoffMarkdown.Contains($value) -Message ('CI-005-Handoff-Markdown fehlt Wert: ' + $value) }
}

[pscustomobject]@{
    status = 'ok'
    cases = @('immutable_contract', 'immutable_readonly_contract', 'todo_normalization_contract', 'handoff_git_contract', 'handoff_capsule_parity', 'handoff_markdown_parity')
} | ConvertTo-Json -Compress
