import { supabase } from './supabaseClient.js';

// Fetches the signed-in user's profile (role, department, active flag).
// Returns null if there is no active session.
export async function getCurrentProfile() {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) return null;

  const { data, error } = await supabase
    .from('profiles')
    .select('id, email, full_name, role, is_active, department_id, team_id')
    .eq('id', session.user.id)
    .single();

  if (error) {
    console.error('Failed to load profile', error);
    return null;
  }
  return data;
}

// Redirects to the login page unless there is a session belonging to an
// active profile with one of the allowed roles. Returns the profile on success.
export async function requireRole(allowedRoles) {
  const profile = await getCurrentProfile();
  if (!profile || !profile.is_active || !allowedRoles.includes(profile.role)) {
    window.location.href = '/index.html';
    return null;
  }
  return profile;
}

export async function signOut() {
  await supabase.auth.signOut();
  window.location.href = '/index.html';
}
