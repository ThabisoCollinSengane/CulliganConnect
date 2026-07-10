export function timeGreeting(name) {
  const hour = new Date().getHours();
  const salutation = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';
  return `${salutation}, ${name || 'there'}!`;
}

const FALLBACK_LINES = [
  "Every case you close makes someone's day easier — let's get after it.",
  'Fresh day, clean slate. You’ve got this.',
  'Small wins add up — one case at a time.',
  'Thanks for showing up for the team today.',
  'Your customers are lucky to have you on the case.',
];

function pickFallback() {
  return FALLBACK_LINES[Math.floor(Math.random() * FALLBACK_LINES.length)];
}

async function countClosed(supabase, from, to, agentId) {
  let query = supabase.from('cases').select('id', { count: 'exact', head: true })
    .gte('closed_at', from.toISOString())
    .lt('closed_at', to.toISOString());
  if (agentId) query = query.eq('assigned_to', agentId);
  const { count } = await query;
  return count || 0;
}

function windowBounds() {
  const yesterday = new Date();
  yesterday.setHours(0, 0, 0, 0);
  yesterday.setDate(yesterday.getDate() - 1);
  const today = new Date(yesterday);
  today.setDate(today.getDate() + 1);
  const dayBefore = new Date(yesterday);
  dayBefore.setDate(dayBefore.getDate() - 1);
  return { dayBefore, yesterday, today };
}

function trendLine(count, prevCount, subject) {
  if (count <= 0) return null;
  const noun = count === 1 ? 'case' : 'cases';
  if (prevCount > 0 && count > prevCount) {
    const pct = Math.round(((count - prevCount) / prevCount) * 100);
    return `Yesterday ${subject} closed ${count} ${noun} — up ${pct}% on the day before. Keep that momentum going!`;
  }
  return `Yesterday ${subject} closed ${count} ${noun} — nice work. Let's keep it rolling today.`;
}

// Personal encouraging line for an agent, based on their own recent trend.
export async function motivationalLine(supabase, agentId) {
  const { dayBefore, yesterday, today } = windowBounds();
  const [closedYesterday, closedDayBefore] = await Promise.all([
    countClosed(supabase, yesterday, today, agentId),
    countClosed(supabase, dayBefore, yesterday, agentId),
  ]);
  return trendLine(closedYesterday, closedDayBefore, 'you') || pickFallback();
}

// Collective/team version for the admin dashboard.
export async function teamMotivationalLine(supabase) {
  const { dayBefore, yesterday, today } = windowBounds();
  const [closedYesterday, closedDayBefore] = await Promise.all([
    countClosed(supabase, yesterday, today, null),
    countClosed(supabase, dayBefore, yesterday, null),
  ]);
  return trendLine(closedYesterday, closedDayBefore, 'the team') || pickFallback();
}
