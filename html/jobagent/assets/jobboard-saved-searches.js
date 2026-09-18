/* JobAgent saved searches. Uses the canonical renderer filter API only. */
(function () {
    'use strict';

    const api = window.JobAgentUserState;
    const search = window.JobAgentSearch;
    const host = document.getElementById('jobagent-search');
    const layout = host && host.querySelector('.jobboard-layout');
    if (!api || !search || !host || !layout) { return; }

    let editingId = null;
    const panel = document.createElement('section');
    const heading = document.createElement('h2');
    const help = document.createElement('p');
    const nameLabel = document.createElement('label');
    const name = document.createElement('input');
    const save = document.createElement('button');
    const cancel = document.createElement('button');
    const notice = document.createElement('p');
    const list = document.createElement('div');

    panel.id = 'jobagent-saved-searches';
    panel.className = 'saved-searches';
    heading.textContent = 'Gespeicherte Suchauftraege';
    help.textContent = 'Suchauftraege speichern Filter lokal. Sie starten keinen Abruf. „Als gesehen markieren“ bestaetigt die aktuelle Reportgeneration ausdruecklich.';
    nameLabel.textContent = 'Name des Suchauftrags';
    name.id = 'jobagent-saved-search-name';
    name.type = 'text';
    name.maxLength = 160;
    name.autocomplete = 'off';
    nameLabel.htmlFor = name.id;
    save.type = 'button';
    save.id = 'jobagent-saved-search-save';
    save.textContent = 'Suchauftrag speichern';
    cancel.type = 'button';
    cancel.id = 'jobagent-saved-search-cancel';
    cancel.textContent = 'Bearbeitung abbrechen';
    cancel.hidden = true;
    notice.id = 'jobagent-saved-search-notice';
    notice.className = 'job-mark-message';
    notice.setAttribute('role', 'status');
    list.id = 'jobagent-saved-search-list';
    list.className = 'result-list';
    panel.append(heading, help, nameLabel, save, cancel, notice, list);
    layout.parentNode.insertBefore(panel, layout);

    function state() {
        const loaded = api.read(localStorage);
        return loaded.persistent ? loaded.state : api.createEmptyState();
    }

    function setNotice(value) { notice.textContent = value; }
    function newId() {
        const value = globalThis.crypto && typeof globalThis.crypto.randomUUID === 'function'
            ? globalThis.crypto.randomUUID().replace(/-/g, '')
            : `${Date.now().toString(36)}${Math.random().toString(36).slice(2)}`;
        return `search:${value}`;
    }
    function resetEditor() {
        editingId = null;
        name.value = '';
        save.textContent = 'Suchauftrag speichern';
        cancel.hidden = true;
    }

    function snapshot(filters) {
        const current = search.snapshot(filters);
        if (!current.generation_id) { throw new Error('Die Reportgeneration ist nicht verfuegbar; der Suchauftrag wurde nicht geaendert.'); }
        return current;
    }

    function compare(item) {
        try { return api.compareSavedSearch(item, snapshot(item.filters)); }
        catch { return { available: false, reason: 'comparison_unavailable', new_job_ids: [], changed_job_ids: [], personal_visibility_job_ids: [] }; }
    }

    function apply(item) {
        search.applyFilters(item.filters);
        setNotice(`Suchauftrag „${item.name}“ angewendet. Ansicht Stellen, Seite 1.`);
    }

    function showChanges(item, comparison) {
        const newIds = comparison.new_job_ids || [];
        const changedIds = comparison.changed_job_ids || [];
        const ids = [...new Set(newIds.concat(changedIds))];
        window.JobAgentSavedSearchSubset = { ids, newIds, changedIds, searchId: item.search_id };
        search.applyFilters(item.filters);
        window.JobAgentSavedSearchSubset = { ids, newIds, changedIds, searchId: item.search_id };
        search.rerender();
        setNotice(ids.length ? `Teilmenge „Neu seit letzter Sichtung“ fuer „${item.name}“ angezeigt.` : `Keine neuen oder fachlich geaenderten Treffer fuer „${item.name}“.`);
    }

    function decorateSubset() {
        const subset = window.JobAgentSavedSearchSubset;
        if (!subset) { return; }
        document.querySelectorAll('.job-card[data-job-id]').forEach(card => {
            if (card.querySelector('.saved-search-result-label')) { return; }
            const id = card.dataset.jobId;
            const labels = [];
            if (subset.newIds.includes(id)) { labels.push('Neu in dieser Suche'); }
            if (subset.changedIds.includes(id)) { labels.push('Fachlich geaendert'); }
            if (!labels.length) { return; }
            const label = document.createElement('p');
            label.className = 'saved-search-result-label';
            label.textContent = labels.join(' · ');
            card.prepend(label);
        });
    }

    function render() {
        const searches = Object.values(state().saved_searches).sort((left, right) => left.name.localeCompare(right.name, 'de'));
        const focusId = document.activeElement && document.activeElement.dataset.savedSearchId;
        list.replaceChildren();
        if (!searches.length) {
            const empty = document.createElement('p');
            empty.className = 'empty-state';
            empty.textContent = 'Keine Suchauftraege gespeichert.';
            list.append(empty);
            return;
        }
        searches.forEach(item => {
            const comparison = compare(item);
            const card = document.createElement('article');
            const title = document.createElement('h3');
            const summary = document.createElement('p');
            const baseline = document.createElement('p');
            const actions = document.createElement('p');
            const open = button('Aufrufen', item.search_id);
            const edit = button('Bearbeiten', item.search_id);
            const duplicate = button('Duplizieren', item.search_id);
            const remove = button('Loeschen', item.search_id);
            const seen = button('Als gesehen markieren', item.search_id);
            const changes = button('Neue/Aenderungen anzeigen', item.search_id);
            card.className = 'result-card saved-search-card';
            card.dataset.savedSearchId = item.search_id;
            title.textContent = item.name;
            if (comparison.available) {
                summary.textContent = `Treffer: ${comparison.current_job_ids.length} · Neu seit letzter Sichtung: ${comparison.new_job_ids.length} · Fachlich geaendert: ${comparison.changed_job_ids.length}.`;
                if (comparison.personal_visibility_job_ids.length) {
                    baseline.textContent = `${comparison.personal_visibility_job_ids.length} Treffer durch persoenliche Auswahl sichtbar.`;
                } else {
                    baseline.textContent = `Bestaetigter Stand: ${item.baseline.generation_id}.`;
                }
            } else {
                summary.textContent = 'Vergleich nicht verfuegbar.';
                baseline.textContent = `Bestaetigter Stand: ${item.baseline && item.baseline.generation_id || 'unbekannt'}.`;
            }
            open.addEventListener('click', () => apply(item));
            edit.addEventListener('click', () => {
                editingId = item.search_id;
                name.value = item.name;
                save.textContent = 'Aenderungen speichern und Vergleich zuruecksetzen';
                cancel.hidden = false;
                apply(item);
                name.focus();
            });
            duplicate.addEventListener('click', () => {
                editingId = null;
                name.value = `${item.name} Kopie`;
                save.textContent = 'Suchauftrag speichern';
                cancel.hidden = false;
                apply(item);
                name.focus();
            });
            remove.addEventListener('click', () => {
                const result = api.deleteSavedSearch(localStorage, item.search_id);
                setNotice(result.persistent ? `Suchauftrag „${item.name}“ geloescht.` : 'Suchauftrag konnte nicht lokal geloescht werden.');
                if (result.persistent) { render(); }
            });
            seen.addEventListener('click', () => {
                try {
                    const current = snapshot(item.filters);
                    const result = api.markSavedSearchSeen(localStorage, item.search_id, {
                        generation_id: current.generation_id,
                        confirmed_job_ids: current.visible_job_ids,
                        confirmed_change_event_ids: Object.values(current.change_events_by_job).flat()
                    });
                    setNotice(result.persistent ? `Suchauftrag „${item.name}“ fuer diese Generation als gesehen markiert.` : 'Sichtungsstand konnte nicht lokal gespeichert werden.');
                    if (result.persistent) { render(); }
                } catch (error) { setNotice(error.message || 'Sichtungsstand ist nicht verfuegbar.'); }
            });
            changes.addEventListener('click', () => showChanges(item, comparison));
            actions.className = 'job-card-actions';
            actions.append(open, changes, edit, duplicate, remove, seen);
            card.append(title, summary, baseline, actions);
            list.append(card);
        });
        if (focusId) { list.querySelector(`[data-saved-search-id="${CSS.escape(focusId)}"] button`)?.focus(); }
    }

    function button(text, id) {
        const node = document.createElement('button');
        node.type = 'button';
        node.textContent = text;
        node.dataset.savedSearchId = id;
        return node;
    }

    save.addEventListener('click', () => {
        try {
            const current = search.currentFilters();
            const baseline = snapshot(current);
            const existing = editingId && state().saved_searches[editingId];
            const result = api.saveSavedSearch(localStorage, {
                search_id: existing ? existing.search_id : newId(),
                name: name.value,
                filters: current
            }, {
                generation_id: baseline.generation_id,
                confirmed_job_ids: baseline.visible_job_ids,
                confirmed_change_event_ids: Object.values(baseline.change_events_by_job).flat()
            });
            setNotice(result.persistent ? (existing ? `Suchauftrag „${result.search.name}“ aktualisiert; Vergleich zurueckgesetzt.` : `Suchauftrag „${result.search.name}“ mit aktuellem Bestand gespeichert.`) : 'Suchauftrag konnte nicht lokal gespeichert werden.');
            if (result.persistent) { resetEditor(); render(); }
        } catch (error) { setNotice(error.message || 'Suchauftrag ist ungueltig.'); }
    });
    cancel.addEventListener('click', () => { resetEditor(); setNotice('Bearbeitung verworfen.'); });
    window.addEventListener('storage', render);
    window.addEventListener('hashchange', render);
    new MutationObserver(decorateSubset).observe(document.getElementById('jobagent-job-results'), { childList: true, subtree: true });
    render();
}());
