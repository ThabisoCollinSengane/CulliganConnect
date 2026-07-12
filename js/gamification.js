import { supabase } from './supabaseClient.js';

// ---- Weighted score, factoring escalation quality ----
// A pure formula (no Supabase dependency) so it can be imported anywhere the
// score is shown — agent leaderboards, team leaderboard, admin reports —
// and stays identical everywhere. Guards against gaming volume by rushing
// escalations: an agent's raw output score is reduced in proportion to how
// often the escalations THEY closed had already breached their SLA timer.
// No escalations closed at all = no penalty (never punished for not having any).
const ESCALATION_PENALTY_FACTOR = 0.5; // 100% breach rate roughly halves the score

export function weightedScore({ closed = 0, interacted = 0, escClosed = 0, escBreached = 0 }) {
  const raw = closed * 2 + interacted;
  if (!escClosed) return raw;
  const breachRate = escBreached / escClosed;
  return Math.round(raw * (1 - breachRate * ESCALATION_PENALTY_FACTOR));
}

export async function fetchEscalationStats(agentId, fromISO, toISO) {
  let q = supabase.from('escalation_audit').select('was_overdue').eq('closed_by', agentId).not('closed_at', 'is', null);
  if (fromISO) q = q.gte('closed_at', fromISO);
  if (toISO) q = q.lt('closed_at', toISO);
  const { data } = await q;
  const escClosed = (data || []).length;
  const escBreached = (data || []).filter(r => r.was_overdue).length;
  return { escClosed, escBreached };
}

// ---- Streaks ----
function dateKey(d) {
  return d.toISOString().slice(0, 10);
}

// Duolingo-style: today only counts once it hits target (so an in-progress
// day doesn't erase yesterday's streak); walking backward from there, any
// unbroken run of prior days that hit target extends the count.
export async function computeStreak(agentId, dailyTarget, lookbackDays = 60) {
  const since = new Date();
  since.setDate(since.getDate() - lookbackDays);
  since.setHours(0, 0, 0, 0);

  const [{ data: closedCases }, { data: calls }] = await Promise.all([
    supabase.from('cases').select('closed_at').eq('closed_by', agentId).gte('closed_at', since.toISOString()),
    supabase.from('call_logs').select('call_date, calls_taken').eq('agent_id', agentId).gte('call_date', dateKey(since)),
  ]);

  const totals = {};
  for (const c of closedCases || []) {
    const key = c.closed_at.slice(0, 10);
    totals[key] = (totals[key] || 0) + 1;
  }
  for (const c of calls || []) {
    totals[c.call_date] = (totals[c.call_date] || 0) + c.calls_taken;
  }

  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const cursor = new Date(today);
  let streak = 0;

  if ((totals[dateKey(cursor)] || 0) >= dailyTarget) streak++;
  cursor.setDate(cursor.getDate() - 1);
  while ((totals[dateKey(cursor)] || 0) >= dailyTarget) {
    streak++;
    cursor.setDate(cursor.getDate() - 1);
  }

  const metToday = (totals[dateKey(today)] || 0) >= dailyTarget;
  return { streak, metToday };
}

// ---- Badges ----
function mondayOf(d = new Date()) {
  const date = new Date(d);
  date.setHours(0, 0, 0, 0);
  date.setDate(date.getDate() - ((date.getDay() + 6) % 7));
  return date;
}

// Computes lifetime + this-week stats for the agent, works out which badges
// they newly qualify for (that they don't already have), inserts them, and
// drops a matching event into the activity feed. Returns the newly-earned
// ones so the caller can show a "badge unlocked" toast.
export async function checkAndAwardBadges(agentId, { streak } = {}) {
  const weekStart = mondayOf();
  const weekKey = dateKey(weekStart);

  const [
    { count: lifetimeClosed },
    { data: callRows },
    { count: weekClosed },
    { data: weekCallRows },
    { escClosed, escBreached },
    { data: teamEsc },
    { data: existing },
  ] = await Promise.all([
    supabase.from('cases').select('id', { count: 'exact', head: true }).eq('closed_by', agentId),
    supabase.from('call_logs').select('calls_taken').eq('agent_id', agentId),
    supabase.from('cases').select('id', { count: 'exact', head: true }).eq('closed_by', agentId).gte('closed_at', weekStart.toISOString()),
    supabase.from('call_logs').select('calls_taken').eq('agent_id', agentId).gte('call_date', weekKey),
    fetchEscalationStats(agentId, null, null),
    supabase.from('escalation_audit').select('was_overdue').not('closed_at', 'is', null),
    supabase.from('badges').select('badge_key').eq('agent_id', agentId),
  ]);

  const lifetimeCalls = (callRows || []).reduce((s, r) => s + r.calls_taken, 0);
  const weekCalls = (weekCallRows || []).reduce((s, r) => s + r.calls_taken, 0);
  const teamEscClosed = (teamEsc || []).length;
  const teamEscBreached = (teamEsc || []).filter(r => r.was_overdue).length;
  const teamBreachRate = teamEscClosed ? teamEscBreached / teamEscClosed : 1;
  const ownBreachRate = escClosed ? escBreached / escClosed : 0;

  const candidates = [];
  if ((lifetimeClosed || 0) >= 1) candidates.push(['first_close', '🎉 First Close']);
  if ((lifetimeClosed || 0) >= 50) candidates.push(['closes_50', '🥈 50 Closes']);
  if ((lifetimeClosed || 0) >= 100) candidates.push(['closes_100', '🥇 100 Closes']);
  if ((lifetimeClosed || 0) >= 250) candidates.push(['closes_250', '💎 250 Closes']);
  if (lifetimeCalls >= 500) candidates.push(['calls_500', '📞 500 Calls']);
  if ((weekClosed || 0) >= 5) candidates.push([`weekly_5_closed:${weekKey}`, '⭐ 5 Closed This Week']);
  if (weekCalls >= 50) candidates.push([`weekly_50_calls:${weekKey}`, '📞 50 Calls This Week']);
  if ((streak || 0) >= 3) candidates.push(['streak_3', '🔥 3-Day Streak']);
  if ((streak || 0) >= 5) candidates.push(['streak_5', '🔥🔥 5-Day Streak']);
  if ((streak || 0) >= 10) candidates.push(['streak_10', '🔥🔥🔥 10-Day Streak']);
  if (escClosed >= 10 && ownBreachRate <= teamBreachRate) candidates.push(['escalation_specialist', '🛡️ Escalation Specialist']);

  const owned = new Set((existing || []).map(b => b.badge_key));
  const toAward = candidates.filter(([key]) => !owned.has(key));
  if (toAward.length === 0) return [];

  const { error } = await supabase.from('badges').insert(
    toAward.map(([badge_key, label]) => ({ agent_id: agentId, badge_key, label }))
  );
  if (error) return []; // race with another tab hitting the unique constraint — fine, just skip the toast

  await supabase.from('activity_feed').insert(
    toAward.map(([, label]) => ({ actor_id: agentId, type: 'badge', meta: { label } }))
  );

  return toAward.map(([badge_key, label]) => ({ badge_key, label }));
}

// ---- Team leaderboard ----
// Sums each active agent's escalation-adjusted weighted score (month to date)
// into their team. Teams with no agents/activity still appear at 0, so a
// team leader can see they're on the board.
export async function computeTeamLeaderboard() {
  const monthStart = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
  const now = new Date();

  const [{ data: agentList }, { data: teams }] = await Promise.all([
    supabase.from('profiles').select('id, full_name, team_id').eq('role', 'agent').eq('is_active', true),
    supabase.from('teams').select('id, name').eq('is_active', true).order('name'),
  ]);

  const perAgent = await Promise.all((agentList || []).map(async (a) => {
    const [{ count: closed }, { data: notes }, { escClosed, escBreached }] = await Promise.all([
      supabase.from('cases').select('id', { count: 'exact', head: true })
        .eq('closed_by', a.id).gte('closed_at', monthStart.toISOString()),
      supabase.from('case_notes').select('case_id').eq('user_id', a.id).gte('created_at', monthStart.toISOString()),
      fetchEscalationStats(a.id, monthStart.toISOString(), now.toISOString()),
    ]);
    const interacted = new Set((notes || []).map(n => n.case_id)).size;
    return { agent: a, score: weightedScore({ closed: closed || 0, interacted, escClosed, escBreached }) };
  }));

  const totals = {};
  for (const r of perAgent) {
    const key = r.agent.team_id || '_none';
    totals[key] = (totals[key] || 0) + r.score;
  }

  return (teams || [])
    .map(t => ({ team: t, score: totals[t.id] || 0 }))
    .sort((a, b) => b.score - a.score);
}
