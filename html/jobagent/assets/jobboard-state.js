/* JobAgent personal browser state. No network access and no DOM dependency. */
(function (root, factory) {
    const api = factory();
    if (typeof module === 'object' && module.exports) { module.exports = api; }
    root.JobAgentUserState = api;
}(typeof globalThis === 'object' ? globalThis : this, function () {
    'use strict';

    const SCHEMA_VERSION = 'jobagent-user-state/v2';
    const PROJECT_KEY = 'jobagent:personal:v2';
    const LEGACY_PROJECT_KEY = 'jobagent:personal:v1';
    const UTC_TIMESTAMP = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z$/;
    const LOCAL_DATE = /^\d{4}-\d{2}-\d{2}$/;
    const OFFSET_TIME = /^\d{2}:\d{2}(?:\+|-)(?:0\d|1\d|2[0-3]):[0-5]\d$/;
    const FORBIDDEN_KEYS = new Set(['__proto__', 'constructor', 'prototype']);
    const STAGES = ['NONE', 'PREPARING', 'APPLIED', 'INTERVIEW', 'REJECTED', 'WITHDRAWN'];
    const TASK_TYPES = ['APPLICATION_DEADLINE', 'INTERVIEW', 'FOLLOW_UP', 'OTHER'];
    const TASK_STATUSES = ['OPEN', 'DONE'];
    const HIDDEN_REASONS = ['', 'ROLE', 'LOCATION', 'CONDITIONS', 'EMPLOYER', 'OTHER'];

    function fail(code, message) { const error = new Error(message); error.code = code; throw error; }
    function isPlainObject(value) { return value !== null && typeof value === 'object' && !Array.isArray(value) && Object.getPrototypeOf(value) === Object.prototype; }
    function requireObject(value, name) { if (!isPlainObject(value)) { fail('invalid_state', `${name} muss ein JSON-Objekt sein.`); } return value; }
    function assertOnlyKeys(value, permitted, name) { Object.keys(value).forEach(key => { if (!permitted.has(key)) { fail('invalid_state', `${name} enthaelt das nicht erlaubte Feld ${key}.`); } }); }
    function assertJobId(value) { if (typeof value !== 'string' || !/^job:[^\s]{1,500}$/.test(value) || FORBIDDEN_KEYS.has(value)) { fail('invalid_job_id', 'job_id muss eine stabile, nicht leere JobAgent-ID sein.'); } return value; }
    function assertCompanyId(value) { if (typeof value !== 'string' || !/^[A-Za-z0-9][A-Za-z0-9:_-]{0,500}$/.test(value) || FORBIDDEN_KEYS.has(value)) { fail('invalid_company_id', 'company_id muss eine stabile, nicht leere Firmen-ID sein.'); } return value; }
    function codePointLength(value) { return Array.from(value).length; }
    function assertText(value, field, maximum, nullable) { if (nullable && value === null) { return null; } if (typeof value !== 'string' || codePointLength(value) > maximum) { fail('invalid_state', `${field} muss Text mit maximal ${maximum} Unicode-Codepoints sein.`); } return value; }
    function assertUtcTimestamp(value, field, nullable) { if (nullable && value === null) { return null; } if (typeof value !== 'string' || !UTC_TIMESTAMP.test(value) || Number.isNaN(Date.parse(value))) { fail('invalid_timestamp', `${field} muss ein gueltiger UTC-Zeitpunkt mit Z-Offset sein.`); } return new Date(value).toISOString(); }
    function assertHttpUrl(value, field, nullable) { if (nullable && value === null) { return null; } if (typeof value !== 'string' || value.length > 2048 || !/^https?:\/\//i.test(value)) { fail('invalid_state', `${field} muss eine HTTP(S)-URL oder null sein.`); } return value; }
    function toUtc(now) { const date = now === undefined ? new Date() : new Date(now); if (Number.isNaN(date.getTime())) { fail('invalid_timestamp', 'Die Bedienzeit ist ungueltig.'); } return date.toISOString(); }
    function clone(value) { return JSON.parse(JSON.stringify(value)); }
    function later(first, second) { return first !== null && (second === null || Date.parse(first) > Date.parse(second)); }
    function appliedFromStage(stage) { return !['NONE', 'PREPARING'].includes(stage); }

    function emptyState() { return { schema_version: SCHEMA_VERSION, project_key: PROJECT_KEY, updated_at: null, jobs: {}, hidden_jobs: {}, hidden_companies: {} }; }
    function emptyRecord() { return { favorite: false, favorite_updated_at: null, application_stage: 'NONE', application_updated_at: null, applied: false, applied_at: null, note: '', next_action: '', tasks: [], application_history: [] }; }
    function normalizeReference(value) {
        if (value === undefined) { return undefined; }
        const reference = requireObject(value, 'reference');
        assertOnlyKeys(reference, new Set(['title', 'company', 'official_url', 'observed_at']), 'reference');
        ['title', 'company', 'official_url', 'observed_at'].forEach(key => { if (!(key in reference)) { fail('invalid_state', `reference.${key} fehlt.`); } });
        return { title: assertText(reference.title, 'reference.title', 1000, false), company: assertText(reference.company, 'reference.company', 1000, false), official_url: assertHttpUrl(reference.official_url, 'reference.official_url', true), observed_at: assertUtcTimestamp(reference.observed_at, 'reference.observed_at', false) };
    }
    function normalizeTask(value) {
        const task = requireObject(value, 'tasks.*');
        assertOnlyKeys(task, new Set(['task_id', 'type', 'title', 'local_date', 'time_with_offset', 'status', 'updated_at', 'deleted_at']), 'tasks.*');
        ['task_id', 'type', 'title', 'local_date', 'time_with_offset', 'status', 'updated_at', 'deleted_at'].forEach(key => { if (!(key in task)) { fail('invalid_state', `tasks.*.${key} fehlt.`); } });
        if (typeof task.task_id !== 'string' || !/^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$/.test(task.task_id)) { fail('invalid_task_id', 'task_id ist ungueltig.'); }
        if (!TASK_TYPES.includes(task.type) || !TASK_STATUSES.includes(task.status)) { fail('invalid_state', 'Termin-Typ oder -Status ist ungueltig.'); }
        if (typeof task.local_date !== 'string' || !LOCAL_DATE.test(task.local_date) || Number.isNaN(Date.parse(`${task.local_date}T00:00:00Z`))) { fail('invalid_state', 'local_date muss ein gueltiges lokales YYYY-MM-DD-Datum sein.'); }
        if (task.time_with_offset !== null && (typeof task.time_with_offset !== 'string' || !OFFSET_TIME.test(task.time_with_offset))) { fail('invalid_state', 'time_with_offset muss HH:MM mit explizitem Offset sein.'); }
        return { task_id: task.task_id, type: task.type, title: assertText(task.title, 'tasks.*.title', 200, false), local_date: task.local_date, time_with_offset: task.time_with_offset, status: task.status, updated_at: assertUtcTimestamp(task.updated_at, 'tasks.*.updated_at', false), deleted_at: assertUtcTimestamp(task.deleted_at, 'tasks.*.deleted_at', true) };
    }
    function normalizeHistory(value) {
        if (!Array.isArray(value)) { fail('invalid_state', 'application_history muss eine Liste sein.'); }
        return value.map((entry, index) => { const item = requireObject(entry, `application_history.${index}`); assertOnlyKeys(item, new Set(['from_stage', 'to_stage', 'at', 'reason']), `application_history.${index}`); if (!STAGES.includes(item.from_stage) || !STAGES.includes(item.to_stage)) { fail('invalid_state', 'Historienstufe ist ungueltig.'); } return { from_stage: item.from_stage, to_stage: item.to_stage, at: assertUtcTimestamp(item.at, 'application_history.*.at', false), reason: assertText(item.reason, 'application_history.*.reason', 200, false) }; });
    }
    function normalizeRecord(value) {
        const record = requireObject(value, 'jobs.*');
        assertOnlyKeys(record, new Set(['favorite', 'favorite_updated_at', 'application_stage', 'application_updated_at', 'applied', 'applied_at', 'note', 'next_action', 'tasks', 'application_history', 'reference']), 'jobs.*');
        ['favorite', 'favorite_updated_at', 'application_stage', 'application_updated_at', 'applied', 'applied_at', 'note', 'next_action', 'tasks', 'application_history'].forEach(key => { if (!(key in record)) { fail('invalid_state', `jobs.*.${key} fehlt.`); } });
        if (typeof record.favorite !== 'boolean' || !STAGES.includes(record.application_stage) || typeof record.applied !== 'boolean') { fail('invalid_state', 'Favorit, Stufe oder Bewerbungsprojektion ist ungueltig.'); }
        const normalized = { favorite: record.favorite, favorite_updated_at: assertUtcTimestamp(record.favorite_updated_at, 'jobs.*.favorite_updated_at', true), application_stage: record.application_stage, application_updated_at: assertUtcTimestamp(record.application_updated_at, 'jobs.*.application_updated_at', true), applied: record.applied, applied_at: assertUtcTimestamp(record.applied_at, 'jobs.*.applied_at', true), note: assertText(record.note, 'jobs.*.note', 4000, false), next_action: assertText(record.next_action, 'jobs.*.next_action', 200, false), tasks: record.tasks.map(normalizeTask), application_history: normalizeHistory(record.application_history) };
        if (normalized.applied !== appliedFromStage(normalized.application_stage)) { fail('invalid_state', 'applied muss aus application_stage abgeleitet sein.'); }
        if (normalized.applied && (normalized.application_updated_at === null || normalized.applied_at === null)) { fail('invalid_state', 'Beworbene Stufen brauchen Zeitbelege.'); }
        if (!normalized.applied && normalized.applied_at !== null) { fail('invalid_state', 'Nicht beworbene Stufen duerfen kein applied_at haben.'); }
        if (normalized.tasks.filter(task => task.deleted_at === null && task.status === 'OPEN').length > 20) { fail('task_limit', 'Pro Stelle sind hoechstens 20 offene Termine erlaubt.'); }
        const ids = new Set(); normalized.tasks.forEach(task => { if (ids.has(task.task_id)) { fail('invalid_task_id', 'task_id darf je Stelle nur einmal vorkommen.'); } ids.add(task.task_id); });
        const reference = normalizeReference(record.reference); if (reference !== undefined) { normalized.reference = reference; }
        return normalized;
    }
    function normalizeVisibility(value, field) {
        const entry = requireObject(value, field); assertOnlyKeys(entry, new Set(['hidden', 'reason', 'text', 'updated_at']), field);
        ['hidden', 'reason', 'text', 'updated_at'].forEach(key => { if (!(key in entry)) { fail('invalid_state', `${field}.${key} fehlt.`); } });
        if (typeof entry.hidden !== 'boolean' || !HIDDEN_REASONS.includes(entry.reason)) { fail('invalid_state', `${field} enthaelt einen ungueltigen Ausblendstatus oder Grund.`); }
        return { hidden: entry.hidden, reason: entry.reason, text: assertText(entry.text, `${field}.text`, 500, false), updated_at: assertUtcTimestamp(entry.updated_at, `${field}.updated_at`, false) };
    }
    function normalizeVisibilityMap(value, kind) {
        const source = value === undefined ? {} : requireObject(value, kind), target = {};
        Object.keys(source).sort().forEach(id => { if (kind === 'hidden_jobs') { assertJobId(id); } else { assertCompanyId(id); } target[id] = normalizeVisibility(source[id], `${kind}.${id}`); });
        return target;
    }
    function normalizeState(value) {
        const state = requireObject(value, 'state'); assertOnlyKeys(state, new Set(['schema_version', 'project_key', 'updated_at', 'jobs', 'hidden_jobs', 'hidden_companies']), 'state');
        if (state.schema_version !== SCHEMA_VERSION) { fail(state.schema_version ? 'unsupported_version' : 'invalid_state', 'Die Zustandsversion wird nicht unterstuetzt.'); }
        if (state.project_key !== PROJECT_KEY) { fail('invalid_state', 'Der Zustand gehoert nicht zu diesem JobAgent-Projekt.'); }
        const jobs = requireObject(state.jobs, 'jobs'), normalizedJobs = {};
        Object.keys(jobs).sort().forEach(jobId => { assertJobId(jobId); normalizedJobs[jobId] = normalizeRecord(jobs[jobId]); });
        return { schema_version: SCHEMA_VERSION, project_key: PROJECT_KEY, updated_at: assertUtcTimestamp(state.updated_at, 'updated_at', true), jobs: normalizedJobs, hidden_jobs: normalizeVisibilityMap(state.hidden_jobs, 'hidden_jobs'), hidden_companies: normalizeVisibilityMap(state.hidden_companies, 'hidden_companies') };
    }
    function normalizeLegacyState(value) {
        const legacy = requireObject(value, 'legacy state');
        if (legacy.schema_version !== 'jobagent-user-state/v1' || legacy.project_key !== LEGACY_PROJECT_KEY || !isPlainObject(legacy.jobs)) { fail('unsupported_version', 'Der Altzustand ist nicht v1.'); }
        const migrated = emptyState(); migrated.updated_at = assertUtcTimestamp(legacy.updated_at, 'legacy.updated_at', true);
        Object.keys(legacy.jobs).sort().forEach(jobId => { assertJobId(jobId); const old = requireObject(legacy.jobs[jobId], 'legacy.jobs.*'); if (typeof old.favorite !== 'boolean' || typeof old.applied !== 'boolean') { fail('invalid_state', 'Altzustand enthaelt ungueltige Markierungen.'); } const updated = assertUtcTimestamp(old.applied_updated_at, 'legacy.applied_updated_at', true); const stage = old.applied ? 'APPLIED' : 'NONE'; const record = emptyRecord(); record.favorite = old.favorite; record.favorite_updated_at = assertUtcTimestamp(old.favorite_updated_at, 'legacy.favorite_updated_at', true); record.application_stage = stage; record.application_updated_at = updated; record.applied = old.applied; record.applied_at = old.applied ? assertUtcTimestamp(old.applied_at, 'legacy.applied_at', false) : null; const reference = normalizeReference(old.reference); if (reference !== undefined) { record.reference = reference; } migrated.jobs[jobId] = record; });
        return migrated;
    }
    function readRaw(storage, key) { try { return storage.getItem(key); } catch (_) { return undefined; } }
    function read(storage) {
        if (!storage || typeof storage.getItem !== 'function') { return { persistent: false, reason: 'storage_unavailable', state: emptyState() }; }
        const raw = readRaw(storage, PROJECT_KEY); if (raw === undefined) { return { persistent: false, reason: 'storage_unavailable', state: emptyState() }; }
        if (raw !== null) { try { return { persistent: true, reason: 'valid', state: normalizeState(JSON.parse(raw)), raw }; } catch (error) { return { persistent: false, reason: error.code || 'corrupt', state: emptyState(), raw }; } }
        const legacyRaw = readRaw(storage, LEGACY_PROJECT_KEY); if (legacyRaw === undefined) { return { persistent: false, reason: 'storage_unavailable', state: emptyState() }; }
        if (legacyRaw === null) { return { persistent: true, reason: 'missing', state: emptyState() }; }
        try { return { persistent: true, reason: 'migrated_v1_pending_save', state: normalizeLegacyState(JSON.parse(legacyRaw)), legacy_raw: legacyRaw }; } catch (error) { return { persistent: false, reason: error.code || 'corrupt', state: emptyState(), raw: legacyRaw }; }
    }
    function write(storage, state) { const serialized = JSON.stringify(normalizeState(state)); try { storage.setItem(PROJECT_KEY, serialized); return { persistent: true, serialized }; } catch (_) { return { persistent: false, reason: 'storage_write_failed' }; } }
    function referenceFromJob(job, observedAt) { if (!job || typeof job !== 'object') { return undefined; } if (!['title', 'company', 'official_url'].some(key => Object.prototype.hasOwnProperty.call(job, key))) { return undefined; } return { title: assertText(job.title || '', 'job.title', 1000, false), company: assertText(job.company || '', 'job.company', 1000, false), official_url: assertHttpUrl(job.official_url === undefined ? null : job.official_url, 'job.official_url', true), observed_at: observedAt }; }
    function saveMutation(storage, job, now, mutate) { const jobId = assertJobId(job && job.job_id); const loaded = read(storage); if (!loaded.persistent) { return { persistent: false, changed: false, reason: loaded.reason, state: loaded.state, record: null }; } const state = clone(loaded.state), record = state.jobs[jobId] ? clone(state.jobs[jobId]) : emptyRecord(), timestamp = toUtc(now); const changed = mutate(record, timestamp); if (!changed) { return { persistent: true, changed: false, reason: 'unchanged', state, record: clone(record) }; } const reference = referenceFromJob(job, timestamp); if (reference !== undefined) { record.reference = reference; } state.jobs[jobId] = record; state.updated_at = timestamp; const saved = write(storage, state); return saved.persistent ? { persistent: true, changed: true, reason: 'saved', state, record: clone(record) } : { persistent: false, changed: false, reason: saved.reason, state: loaded.state, record: null }; }
    function transitionAllowed(from, to) { return (from === 'NONE' && ['PREPARING', 'APPLIED'].includes(to)) || (from === 'PREPARING' && ['NONE', 'APPLIED'].includes(to)) || (from === 'APPLIED' && ['INTERVIEW', 'REJECTED', 'WITHDRAWN'].includes(to)) || (from === 'INTERVIEW' && ['REJECTED', 'WITHDRAWN'].includes(to)); }
    function transitionApplication(storage, job, stage, options, now) { if (!STAGES.includes(stage)) { fail('invalid_stage', 'Die Bewerbungsstufe ist ungueltig.'); } const correction = options && options.correction === true, reason = options && options.reason !== undefined ? assertText(options.reason, 'reason', 200, false) : ''; return saveMutation(storage, job, now, (record, timestamp) => { const from = record.application_stage; if (from === stage) { return false; } if (!transitionAllowed(from, stage) && !correction) { fail('invalid_transition', 'Dieser Stufenwechsel braucht eine ausdrueckliche Benutzerkorrektur.'); } record.application_stage = stage; record.application_updated_at = timestamp; record.applied = appliedFromStage(stage); record.applied_at = record.applied ? timestamp : null; if (correction && !transitionAllowed(from, stage)) { record.application_history.push({ from_stage: from, to_stage: stage, at: timestamp, reason }); } return true; }); }
    function setMark(storage, job, field, enabled, now, options) { if (field === 'applied') { return transitionApplication(storage, job, enabled ? 'APPLIED' : 'NONE', options, now); } if (field !== 'favorite' || typeof enabled !== 'boolean') { fail('invalid_field', 'Nur favorite oder applied duerfen gesetzt werden.'); } return saveMutation(storage, job, now, (record, timestamp) => { if (record.favorite === enabled) { return false; } record.favorite = enabled; record.favorite_updated_at = timestamp; return true; }); }
    function setVisibility(storage, scope, id, hidden, options, now) {
        if (!['job', 'company'].includes(scope) || typeof hidden !== 'boolean') { fail('invalid_visibility', 'Ausblendung braucht einen gueltigen Bereich und Wahrheitswert.'); }
        const stableId = scope === 'job' ? assertJobId(id) : assertCompanyId(id), input = options === undefined ? {} : requireObject(options, 'visibility options');
        assertOnlyKeys(input, new Set(['reason', 'text']), 'visibility options');
        const reason = input.reason === undefined ? '' : input.reason, detail = input.text === undefined ? '' : assertText(input.text, 'visibility text', 500, false);
        if (!HIDDEN_REASONS.includes(reason)) { fail('invalid_visibility_reason', 'Der Ausblendgrund ist ungueltig.'); }
        const loaded = read(storage); if (!loaded.persistent) { return { persistent: false, changed: false, reason: loaded.reason, state: loaded.state }; }
        const state = clone(loaded.state), bucket = scope === 'job' ? state.hidden_jobs : state.hidden_companies, current = bucket[stableId], timestamp = toUtc(now);
        if (current && current.hidden === hidden && current.reason === reason && current.text === detail) { return { persistent: true, changed: false, reason: 'unchanged', state }; }
        bucket[stableId] = { hidden, reason, text: detail, updated_at: timestamp }; state.updated_at = timestamp;
        const saved = write(storage, state); return saved.persistent ? { persistent: true, changed: true, reason: 'saved', state: clone(state), entry: clone(bucket[stableId]) } : { persistent: false, changed: false, reason: saved.reason, state: loaded.state };
    }
    function visibilityFor(state, jobId, companyId) {
        const normalized = normalizeState(state), job = normalized.hidden_jobs[assertJobId(jobId)], company = normalized.hidden_companies[assertCompanyId(companyId)];
        if (job && job.hidden) { return { hidden: true, scope: 'job', entry: clone(job), company_hidden: Boolean(company && company.hidden) }; }
        if (company && company.hidden) { return { hidden: true, scope: 'company', entry: clone(company), company_hidden: true }; }
        return { hidden: false, scope: '', entry: null, company_hidden: false };
    }
    function updateApplicationText(storage, job, values, now) { const update = requireObject(values, 'application data'); assertOnlyKeys(update, new Set(['note', 'next_action']), 'application data'); return saveMutation(storage, job, now, record => { let changed = false; ['note', 'next_action'].forEach(key => { if (Object.prototype.hasOwnProperty.call(update, key)) { const value = assertText(update[key], key, key === 'note' ? 4000 : 200, false); if (record[key] !== value) { record[key] = value; changed = true; } } }); return changed; }); }
    function upsertTask(storage, job, task, now) { const input = requireObject(task, 'task'); return saveMutation(storage, job, now, (record, timestamp) => { const item = normalizeTask({ task_id: input.task_id, type: input.type, title: input.title, local_date: input.local_date, time_with_offset: input.time_with_offset === undefined ? null : input.time_with_offset, status: input.status === undefined ? 'OPEN' : input.status, updated_at: timestamp, deleted_at: null }); const index = record.tasks.findIndex(candidate => candidate.task_id === item.task_id); if (index < 0 && item.status === 'OPEN' && record.tasks.filter(candidate => candidate.deleted_at === null && candidate.status === 'OPEN').length >= 20) { fail('task_limit', 'Pro Stelle sind hoechstens 20 offene Termine erlaubt.'); } if (index >= 0 && record.tasks[index].deleted_at !== null) { fail('task_deleted', 'Ein geloeschter Termin darf nicht still wiederbelebt werden.'); } if (index >= 0 && JSON.stringify(Object.assign({}, record.tasks[index], { updated_at: item.updated_at })) === JSON.stringify(item)) { return false; } if (index >= 0) { record.tasks[index] = item; } else { record.tasks.push(item); } return true; }); }
    function deleteTask(storage, job, taskId, now) { if (typeof taskId !== 'string') { fail('invalid_task_id', 'task_id ist ungueltig.'); } return saveMutation(storage, job, now, (record, timestamp) => { const task = record.tasks.find(candidate => candidate.task_id === taskId); if (!task || task.deleted_at !== null) { return false; } task.deleted_at = timestamp; task.updated_at = timestamp; return true; }); }
    function mergeRecord(existing, incoming) { const merged = clone(existing); if (later(incoming.favorite_updated_at, existing.favorite_updated_at)) { merged.favorite = incoming.favorite; merged.favorite_updated_at = incoming.favorite_updated_at; } if (later(incoming.application_updated_at, existing.application_updated_at)) { ['application_stage', 'application_updated_at', 'applied', 'applied_at', 'application_history', 'note', 'next_action'].forEach(key => { merged[key] = clone(incoming[key]); }); } const tasks = new Map(existing.tasks.map(task => [task.task_id, task])); incoming.tasks.forEach(task => { const old = tasks.get(task.task_id); if (!old || later(task.updated_at, old.updated_at)) { tasks.set(task.task_id, clone(task)); } }); merged.tasks = Array.from(tasks.values()).sort((left, right) => left.task_id.localeCompare(right.task_id, 'de')); if (incoming.reference && (!existing.reference || later(incoming.reference.observed_at, existing.reference.observed_at))) { merged.reference = clone(incoming.reference); } return normalizeRecord(merged); }
    function mergeVisibility(existing, incoming) { return !existing || later(incoming.updated_at, existing.updated_at) ? clone(incoming) : clone(existing); }
    function previewImport(storage, serialized) { const loaded = read(storage); if (!loaded.persistent) { return { valid: false, persistent: false, reason: loaded.reason, state: loaded.state }; } let imported; try { imported = normalizeState(typeof serialized === 'string' ? JSON.parse(serialized) : serialized); } catch (error) { return { valid: false, persistent: true, reason: error.code || 'invalid_import', state: loaded.state }; } const merged = clone(loaded.state), changedJobIds = [], changedVisibilityIds = []; Object.keys(imported.jobs).sort().forEach(jobId => { const existing = merged.jobs[jobId], candidate = existing ? mergeRecord(existing, imported.jobs[jobId]) : clone(imported.jobs[jobId]); if (JSON.stringify(candidate) !== JSON.stringify(existing)) { merged.jobs[jobId] = candidate; changedJobIds.push(jobId); } }); ['hidden_jobs', 'hidden_companies'].forEach(bucket => Object.keys(imported[bucket]).sort().forEach(id => { const candidate = mergeVisibility(merged[bucket][id], imported[bucket][id]); if (JSON.stringify(candidate) !== JSON.stringify(merged[bucket][id])) { merged[bucket][id] = candidate; changedVisibilityIds.push(`${bucket}:${id}`); } })); if (changedJobIds.length || changedVisibilityIds.length) { merged.updated_at = imported.updated_at || loaded.state.updated_at; } return { valid: true, persistent: true, reason: 'preview', state: merged, changed_job_ids: changedJobIds, changed_visibility_ids: changedVisibilityIds, imported_job_ids: Object.keys(imported.jobs).sort() }; }
    function importState(storage, serialized) { const preview = previewImport(storage, serialized); if (!preview.valid || !preview.persistent || !preview.changed_job_ids.length) { return Object.assign({}, preview, { changed: false }); } const saved = write(storage, preview.state); return saved.persistent ? Object.assign({}, preview, { changed: true, reason: 'imported' }) : { valid: true, persistent: false, changed: false, reason: saved.reason, state: read(storage).state, changed_job_ids: [] }; }
    function exportState(storage) { const loaded = read(storage); return { persistent: loaded.persistent, reason: loaded.reason, serialized: JSON.stringify(loaded.state), state: clone(loaded.state) }; }
    function subscribeStorage(storage, callback, eventTarget) { const target = eventTarget || root; if (!target || typeof target.addEventListener !== 'function' || typeof callback !== 'function') { return () => {}; } const listener = event => { if (!event || event.key !== PROJECT_KEY || (event.storageArea && storage && event.storageArea !== storage)) { return; } if (event.newValue === null) { callback({ persistent: true, reason: 'missing', state: emptyState() }); return; } try { callback({ persistent: true, reason: 'valid', state: normalizeState(JSON.parse(event.newValue)) }); } catch (error) { callback({ persistent: false, reason: error.code || 'corrupt', state: emptyState() }); } }; target.addEventListener('storage', listener); return () => target.removeEventListener('storage', listener); }
    return Object.freeze({ SCHEMA_VERSION, PROJECT_KEY, LEGACY_PROJECT_KEY, STAGES, TASK_TYPES, TASK_STATUSES, HIDDEN_REASONS, createEmptyState: emptyState, createEmptyRecord: emptyRecord, normalizeState, read, setMark, setVisibility, visibilityFor, transitionApplication, updateApplicationText, upsertTask, deleteTask, previewImport, importState, exportState, subscribeStorage });
}));
