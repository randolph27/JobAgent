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
  return ($lines -join "`n") + "`n"
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

function Save-TodoState([object]$st) {
  Write-Json (Get-TodoStatePath) $st
  Atomic-WriteTextUtf8 (Get-TodoCurrentPath) (Render-TodoCurrent $st)
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

function Get-TodoItemById([object]$state, [string]$todoId) {
  if (-not $state -or -not $todoId) { return $null }
  foreach ($it in @($state.items)) {
    $id = [string](Get-Prop $it "todo_id" (Get-Prop $it "id" ""))
    if ($id -eq $todoId) { return $it }
  }
  return $null
}

function Resolve-CodexLoopTodoSelection([string]$requestedTodoId = $null) {
  $state = Load-TodoState
  $items = @($state.items)
  $inProgress = @($items | Where-Object { (Normalize-TodoStatus ([string](Get-Prop $_ "status" "open"))) -eq "in-progress" })
  if ($inProgress.Count -gt 1) {
    return @{
      ok = $false
      stop_reason = "meta_loop_blocked"
      message = "multiple in-progress todo items"
      state = $state
      previous_active_id = [string](Get-Prop $state "active_id" $null)
    }
  }

  $previousActiveId = [string](Get-Prop $state "active_id" $null)
  $targetTodoId = [string]$requestedTodoId
  if (-not $targetTodoId) { $targetTodoId = $previousActiveId }
  if (-not $targetTodoId) {
    return @{
      ok = $false
      stop_reason = "resume_missing"
      message = "no active_id and no explicit todo target"
      state = $state
      previous_active_id = $previousActiveId
    }
  }

  $item = Get-TodoItemById $state $targetTodoId
  if ($null -eq $item) {
    return @{
      ok = $false
      stop_reason = "resume_missing"
      message = ("todo target not found: " + $targetTodoId)
      state = $state
      previous_active_id = $previousActiveId
      todo_id = $targetTodoId
    }
  }

  $status = Normalize-TodoStatus ([string](Get-Prop $item "status" "open"))
  if ($status -eq "done") {
    return @{
      ok = $false
      stop_reason = "meta_loop_blocked"
      message = ("todo target already done: " + $targetTodoId)
      state = $state
      previous_active_id = $previousActiveId
      todo_id = $targetTodoId
    }
  }

  return @{
    ok = $true
    state = $state
    item = $item
    todo_id = $targetTodoId
    previous_active_id = $previousActiveId
    target_status = $status
  }
}

function Set-CodexLoopFocus([object]$state, [string]$todoId) {
  $target = Get-TodoItemById $state $todoId
  if ($null -eq $target) { return $false }

  foreach ($it in @($state.items)) {
    $id = [string](Get-Prop $it "todo_id" (Get-Prop $it "id" ""))
    if (-not $id) { continue }
    $status = Normalize-TodoStatus ([string](Get-Prop $it "status" "open"))
    if ($id -eq $todoId) {
      $it.status = "in-progress"
    } elseif ($status -eq "in-progress") {
      $it.status = "open"
    }
  }

  $state.active_id = $todoId
  Save-TodoState $state
  $idx = Normalize-TodoIndexRows (Load-TodoIndex) $state
  Save-TodoIndex $idx
  return $true
}

function Apply-CodexLoopTodoResult(
  [string]$todoId,
  [string]$todoStatus,
  [string]$stopReason,
  [string]$summary = "",
  [string]$next = "",
  [string]$previousActiveId = $null
) {
  $state = Load-TodoState
  $target = Get-TodoItemById $state $todoId
  if ($null -eq $target) { return $null }

  $fallbackStatus = "in-progress"
  if ($stopReason -in @("real_blocker", "meta_loop_blocked", "resume_missing")) {
    $fallbackStatus = "blocked"
  }
  $normalizedStatus = Normalize-TodoStatus $todoStatus $fallbackStatus

  foreach ($it in @($state.items)) {
    $id = [string](Get-Prop $it "todo_id" (Get-Prop $it "id" ""))
    if (-not $id) { continue }
    if ($id -eq $todoId) { continue }
    $status = Normalize-TodoStatus ([string](Get-Prop $it "status" "open"))
    if ($status -eq "in-progress") { $it.status = "open" }
  }

  $target.status = $normalizedStatus
  if ($normalizedStatus -eq "done") {
    $restored = $null
    if ($previousActiveId -and $previousActiveId -ne $todoId) {
      $restored = Get-TodoItemById $state $previousActiveId
    }
    if ($restored) {
      $restoredStatus = Normalize-TodoStatus ([string](Get-Prop $restored "status" "open"))
      if ($restoredStatus -eq "open") { $restored.status = "in-progress" }
      $state.active_id = $previousActiveId
    } else {
      $state.active_id = $null
    }
  } else {
    $state.active_id = $todoId
  }

  Save-TodoState $state
  $idx = Normalize-TodoIndexRows (Load-TodoIndex) $state
  Save-TodoIndex $idx
  if ($normalizedStatus -eq "done") { Cmd-TodoCompact }
  return @{
    state = Load-TodoState
    summary = $summary
    next = $next
    todo_status = $normalizedStatus
    stop_reason = $stopReason
  }
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

  $doneRoadmapKeys = @{}
  foreach ($id in $order) {
    if (-not $rowsById.ContainsKey($id)) { continue }
    $row = $rowsById[$id]
    $status = [string](Get-Prop $row "last_status" "open")
    if ($status -ne "done") { continue }
    $key = Get-RoadmapTaskKey ([string](Get-Prop $row "title" ""))
    if ($key) { $doneRoadmapKeys[$key] = $true }
  }

  $rows = New-Object System.Collections.Generic.List[object]
  foreach ($id in $order) {
    if (-not $rowsById.ContainsKey($id)) { continue }
    $row = $rowsById[$id]
    $status = [string](Get-Prop $row "last_status" "open")
    if ($status -ne "done" -and -not $activeById.ContainsKey($id)) {
      $key = Get-RoadmapTaskKey ([string](Get-Prop $row "title" ""))
      if ($key -and $doneRoadmapKeys.ContainsKey($key)) { continue }
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
  Append-TodoEvent @{ ts=NowIso; type="seed"; count=$added.Count; todo_ids=@($added | ForEach-Object { $_.todo_id }); source="Roadmap.md" }
  CI-Info ("todo-seed: added " + $added.Count + " item(s) from Roadmap.md")
}

function Cmd-TodoCompact() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $st = Load-TodoState; $items = New-Object System.Collections.Generic.List[object]; $active = [string](Get-Prop $st "active_id" $null)
  foreach ($it in @($st.items)) {
    $id = [string](Get-Prop $it "todo_id" $null); if (-not $id) { continue }
    $status = [string](Get-Prop $it "status" "open"); if ($status -notin @("open","in-progress","blocked","done")) { $status = "open"; $it.status = $status }
    if ($status -eq "done") { continue }
    $items.Add($it)
  }
  $inProg = @($items | Where-Object { [string](Get-Prop $_ "status" "") -eq "in-progress" })
  if ($inProg.Count -gt 1) {
    if (-not $active) { $active = [string](Get-Prop $inProg[0] "todo_id" $null); $st.active_id = $active }
    foreach ($it in $inProg) { if ([string](Get-Prop $it "todo_id" "") -ne $active) { $it.status = "open" } }
  }
  $st.items = $items.ToArray(); Save-TodoState $st
  $idx = Normalize-TodoIndexRows (Load-TodoIndex) $st
  Save-TodoIndex $idx
  CI-Info ("todo-compact: ok (items=" + $st.items.Count + ", index=" + @($idx.todos).Count + ")")
}

function Cmd-TodoPrune() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; Ensure-TodoEventsFile
  $idx = Load-TodoIndex; $doneIds = @($idx.todos | Where-Object { (Get-TodoIndexStatus $_) -eq "done" } | ForEach-Object { Get-TodoIndexId $_ }) | Select-Object -Unique
  if (-not $doneIds -or $doneIds.Count -eq 0) { CI-Info "todo-prune: nothing to prune (no done ids)"; return }
  $src = Get-TodoEventsPath; $ts = TsId; $doneOut = Join-Path $LogsRoot ("todo\\done-events-" + $ts + ".jsonl"); $keepOut = Join-Path $LogsRoot ("todo\\active-events-" + $ts + ".jsonl")
  $doneLines = New-Object System.Collections.Generic.List[string]; $keepLines = New-Object System.Collections.Generic.List[string]
  foreach ($line in (Get-Content -LiteralPath $src -ErrorAction SilentlyContinue)) {
    $keep = $true; try { $o = $line | ConvertFrom-Json -ErrorAction Stop; $tid = [string](Get-Prop $o "todo_id" $null); if ($tid -and ($doneIds -contains $tid)) { $keep = $false } } catch { $keep = $true }
    if ($keep) { $keepLines.Add($line) } else { $doneLines.Add($line) }
  }
  Atomic-WriteTextUtf8 $doneOut (($doneLines -join "`r`n") + "`r`n"); Atomic-WriteTextUtf8 $keepOut (($keepLines -join "`r`n") + "`r`n"); Atomic-WriteTextUtf8 $src (($keepLines -join "`r`n") + "`r`n")
  $dg = Try-ReadJson (Get-TodoDigestPath); if ($null -eq $dg) { $dg = @{ ts=NowIso; done_total=0; done_last_30d=0; recent_done=@(); last_prune_ts=$null; last_rotation_ts=$null } }
  $dg.last_prune_ts = NowIso; Write-Json (Get-TodoDigestPath) $dg
  CI-Info ("todo-prune: moved " + $doneLines.Count + " done-event line(s) -> " + $doneOut)
}

function Cmd-TodoRotate() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; Ensure-TodoEventsFile
  $p = Get-TodoEventsPath; $fi = Get-Item -LiteralPath $p; $size = [int]$fi.Length; $lines = 0; try { $lines = (Get-Content -LiteralPath $p | Measure-Object -Line).Lines } catch { $lines = 0 }
  $rotate = $false; if ($size -gt 25600) { $rotate = $true }; if ($lines -gt 80) { $rotate = $true }
  if (-not $rotate) { CI-Info ("todo-rotate: ok (size=" + $size + " bytes, lines=" + $lines + ")"); return }
  $ts = TsId; $archive = Join-Path $LogsRoot ("todo\\events-rotated-" + $ts + ".jsonl"); try { Copy-Item -Force -LiteralPath $p -Destination $archive } catch { $null = $_ }
  $st = Load-TodoState; $cp = @{ ts=NowIso; state=$st }; Write-Json (Get-TodoCheckpointPath) $cp
  $tail = @(); try { $tail = Get-Content -LiteralPath $p -Tail 30 } catch { $tail = @() }
  Atomic-WriteTextUtf8 $p (($tail -join "`r`n") + "`r`n")
  $dg = Try-ReadJson (Get-TodoDigestPath); if ($null -eq $dg) { $dg = @{ ts=NowIso; done_total=0; done_last_30d=0; recent_done=@(); last_prune_ts=$null; last_rotation_ts=$null } }
  $dg.last_rotation_ts = NowIso; Write-Json (Get-TodoDigestPath) $dg
  CI-Info ("todo-rotate: archived -> " + $archive + " checkpoint -> " + (Get-TodoCheckpointPath))
}

function Cmd-TodoRebuild() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $cpPath = Get-TodoCheckpointPath; if (-not (Test-Path -LiteralPath $cpPath)) { CI-Info "todo-rebuild: no checkpoint found"; return }
  $cp = Try-ReadJson $cpPath; $st = Get-Prop $cp "state" $null; if ($null -eq $st) { CI-Info "todo-rebuild: checkpoint invalid"; return }
  Save-TodoState $st; CI-Info "todo-rebuild: restored todo.state.json from checkpoint"
}

function Cmd-TodoSanitize() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $st = Load-TodoState; Save-TodoState $st; Ensure-TodoEventsFile
  $idx = Normalize-TodoIndexRows (Load-TodoIndex) $st
  Save-TodoIndex $idx
  $dg = Try-ReadJson (Get-TodoDigestPath); if ($null -eq $dg) { $dg = @{ ts=NowIso; done_total=0; done_last_30d=0; recent_done=@(); last_prune_ts=$null; last_rotation_ts=$null } }
  Write-Json (Get-TodoDigestPath) $dg; CI-Info "todo-sanitize: ok"
}
