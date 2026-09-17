/* JobAgent personal browser state. No network access and no DOM dependency. */
(function (root, factory) {
    const api = factory();
    if (typeof module === 'object' && module.exports) {
        module.exports = api;
    }
    root.JobAgentUserState = api;
}(typeof globalThis === 'object' ? globalThis : this, function () {
    'use strict';

    const SCHEMA_VERSION = 'jobagent-user-state/v1';
    const PROJECT_KEY = 'jobagent:personal:v1';
    const UTC_TIMESTAMP = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z$/;
    const FORBIDDEN_KEYS = new Set(['__proto__', 'constructor', 'prototype']);

    function fail(code, message) {
        const error = new Error(message);
        error.code = code;
        throw error;
    }

    function isPlainObject(value) {
        return value !== null && typeof value === 'object' && !Array.isArray(value) && Object.getPrototypeOf(value) === Object.prototype;
    }

    function requireObject(value, name) {
        if (!isPlainObject(value)) {
            fail('invalid_state', `${name} muss ein JSON-Objekt sein.`);
        }
        return value;
    }

    function assertOnlyKeys(value, permitted, name) {
        Object.keys(value).forEach((key) => {
            if (!permitted.has(key)) {
                fail('invalid_state', `${name} enthaelt das nicht erlaubte Feld ${key}.`);
            }
        });
    }

    function assertJobId(value) {
        if (typeof value !== 'string' || !/^job:[^\s]{1,500}$/.test(value) || FORBIDDEN_KEYS.has(value)) {
            fail('invalid_job_id', 'job_id muss eine stabile, nicht leere JobAgent-ID sein.');
        }
        return value;
    }

    function assertUtcTimestamp(value, field, nullable) {
        if (nullable && value === null) {
            return null;
        }
        if (typeof value !== 'string' || !UTC_TIMESTAMP.test(value) || Number.isNaN(Date.parse(value))) {
            fail('invalid_timestamp', `${field} muss ein gueltiger UTC-Zeitpunkt mit Z-Offset sein.`);
        }
        return new Date(value).toISOString();
    }

    function assertText(value, field, maximum, nullable) {
        if (nullable && value === null) {
            return null;
        }
        if (typeof value !== 'string' || value.length > maximum) {
            fail('invalid_state', `${field} muss Text mit maximal ${maximum} Zeichen sein.`);
        }
        return value;
    }

    function assertHttpUrl(value, field, nullable) {
        if (nullable && value === null) {
            return null;
        }
        if (typeof value !== 'string' || value.length > 2048 || !/^https?:\/\//i.test(value)) {
            fail('invalid_state', `${field} muss eine HTTP(S)-URL oder null sein.`);
        }
        return value;
    }

    function toUtc(now) {
        const date = now === undefined ? new Date() : new Date(now);
        if (Number.isNaN(date.getTime())) {
            fail('invalid_timestamp', 'Die Bedienzeit ist ungueltig.');
        }
        return date.toISOString();
    }

    function emptyState() {
        return { schema_version: SCHEMA_VERSION, project_key: PROJECT_KEY, updated_at: null, jobs: {} };
    }

    function normalizeReference(value) {
        if (value === undefined) {
            return undefined;
        }
        const reference = requireObject(value, 'reference');
        assertOnlyKeys(reference, new Set(['title', 'company', 'official_url', 'observed_at']), 'reference');
        ['title', 'company', 'official_url', 'observed_at'].forEach((key) => {
            if (!(key in reference)) {
                fail('invalid_state', `reference.${key} fehlt.`);
            }
        });
        return {
            title: assertText(reference.title, 'reference.title', 1000, false),
            company: assertText(reference.company, 'reference.company', 1000, false),
            official_url: assertHttpUrl(reference.official_url, 'reference.official_url', true),
            observed_at: assertUtcTimestamp(reference.observed_at, 'reference.observed_at', false)
        };
    }

    function normalizeRecord(value) {
        const record = requireObject(value, 'jobs.*');
        assertOnlyKeys(record, new Set(['favorite', 'applied', 'favorite_updated_at', 'applied_updated_at', 'applied_at', 'reference']), 'jobs.*');
        ['favorite', 'applied', 'favorite_updated_at', 'applied_updated_at', 'applied_at'].forEach((key) => {
            if (!(key in record)) {
                fail('invalid_state', `jobs.*.${key} fehlt.`);
            }
        });
        if (typeof record.favorite !== 'boolean' || typeof record.applied !== 'boolean') {
            fail('invalid_state', 'jobs.*.favorite und jobs.*.applied muessen Booleans sein.');
        }
        const normalized = {
            favorite: record.favorite,
            applied: record.applied,
            favorite_updated_at: assertUtcTimestamp(record.favorite_updated_at, 'jobs.*.favorite_updated_at', true),
            applied_updated_at: assertUtcTimestamp(record.applied_updated_at, 'jobs.*.applied_updated_at', true),
            applied_at: assertUtcTimestamp(record.applied_at, 'jobs.*.applied_at', true)
        };
        if (normalized.applied && (normalized.applied_updated_at === null || normalized.applied_at === null)) {
            fail('invalid_state', 'jobs.*.applied braucht applied_updated_at und applied_at.');
        }
        if (!normalized.applied && normalized.applied_at !== null) {
            fail('invalid_state', 'jobs.*.applied_at muss bei nicht beworbenen Stellen null sein.');
        }
        const reference = normalizeReference(record.reference);
        if (reference !== undefined) {
            normalized.reference = reference;
        }
        return normalized;
    }

    function normalizeState(value) {
        const state = requireObject(value, 'state');
        assertOnlyKeys(state, new Set(['schema_version', 'project_key', 'updated_at', 'jobs']), 'state');
        if (state.schema_version !== SCHEMA_VERSION) {
            fail(state.schema_version ? 'unsupported_version' : 'invalid_state', 'Die Zustandsversion wird nicht unterstuetzt.');
        }
        if (state.project_key !== PROJECT_KEY) {
            fail('invalid_state', 'Der Zustand gehoert nicht zu diesem JobAgent-Projekt.');
        }
        const jobs = requireObject(state.jobs, 'jobs');
        const normalizedJobs = {};
        Object.keys(jobs).sort().forEach((jobId) => {
            assertJobId(jobId);
            normalizedJobs[jobId] = normalizeRecord(jobs[jobId]);
        });
        return {
            schema_version: SCHEMA_VERSION,
            project_key: PROJECT_KEY,
            updated_at: assertUtcTimestamp(state.updated_at, 'updated_at', true),
            jobs: normalizedJobs
        };
    }

    function clone(value) {
        return JSON.parse(JSON.stringify(value));
    }

    function referenceFromJob(job, observedAt) {
        if (!job || typeof job !== 'object') {
            return undefined;
        }
        const hasReference = Object.prototype.hasOwnProperty.call(job, 'title') || Object.prototype.hasOwnProperty.call(job, 'company') || Object.prototype.hasOwnProperty.call(job, 'official_url');
        if (!hasReference) {
            return undefined;
        }
        return {
            title: assertText(job.title || '', 'job.title', 1000, false),
            company: assertText(job.company || '', 'job.company', 1000, false),
            official_url: assertHttpUrl(job.official_url === undefined ? null : job.official_url, 'job.official_url', true),
            observed_at: observedAt
        };
    }

    function read(storage) {
        if (!storage || typeof storage.getItem !== 'function') {
            return { persistent: false, reason: 'storage_unavailable', state: emptyState() };
        }
        let raw;
        try {
            raw = storage.getItem(PROJECT_KEY);
        } catch (_) {
            return { persistent: false, reason: 'storage_unavailable', state: emptyState() };
        }
        if (raw === null) {
            return { persistent: true, reason: 'missing', state: emptyState() };
        }
        try {
            return { persistent: true, reason: 'valid', state: normalizeState(JSON.parse(raw)), raw };
        } catch (error) {
            return { persistent: false, reason: error.code || 'corrupt', state: emptyState(), raw };
        }
    }

    function write(storage, state) {
        const serialized = JSON.stringify(normalizeState(state));
        try {
            storage.setItem(PROJECT_KEY, serialized);
            return { persistent: true, serialized };
        } catch (_) {
            return { persistent: false, reason: 'storage_write_failed' };
        }
    }

    function currentRecord(state, jobId) {
        return state.jobs[jobId] ? clone(state.jobs[jobId]) : { favorite: false, applied: false, favorite_updated_at: null, applied_updated_at: null, applied_at: null };
    }

    function setMark(storage, job, field, enabled, now) {
        if (field !== 'favorite' && field !== 'applied') {
            fail('invalid_field', 'Nur favorite oder applied duerfen gesetzt werden.');
        }
        if (typeof enabled !== 'boolean') {
            fail('invalid_state', `${field} muss ein Boolean sein.`);
        }
        const jobId = assertJobId(job && job.job_id);
        const loaded = read(storage);
        if (!loaded.persistent && loaded.reason !== 'missing') {
            return { persistent: false, changed: false, reason: loaded.reason, state: loaded.state, record: null };
        }
        const state = clone(loaded.state);
        const record = currentRecord(state, jobId);
        if (record[field] === enabled) {
            return { persistent: true, changed: false, reason: 'unchanged', state, record: clone(record) };
        }
        const timestamp = toUtc(now);
        record[field] = enabled;
        record[`${field}_updated_at`] = timestamp;
        if (field === 'applied') {
            record.applied_at = enabled ? timestamp : null;
        }
        const reference = referenceFromJob(job, timestamp);
        if (reference !== undefined) {
            record.reference = reference;
        }
        state.jobs[jobId] = record;
        state.updated_at = timestamp;
        const saved = write(storage, state);
        if (!saved.persistent) {
            return { persistent: false, changed: false, reason: saved.reason, state: loaded.state, record: null };
        }
        return { persistent: true, changed: true, reason: 'saved', state, record: clone(record) };
    }

    function later(first, second) {
        return Date.parse(first) > Date.parse(second);
    }

    function mergeRecord(existing, incoming) {
        const merged = clone(existing);
        ['favorite', 'applied'].forEach((field) => {
            const timestampField = `${field}_updated_at`;
            if (later(incoming[timestampField], existing[timestampField])) {
                merged[field] = incoming[field];
                merged[timestampField] = incoming[timestampField];
                if (field === 'applied') {
                    merged.applied_at = incoming.applied_at;
                }
            }
        });
        if (incoming.reference && (!existing.reference || later(incoming.reference.observed_at, existing.reference.observed_at))) {
            merged.reference = clone(incoming.reference);
        }
        return merged;
    }

    function previewImport(storage, serialized) {
        const loaded = read(storage);
        if (!loaded.persistent && loaded.reason !== 'missing') {
            return { valid: false, persistent: false, reason: loaded.reason, state: loaded.state };
        }
        let imported;
        try {
            imported = normalizeState(typeof serialized === 'string' ? JSON.parse(serialized) : serialized);
        } catch (error) {
            return { valid: false, persistent: true, reason: error.code || 'invalid_import', state: loaded.state };
        }
        const merged = clone(loaded.state);
        const changedJobIds = [];
        Object.keys(imported.jobs).sort().forEach((jobId) => {
            const existing = merged.jobs[jobId];
            const candidate = existing ? mergeRecord(existing, imported.jobs[jobId]) : clone(imported.jobs[jobId]);
            if (JSON.stringify(candidate) !== JSON.stringify(existing)) {
                merged.jobs[jobId] = candidate;
                changedJobIds.push(jobId);
            }
        });
        if (changedJobIds.length) {
            merged.updated_at = imported.updated_at || loaded.state.updated_at;
        }
        return { valid: true, persistent: true, reason: 'preview', state: merged, changed_job_ids: changedJobIds, imported_job_ids: Object.keys(imported.jobs).sort() };
    }

    function importState(storage, serialized) {
        const preview = previewImport(storage, serialized);
        if (!preview.valid || !preview.persistent || preview.changed_job_ids.length === 0) {
            return Object.assign({}, preview, { changed: false });
        }
        const saved = write(storage, preview.state);
        if (!saved.persistent) {
            return { valid: true, persistent: false, changed: false, reason: saved.reason, state: read(storage).state, changed_job_ids: [] };
        }
        return Object.assign({}, preview, { changed: true, reason: 'imported' });
    }

    function exportState(storage) {
        const loaded = read(storage);
        return { persistent: loaded.persistent, reason: loaded.reason, serialized: JSON.stringify(loaded.state), state: clone(loaded.state) };
    }

    function subscribeStorage(storage, callback, eventTarget) {
        const target = eventTarget || root;
        if (!target || typeof target.addEventListener !== 'function' || typeof callback !== 'function') {
            return function () {};
        }
        const listener = (event) => {
            if (!event || event.key !== PROJECT_KEY || (event.storageArea && storage && event.storageArea !== storage)) {
                return;
            }
            if (event.newValue === null) {
                callback({ persistent: true, reason: 'missing', state: emptyState() });
                return;
            }
            try {
                callback({ persistent: true, reason: 'valid', state: normalizeState(JSON.parse(event.newValue)) });
            } catch (error) {
                callback({ persistent: false, reason: error.code || 'corrupt', state: emptyState() });
            }
        };
        target.addEventListener('storage', listener);
        return function () { target.removeEventListener('storage', listener); };
    }

    return Object.freeze({
        SCHEMA_VERSION,
        PROJECT_KEY,
        createEmptyState: emptyState,
        normalizeState,
        read,
        setMark,
        previewImport,
        importState,
        exportState,
        subscribeStorage
    });
}));
