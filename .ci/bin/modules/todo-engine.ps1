function Render-TodoCurrent([object]$state) {
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("# Todo (current)")
  $lines.Add("")
  $active = $state.active_id
  if ($active) { $lines.Add("Active: **$active**") } else { $lines.Add("Active: _(none)_") }
  $lines.Add("")
  $items = @()
  try { $items = $state.items } catch { $items = @() }
  if (-not $items -or $items.Count -eq 0) {
    $lines.Add("- (no items)")
  } else {
    foreach ($it in $items) {
      $id = Get-Prop $it "todo_id" $null
      if (-not $id) { $id = Get-Prop $it "id" "?" }
      $st = Get-Prop $it "status" "open"
      $msg = Get-Prop $it "title" ""
      $lines.Add("- [$st] $id $msg")
    }
  }
  return ($lines -join "`r`n") + "`r`n"
}

function Set-PropSafe([object]$o, [string]$name, [object]$value) {
  if ($null -eq $o) { return }
  if ($o -is [hashtable]) { $o[$name] = $value; return }
  try {
    if ($o.PSObject.Properties.Match($name).Count -gt 0) { $o.$name = $value }
    else { $o | Add-Member -NotePropertyName $name -NotePropertyValue $value -Force }
  } catch {
    try { $o | Add-Member -NotePropertyName $name -NotePropertyValue $value -Force } catch { $null = $_ }
  }
}

function Get-TodoStatePath()  { Join-Path $RepoRoot "todo.state.json" }
function Get-TodoEventsPath() { Join-Path $RepoRoot "todo.events.jsonl" }
function Get-TodoIndexPath()  { Join-Path $RepoRoot "todo.master.index.json" }
function Get-TodoDigestPath() { Join-Path $RepoRoot "todo.history.digest.json" }
function Get-TodoCheckpointPath() { Join-Path $RepoRoot "todo.checkpoint.json" }
function Get-TodoCurrentPath() { Join-Path $RepoRoot "todo.current.md" }
function Get-RoadmapArchivePath() { Join-Path $RepoRoot "Roadmap_archive.md" }

function Ensure-TodoEventsFile() {
  $p = Get-TodoEventsPath
  if (-not (Test-Path -LiteralPath $p)) { Atomic-WriteTextUtf8 $p "" }
}

function Load-TodoState() {
  $p = Get-TodoStatePath
  $st = Try-ReadJson $p
  if ($null -eq $st) {
    $st = @{ cursor=0; active_id=$null; items=@() }
    Write-Json $p $st
  }
  if ($null -eq (Get-Prop $st "items" $null)) { Set-PropSafe $st "items" @() }
  if ($null -eq (Get-Prop $st "cursor" $null)) { Set-PropSafe $st "cursor" 0 }
  return $st
}

function Normalize-TodoState([object]$st, [bool]$removeDone = $false) {
  if ($null -eq $st) { $st = @{ cursor=0; active_id=$null; items=@() } }
  $active = [string](Get-Prop $st "active_id" "")
  $byId = @{}
  $order = New-Object System.Collections.Generic.List[string]
  $maxCursor = 0
  try { $maxCursor = [int](Get-Prop $st "cursor" 0) } catch { $maxCursor = 0 }

  foreach ($item in @(Get-Prop $st "items" @())) {
    $id = [string](Get-Prop $item "todo_id" "")
    if (-not $id) { $id = [string](Get-Prop $item "id" "") }
    if (-not $id) { continue }
    if ($id -match '^TD-(\d+)$') {
      $number = 0
      try { $number = [int]$Matches[1] } catch { $number = 0 }
      if ($number -gt $maxCursor) { $maxCursor = $number }
    }
    $status = Normalize-TodoStatus ([string](Get-Prop $item "status" "open"))
    Set-PropSafe $item "todo_id" $id
    Set-PropSafe $item "status" $status
    if ($removeDone -and $status -eq "done") { continue }
    if (-not $byId.ContainsKey($id)) { $order.Add($id) }
    $byId[$id] = $item
  }

  if ($active -and -not $byId.ContainsKey($active)) { $active = "" }
  if (-not $active) {
    foreach ($id in $order) {
      if ([string](Get-Prop $byId[$id] "status" "") -eq "in-progress") { $active = $id; break }
    }
  }
  foreach ($id in $order) {
    $item = $byId[$id]
    if ([string](Get-Prop $item "status" "") -eq "in-progress" -and $id -ne $active) {
      Set-PropSafe $item "status" "open"
    }
  }

  Set-PropSafe $st "cursor" $maxCursor
  Set-PropSafe $st "active_id" $(if ($active) { $active } else { $null })
  Set-PropSafe $st "items" @($order | ForEach-Object { $byId[$_] })
  return $st
}

function Save-TodoState([object]$st) {
  $normalized = Normalize-TodoState $st $false
  Write-Json (Get-TodoStatePath) $normalized
  Atomic-WriteTextUtf8 (Get-TodoCurrentPath) (Render-TodoCurrent $normalized)
}

$script:TodoAllowedStatuses = @("open","in-progress","blocked","done")
$script:RoadmapSubtaskPrefixes = @(
  "Beschreibung:",
  "Scope:",
  "Ist-Stand (",
  "Schritte:",
  "Evidence:",
  "Funktionstest:",
  "Audit:",
  "Supertest:"
)

function Normalize-TodoStatus([string]$status, [string]$fallback = "open") {
  $value = [string]$status
  if (-not $value) { $value = $fallback }
  if ($value -notin $script:TodoAllowedStatuses) { $value = $fallback }
  return $value
}

function Get-TodoIndexId([object]$row) {
  $id = [string](Get-Prop $row "todo_id" $null)
  if (-not $id) { $id = [string](Get-Prop $row "id" $null) }
  return $id
}

function Get-TodoIndexStatus([object]$row) {
  $status = [string](Get-Prop $row "last_status" $null)
  if (-not $status) { $status = [string](Get-Prop $row "status" $null) }
  return (Normalize-TodoStatus $status "open")
}

function Normalize-TodoTimestamp([object]$value, [bool]$allowEmpty = $false) {
  if ($null -eq $value) {
    if ($allowEmpty) { return "" }
    return NowIso
  }
  if ($value -is [datetimeoffset]) { return $value.ToString("yyyy-MM-ddTHH:mm:ss.fffzzz") }
  if ($value -is [datetime]) {
    $dto = [datetimeoffset]::new($value)
    return $dto.ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
  }

  $text = [string]$value
  if (-not $text) {
    if ($allowEmpty) { return "" }
    return NowIso
  }

  $parsed = [datetimeoffset]::MinValue
  if ([datetimeoffset]::TryParse($text, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AllowWhiteSpaces, [ref]$parsed)) {
    return $parsed.ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
  }
  return $text
}

function Get-TodoIndexTimestamp([object]$row) {
  $last = [string](Get-Prop $row "last_ts" $null)
  if (-not $last) { $last = [string](Get-Prop $row "ts" $null) }
  return (Normalize-TodoTimestamp $last)
}

function Is-RoadmapSubtaskTitle([string]$title) {
  $t = [string]$title
  if (-not $t) { return $false }
  foreach ($prefix in $script:RoadmapSubtaskPrefixes) {
    if ($t.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
  }
  return $false
}

function Get-RoadmapTaskKey([string]$title) {
  $t = [string]$title
  if (-not $t) { return "" }
  if ($t -match '([A-Z]+-\d{3})') { return [string]$Matches[1] }
  return ""
}

function Get-RoadmapArchivedDoneKeys() {
  $p = Get-RoadmapArchivePath
  if (-not (Test-Path -LiteralPath $p)) { return @{} }
  $keys = @{}
  foreach ($line in (Get-Content -LiteralPath $p -ErrorAction SilentlyContinue)) {
    if ($line -notmatch '^\-\s*\[\s*x\s*\]\s*(.+)$') { continue }
    $key = Get-RoadmapTaskKey ([string]$Matches[1].Trim())
    if ($key) { $keys[$key] = $true }
  }
  return $keys
}

function Normalize-TodoIndexRows([object]$idx, [object]$state = $null) {
  if ($null -eq $idx) { $idx = @{ ts=NowIso; todos=@() } }
  if ($null -eq (Get-Prop $idx "todos" $null)) { Set-PropSafe $idx "todos" @() }

  $hasState = ($null -ne $state)
  $archivedDoneRoadmapKeys = Get-RoadmapArchivedDoneKeys
  $activeById = @{}
  if ($state) {
    foreach ($it in @($state.items)) {
      $id = [string](Get-Prop $it "todo_id" $null)
      if ($id) { $activeById[$id] = $it }
    }
  }

  $rowsById = @{}
  $order = New-Object System.Collections.Generic.List[string]
  foreach ($row in @($idx.todos)) {
    $id = Get-TodoIndexId $row
    if (-not $id) { continue }

    $title = [string](Get-Prop $row "title" "")
    if (-not $title) { continue }

    $status = Get-TodoIndexStatus $row
    if (-not $activeById.ContainsKey($id) -and $status -ne "done" -and (Is-RoadmapSubtaskTitle $title)) { continue }

    $source = [string](Get-Prop $row "source" "roadmap")
    $createdTs = Normalize-TodoTimestamp (Get-Prop $row "created_ts" $null) $true
    $prio = [string](Get-Prop $row "prio" "normal")
    $tags = @(Ensure-StringArray (Get-Prop $row "tags" @("roadmap")))
    $lastTs = Get-TodoIndexTimestamp $row

    if ($activeById.ContainsKey($id)) {
      $active = $activeById[$id]
      $title = [string](Get-Prop $active "title" $title)
      $status = Normalize-TodoStatus ([string](Get-Prop $active "status" $status))
      $source = [string](Get-Prop $active "source" $source)
      $createdTs = Normalize-TodoTimestamp (Get-Prop $active "created_ts" $createdTs) $true
      $lastTs = Normalize-TodoTimestamp (NowIso)
    } else {
      $roadmapKey = Get-RoadmapTaskKey $title
      if ($roadmapKey -and $status -ne "done" -and $archivedDoneRoadmapKeys.ContainsKey($roadmapKey)) {
        $status = "done"
        $lastTs = Normalize-TodoTimestamp (NowIso)
      }
    }

    $normalized = @{
      todo_id = $id
      title = $title
      last_status = $status
      prio = $prio
      tags = $tags
      source = $source
      created_ts = $createdTs
      last_ts = $lastTs
    }

    if (-not $rowsById.ContainsKey($id)) {
      $rowsById[$id] = $normalized
      $order.Add($id)
      continue
    }

    $existing = $rowsById[$id]
    $existingStatus = [string](Get-Prop $existing "last_status" "open")
    $existingTs = [string](Get-Prop $existing "last_ts" "")
    $replace = $false
    if ($existingStatus -ne "done" -and $status -eq "done") {
      $replace = $true
    } elseif ($lastTs -gt $existingTs) {
      $replace = $true
    }
    if ($replace) { $rowsById[$id] = $normalized }
  }

  foreach ($id in $activeById.Keys) {
    if ($rowsById.ContainsKey($id)) { continue }
    $active = $activeById[$id]
    $rowsById[$id] = @{
      todo_id = $id
      title = [string](Get-Prop $active "title" "")
      last_status = Normalize-TodoStatus ([string](Get-Prop $active "status" "open"))
      prio = "normal"
      tags = @("roadmap")
      source = [string](Get-Prop $active "source" "roadmap")
      created_ts = [string](Get-Prop $active "created_ts" (NowIso))
      last_ts = Normalize-TodoTimestamp (NowIso)
    }
    $order.Add($id)
  }

  $rows = New-Object System.Collections.Generic.List[object]
  foreach ($id in $order) {
    if (-not $rowsById.ContainsKey($id)) { continue }
    $row = $rowsById[$id]
    $status = [string](Get-Prop $row "last_status" "open")
    if ($hasState -and $status -ne "done" -and -not $activeById.ContainsKey($id)) {
      continue
    }
    $rows.Add($row)
  }

  $idx.todos = $rows.ToArray()
  return $idx
}

function Load-TodoIndex() {
  $p = Get-TodoIndexPath
  $idx = Try-ReadJson $p
  if ($null -eq $idx) { $idx = @{ ts=NowIso; todos=@() }; Write-Json $p $idx }
  if ($null -eq (Get-Prop $idx "todos" $null)) { Set-PropSafe $idx "todos" @() }
  return (Normalize-TodoIndexRows $idx)
}

function Save-TodoIndex([object]$idx) {
  $now = NowIso
  Set-PropSafe $idx "ts" $now
  Write-Json (Get-TodoIndexPath) $idx
}

function Sync-TodoCheckpointState([object]$state) {
  $path = Get-TodoCheckpointPath
  if (-not (Test-Path -LiteralPath $path)) { return }
  $checkpoint = Try-ReadJson $path
  if ($null -eq $checkpoint -or [string](Get-Prop $checkpoint "schema" "") -ne "todo-checkpoint-v2") { return }
  Set-PropSafe $checkpoint "state" (Normalize-TodoState $state $true)
  Set-PropSafe $checkpoint "history_archives" @(Ensure-StringArray (Get-Prop $state "history_archives" @()))
  Write-Json $path $checkpoint
}

function Append-TodoEvent([hashtable]$ev) {
  $p = Get-TodoEventsPath
  if (-not (Test-Path -LiteralPath $p)) { Atomic-WriteTextUtf8 $p "" }
  if ($null -eq $ev) { $ev = @{} }

  if (-not $ev.ContainsKey("ts") -or -not [string]$ev.ts) { $ev.ts = NowIso }
  if (-not $ev.ContainsKey("event_id") -or -not [string]$ev.event_id) { $ev.event_id = New-EventId }
  if (-not $ev.ContainsKey("todo_id") -or -not [string]$ev.todo_id) {
    try {
      $st = Load-TodoState
      $aid = [string](Get-Prop $st "active_id" "")
      if ($aid) { $ev.todo_id = $aid } else { $ev.todo_id = "SYSTEM" }
    } catch { $ev.todo_id = "SYSTEM" }
  }

  if (-not $ev.ContainsKey("type") -or -not [string]$ev.type) { $ev.type = "note" }
  if (-not $ev.ContainsKey("status") -or -not [string]$ev.status) { $ev.status = "open" }
  if (-not $ev.ContainsKey("prio") -or -not [string]$ev.prio) { $ev.prio = "low" }
  if (-not $ev.ContainsKey("source") -or -not [string]$ev.source) { $ev.source = $script:LastCmdName }
  if (-not $ev.ContainsKey("msg") -or $null -eq $ev.msg) { $ev.msg = "" } else { $ev.msg = [string]$ev.msg }

  $ev.refs    = Ensure-StringArray (Get-Prop $ev "refs" $null)
  $ev.changed = Ensure-StringArray (Get-Prop $ev "changed" $null)

  $v = Get-Prop $ev "verified" $null
  if ($null -eq $v) { $ev.verified = @() }
  elseif ($v -is [string]) { $ev.verified = @([string]$v) }
  else { try { $ev.verified = @($v) } catch { $ev.verified = @() } }

  $ev.git = To-Hashtable (Get-Prop $ev "git" $null)

  $line = (ConvertTo-Json $ev -Compress -Depth 8)
  Add-Content -LiteralPath $p -Value $line -Encoding UTF8
  return $ev
}

function Next-TodoId([object]$st) {
  $n = 0; try { $n = [int]$st.cursor } catch { $n = 0 }
  $n = $n + 1
  $st.cursor = $n
  return ("TD-" + $n.ToString("0000"))
}

function New-EventId() {
  $ts = TsId
  $g = ([guid]::NewGuid().ToString("N")).Substring(0,6)
  return ("EV-" + $ts + "-" + $g)
}

function Ensure-StringArray([object]$v) {
  if ($null -eq $v) { return @() }
  if ($v -is [string]) { return @([string]$v) }
  try { return @($v | ForEach-Object { [string]$_ }) } catch { return @() }
}

function To-Hashtable([object]$o) {
  if ($null -eq $o) { return @{} }
  if ($o -is [hashtable]) { return $o }
  $h = @{}
  try {
    foreach ($p in $o.PSObject.Properties) { $h[$p.Name] = $p.Value }
  } catch { $null = $_ }
  return $h
}

function Get-TodoConfig() {
  $cfg = Try-ReadJson (Get-ConfigPath)
  $t = Get-Prop $cfg "todo" $null
  if ($null -eq $t) { return @{ autoseed_from_roadmap=$true; seed_max_items=8 } }
  $auto = $true; try { $auto = [bool](Get-Prop $t "autoseed_from_roadmap" $true) } catch { $auto = $true }
  $max = 8; try { $max = [int](Get-Prop $t "seed_max_items" 8) } catch { $max = 8 }
  return @{ autoseed_from_roadmap=$auto; seed_max_items=$max }
}

function Parse-RoadmapOpenTasks() {
  $p = Join-Path $RepoRoot "Roadmap.md"
  if (-not (Test-Path -LiteralPath $p)) { return @() }
  $lines = Get-Content -LiteralPath $p -ErrorAction SilentlyContinue
  $sec = ""; $out = New-Object 'System.Collections.Generic.List[object]'
  foreach ($l in $lines) {
    if ($l -match '^\s*##\s+(.+)$') { $sec = $Matches[1].Trim(); continue }
    if ($l -match '^\-\s*\[\s*\]\s*(.+)$') {
      $txt = $Matches[1].Trim()
      if ($txt -and $txt -match '^[A-Z]+-\d{3}\b' -and $txt -match '#comment:') { [void]$out.Add(@{ section=$sec; text=$txt }) }
    }
  }
  return $out.ToArray()
}

function Cmd-TodoSeed() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; Ensure-ProjectStubs
  $tcfg = Get-TodoConfig; if (-not $tcfg.autoseed_from_roadmap) { CI-Info "todo-seed: autoseed disabled in ci.config.json"; return }
  $force = $false; try { if ($Args -and ($Args -contains "--force")) { $force = $true } } catch { $force = $false }
  $st = Load-TodoState; $items = @($st.items)
  if (-not $force -and $items.Count -gt 0) { CI-Info ("todo-seed: skipped (todo not empty, items=" + $items.Count + ")"); return }
  $cands = Parse-RoadmapOpenTasks; if (-not $cands -or $cands.Count -eq 0) { CI-Info "todo-seed: no open tasks in Roadmap.md"; return }
  $idx = Load-TodoIndex; $existingTitles = @()
  foreach ($it in @($items)) { $existingTitles += [string](Get-Prop $it "title" "") }
  foreach ($t in @($idx.todos)) { $existingTitles += [string](Get-Prop $t "title" "") }
  $max = [int]$tcfg.seed_max_items; $added = New-Object System.Collections.Generic.List[object]
  foreach ($c in $cands) {
    if ($added.Count -ge $max) { break }
    $sec = [string](Get-Prop $c "section" ""); $txt = [string](Get-Prop $c "text" ""); $title = $txt; if ($sec) { $title = $sec + ": " + $txt }
    if ($existingTitles -contains $title) { continue }
    $id = Next-TodoId $st; $item = @{ todo_id=$id; status="open"; title=$title; source="roadmap"; created_ts=NowIso; refs=@("Roadmap.md") }
    $added.Add($item); $existingTitles += $title
  }
  if ($added.Count -eq 0) { CI-Info "todo-seed: nothing to add (all roadmap tasks already present)"; return }
  $st.items = @($added.ToArray()); if (-not $st.active_id) { $st.active_id = $null }
  Save-TodoState $st
  foreach ($a in $added) {
    $idx.todos += @{
      todo_id = $a.todo_id
      title = $a.title
      last_status = $a.status
      prio = "normal"
      tags = @("roadmap")
      source = $a.source
      created_ts = $a.created_ts
      last_ts = NowIso
    }
  }
  $idx = Normalize-TodoIndexRows $idx $st
  Save-TodoIndex $idx
  Sync-TodoCheckpointState $st
  Append-TodoEvent @{ ts=NowIso; type="seed"; count=$added.Count; todo_ids=@($added | ForEach-Object { $_.todo_id }); source="Roadmap.md" }
  CI-Info ("todo-seed: added " + $added.Count + " item(s) from Roadmap.md")
}

function Cmd-TodoCompact() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $st = Load-TodoState
  $idx = Load-TodoIndex
  foreach ($item in @($st.items)) {
    if ([string](Get-Prop $item "status" "") -ne "done") { continue }
    $id = [string](Get-Prop $item "todo_id" "")
    foreach ($row in @($idx.todos)) {
      if ((Get-TodoIndexId $row) -eq $id) {
        Set-PropSafe $row "last_status" "done"
        Set-PropSafe $row "last_ts" (NowIso)
      }
    }
  }
  $st = Normalize-TodoState $st $true
  Save-TodoState $st
  $idx = Normalize-TodoIndexRows $idx $st
  Save-TodoIndex $idx
  Sync-TodoCheckpointState $st
  CI-Info ("todo-compact: ok (items=" + $st.items.Count + ", index=" + @($idx.todos).Count + ")")
}

function Update-TodoHistoryDigest([object]$idx, [string]$pruneTs = "", [string]$rotationTs = "") {
  $path = Get-TodoDigestPath
  $digest = Try-ReadJson $path
  if ($null -eq $digest) { $digest = @{ ts=NowIso; done_total=0; done_last_30d=0; recent_done=@(); last_prune_ts=$null; last_rotation_ts=$null } }
  $done = @($idx.todos | Where-Object { (Get-TodoIndexStatus $_) -eq "done" } | Sort-Object { Get-TodoIndexTimestamp $_ } -Descending)
  $cutoff = [datetimeoffset]::Now.AddDays(-30)
  $recentCount = 0
  foreach ($row in $done) {
    $parsed = [datetimeoffset]::MinValue
    if ([datetimeoffset]::TryParse((Get-TodoIndexTimestamp $row), [ref]$parsed) -and $parsed -ge $cutoff) { $recentCount++ }
  }
  Set-PropSafe $digest "ts" (NowIso)
  Set-PropSafe $digest "done_total" $done.Count
  Set-PropSafe $digest "done_last_30d" $recentCount
  Set-PropSafe $digest "recent_done" @($done | Select-Object -First 20 | ForEach-Object { @{ todo_id=(Get-TodoIndexId $_); title=[string](Get-Prop $_ "title" ""); last_ts=(Get-TodoIndexTimestamp $_) } })
  if ($pruneTs) { Set-PropSafe $digest "last_prune_ts" $pruneTs }
  if ($rotationTs) { Set-PropSafe $digest "last_rotation_ts" $rotationTs }
  Write-Json $path $digest
}

function Cmd-TodoPrune() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; Ensure-TodoEventsFile
  $idx = Load-TodoIndex; $doneIds = @(($idx.todos | Where-Object { (Get-TodoIndexStatus $_) -eq "done" } | ForEach-Object { Get-TodoIndexId $_ }) | Select-Object -Unique)
  if (-not $doneIds -or $doneIds.Count -eq 0) { Update-TodoHistoryDigest $idx; CI-Info "todo-prune: nothing to prune (no done ids)"; return }
  $src = Get-TodoEventsPath; $ts = TsId; $doneOut = Join-Path $LogsRoot ("todo\\done-events-" + $ts + ".jsonl")
  $doneLines = New-Object System.Collections.Generic.List[string]; $keepLines = New-Object System.Collections.Generic.List[string]
  foreach ($line in (Get-Content -LiteralPath $src -ErrorAction SilentlyContinue)) {
    $keep = $true; try { $o = $line | ConvertFrom-Json -ErrorAction Stop; $tid = [string](Get-Prop $o "todo_id" $null); $eventType = [string](Get-Prop $o "type" ""); if ($eventType -ne "checkpoint" -and $tid -and ($doneIds -contains $tid)) { $keep = $false } } catch { $keep = $true }
    if ($keep) { $keepLines.Add($line) } else { $doneLines.Add($line) }
  }
  if ($doneLines.Count -gt 0) { Atomic-WriteTextUtf8 $doneOut (($doneLines -join "`r`n") + "`r`n") }
  Atomic-WriteTextUtf8 $src $(if ($keepLines.Count -gt 0) { ($keepLines -join "`r`n") + "`r`n" } else { "" })
  $now = NowIso
  Update-TodoHistoryDigest $idx $now
  CI-Info ("todo-prune: moved " + $doneLines.Count + " done-event line(s) -> " + $doneOut)
}

function Get-TodoEventBoundaryId([string[]]$lines, [bool]$first) {
  $selected = $null
  if ($first) { $selected = @($lines | Select-Object -First 1) } else { $selected = @($lines | Select-Object -Last 1) }
  if (-not $selected) { return "empty" }
  try {
    $event = $selected[0] | ConvertFrom-Json -ErrorAction Stop
    $ts = Normalize-TodoTimestamp (Get-Prop $event "ts" "") $true
    if ($ts) { return ($ts -replace '[^0-9]', '').Substring(0, [Math]::Min(14, ($ts -replace '[^0-9]', '').Length)) }
  } catch { $null = $_ }
  return "unknown"
}

function Test-TodoRotationRequired([string[]]$lines, [int64]$size) {
  if ($size -gt 25600 -or @($lines).Count -gt 50) { return $true }
  if (@($lines).Count -eq 0) { return $false }
  try {
    $first = $lines[0] | ConvertFrom-Json -ErrorAction Stop
    $value = Get-Prop $first "ts" $null
    $parsed = [datetimeoffset]::MinValue
    if ($value -is [datetimeoffset]) { $parsed = $value }
    elseif ($value -is [datetime]) { $parsed = [datetimeoffset]::new($value) }
    elseif (-not [datetimeoffset]::TryParse([string]$value, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AllowWhiteSpaces, [ref]$parsed)) { return $false }
    if ($parsed -ne [datetimeoffset]::MinValue) {
      return ($parsed -lt [datetimeoffset]::Now.AddDays(-14))
    }
  } catch { $null = $_ }
  return $false
}

function Cmd-TodoRotate() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; Ensure-TodoEventsFile
  $p = Get-TodoEventsPath
  $fi = Get-Item -LiteralPath $p
  $size = [int64]$fi.Length
  $eventLines = @((Get-Content -LiteralPath $p -ErrorAction SilentlyContinue) | Where-Object { [string]$_ })
  if (-not (Test-TodoRotationRequired $eventLines $size)) { CI-Info ("todo-rotate: ok (size=" + $size + " bytes, lines=" + $eventLines.Count + ")"); return }

  $now = NowIso
  $checkpointId = New-EventId
  $firstId = Get-TodoEventBoundaryId $eventLines $true
  $lastId = Get-TodoEventBoundaryId $eventLines $false
  $archive = Join-Path $LogsRoot ("todo\\active-events-" + $firstId + "--" + $lastId + ".jsonl")
  Atomic-WriteTextUtf8 $archive $(if ($eventLines.Count -gt 0) { ($eventLines -join "`r`n") + "`r`n" } else { "" })

  $st = Normalize-TodoState (Load-TodoState) $false
  $history = @(Ensure-StringArray (Get-Prop $st "history_archives" @()))
  $archiveRel = (To-RelPath $archive).Replace("\", "/")
  if ($history -notcontains $archiveRel) { $history += $archiveRel }
  Set-PropSafe $st "checkpoint_event_id" $checkpointId
  Set-PropSafe $st "history_archives" $history
  Save-TodoState $st
  $checkpoint = @{ schema="todo-checkpoint-v2"; version=2; ts=$now; checkpoint_event_id=$checkpointId; history_archives=$history; state=$st }
  Write-Json (Get-TodoCheckpointPath) $checkpoint
  $checkpointEvent = @{ ts=$now; event_id=$checkpointId; todo_id=$(if ($st.active_id) { [string]$st.active_id } else { "SYSTEM" }); type="checkpoint"; status=$(if ($st.active_id) { "in-progress" } else { "open" }); prio="low"; source="todo-rotate"; msg="checkpoint created"; refs=@("file:todo.checkpoint.json", ("file:" + $archiveRel)); changed=@(); verified=@(); git=@{}; history_archives=$history }
  Atomic-WriteTextUtf8 $p ((To-Json $checkpointEvent) + "`r`n")
  Update-TodoHistoryDigest (Load-TodoIndex) "" $now
  CI-Info ("todo-rotate: archived -> " + $archive + " checkpoint -> " + (Get-TodoCheckpointPath))
}

function Cmd-TodoRebuild() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $cpPath = Get-TodoCheckpointPath; if (-not (Test-Path -LiteralPath $cpPath)) { CI-Info "todo-rebuild: no checkpoint found"; return }
  $cp = Try-ReadJson $cpPath
  if ($null -eq $cp) { throw "todo-rebuild: checkpoint invalid JSON" }
  $st = Get-Prop $cp "state" $null
  if ($null -eq $st -and $null -ne (Get-Prop $cp "items" $null)) { $st = $cp }
  if ($null -eq $st) { throw "todo-rebuild: unsupported checkpoint schema" }
  $st = Normalize-TodoState $st $true
  Save-TodoState $st
  $idx = Normalize-TodoIndexRows (Load-TodoIndex) $st
  Save-TodoIndex $idx
  CI-Info "todo-rebuild: restored todo state from checkpoint"
}

function Cmd-TodoSanitize() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $st = Load-TodoState; Save-TodoState $st; Ensure-TodoEventsFile
  $idx = Normalize-TodoIndexRows (Load-TodoIndex) $st
  Save-TodoIndex $idx
  $dg = Try-ReadJson (Get-TodoDigestPath); if ($null -eq $dg) { $dg = @{ ts=NowIso; done_total=0; done_last_30d=0; recent_done=@(); last_prune_ts=$null; last_rotation_ts=$null } }
  Write-Json (Get-TodoDigestPath) $dg; CI-Info "todo-sanitize: ok"
}
