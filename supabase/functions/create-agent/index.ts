import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization") || "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;
  if (!token) {
    return json({ error: "Missing bearer token" }, 401);
  }

  const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
  const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
  const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // Verify the caller's identity using their own token (anon key + RLS).
  const callerClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });

  const { data: { user: caller }, error: callerError } = await callerClient.auth.getUser(token);
  if (callerError || !caller) {
    return json({ error: "Invalid session" }, 401);
  }

  const { data: callerProfile, error: profileError } = await callerClient
    .from("profiles")
    .select("role, is_active")
    .eq("id", caller.id)
    .single();

  if (profileError || !callerProfile || callerProfile.role !== "admin" || !callerProfile.is_active) {
    return json({ error: "Admin access required" }, 403);
  }

  const body = await req.json().catch(() => ({}));
  const { full_name, email, password, department_id, role } = body;

  if (!full_name || !email || !password || String(password).length < 8) {
    return json({ error: "full_name, email and a password (8+ chars) are required" }, 400);
  }
  if (role && !["agent", "admin"].includes(role)) {
    return json({ error: 'role must be "agent" or "admin"' }, 400);
  }

  // Elevated client for user creation — the service role key never reaches the browser,
  // and is injected automatically by Supabase for Edge Functions in this project.
  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const { data: created, error: createError } = await adminClient.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });

  if (createError) {
    return json({ error: createError.message }, 400);
  }

  const { error: insertError } = await adminClient.from("profiles").insert({
    id: created.user.id,
    email,
    full_name,
    role: role || "agent",
    department_id: department_id || null,
    is_active: true,
  });

  if (insertError) {
    // Roll back the auth user so we don't leave an orphaned login with no profile.
    await adminClient.auth.admin.deleteUser(created.user.id);
    return json({ error: insertError.message }, 400);
  }

  await adminClient.from("audit_log").insert({
    actor_id: caller.id,
    action: "create_agent",
    entity_type: "profiles",
    entity_id: created.user.id,
    detail: { email, role: role || "agent" },
  });

  return json({ id: created.user.id, email });
});
