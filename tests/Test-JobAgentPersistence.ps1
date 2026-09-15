#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Get-FileSha256 {
    param([Parameter(Mandatory)][string]$Path)

    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Set-AtomicWriteFault {
    param([Parameter()][scriptblock]$FaultInjector)

    $module = Get-Module JobAgent.Persistence
    & $module {
        param($injector)
        $script:AtomicWriteFaultInjector = $injector
    } $FaultInjector
}

function Assert-AtomicWriteFailurePreservesStore {
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][string]$DataRoot,
        [Parameter(Mandatory)][object]$Document,
        [Parameter(Mandatory)][string]$FailurePoint,
        [Parameter()][switch]$CreateBackup
    )

    $paths = Get-JobAgentStorePaths -ProjectRoot $ProjectRoot -DataRoot $DataRoot
    $beforeHash = Get-FileSha256 -Path $paths.store_path
    Set-AtomicWriteFault -FaultInjector {
        param($point)
        if ($point -eq $FailurePoint) {
            throw "Erwartete Testunterbrechung: $point"
        }
    }
    try {
        try {
            Write-JobAgentStore -ProjectRoot $ProjectRoot -DataRoot $DataRoot -Document $Document -CreateBackup:$CreateBackup | Out-Null
            throw "Testunterbrechung $FailurePoint wurde nicht ausgeloest."
        }
        catch {
            Assert-True -Condition ($_.Exception.Message -match 'Erwartete Testunterbrechung') -Message "Unerwarteter Fehler bei ${FailurePoint}: $($_.Exception.Message)"
        }
    }
    finally {
        Set-AtomicWriteFault
    }
    Assert-True -Condition ((Get-FileSha256 -Path $paths.store_path) -eq $beforeHash) -Message "Store wurde bei Unterbrechung $FailurePoint veraendert."
    Assert-True -Condition (@(Get-ChildItem -LiteralPath $paths.data_root -Filter '.store.json.*.tmp' -File).Count -eq 0) -Message "Temporäre Datei blieb nach Unterbrechung $FailurePoint zurueck."
}

function New-TestLocation {
    [pscustomobject]@{
        label = 'Muenchen'
        city = 'Muenchen'
        region = 'Bayern'
        country = 'DE'
        target_area = 'MUNICH'
    }
}

function New-TestCompany {
    param([string]$Name = 'Example AG')
    [pscustomobject]@{
        company_id = 'company:example_ag'
        canonical_name = $Name
        canonical_domain = 'example.invalid'
        official_website_url = 'https://example.invalid/'
        career_url = 'https://example.invalid/careers'
        aliases = @('Example')
        locations = @(New-TestLocation)
        industry = 'UNKNOWN'
        ats = @()
        scan_status = 'SUCCESS'
        scan_priority = 80
        next_scan_at = '2026-08-18T10:30:00Z'
        verification_status = 'CAREER_URL_VERIFIED'
        discovery_source = [pscustomobject]@{
            type = 'OFFICIAL_WEBSITE'
            url = 'https://example.invalid/careers'
            observed_at = '2026-08-17T10:00:00Z'
            verification_url = 'https://example.invalid/careers'
            discovery_origin = 'seed.manual'
            target_area = 'MUNICH'
            industry_hint = 'UNKNOWN'
            evidence_note = 'Offizielle Firmenquelle wurde manuell gepflegt.'
        }
        created_at = '2026-08-17T10:00:00Z'
        updated_at = '2026-08-17T10:30:00Z'
        last_successful_scan_at = '2026-08-17T10:30:00Z'
    }
}

function New-TestSource {
    [pscustomobject]@{
        source_id = 'source:example_ag_career'
        company_id = 'company:example_ag'
        source_type = 'CAREER_PAGE'
        url = 'https://example.invalid/careers'
        canonical_url = 'https://example.invalid/careers'
        is_official = $true
        verified_at = '2026-08-17T10:30:00Z'
        verification_basis = 'CAREER_URL'
        verification_evidence = @(
            [pscustomobject]@{
                status = 'VERIFIED'
                evidence_type = 'CAREER_URL'
                url = 'https://example.invalid/careers'
                basis_url = 'https://example.invalid/'
                redirect_chain = @()
                observed_at = '2026-08-17T10:30:00Z'
                reason = 'Karriere-URL wurde als offizielle Firmenquelle gepflegt.'
            }
        )
    }
}

function New-TestJob {
    param(
        [string]$Status = 'NEW',
        [string]$JobId = 'job:example_ag_head_it_123',
        [string]$SourceId = 'source:example_ag_career',
        [string]$OfficialUrl = 'https://example.invalid/careers/head-it-123'
    )
    [pscustomobject]@{
        job_id = $JobId
        company_id = 'company:example_ag'
        official_url = $OfficialUrl
        alternative_official_urls = @()
        source_id = $SourceId
        external_job_id = '123'
        ats_job_id = 'UNKNOWN'
        title = 'Head of IT'
        location = New-TestLocation
        work_model = 'HYBRID'
        employment_type = 'FULL_TIME'
        status = $Status
        first_seen = '2026-08-17T10:30:00Z'
        last_seen = '2026-08-17T10:30:00Z'
        changed_at = '2026-08-17T10:30:00Z'
        classification = [pscustomobject]@{
            result = 'MATCH'
            priority = 'A'
            score = 92
            reasons = @('IT-Gesamtverantwortung belegt')
            rejected_reasons = @()
            evaluated_at = '2026-08-17T10:30:00Z'
        }
        priority = 'A'
        requirements = @('Fuehrungserfahrung')
        salary = 'UNKNOWN'
        identity_basis = 'OFFICIAL_JOB_ID'
    }
}

function New-TestSnapshot {
    param([string]$Status = 'NEW')
    [pscustomobject]@{
        snapshot_id = 'snapshot:example_ag_head_it_123_20260817'
        job_id = 'job:example_ag_head_it_123'
        scan_run_id = 'scanrun:20260817T103000Z'
        source_id = 'source:example_ag_career'
        captured_at = '2026-08-17T10:30:10Z'
        content_hash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
        status = $Status
        title = 'Head of IT'
        location = New-TestLocation
        official_url = 'https://example.invalid/careers/head-it-123'
        summary = 'IT-Fuehrungsrolle mit offizieller Detailseite.'
    }
}

function New-TestScanAttempt {
    [pscustomobject]@{
        scan_attempt_id = 'scanattempt:example_ag_20260817T103000Z'
        scan_run_id = 'scanrun:20260817T103000Z'
        company_id = 'company:example_ag'
        source_id = 'source:example_ag_career'
        started_at = '2026-08-17T10:30:00Z'
        finished_at = '2026-08-17T10:30:10Z'
        status = 'SUCCESS'
        adapter = 'fixture-html'
        error_class = 'NONE'
        retry_recommendation = 'NONE'
        http_status = 200
    }
}

function New-TestScanRun {
    [pscustomobject]@{
        scan_run_id = 'scanrun:20260817T103000Z'
        started_at = '2026-08-17T10:30:00Z'
        finished_at = '2026-08-17T10:31:00Z'
        status = 'SUCCESS'
        company_ids = @('company:example_ag')
        artifact_paths = @('logs/jobagent/daily-run-2026-08-17.json')
        errors = @()
    }
}

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('jobagent-persistence-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

try {
    $empty = Read-JobAgentStore -ProjectRoot $testRoot
    Assert-True -Condition ($empty.schema_version -eq 'jobagent/v1') -Message 'Leerer Store liefert falsche Schema-Version.'
    Assert-True -Condition (@($empty.jobs).Count -eq 0) -Message 'Leerer Store enthaelt Jobs.'
    Assert-True -Condition (@($empty.discovery_inventory).Count -eq 0) -Message 'Leerer Store initialisiert discovery_inventory nicht.'
    Assert-True -Condition (@($empty.discovered_urls).Count -eq 0) -Message 'Leerer Store initialisiert discovered_urls nicht.'

    $transaction = Invoke-JobAgentStoreTransaction -ProjectRoot $testRoot -ScriptBlock {
        param($document)
        $document = Upsert-JobAgentCompany -Document $document -Company (New-TestCompany)
        $document = Upsert-JobAgentJobSource -Document $document -JobSource (New-TestSource)
        $document = Upsert-JobAgentScanRun -Document $document -ScanRun (New-TestScanRun)
        $document = Upsert-JobAgentJobSnapshot -Document $document -Job (New-TestJob) -Snapshot (New-TestSnapshot) -ChangeEvent ([pscustomobject]@{
            change_event_id = 'change:example_ag_head_it_123_created'
            job_id = 'job:example_ag_head_it_123'
            scan_run_id = 'scanrun:20260817T103000Z'
            event_type = 'JOB_CREATED'
            created_at = '2026-08-17T10:30:10Z'
            old_status = $null
            new_status = 'NEW'
            changed_fields = @('status')
            reason = 'Erstmals ueber offizielle Karriere-URL erkannt.'
        })
        Record-JobAgentScanAttempt -Document $document -ScanAttempt (New-TestScanAttempt)
    }
    Assert-True -Condition (Test-Path -LiteralPath $transaction.store_path) -Message 'Store wurde nicht geschrieben.'

    $loaded = Read-JobAgentStore -ProjectRoot $testRoot
    Assert-True -Condition (@($loaded.companies).Count -eq 1) -Message 'Company wurde nicht persistiert.'
    Assert-True -Condition (@($loaded.jobs).Count -eq 1) -Message 'Job wurde nicht persistiert.'
    Assert-True -Condition ($loaded.jobs[0].job_validity.result -eq 'UNKNOWN') -Message 'Legacy-Job erhielt keinen sicheren UNKNOWN-Gueltigkeitsstatus.'
    Assert-True -Condition ($loaded.jobs[0].regional_scope.result -eq 'UNKNOWN') -Message 'Legacy-Job erhielt keinen sicheren UNKNOWN-Gebietsstatus.'
    Assert-True -Condition (@($loaded.scan_attempts).Count -eq 1) -Message 'ScanAttempt wurde nicht persistiert.'
    Assert-True -Condition (@($loaded.job_sources[0].verification_evidence).Count -eq 1) -Message 'Verifikationsbeleg wurde nicht persistiert.'
    Assert-True -Condition (@($loaded.discovery_inventory).Count -eq 0) -Message 'Direkter Store-Upsert darf kein Discovery-Inventar erfinden.'
    Assert-True -Condition (@($loaded.discovered_urls).Count -eq 0) -Message 'Direkter Store-Upsert darf keine Discovery-URLs erfinden.'

    Invoke-JobAgentStoreTransaction -ProjectRoot $testRoot -CreateBackup -ScriptBlock {
        param($document)
        Upsert-JobAgentCompany -Document $document -Company (New-TestCompany -Name 'Example AG Updated')
    } | Out-Null
    $reloaded = Read-JobAgentStore -ProjectRoot $testRoot
    Assert-True -Condition (@($reloaded.companies).Count -eq 1) -Message 'Idempotentes Upsert hat Duplikat erzeugt.'
    Assert-True -Condition ($reloaded.companies[0].canonical_name -eq 'Example AG Updated') -Message 'Idempotentes Upsert hat Firma nicht aktualisiert.'
    $paths = Get-JobAgentStorePaths -ProjectRoot $testRoot
    Assert-True -Condition (@(Get-ChildItem -LiteralPath $paths.backup_root -Filter '*.json').Count -ge 1) -Message 'Backup wurde nicht erzeugt.'

    $interruptedDocument = $reloaded.PSObject.Copy()
    $interruptedDocument.companies = @($reloaded.companies)
    $interruptedDocument.companies[0].canonical_name = 'Darf nicht persistiert werden'
    foreach ($failurePoint in @('before_temp_write', 'before_replace')) {
        Assert-AtomicWriteFailurePreservesStore -ProjectRoot $testRoot -DataRoot 'data/jobagent' -Document $interruptedDocument -FailurePoint $failurePoint
    }
    $backupPathsBeforeInterruptedWrite = @((Get-ChildItem -LiteralPath $paths.backup_root -Filter '*.json' -File).FullName)
    Assert-AtomicWriteFailurePreservesStore -ProjectRoot $testRoot -DataRoot 'data/jobagent' -Document $interruptedDocument -FailurePoint 'after_backup' -CreateBackup
    $backupPathsAfterInterruptedWrite = @((Get-ChildItem -LiteralPath $paths.backup_root -Filter '*.json' -File).FullName)
    $interruptedBackup = @($backupPathsAfterInterruptedWrite | Where-Object { $_ -notin $backupPathsBeforeInterruptedWrite })
    Assert-True -Condition ($interruptedBackup.Count -eq 1) -Message 'Unterbrechung nach Backup erzeugt keinen eindeutigen belegbaren Backup-Snapshot.'
    Assert-True -Condition ((Get-FileSha256 -Path $paths.store_path) -eq (Get-FileSha256 -Path $interruptedBackup[0])) -Message 'Backup nach Unterbrechung stimmt nicht mit der geschuetzten Storegeneration ueberein.'

    $migrationPaths = Get-JobAgentStorePaths -ProjectRoot $testRoot -DataRoot 'migration'
    New-Item -ItemType Directory -Path $migrationPaths.data_root -Force | Out-Null
    $legacy = New-JobAgentEmptyDocument
    $legacy.schema_version = 'jobagent/v0'
    Set-Content -LiteralPath $migrationPaths.store_path -Value ($legacy | ConvertTo-Json -Depth 100) -Encoding UTF8
    $migration = Update-JobAgentStoreMigration -ProjectRoot $testRoot -DataRoot 'migration'
    Assert-True -Condition ($migration.migrated -eq $true) -Message 'Migration wurde nicht ausgefuehrt.'
    Assert-True -Condition ((Read-JobAgentStore -ProjectRoot $testRoot -DataRoot 'migration').schema_version -eq 'jobagent/v1') -Message 'Migration hat Schema-Version nicht angehoben.'
    Assert-True -Condition (Test-Path -LiteralPath $migrationPaths.migration_log_path) -Message 'Migrationslog wurde nicht geschrieben.'

    $unsupportedMigrationPaths = Get-JobAgentStorePaths -ProjectRoot $testRoot -DataRoot 'unsupported-migration'
    New-Item -ItemType Directory -Path $unsupportedMigrationPaths.data_root -Force | Out-Null
    $unsupportedMigration = New-JobAgentEmptyDocument
    $unsupportedMigration.schema_version = 'jobagent/v999'
    Set-Content -LiteralPath $unsupportedMigrationPaths.store_path -Value ($unsupportedMigration | ConvertTo-Json -Depth 100) -Encoding UTF8
    $unsupportedMigrationHash = Get-FileSha256 -Path $unsupportedMigrationPaths.store_path
    try {
        Update-JobAgentStoreMigration -ProjectRoot $testRoot -DataRoot 'unsupported-migration' | Out-Null
        throw 'Unbekannte Schema-Migration wurde akzeptiert.'
    }
    catch {
        Assert-True -Condition ($_.Exception.Message -match 'Keine Migration') -Message "Unerwarteter Fehler fuer unbekannte Migration: $($_.Exception.Message)"
    }
    Assert-True -Condition ((Get-FileSha256 -Path $unsupportedMigrationPaths.store_path) -eq $unsupportedMigrationHash) -Message 'Unbekannte Migration hat den vorhandenen Store veraendert.'

    $legacyPaths = Get-JobAgentStorePaths -ProjectRoot $testRoot -DataRoot 'legacy-v1'
    New-Item -ItemType Directory -Path $legacyPaths.data_root -Force | Out-Null
    $legacyV1 = New-JobAgentEmptyDocument
    $legacyV1.companies = @((New-TestCompany))
    $legacyV1.job_sources = @(
        [pscustomobject]@{
            source_id = 'source:example_ag_career'
            company_id = 'company:example_ag'
            source_type = 'CAREER_PAGE'
            url = 'https://example.invalid/careers'
            canonical_url = 'https://example.invalid/careers'
            is_official = $true
            verified_at = '2026-08-17T10:30:00Z'
            verification_basis = 'CAREER_URL'
        }
    )
    Set-Content -LiteralPath $legacyPaths.store_path -Value ($legacyV1 | ConvertTo-Json -Depth 100) -Encoding UTF8
    $legacyLoaded = Read-JobAgentStore -ProjectRoot $testRoot -DataRoot 'legacy-v1'
    Assert-True -Condition (@($legacyLoaded.job_sources[0].verification_evidence).Count -eq 1) -Message 'Legacy-v1-Quelle wurde nicht mit Verifikationsbeleg normalisiert.'
    Assert-True -Condition ($legacyLoaded.job_sources[0].verification_evidence[0].evidence_type -eq 'CAREER_URL') -Message 'Legacy-v1-Normalisierung nutzt falschen Evidenztyp.'
    Assert-True -Condition (@($legacyLoaded.discovery_inventory).Count -eq 0) -Message 'Legacy-v1-Normalisierung setzt discovery_inventory nicht verlustfrei auf leer.'
    Assert-True -Condition (@($legacyLoaded.discovered_urls).Count -eq 0) -Message 'Legacy-v1-Normalisierung setzt discovered_urls nicht verlustfrei auf leer.'

    $candidates = @(Get-JobAgentDailyOutputCandidates -Document $reloaded)
    Assert-True -Condition ($candidates.Count -eq 1) -Message 'DailyOutputCandidates liefert unerwartete Anzahl.'

    $removed = Mark-JobAgentMissingJobs -Document $reloaded -CompanyId 'company:example_ag' -SeenJobIds @() -ScanRunId 'scanrun:20260817T103000Z' -ChangedAt '2026-08-17T12:00:00Z'
    Assert-True -Condition ($removed.jobs[0].status -eq 'REMOVED') -Message 'markMissingJobs setzt Status nicht auf REMOVED.'
    Assert-True -Condition (@($removed.change_events | Where-Object event_type -eq 'JOB_REMOVED').Count -eq 1) -Message 'markMissingJobs erzeugt kein ChangeEvent.'

    $sourceScoped = $reloaded.PSObject.Copy()
    $sourceScoped.jobs = @(
        (New-TestJob -JobId 'job:example_ag_head_it_123' -SourceId 'source:example_ag_career' -OfficialUrl 'https://example.invalid/careers/head-it-123'),
        (New-TestJob -JobId 'job:example_ag_head_it_456' -SourceId 'source:example_ag_ats' -OfficialUrl 'https://jobs.example.invalid/posting/456')
    )
    $sourceScoped.change_events = @()
    $sourceScopedRemoved = Mark-JobAgentMissingJobs -Document $sourceScoped -CompanyId 'company:example_ag' -SourceId 'source:example_ag_career' -SeenJobIds @() -ScanRunId 'scanrun:20260817T123000Z' -ChangedAt '2026-08-17T12:30:00Z'
    $sourceScopedCareerJob = @($sourceScopedRemoved.jobs | Where-Object { [string]$_.source_id -eq 'source:example_ag_career' })[0]
    $sourceScopedAtsJob = @($sourceScopedRemoved.jobs | Where-Object { [string]$_.source_id -eq 'source:example_ag_ats' })[0]
    Assert-True -Condition ($sourceScopedCareerJob.status -eq 'REMOVED') -Message 'Quellgefiltertes markMissingJobs entfernt den betroffenen Quelljob nicht.'
    Assert-True -Condition ($sourceScopedAtsJob.status -ne 'REMOVED') -Message 'Quellgefiltertes markMissingJobs entfernt fremde Quellen faelschlich.'

    $badRoot = Join-Path $testRoot 'bad'
    New-Item -ItemType Directory -Path $badRoot -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $badRoot 'store.json') -Value '{bad-json' -Encoding UTF8
    try {
        Read-JobAgentStore -ProjectRoot $testRoot -DataRoot 'bad' | Out-Null
        throw 'Beschaedigter Store wurde akzeptiert.'
    }
    catch {
        Assert-True -Condition ($_.Exception.Message -match 'kann nicht geladen') -Message "Unerwarteter Fehler fuer beschaedigten Store: $($_.Exception.Message)"
    }

    $lock = Enter-JobAgentStoreLock -ProjectRoot $testRoot
    try {
        try {
            Enter-JobAgentStoreLock -ProjectRoot $testRoot | Out-Null
            throw 'Parallele Lock-Verletzung wurde akzeptiert.'
        }
        catch {
            Assert-True -Condition ($_.Exception.Message -match 'gesperrt') -Message "Unerwarteter Lock-Fehler: $($_.Exception.Message)"
        }
    }
    finally {
        Exit-JobAgentStoreLock -Lock $lock
    }

    $stalePaths = Get-JobAgentStorePaths -ProjectRoot $testRoot -DataRoot 'stale-lock'
    New-Item -ItemType Directory -Path $stalePaths.data_root -Force | Out-Null
    Set-Content -LiteralPath $stalePaths.lock_path -Value '{"pid":999999,"acquired_at":"2000-01-01T00:00:00.000Z"}' -Encoding UTF8
    $staleLock = Enter-JobAgentStoreLock -ProjectRoot $testRoot -DataRoot 'stale-lock'
    Exit-JobAgentStoreLock -Lock $staleLock
    Exit-JobAgentStoreLock -Lock $staleLock
    $stalePayload = Get-Content -LiteralPath $stalePaths.lock_path -Raw | ConvertFrom-Json
    Assert-True -Condition ($stalePayload.pid -eq $PID) -Message 'Stale-Lock wurde nicht durch den aktuellen Besitzer uebernommen.'
    $reacquiredLock = Enter-JobAgentStoreLock -ProjectRoot $testRoot -DataRoot 'stale-lock'
    Exit-JobAgentStoreLock -Lock $reacquiredLock

    $outside = Join-Path ([IO.Path]::GetTempPath()) ('jobagent-outside-' + [guid]::NewGuid().ToString('N'))
    try {
        Get-JobAgentStorePaths -ProjectRoot $testRoot -DataRoot $outside | Out-Null
        throw 'Absoluter Fremdpfad wurde akzeptiert.'
    }
    catch {
        Assert-True -Condition ($_.Exception.Message -match 'ausserhalb') -Message "Unerwarteter Pfadfehler: $($_.Exception.Message)"
    }

    try {
        Get-JobAgentStorePaths -ProjectRoot $testRoot -DataRoot '..\\escaped' | Out-Null
        throw 'Traversal-Pfad wurde akzeptiert.'
    }
    catch {
        Assert-True -Condition ($_.Exception.Message -match 'ausserhalb') -Message "Unerwarteter Traversalfehler: $($_.Exception.Message)"
    }

    [pscustomobject]@{
        status = 'ok'
        cases = @('empty_store', 'write_reload', 'legacy_job_scope_normalization', 'idempotent_upsert', 'backup', 'atomic_write_interruptions', 'migration', 'unsupported_migration_preserves_store', 'legacy_v1_source_evidence_normalization', 'discovery_retention_shape', 'corrupt_store', 'lock_violation', 'stale_lock_and_repeated_release', 'path_guard', 'traversal_guard', 'missing_jobs', 'source_scoped_missing_jobs')
        store_path = $paths.store_path
    } | ConvertTo-Json -Depth 4
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
