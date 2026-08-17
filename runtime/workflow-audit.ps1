#requires -Version 7.4

Set-StrictMode -Version 3.0

function Invoke-WorkflowAudit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [switch]$AsJson
    )

    $resolvedRoot = [IO.Path]::GetFullPath($RepoRoot)
    $issues = [Collections.Generic.List[object]]::new()
    $metrics = [ordered]@{}

    function Add-WorkflowIssue {
        param(
            [Parameter(Mandatory)][ValidateSet('error', 'warning', 'info')][string]$Severity,
            [Parameter(Mandatory)][string]$Code,
            [Parameter(Mandatory)][string]$Path,
            [Parameter(Mandatory)][string]$Detail
        )

        $issues.Add([pscustomobject]@{
                severity = $Severity
                code = $Code
                path = $Path.Replace('\', '/')
                detail = $Detail
            })
    }

    function Read-JsonArtifact {
        param([Parameter(Mandatory)][string]$RelativePath)

        $path = Join-Path $resolvedRoot $RelativePath
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
        try {
            return Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
        }
        catch {
            Add-WorkflowIssue error 'json.invalid' $RelativePath $_.Exception.Message
            return $null
        }
    }

    function Get-PropertyValue {
        param(
            $Object,
            [Parameter(Mandatory)][string]$Name,
            $Default = $null
        )

        if ($null -eq $Object) { return $Default }
        $property = $Object.PSObject.Properties[$Name]
        if ($null -eq $property) { return $Default }
        return $property.Value
    }

    function Get-RoadmapIds {
        param([Parameter(Mandatory)][string]$RelativePath)

        $path = Join-Path $resolvedRoot $RelativePath
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
        $ids = [Collections.Generic.List[string]]::new()
        foreach ($line in Get-Content -LiteralPath $path) {
            if ($line -match '^\s*(?:[-*]\s*)?\[(?: |x|X)\]\s*(?:\*\*)?([A-Z][A-Z0-9]+-\d+)\b') {
                $ids.Add($Matches[1])
            }
        }
        return @($ids)
    }

    $config = Read-JsonArtifact '.ci\ci.config.json'
    if ($null -ne $config) {
        $metrics['config_valid'] = $true
        $workspaceLock = Get-PropertyValue $config 'workspace_lock'
        if ($workspaceLock -is [string]) {
            Add-WorkflowIssue warning 'config.workspace_lock.legacy_string' '.ci/ci.config.json' 'workspace_lock sollte ein typisiertes Objekt mit on und stale_minutes sein.'
        }
        $features = Get-PropertyValue $config 'features'
        $topBrowser = Get-PropertyValue $config 'browser_tests'
        if ($null -ne $features -and $null -ne $topBrowser) {
            Add-WorkflowIssue warning 'config.features.duplicate_shape' '.ci/ci.config.json' 'features.browser_tests und browser_tests auf Top-Level konkurrieren.'
        }
    }

    $eventRelative = 'todo.events.jsonl'
    $eventPath = Join-Path $resolvedRoot $eventRelative
    $events = [Collections.Generic.List[object]]::new()
    $eventIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $oldest = $null
    $blankLines = 0
    if (Test-Path -LiteralPath $eventPath -PathType Leaf) {
        $lineNumber = 0
        foreach ($line in Get-Content -LiteralPath $eventPath) {
            $lineNumber++
            if ([string]::IsNullOrWhiteSpace($line)) {
                $blankLines++
                continue
            }
            try {
                $event = $line | ConvertFrom-Json
                $events.Add($event)
                $eventId = [string](Get-PropertyValue $event 'event_id' '')
                if (-not $eventId) {
                    Add-WorkflowIssue warning 'todo.event_id.missing' $eventRelative "Zeile $lineNumber hat keine event_id."
                }
                elseif (-not $eventIds.Add($eventId)) {
                    Add-WorkflowIssue error 'todo.event_id.duplicate' $eventRelative "Doppelte event_id in Zeile ${lineNumber}: $eventId"
                }
                $timestamp = [string](Get-PropertyValue $event 'ts' '')
                if ($timestamp) {
                    try {
                        $parsed = [DateTimeOffset]::Parse(
                            $timestamp,
                            [Globalization.CultureInfo]::InvariantCulture,
                            [Globalization.DateTimeStyles]::RoundtripKind
                        )
                        if ($null -eq $oldest -or $parsed -lt $oldest) { $oldest = $parsed }
                    }
                    catch {
                        Add-WorkflowIssue warning 'todo.timestamp.invalid' $eventRelative "Ungueltiger Zeitstempel in Zeile ${lineNumber}: $timestamp"
                    }
                }
            }
            catch {
                Add-WorkflowIssue error 'todo.jsonl.invalid' $eventRelative "Zeile ${lineNumber}: $($_.Exception.Message)"
            }
        }

        $eventBytes = (Get-Item -LiteralPath $eventPath -Force).Length
        $metrics['todo_event_lines'] = $lineNumber
        $metrics['todo_event_objects'] = $events.Count
        $metrics['todo_event_bytes'] = $eventBytes
        $metrics['todo_event_blank_lines'] = $blankLines
        if ($lineNumber -gt 50) {
            Add-WorkflowIssue warning 'todo.rotation.lines_exceeded' $eventRelative "Dokumentierter Grenzwert 50, aktuell $lineNumber."
        }
        if ($eventBytes -gt 25600) {
            Add-WorkflowIssue warning 'todo.rotation.bytes_exceeded' $eventRelative "Dokumentierter Grenzwert 25 KiB, aktuell $eventBytes Byte."
        }
        if ($null -ne $oldest -and ([DateTimeOffset]::Now - $oldest).TotalDays -gt 14) {
            Add-WorkflowIssue warning 'todo.rotation.age_exceeded' $eventRelative "Aeltestes Event ist aelter als 14 Tage: $($oldest.ToString('o'))."
        }
        if ($blankLines -gt 0) {
            Add-WorkflowIssue warning 'todo.jsonl.blank_lines' $eventRelative "$blankLines Leerzeilen im JSONL-Stream."
        }
    }

    $state = Read-JsonArtifact 'todo.state.json'
    $master = Read-JsonArtifact 'todo.master.index.json'
    $checkpoint = Read-JsonArtifact 'todo.checkpoint.json'
    $handoff = Read-JsonArtifact 'handoff.latest.json'

    if ($null -ne $master) {
        $legacyItems = @(Get-PropertyValue $master 'items' @())
        $canonicalTodos = @(Get-PropertyValue $master 'todos' @())
        $metrics['todo_master_items'] = $legacyItems.Count
        $metrics['todo_master_todos'] = $canonicalTodos.Count
        if ($legacyItems.Count -gt 0 -and $canonicalTodos.Count -gt 0) {
            Add-WorkflowIssue error 'todo.master.dual_schema' 'todo.master.index.json' "items=$($legacyItems.Count) und todos=$($canonicalTodos.Count) sind gleichzeitig befuellt."
        }
    }

    if ($null -ne $checkpoint) {
        $checkpointState = Get-PropertyValue $checkpoint 'state'
        $throughEventId = [string](Get-PropertyValue $checkpoint 'through_event_id' '')
        if (-not $throughEventId) {
            $throughEventId = [string](Get-PropertyValue $checkpoint 'checkpoint_event_id' '')
        }
        if (-not $throughEventId -and $null -ne $checkpointState) {
            $throughEventId = [string](Get-PropertyValue $checkpointState 'checkpoint_event_id' '')
        }
        $throughSequence = Get-PropertyValue $checkpoint 'through_sequence'
        if ($null -eq $checkpointState) {
            Add-WorkflowIssue error 'todo.checkpoint.state_missing' 'todo.checkpoint.json' 'Rebuild erwartet ein eingebettetes state-Objekt.'
        }
        if (-not $throughEventId -and $null -eq $throughSequence) {
            Add-WorkflowIssue error 'todo.checkpoint.boundary_missing' 'todo.checkpoint.json' 'Checkpoint besitzt weder through_event_id/checkpoint_event_id noch through_sequence.'
        }
    }

    if ($null -ne $state -and $null -ne $handoff) {
        $activeId = [string](Get-PropertyValue $state 'active_id' '')
        $handoffStatus = [string](Get-PropertyValue $handoff 'status' '')
        if ($activeId -and $handoffStatus -eq 'blocked') {
            $stateStatus = ''
            foreach ($item in @(Get-PropertyValue $state 'items' @())) {
                if ([string](Get-PropertyValue $item 'todo_id' '') -eq $activeId) {
                    $stateStatus = [string](Get-PropertyValue $item 'status' '')
                    break
                }
            }
            if ($stateStatus -and $stateStatus -ne 'blocked') {
                Add-WorkflowIssue error 'handoff.state.status_mismatch' 'handoff.latest.json' "Handoff=blocked, todo.state fuer $activeId=$stateStatus."
            }
        }
    }

    $roadmapIds = @(Get-RoadmapIds 'Roadmap.md')
    $archiveIds = @(Get-RoadmapIds 'Roadmap_archive.md')
    $metrics['roadmap_items'] = $roadmapIds.Count
    $metrics['roadmap_archive_items'] = $archiveIds.Count
    foreach ($group in @($roadmapIds | Group-Object | Where-Object Count -gt 1)) {
        Add-WorkflowIssue error 'roadmap.id.duplicate_active' 'Roadmap.md' "ID $($group.Name) erscheint $($group.Count)-mal."
    }
    foreach ($group in @($archiveIds | Group-Object | Where-Object Count -gt 1)) {
        Add-WorkflowIssue error 'roadmap.id.duplicate_archive' 'Roadmap_archive.md' "ID $($group.Name) erscheint $($group.Count)-mal."
    }
    $activeSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($id in $roadmapIds) { $null = $activeSet.Add([string]$id) }
    foreach ($id in @($archiveIds | Sort-Object -Unique)) {
        if ($activeSet.Contains($id)) {
            Add-WorkflowIssue error 'roadmap.id.active_archive_overlap' 'Roadmap.md' "ID $id ist aktiv und archiviert."
        }
    }

    $readmePath = Join-Path $resolvedRoot 'README.md'
    if (Test-Path -LiteralPath $readmePath -PathType Leaf) {
        $fences = @(Select-String -LiteralPath $readmePath -Pattern '^\s*```').Count
        $metrics['readme_code_fences'] = $fences
        if (($fences % 2) -ne 0) {
            Add-WorkflowIssue error 'readme.code_fence.unbalanced' 'README.md' "Ungerade Anzahl von Code-Fences: $fences."
        }
    }

    $errorCount = @($issues | Where-Object severity -eq 'error').Count
    $warningCount = @($issues | Where-Object severity -eq 'warning').Count
    $report = [ordered]@{
        schema = 'workflow-bootstrap-audit/v1'
        generated_utc = [DateTimeOffset]::UtcNow.ToString('o')
        repo_root = $resolvedRoot
        status = if ($errorCount -gt 0) { 'error' } elseif ($warningCount -gt 0) { 'warning' } else { 'ok' }
        errors = $errorCount
        warnings = $warningCount
        metrics = $metrics
        issues = @($issues)
    }

    if ($AsJson) {
        $report | ConvertTo-Json -Depth 12
    }
    else {
        Write-Output "workflow-audit: status=$($report.status) errors=$errorCount warnings=$warningCount"
        foreach ($issue in $issues) {
            Write-Output "[$($issue.severity.ToUpperInvariant())] $($issue.code) $($issue.path): $($issue.detail)"
        }
    }

    if ($errorCount -gt 0) {
        throw "Workflow-Audit meldet $errorCount Fehler. Es wurden keine Dateien geaendert."
    }
}
