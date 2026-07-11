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
