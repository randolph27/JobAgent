function Render-TodoCurrent([object]$state) {
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("# Todo (current)")
  $lines.Add("")
  $active = $state.active_id
  if ($active) { $lines.Add("Active: **$active**") } else { $lines.Add("Active: **none**") }
  $lines.Add("")
  $items = @()
  try { $items = $state.items } catch { $items = @() }
  if (-not $items -or $items.Count -eq 0) {
    $lines.Add("Keine aktiven Todos.")
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

function Ensure-TodoEventsFile() {
  $p = Get-TodoEventsPath
  if (-not (Test-Path -LiteralPath $p)) { Atomic-WriteTextUtf8 $p "" }
}

function Load-TodoState() {
  $p = Get-TodoStatePath
  $st = Try-ReadJson $p
  if ($null -eq $st) {
    $st = @{ cursor=0; active_id=""; items=@() }
    Write-Json $p $st
  }
  if ($null -eq (Get-Prop $st "items" $null)) { Set-PropSafe $st "items" @() }
  if ($null -eq (Get-Prop $st "cursor" $null)) { Set-PropSafe $st "cursor" 0 }
  if ($null -eq (Get-Prop $st "active_id" $null)) { Set-PropSafe $st "active_id" "" }
  return $st
}

function Save-TodoState([object]$st) {
  Write-Json (Get-TodoStatePath) $st
  Atomic-WriteTextUtf8 (Get-TodoCurrentPath) (Render-TodoCurrent $st)
}

function Load-TodoIndex() {
  $p = Get-TodoIndexPath
  $idx = Try-ReadJson $p
  if ($null -eq $idx) { $idx = @{ ts=NowIso; todos=@() }; Write-Json $p $idx }
  if ($null -eq (Get-Prop $idx "todos" $null)) { Set-PropSafe $idx "todos" @() }
  return $idx
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
    if ($l -match '^\-\s*\[\s*\]\s*([A-Z]+-\d+)\b\s*(.+)$') {
      $id = $Matches[1].Trim()
      $rest = $Matches[2].Trim()
      $txt = (($id + " " + $rest).Trim())
      if ($txt) { [void]$out.Add(@{ section=$sec; id=$id; text=$txt }) }
    }
  }
  return $out.ToArray()
}

function Get-RoadmapTaskCatalog() {
  $catalog = @{}
  $paths = @(
    (Join-Path $RepoRoot "Roadmap_archive.md"),
    (Join-Path $RepoRoot "Roadmap.md")
  )
  foreach ($path in $paths) {
    if (-not (Test-Path -LiteralPath $path)) { continue }
    foreach ($line in (Get-Content -LiteralPath $path -ErrorAction SilentlyContinue)) {
      if ($line -notmatch '^\-\s*\[([xX ])\]\s*([A-Z]+-\d+)\b\s*(.+)$') { continue }
      $mark = [string]$Matches[1]
      $id = [string]$Matches[2]
      $rest = [string]$Matches[3]
      $status = if ($mark -match '[xX]') { "done" } else { "open" }
      $catalog[$id] = @{
        id = $id
        status = $status
        title = (($id + " " + $rest.Trim()).Trim())
      }
    }
  }
  return $catalog
}

function Get-TodoRoadmapId([object]$item) {
  if ($null -eq $item) { return $null }
  $roadmapId = [string](Get-Prop $item "roadmap_id" $null)
  if ($roadmapId -match '^[A-Z]+-\d{3,4}$') { return $roadmapId }

  $todoId = [string](Get-Prop $item "todo_id" $null)
  if ($todoId -match '^[A-Z]+-\d{3,4}$' -and $todoId -notmatch '^TD-\d{4}$') { return $todoId }

  $id = [string](Get-Prop $item "id" $null)
  if ($id -match '^[A-Z]+-\d{3,4}$' -and $id -notmatch '^TD-\d{4}$') { return $id }

  $title = [string](Get-Prop $item "title" "")
  if ($title -match '\b([A-Z]+-\d{3,4})\b') { return [string]$Matches[1] }
  return $null
}

function Test-MalformedOpenRoadmapIndexEntry([object]$item) {
  if ($null -eq $item) { return $false }
  if ([string](Get-Prop $item "source" "") -ne "roadmap") { return $false }
  if ([string](Get-Prop $item "todo_id" $null)) { return $false }
  if ([string](Get-Prop $item "id" "") -notmatch '^TD-\d{4}$') { return $false }

  $status = [string](Get-Prop $item "status" "")
  if ($status -notin @("open", "in-progress", "blocked")) { return $false }

  $title = [string](Get-Prop $item "title" "")
  if ($title -match '^(Beschreibung:|Scope:|Ist-Stand\b|Schritte:|Evidence:|Funktionstest:|Audit:|Supertest:)') { return $true }
  if ($title -match '^[A-Z]+-\d{3,4}\b.+#comment:') { return $true }
  return $false
}

function Get-RoadmapPath() { Join-Path $RepoRoot "Roadmap.md" }

function Parse-RoadmapAutogrowArgs([string[]]$argv) {
  $norm = {
    param([string]$v)
    $x = [string]$v
    if (-not $x) { return $x }
    $x = $x.Trim()
    if ($x.Length -ge 2 -and $x.StartsWith('"') -and $x.EndsWith('"')) { $x = $x.Substring(1, $x.Length - 2) }
    return $x
  }
  $opts = @{
    signature = $null
    reason = $null
    cmd = $null
    source = "verify.digest"
    dry_run = $false
  }
  if (-not $argv) { return $opts }
  for ($i = 0; $i -lt $argv.Count; $i++) {
    $a = & $norm ([string]$argv[$i])
    if (-not $a) { continue }
    if ($a -eq "--dry-run") { $opts.dry_run = $true; continue }
    if ($a -eq "--signature" -and ($i + 1) -lt $argv.Count) { $i++; $opts.signature = (& $norm ([string]$argv[$i])); continue }
    if ($a -eq "--reason" -and ($i + 1) -lt $argv.Count) { $i++; $opts.reason = (& $norm ([string]$argv[$i])); continue }
    if ($a -eq "--cmd" -and ($i + 1) -lt $argv.Count) { $i++; $opts.cmd = (& $norm ([string]$argv[$i])); continue }
    if ($a -eq "--source" -and ($i + 1) -lt $argv.Count) { $i++; $opts.source = (& $norm ([string]$argv[$i])); continue }
  }
  return $opts
}

function Get-RoadmapNextId([string]$prefix="OPS", [string]$roadmapText=$null) {
  if (-not $roadmapText) {
    $rp = Get-RoadmapPath
    if (Test-Path -LiteralPath $rp) { $roadmapText = Get-Content -Raw -LiteralPath $rp } else { $roadmapText = "" }
  }
  $max = 0
  $rx = [regex]::new("\b" + [regex]::Escape($prefix) + "-(\d{3,4})\b")
  foreach ($m in $rx.Matches($roadmapText)) {
    try {
      $n = [int]$m.Groups[1].Value
      if ($n -gt $max) { $max = $n }
    } catch { $null = $_ }
  }
  $next = $max + 1
  return ($prefix + "-" + $next.ToString("000"))
}

function Build-RoadmapAutogrowItemLines([hashtable]$ctx) {
  $id = [string](Get-Prop $ctx "id" "OPS-000")
  $sig = [string](Get-Prop $ctx "signature" "FSIG-UNKNOWN")
  $cmd = [string](Get-Prop $ctx "cmd" "TODO: command from verify.digest")
  $reason = [string](Get-Prop $ctx "reason" "TODO: reason from failbundle/verify")
  $src = [string](Get-Prop $ctx "source" "verify.digest")
  $ts = Get-Date -Format "yyyy-MM-dd HH:mm"
  $evidenceBase = [string](Get-Prop $ctx "evidence_base" "logs/verify/ops-220-roadmap-autogrow")
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("- [ ] $id Auto-Task fuer neue Fail-Signatur $sig #comment: Automatisch erzeugter Roadmap-Punkt fuer einen bisher nicht gemappten Verify-Fehler; Nachfolgechat kann ohne Informationsverlust weiterarbeiten.")
  $lines.Add("  - [ ] Beschreibung: Neue Fail-Signatur `$sig` wurde in `$src` erkannt und war zuvor nicht in `Roadmap.md` erfasst; Ziel ist reproduzierbare Analyse/Fix mit klaren Akzeptanzkriterien.")
  $lines.Add("  - [ ] Scope: `.ci/bin/modules/verify-logic.ps1`, `.ci/bin/modules/core-utils.ps1`, betroffene Build-/Testmodule laut Fehlerspur; No-Go: keine irrelevanten UI-Refactors, keine Android-spezifischen Aenderungen.")
  $lines.Add("  - [ ] Ist-Stand ($ts): Auto-Erkennung hat neuen Befund erzeugt (`fail_signature=$sig`, `reason=$reason`, `cmd=$cmd`).")
  $lines.Add("  - [ ] Schritte:")
  $lines.Add("      1. Fehlerspur reproduzieren (`$cmd`) und erste rote Stelle mit Logbeleg isolieren; Ergebnis: deterministische Repro ohne Zusatzannahmen.")
  $lines.Add("      2. Root-Cause in den betroffenen Modulen fixen, inklusive Guard gegen Rueckfall; Ergebnis: Signatur tritt unter denselben Bedingungen nicht erneut auf.")
  $lines.Add("      3. Funktionstests und gezielte Regressionen ausfuehren und Evidence schreiben; Ergebnis: Gruenlauf fuer den betroffenen Pfad mit nachvollziehbarer Dokumentation.")
  $lines.Add("  - [ ] Evidence: `$evidenceBase-first-run.txt`, `$evidenceBase-idempotence.txt`, `logs/verify/ops-220-roadmap-diff.patch`.")
  $lines.Add("  - [ ] Funktionstest: `pwsh -NoProfile -Command `".\\.ci\\bin\\ci.cmd roadmap-autogrow --signature $sig --dry-run`"`; danach betroffener Funktions-/CI-Test laut Fehlerkontext.")
  $lines.Add("  - [ ] Audit: Manuell auf `1920x1080`, `1366x900`, `800x900` pruefen (kein Overlap/Clipping, Touch-Targets, Text-Layout), falls UI betroffen; sonst N/A mit Begruendung dokumentieren.")
  $lines.Add("  - [ ] Supertest: Nur auf expliziten User-Befehl `node tests/ui/run-supertest.js` nach gruenen Funktions-/CI-Tests.")
  return $lines.ToArray()
}

function Insert-RoadmapAutogrowItem([string]$roadmapText, [string[]]$itemLines) {
  $lines = @($roadmapText -split "`r?`n", -1)
  if (-not $lines) { $lines = @() }
  $insertIdx = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*##\s+Aktive Punkte\b') { $insertIdx = $i + 1; break }
  }
  if ($insertIdx -lt 0) {
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($l in $lines) { $out.Add($l) }
    if ($out.Count -gt 0 -and $out[$out.Count - 1] -ne "") { $out.Add("") }
    $out.Add("## Aktive Punkte")
    foreach ($l in $itemLines) { $out.Add($l) }
    return ($out -join "`r`n").TrimEnd() + "`r`n"
  }

  while ($insertIdx -lt $lines.Count -and [string]::IsNullOrWhiteSpace($lines[$insertIdx])) { $insertIdx++ }
  if ($insertIdx -lt $lines.Count -and $lines[$insertIdx] -match '^\s*-\s*\[\s*\]\s*ONB-001\b') { $insertIdx++ }

  $result = New-Object System.Collections.Generic.List[string]
  for ($i = 0; $i -lt $insertIdx; $i++) { $result.Add($lines[$i]) }
  foreach ($l in $itemLines) { $result.Add($l) }
  for ($i = $insertIdx; $i -lt $lines.Count; $i++) { $result.Add($lines[$i]) }
  return ($result -join "`r`n").TrimEnd() + "`r`n"
}

function Write-RoadmapTextSafely([string]$roadmapPath, [string]$content) {
  if (Get-Command -Name With-ImmutableWrite -ErrorAction SilentlyContinue) {
    With-ImmutableWrite { Atomic-WriteTextUtf8 $roadmapPath $content }
    return
  }
  if (Get-Command -Name Set-ReadOnlyFlag -ErrorAction SilentlyContinue) {
    Set-ReadOnlyFlag $roadmapPath $false
    try { Atomic-WriteTextUtf8 $roadmapPath $content } finally { Set-ReadOnlyFlag $roadmapPath $true }
    return
  }
  Atomic-WriteTextUtf8 $roadmapPath $content
}

function Write-RoadmapAutogrowPatch([string]$patchPath, [string]$id, [string]$sig, [string[]]$itemLines) {
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("--- Roadmap.md (before)")
  $lines.Add("+++ Roadmap.md (after)")
  $lines.Add("@@ OPS-220 autogrow item @@")
  $lines.Add("+# fail_signature: " + $sig)
  $lines.Add("+# roadmap_id: " + $id)
  foreach ($l in $itemLines) { $lines.Add("+" + $l) }
  Atomic-WriteTextUtf8 $patchPath (($lines -join "`r`n") + "`r`n")
}

function Invoke-RoadmapAutogrow([hashtable]$opts=$null) {
  Ensure-CoreFolders
  $rp = Get-RoadmapPath
  if (-not (Test-Path -LiteralPath $rp)) { throw "roadmap-autogrow: Roadmap.md missing." }
  if ($null -eq $opts) { $opts = @{} }

  $vdPath = Join-Path $LogsRoot "verify\verify.digest.json"
  $fbPath = Join-Path $LogsRoot "verify\failbundle-latest.json"
  $vd = Try-ReadJson $vdPath
  $fb = Try-ReadJson $fbPath

  $sig = [string](Get-Prop $opts "signature" $null)
  if (-not $sig) { $sig = [string](Get-Prop $vd "fail_signature" $null) }
  if (-not $sig) { throw "roadmap-autogrow: no fail_signature available (pass --signature or provide logs/verify/verify.digest.json)." }

  $cmd = [string](Get-Prop $opts "cmd" $null)
  if (-not $cmd) { $cmd = [string](Get-Prop $vd "cmd" "TODO: command from verify.digest") }
  $reason = [string](Get-Prop $opts "reason" $null)
  if (-not $reason) { $reason = [string](Get-Prop $fb "reason" $null) }
  if (-not $reason) { $reason = "TODO: reason from failbundle/verify" }
  $src = [string](Get-Prop $opts "source" "verify.digest")
  $dryRun = [bool](Get-Prop $opts "dry_run" $false)

  $before = Get-Content -Raw -LiteralPath $rp
  $sigEsc = [regex]::Escape($sig)
  $existsHeading = ($before -match ("(?m)^\s*-\s*\[\s*[xX ]\s*\]\s*OPS-\d{3,4}\s+Auto-Task fuer neue Fail-Signatur\s+" + $sigEsc + "\b"))
  $existsMarker = ($before -match ("(?m)fail_signature=" + $sigEsc + "\b"))
  if ($existsHeading -or $existsMarker) {
    return @{
      changed = $false
      reason = "already_exists"
      signature = $sig
      roadmap_id = $null
      dry_run = $dryRun
      roadmap_path = $rp
    }
  }

  $id = Get-RoadmapNextId "OPS" $before
  $itemCtx = @{
    id = $id
    signature = $sig
    cmd = $cmd
    reason = $reason
    source = $src
    evidence_base = "logs/verify/ops-220-roadmap-autogrow"
  }
  $itemLines = Build-RoadmapAutogrowItemLines $itemCtx
  $after = Insert-RoadmapAutogrowItem $before $itemLines

  if (-not $dryRun) {
    Write-RoadmapTextSafely $rp $after
    Write-RoadmapAutogrowPatch (Join-Path $LogsRoot "verify\ops-220-roadmap-diff.patch") $id $sig $itemLines
  }

  return @{
    changed = $true
    reason = "inserted"
    signature = $sig
    roadmap_id = $id
    dry_run = $dryRun
    roadmap_path = $rp
    item_lines = $itemLines
    item_text = (($itemLines -join "`r`n") + "`r`n")
  }
}

function Cmd-RoadmapAutogrow([string[]]$argv) {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $opts = Parse-RoadmapAutogrowArgs $argv
  $res = Invoke-RoadmapAutogrow $opts

  $firstRunLog = Join-Path $LogsRoot "verify\ops-220-roadmap-autogrow-first-run.txt"
  $idempotenceLog = Join-Path $LogsRoot "verify\ops-220-roadmap-autogrow-idempotence.txt"
  $dryRunLog = Join-Path $LogsRoot "verify\ops-220-roadmap-autogrow-dry-run.txt"
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("ts=" + (NowIso))
  $lines.Add("changed=" + [string](Get-Prop $res "changed" $false))
  $lines.Add("reason=" + [string](Get-Prop $res "reason" ""))
  $lines.Add("signature=" + [string](Get-Prop $res "signature" ""))
  $lines.Add("roadmap_id=" + [string](Get-Prop $res "roadmap_id" ""))
  $lines.Add("dry_run=" + [string](Get-Prop $res "dry_run" $false))
  $lines.Add("roadmap_path=" + [string](Get-Prop $res "roadmap_path" ""))
  $txt = ($lines -join "`r`n") + "`r`n"

  if ([bool](Get-Prop $res "changed" $false) -and [bool](Get-Prop $res "dry_run" $false)) {
    Atomic-WriteTextUtf8 $dryRunLog $txt
    CI-Info ("roadmap-autogrow: dry-run would insert " + [string](Get-Prop $res "roadmap_id" "") + " for " + [string](Get-Prop $res "signature" ""))
    return
  }
  if ([bool](Get-Prop $res "changed" $false)) {
    Atomic-WriteTextUtf8 $firstRunLog $txt
    try {
      $tid = [string](Get-Prop (Load-TodoState) "active_id" "SYSTEM")
      if (-not $tid) { $tid = "SYSTEM" }
      Append-TodoEvent @{
        ts=NowIso
        type="roadmap_autogrow"
        todo_id=$tid
        status="open"
        prio="medium"
        source="roadmap-autogrow"
        msg=("auto-added roadmap item " + [string](Get-Prop $res "roadmap_id" ""))
        refs=@("file:Roadmap.md","file:logs/verify/ops-220-roadmap-diff.patch")
        changed=@("Roadmap.md")
      } | Out-Null
    } catch { $null = $_ }
    CI-Info ("roadmap-autogrow: inserted " + [string](Get-Prop $res "roadmap_id" "") + " for " + [string](Get-Prop $res "signature" ""))
    return
  }

  Atomic-WriteTextUtf8 $idempotenceLog $txt
  CI-Info ("roadmap-autogrow: no change (" + [string](Get-Prop $res "reason" "unknown") + ") for " + [string](Get-Prop $res "signature" ""))
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
    $sec = [string](Get-Prop $c "section" "")
    $txt = [string](Get-Prop $c "text" "")
    $rid = [string](Get-Prop $c "id" "")
    $title = $txt
    if ($sec) { $title = $sec + ": " + $txt }
    if ($existingTitles -contains $title) { continue }
    $id = Next-TodoId $st
    $item = @{ todo_id=$id; status="open"; title=$title; source="roadmap"; created_ts=NowIso; refs=@("Roadmap.md"); roadmap_id=$rid }
    $added.Add($item); $existingTitles += $title
  }
  if ($added.Count -eq 0) { CI-Info "todo-seed: nothing to add (all roadmap tasks already present)"; return }
  $st.items = @($added.ToArray()); if (-not $st.active_id) { $st.active_id = "" }
  Save-TodoState $st
  foreach ($a in $added) { $idx.todos += @{ id=$a.todo_id; title=$a.title; status=$a.status; source=$a.source; created_ts=$a.created_ts; last_ts=NowIso } }
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
  $st.items = $items.ToArray(); Save-TodoState $st; CI-Info ("todo-compact: ok (items=" + $st.items.Count + ")")
}

function Cmd-TodoPrune() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; Ensure-TodoEventsFile
  $idx = Load-TodoIndex; $doneIds = @($idx.todos | Where-Object { [string](Get-Prop $_ "status" "") -eq "done" } | ForEach-Object { $_.id }) | Select-Object -Unique
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
  $idx = Load-TodoIndex
  $roadmapCatalog = Get-RoadmapTaskCatalog
  # Best-effort: ensure todo.master.index.json contains all active items (seed can fail mid-flight).
  $now = NowIso
  $map = @{}
  $normalizedTodos = New-Object System.Collections.Generic.List[object]
  foreach ($t in @($idx.todos)) {
    if (Test-MalformedOpenRoadmapIndexEntry $t) { continue }
    $id = [string](Get-Prop $t "id" $null)
    $roadmapId = Get-TodoRoadmapId $t
    if ($roadmapId -and $roadmapCatalog.ContainsKey($roadmapId)) {
      $catalogEntry = $roadmapCatalog[$roadmapId]
      $catalogStatus = [string](Get-Prop $catalogEntry "status" "open")
      Set-PropSafe $t "status" $catalogStatus
      Set-PropSafe $t "last_status" $catalogStatus
      Set-PropSafe $t "last_ts" $now
      if (-not [string](Get-Prop $t "roadmap_id" "")) { Set-PropSafe $t "roadmap_id" $roadmapId }
    }
    $normalizedTodos.Add($t)
    if ($id) { $map[$id] = $t }
  }
  $idx.todos = @($normalizedTodos.ToArray())
  foreach ($it in @($st.items)) {
    $id = [string](Get-Prop $it "todo_id" $null)
    if (-not $id) { continue }
    $title = [string](Get-Prop $it "title" "")
    $status = [string](Get-Prop $it "status" "open")
    $source = [string](Get-Prop $it "source" "roadmap")
    $created = [string](Get-Prop $it "created_ts" $now)
    $roadmapId = [string](Get-Prop $it "roadmap_id" "")
    if (-not $map.ContainsKey($id)) {
      $row = @{ id=$id; todo_id=$id; title=$title; status=$status; last_status=$status; source=$source; created_ts=$created; last_ts=$now; roadmap_id=$roadmapId }
      $idx.todos += $row
      $map[$id] = $row
    } else {
      $row = $map[$id]
      Set-PropSafe $row "title" $title
      Set-PropSafe $row "status" $status
      Set-PropSafe $row "last_status" $status
      Set-PropSafe $row "source" $source
      if (-not [string](Get-Prop $row "todo_id" "")) { Set-PropSafe $row "todo_id" $id }
      if ($roadmapId) { Set-PropSafe $row "roadmap_id" $roadmapId }
      if (-not [string](Get-Prop $row "created_ts" "")) { Set-PropSafe $row "created_ts" $created }
      Set-PropSafe $row "last_ts" $now
    }
  }
  Save-TodoIndex $idx
  $dg = Try-ReadJson (Get-TodoDigestPath); if ($null -eq $dg) { $dg = @{ ts=NowIso; done_total=0; done_last_30d=0; recent_done=@(); last_prune_ts=$null; last_rotation_ts=$null } }
  Write-Json (Get-TodoDigestPath) $dg; CI-Info "todo-sanitize: ok"
}


