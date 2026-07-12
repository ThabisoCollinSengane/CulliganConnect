import { supabase } from './supabaseClient.js';

export async function loadRecentActivity(limit = 15) {
  const { data } = await supabase
    .from('activity_feed')
    .select('id, type, case_number, meta, created_at, profiles(full_name)')
    .order('created_at', { ascending: false })
    .limit(limit);
  return data || [];
}

export function formatActivity(row) {
  const name = row.profiles?.full_name || 'Someone';
  if (row.type === 'case_closed') return `✅ ${name} closed case ${row.case_number || ''}`.trim();
  if (row.type === 'badge') return `🏅 ${name} earned "${row.meta?.label || 'a badge'}"`;
  return `${name} did something`;
}

// Realtime INSERT payloads carry the raw row only (no joined profile name),
// so on a new event we just reload the small recent list rather than try to
// keep a name cache in sync.
export function subscribeToActivityFeed(onNew) {
  return supabase
    .channel('activity-feed')
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'activity_feed' }, () => {
      onNew();
    })
    .subscribe();
}
