export const STATUS_LABELS = {
  new: 'New',
  pending: 'Pending',
  escalated: 'Escalated',
  awaiting_internal: 'Awaiting Internal',
  awaiting_customer: 'Awaiting Customer',
  awaiting_response: 'Awaiting Response', // legacy — kept so old history rows render
  resolved: 'Resolved',
  closed: 'Closed',
};

export const STATUS_BADGE_CLASS = {
  new: 'blue',
  pending: 'orange',
  escalated: 'red',
  awaiting_internal: 'orange',
  awaiting_customer: 'blue',
  awaiting_response: 'orange', // legacy
  resolved: 'green',
  closed: 'grey',
};

export function statusBadge(status) {
  const cls = STATUS_BADGE_CLASS[status] || 'grey';
  const label = STATUS_LABELS[status] || status;
  return `<span class="badge ${cls}">${label}</span>`;
}

// Returns { label, className } describing time remaining on an escalation.
export function escalationCountdown(expiresAt) {
  if (!expiresAt) return null;
  const diffMs = new Date(expiresAt).getTime() - Date.now();
  if (diffMs <= 0) {
    return { label: 'OVERDUE', className: 'red' };
  }
  const hours = diffMs / 3600000;
  const label = hours >= 1
    ? `${Math.floor(hours)}h ${Math.round((hours % 1) * 60)}m left`
    : `${Math.round(hours * 60)}m left`;
  if (hours < 0.5) return { label, className: 'red' };
  if (hours < 2) return { label, className: 'orange' };
  return { label, className: 'green' };
}

const OPEN_STATUSES_EXCLUDE = new Set(['closed', 'resolved']);
const PRIORITY_RANK = { urgent: 0, high: 1, normal: 2 };

export function isOverSla(c) {
  if (!c.sla_date || OPEN_STATUSES_EXCLUDE.has(c.status)) return false;
  // sla_date is a plain DATE — compare against today's date, not the current
  // instant, so a case due today doesn't read as "over" until tomorrow.
  return c.sla_date < new Date().toISOString().slice(0, 10);
}

// Case list ordering used across agent/cases.html, admin/cases.html, and
// agent/index.html's "My Day": open cases first (over-SLA, then priority),
// closed/resolved cases last — so the thing needing action is always on top.
export function sortCasesByPriority(cases) {
  return [...cases].sort((a, b) => {
    const aOpen = !OPEN_STATUSES_EXCLUDE.has(a.status);
    const bOpen = !OPEN_STATUSES_EXCLUDE.has(b.status);
    if (aOpen !== bOpen) return aOpen ? -1 : 1;

    if (aOpen) {
      const aOver = isOverSla(a);
      const bOver = isOverSla(b);
      if (aOver !== bOver) return aOver ? -1 : 1;

      const aRank = PRIORITY_RANK[a.priority] ?? PRIORITY_RANK.normal;
      const bRank = PRIORITY_RANK[b.priority] ?? PRIORITY_RANK.normal;
      if (aRank !== bRank) return aRank - bRank;
    }

    return new Date(b.created_at || 0) - new Date(a.created_at || 0);
  });
}

// ---- Stale-case detection (My Day nudge + Cases "stale" filter) ----
// A case counts as stale when it's still open but nothing has happened on it
// for a while: no case-row change (cases.updated_at is trigger-maintained on
// every UPDATE — status, assignment, field edits) AND no note added within the
// window. Adding a note doesn't touch the case row, so we check both, and the
// two pages that surface this share one definition so their counts agree.
export const STALE_HOURS = 48;

export function staleCutoffIso() {
  return new Date(Date.now() - STALE_HOURS * 3600 * 1000).toISOString();
}

// openCases: [{ id, updated_at, created_at, status }]; recentlyNotedIds: Set of
// case ids with at least one note newer than the cutoff. Returns the stale subset.
export function filterStaleCases(openCases, recentlyNotedIds) {
  const cutoff = staleCutoffIso();
  return (openCases || []).filter(c =>
    !OPEN_STATUSES_EXCLUDE.has(c.status) &&
    (c.updated_at || c.created_at || '') < cutoff &&
    !recentlyNotedIds.has(c.id)
  );
}

// Replaces {TOKEN} placeholders in an escalation_templates subject/body.
export function fillTemplate(text, values) {
  if (!text) return '';
  return text.replace(/\{(\w+)\}/g, (match, key) => {
    const v = values[key];
    return v === undefined || v === null || v === '' ? match : String(v);
  });
}

export async function copyToClipboard(text) {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    return false;
  }
}
