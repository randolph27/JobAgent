/* JobAgent calendar: local projection only; navigation never starts a scan. */
(function () {
    'use strict';
    const panel = document.getElementById('jobagent-calendar');
    const tab = document.getElementById('jobagent-tab-calendar');
    const dataNode = document.getElementById('jobagent-search-data');
    if (!panel || !tab || !dataNode) { return; }
    let data;
    try { data = JSON.parse(dataNode.textContent); } catch (_) { return; }
    const calendar = data.calendar || { timezone: 'Europe/Berlin', attempts: [], planned_scans: [] };
    const zone = calendar.timezone === 'Europe/Berlin' ? calendar.timezone : 'Europe/Berlin';
    const dateParts = new Intl.DateTimeFormat('en-CA', { timeZone: zone, year: 'numeric', month: '2-digit', day: '2-digit' });
    const timeParts = new Intl.DateTimeFormat('de-DE', { timeZone: zone, hour: '2-digit', minute: '2-digit', timeZoneName: 'short' });
    const weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    const validDate = value => /^\d{4}-\d{2}-\d{2}$/.test(String(value || '')) && !Number.isNaN(Date.parse(`${value}T00:00:00Z`));
    const berlinDate = value => {
        const parsed = new Date(value);
        if (Number.isNaN(parsed.getTime())) { return null; }
        const parts = Object.fromEntries(dateParts.formatToParts(parsed).filter(part => part.type !== 'literal').map(part => [part.type, part.value]));
        return `${parts.year}-${parts.month}-${parts.day}`;
    };
    const addDays = (value, days) => { const current = new Date(`${value}T00:00:00Z`); current.setUTCDate(current.getUTCDate() + days); return current.toISOString().slice(0, 10); };
    const monthStart = value => `${value.slice(0, 7)}-01`;
    const weekday = value => { const day = new Date(`${value}T00:00:00Z`).getUTCDay(); return day === 0 ? 6 : day - 1; };
    const range = (start, count) => Array.from({ length: count }, (_, index) => addDays(start, index));
    const reference = berlinDate(calendar.reference_time) || new Date().toISOString().slice(0, 10);
    const text = value => String(value || '').replace(/\s+/g, ' ').trim();
    const params = () => new URLSearchParams(location.hash.slice(1));
    const write = next => { const hash = params(); Object.entries(next).forEach(([key, value]) => { if (value === null || value === undefined || value === '') { hash.delete(key); } else { hash.set(key, value); } }); location.hash = `#${hash.toString()}`; };
    const read = () => {
        const hash = params();
        const requested = hash.get('calendarDate');
        const selected = validDate(requested) ? requested : reference;
        return {
            active: hash.get('view') === 'calendar',
            date: selected,
            mode: ['month', 'week'].includes(hash.get('calendarMode')) ? hash.get('calendarMode') : 'month',
            kind: ['all', 'attempt', 'plan', 'task'].includes(hash.get('calendarKind')) ? hash.get('calendarKind') : 'all',
            status: ['all', 'OPEN', 'DONE', 'SUCCESS', 'PARTIAL', 'FAILED', 'RUNNING'].includes(hash.get('calendarStatus')) ? hash.get('calendarStatus') : 'all',
            company: hash.get('company_id') || ''
        };
    };
    const localTasks = () => {
        try {
            const loaded = window.JobAgentUserState && window.JobAgentUserState.read(localStorage);
            const records = loaded && loaded.persistent ? loaded.state.jobs : {};
            return Object.entries(records).flatMap(([jobId, record]) => (record.tasks || []).filter(task => task.deleted_at === null).map(task => ({
                kind: 'task', event_id: `task:${jobId}:${task.task_id}`, job_id: jobId, local_date: task.local_date,
                title: task.title, status: task.status, time_with_offset: task.time_with_offset, company: record.reference && record.reference.company || 'Keine Angabe'
            })));
        } catch (_) { return []; }
    };
    const events = () => {
        const attempts = (calendar.attempts || []).map(item => ({ ...item, kind: 'attempt', local_date: berlinDate(item.finished_at || item.started_at), event_time: item.finished_at || item.started_at }));
        const plans = (calendar.planned_scans || []).map(item => ({ ...item, kind: 'plan', local_date: berlinDate(item.next_scan_at), event_time: item.next_scan_at, status: 'PLANNED' }));
        return [...attempts, ...plans, ...localTasks()].filter(item => validDate(item.local_date));
    };
    const matching = (item, state) => (state.kind === 'all' || item.kind === state.kind) && (state.status === 'all' || item.status === state.status) && (!state.company || item.company_id === state.company);
    const statusLabel = item => item.kind === 'plan' ? 'Geplante Pruefung' : item.kind === 'task' ? (item.status === 'DONE' ? 'Eigener Termin erledigt' : 'Eigener Termin offen') : ({ SUCCESS: item.scan_complete ? 'Erfolgreich und vollstaendig' : 'Erfolgreich, unvollstaendig', PARTIAL: 'Teilweise erfolgreich', FAILED: 'Fehlgeschlagen', SKIPPED: 'Uebersprungen', RUNNING: 'Laeuft' }[item.status] || text(item.status));
    const dateLabel = value => new Intl.DateTimeFormat('de-DE', { timeZone: 'UTC', weekday: 'long', day: '2-digit', month: 'long', year: 'numeric' }).format(new Date(`${value}T00:00:00Z`));
    const make = (tag, value, className) => { const node = document.createElement(tag); if (className) { node.className = className; } if (value !== undefined) { node.textContent = value; } return node; };
    const setTabs = state => {
        const jobPanel = document.getElementById('jobagent-jobs'); const companyPanel = document.getElementById('jobagent-companies'); const appPanel = document.getElementById('jobagent-applications');
        panel.hidden = !state.active; if (state.active) { if (jobPanel) { jobPanel.hidden = true; } if (companyPanel) { companyPanel.hidden = true; } if (appPanel) { appPanel.hidden = true; } }
        ['jobagent-tab-jobs', 'jobagent-tab-companies', 'jobagent-tab-applications'].forEach(id => { const node = document.getElementById(id); if (node && state.active) { node.setAttribute('aria-selected', 'false'); } });
        tab.setAttribute('aria-selected', String(state.active));
    };
    const details = (state, all) => {
        const dayEvents = all.filter(item => item.local_date === state.date && matching(item, state)).sort((left, right) => String(left.event_time || left.time_with_offset || '').localeCompare(String(right.event_time || right.time_with_offset || '')) || String(left.event_id).localeCompare(String(right.event_id)));
        const page = Math.max(1, Number(params().get('calendarPage')) || 1); const pages = Math.max(1, Math.ceil(dayEvents.length / 50)); const slice = dayEvents.slice((Math.min(page, pages) - 1) * 50, Math.min(page, pages) * 50);
        const root = make('section'); root.className = 'calendar-details'; root.append(make('h3', `Details: ${dateLabel(state.date)}`));
        const attempts = dayEvents.filter(item => item.kind === 'attempt'); const companies = new Set(attempts.map(item => item.company_id).filter(Boolean)); const failures = attempts.filter(item => item.status === 'FAILED').length; const newJobs = new Set(attempts.flatMap(item => item.new_job_ids || []));
        root.append(make('p', `${companies.size} Firmen, ${attempts.length} Abrufe, ${failures} Fehler, ${newJobs.size} neue Stellen.`));
        if (!dayEvents.length) { root.append(make('p', 'Keine gespeicherten Abrufe.')); return root; }
        slice.forEach(item => { const entry = make('article', undefined, `calendar-event calendar-${item.kind}`); entry.append(make('h4', `${statusLabel(item)} · ${item.company || 'Keine Angabe'}`)); entry.append(make('p', item.kind === 'task' ? `${item.local_date}${item.time_with_offset ? ` ${item.time_with_offset}` : ''} · ${item.title}` : `${timeParts.format(new Date(item.event_time))} · ${item.event_id}`));
            const link = document.createElement('a');
            if (item.kind === 'task') { link.href = '#view=applications'; link.textContent = 'Zur Bewerbung'; }
            else { link.href = `#view=companies&company=${encodeURIComponent(item.company_id)}`; link.textContent = 'Zur Firma'; }
            entry.append(link); root.append(entry);
        });
        if (pages > 1) { const navigation = make('nav', undefined, 'pagination'); navigation.setAttribute('aria-label', 'Seitennavigation Tagesdetails'); range('2000-01-01', pages).forEach((_, index) => { const number = index + 1; const button = make('button', String(number)); button.type = 'button'; if (number === Math.min(page, pages)) { button.setAttribute('aria-current', 'page'); } button.addEventListener('click', () => write({ calendarPage: number })); navigation.append(button); }); root.append(navigation); }
        return root;
    };
    const render = () => {
        const state = read(); setTabs(state); if (!state.active) { return; }
        const all = events(); panel.replaceChildren();
        const heading = make('h2', 'Kalender'); panel.append(heading, make('p', 'Gespeicherte Abrufe, bekannte Planungen und lokale eigene Termine. Die Navigation startet keinen Abruf.'));
        const controls = make('div', undefined, 'calendar-controls');
        [['Zurueck', -1], ['Zum Datenstand', 0], ['Weiter', 1]].forEach(([label, delta]) => { const button = make('button', label); button.type = 'button'; button.addEventListener('click', () => { const basis = delta === 0 ? reference : state.date; write({ calendarDate: delta === 0 ? reference : addDays(basis, delta * (state.mode === 'week' ? 7 : 31)), calendarPage: null }); }); controls.append(button); });
        const mode = document.createElement('select'); mode.setAttribute('aria-label', 'Kalenderansicht'); [['month', 'Monat'], ['week', 'Woche']].forEach(([value, label]) => { const option = make('option', label); option.value = value; option.selected = state.mode === value; mode.append(option); }); mode.addEventListener('change', () => write({ calendarMode: mode.value, calendarPage: null })); controls.append(mode); panel.append(controls);
        const filters = make('div', undefined, 'calendar-filters'); const select = (key, label, options) => { const wrapper = make('label', label); const node = document.createElement('select'); options.forEach(([value, valueLabel]) => { const option = make('option', valueLabel); option.value = value; option.selected = state[key] === value; node.append(option); }); node.addEventListener('change', () => write({ [key === 'kind' ? 'calendarKind' : key === 'status' ? 'calendarStatus' : 'company_id']: node.value || null, calendarPage: null })); wrapper.append(node); filters.append(wrapper); };
        select('kind', 'Ereignisart', [['all', 'Alle Ereignisse'], ['attempt', 'Abrufe'], ['plan', 'Geplante Pruefungen'], ['task', 'Eigene Termine']]); select('status', 'Status', [['all', 'Alle Status'], ['SUCCESS', 'Erfolgreich'], ['PARTIAL', 'Teilweise erfolgreich'], ['FAILED', 'Fehlgeschlagen'], ['RUNNING', 'Laeuft'], ['OPEN', 'Termin offen'], ['DONE', 'Termin erledigt']]); select('company', 'Firma', [['', 'Alle Firmen'], ...Array.from(new Map((calendar.planned_scans || []).concat(calendar.attempts || []).map(item => [item.company_id, item.company])).entries()).sort((a, b) => String(a[1]).localeCompare(String(b[1]), 'de'))]); panel.append(filters);
        const legend = make('p', undefined, 'calendar-legend'); [['calendar-attempt', 'Abruf'], ['calendar-plan', 'Geplante Pruefung'], ['calendar-task', 'Eigener Termin']].forEach(([className, label]) => legend.append(make('span', label, className))); panel.append(legend);
        const start = state.mode === 'week' ? addDays(state.date, -weekday(state.date)) : addDays(monthStart(state.date), -weekday(monthStart(state.date))); const days = range(start, state.mode === 'week' ? 7 : 42);
        const grid = make('div', undefined, 'calendar-grid'); weekdays.forEach(name => grid.append(make('div', name, 'calendar-weekday'))); days.forEach(day => { const entries = all.filter(item => item.local_date === day && matching(item, state)); const button = make('button', undefined, `calendar-day${day.slice(0, 7) !== state.date.slice(0, 7) ? ' is-outside' : ''}${day === state.date ? ' is-selected' : ''}`); button.type = 'button'; button.dataset.calendarDate = day; button.setAttribute('aria-label', `${dateLabel(day)}: ${entries.length} Ereignisse`); if (day === reference) { button.setAttribute('aria-current', 'date'); } button.append(make('strong', day.slice(8)), make('span', `${entries.length} Ereignisse`, 'calendar-count')); button.addEventListener('click', () => write({ calendarDate: day, calendarPage: null })); button.addEventListener('keydown', event => { const offset = event.key === 'ArrowLeft' ? -1 : event.key === 'ArrowRight' ? 1 : event.key === 'ArrowUp' ? -7 : event.key === 'ArrowDown' ? 7 : event.key === 'Home' ? -weekday(day) : event.key === 'End' ? 6 - weekday(day) : 0; if (event.key === 'Enter') { event.preventDefault(); write({ calendarDate: day, calendarPage: null }); } else if (offset) { event.preventDefault(); const target = addDays(day, offset); write({ calendarDate: target, calendarPage: null }); setTimeout(() => panel.querySelector(`[data-calendar-date="${target}"]`)?.focus(), 0); } }); grid.append(button); }); panel.append(grid);
        const agenda = make('div', undefined, 'calendar-agenda'); days.filter(day => all.some(item => item.local_date === day && matching(item, state)) || day === state.date).forEach(day => { const button = make('button', `${dateLabel(day)} · ${all.filter(item => item.local_date === day && matching(item, state)).length} Ereignisse`); button.type = 'button'; button.addEventListener('click', () => write({ calendarDate: day, calendarPage: null })); agenda.append(button); }); panel.append(agenda, details(state, all));
        const history = calendar.history_start ? `Verfuegbare Abrufhistorie ab ${berlinDate(calendar.history_start)}.` : 'Keine gespeicherte Abrufhistorie vorhanden.'; panel.append(make('p', history, 'unknown'));
    };
    tab.addEventListener('click', event => { event.preventDefault(); event.stopImmediatePropagation(); write({ view: 'calendar', calendarDate: read().date }); }, true);
    tab.addEventListener('keydown', event => { if (['Enter', ' '].includes(event.key)) { event.preventDefault(); tab.click(); } }, true);
    window.addEventListener('hashchange', render); window.addEventListener('storage', render); render();
}());
