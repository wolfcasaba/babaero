// Delete-account edge function.
//
// A Supabase client can't delete its own auth user, but App Store / Play Store
// review require in-app account deletion. This function verifies the caller's
// JWT, then deletes that auth user with the service role. All babaero.* rows
// reference auth.users(id) ON DELETE CASCADE, so the member's data goes with it.
//
// Deploy: supabase functions deploy delete-account (needs the project's
// SERVICE_ROLE key available as an env secret — set automatically for edge
// functions on the hosted project).

import { createClient } from 'jsr:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405, headers: cors });
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return json({ error: 'Missing authorization' }, 401);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  // Identify the caller from their JWT (never trust a user-supplied id).
  const asUser = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const {
    data: { user },
    error: userErr,
  } = await asUser.auth.getUser();
  if (userErr || !user) {
    return json({ error: 'Invalid session' }, 401);
  }

  // Delete with the service role; babaero.* cascades off auth.users.
  const admin = createClient(supabaseUrl, serviceKey);
  const { error } = await admin.auth.admin.deleteUser(user.id);
  if (error) {
    return json({ error: error.message }, 500);
  }

  return json({ ok: true }, 200);
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}
