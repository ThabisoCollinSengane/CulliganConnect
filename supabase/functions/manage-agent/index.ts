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
  const { action, id } = body;

  if (!id) {
    return json({ error: "id is required" }, 400);
  }

  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  if (action === "update") {
    const { full_name, email, password, department_id, team_id, role } = body;

    if (role && !["agent", "admin"].includes(role)) {
      return json({ error: 'role must be "agent" or "admin"' }, 400);
    }
    if (password && String(password).length < 8) {
      return json({ error: "Password must be at least 8 characters" }, 400);
    }
    if (id === caller.id && role && role !== callerProfile.role) {
      return json({ error: "You can't change your own role." }, 400);
    }

    // Keep auth.users (the actual login credentials) and profiles.email in
    // sync in one place, rather than letting the client update profiles.email
    // directly — that would silently desync the two, since only the admin API
    // can touch auth.users.
    if (email || password) {
      const authUpdate: Record<string, unknown> = {};
      if (email) authUpdate.email = email;
      if (password) authUpdate.password = password;
      const { error: authErr } = await adminClient.auth.admin.updateUserById(id, authUpdate);
      if (authErr) return json({ error: authErr.message }, 400);
    }

    const profileUpdate: Record<string, unknown> = {};
    if (full_name) profileUpdate.full_name = full_name;
    if (email) profileUpdate.email = email;
    if (department_id !== undefined) profileUpdate.department_id = department_id || null;
    if (team_id !== undefined) profileUpdate.team_id = team_id || null;
    if (role) profileUpdate.role = role;

    if (Object.keys(profileUpdate).length) {
      const { error: updateErr } = await adminClient.from("profiles").update(profileUpdate).eq("id", id);
      if (updateErr) return json({ error: updateErr.message }, 400);
    }

    // A password reset behaves like a fresh temp password — the agent should
    // see it once and change it themselves, same as at account creation.
    if (password) {
      await adminClient.from("agent_onboarding").delete().eq("profile_id", id);
      await adminClient.from("agent_onboarding").insert({ profile_id: id, temp_password: password });
    }

    await adminClient.from("audit_log").insert({
      actor_id: caller.id,
      action: "update_agent",
      entity_type: "profiles",
      entity_id: id,
      detail: { full_name, email, department_id, team_id, role, password_reset: !!password },
    });

    return json({ id });
  }

  if (action === "delete") {
    if (id === caller.id) {
      return json({ error: "You can't delete your own account." }, 400);
    }

    const { data: target } = await adminClient.from("profiles").select("full_name, email").eq("id", id).single();

    // Deleting the auth user cascades to the profile row and everything with
    // ON DELETE CASCADE (agent_onboarding, badges, call_logs, notifications,
    // quick_notes, targets). Anything still referencing this agent with NO
    // ACTION (cases, case_notes, audit_log, escalation_audit, ...) blocks the
    // delete at the database level instead of silently losing case history —
    // surfaced below as a clear "reassign or disable instead" message.
    const { error: deleteErr } = await adminClient.auth.admin.deleteUser(id);
    if (deleteErr) {
      const isFkViolation = /foreign key|violates|referenced/i.test(deleteErr.message);
      return json({
        error: isFkViolation
          ? "Can't delete — this agent still has cases, notes, or history on record. Reassign or delete their cases first, or disable the account instead."
          : deleteErr.message,
      }, 400);
    }

    await adminClient.from("audit_log").insert({
      actor_id: caller.id,
      action: "delete_agent",
      entity_type: "profiles",
      entity_id: id,
      detail: { full_name: target?.full_name, email: target?.email },
    });

    return json({ id });
  }

  return json({ error: 'action must be "update" or "delete"' }, 400);
});
