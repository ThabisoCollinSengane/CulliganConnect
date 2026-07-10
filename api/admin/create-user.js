import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://gitiijehmmovfopgzmtl.supabase.co';
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  if (!SUPABASE_SERVICE_ROLE_KEY || !SUPABASE_ANON_KEY) {
    res.status(500).json({ error: 'Server is missing Supabase configuration' });
    return;
  }

  const authHeader = req.headers.authorization || '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
  if (!token) {
    res.status(401).json({ error: 'Missing bearer token' });
    return;
  }

  // Verify the caller's identity using their own token (anon key + RLS).
  const callerClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });

  const { data: { user: caller }, error: callerError } = await callerClient.auth.getUser(token);
  if (callerError || !caller) {
    res.status(401).json({ error: 'Invalid session' });
    return;
  }

  const { data: callerProfile, error: profileError } = await callerClient
    .from('profiles')
    .select('role, is_active')
    .eq('id', caller.id)
    .single();

  if (profileError || !callerProfile || callerProfile.role !== 'admin' || !callerProfile.is_active) {
    res.status(403).json({ error: 'Admin access required' });
    return;
  }

  const { full_name, email, password, department_id, role } = req.body || {};

  if (!full_name || !email || !password || password.length < 8) {
    res.status(400).json({ error: 'full_name, email and a password (8+ chars) are required' });
    return;
  }
  if (role && !['agent', 'admin'].includes(role)) {
    res.status(400).json({ error: 'role must be "agent" or "admin"' });
    return;
  }

  // Elevated client for user creation — service role key never reaches the browser.
  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const { data: created, error: createError } = await adminClient.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });

  if (createError) {
    res.status(400).json({ error: createError.message });
    return;
  }

  const { error: insertError } = await adminClient.from('profiles').insert({
    id: created.user.id,
    email,
    full_name,
    role: role || 'agent',
    department_id: department_id || null,
    is_active: true,
  });

  if (insertError) {
    // Roll back the auth user so we don't leave an orphaned login with no profile.
    await adminClient.auth.admin.deleteUser(created.user.id);
    res.status(400).json({ error: insertError.message });
    return;
  }

  await adminClient.from('audit_log').insert({
    actor_id: caller.id,
    action: 'create_agent',
    entity_type: 'profiles',
    entity_id: created.user.id,
    detail: { email, role: role || 'agent' },
  });

  res.status(200).json({ id: created.user.id, email });
}
