// Deletes the calling user's account and all their data.
// Deploy:  supabase functions deploy delete-account
// Requires the default SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY secrets.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const auth = req.headers.get("Authorization") ?? "";
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data: { user }, error } = await admin.auth.getUser(auth.replace("Bearer ", ""));
  if (error || !user) return new Response("unauthorized", { status: 401 });

  // 1. Every public row owned by the user (see migration delete_user_data).
  const { error: rpcErr } = await admin.rpc("delete_user_data", { uid: user.id });
  if (rpcErr) return new Response(rpcErr.message, { status: 500 });

  // 2. Storage objects under <uid>/ in every bucket.
  const { data: buckets } = await admin.storage.listBuckets();
  for (const b of buckets ?? []) {
    const { data: files } = await admin.storage.from(b.id).list(user.id);
    if (files?.length) {
      await admin.storage.from(b.id).remove(files.map((f) => `${user.id}/${f.name}`));
    }
  }

  // 3. The auth user itself.
  const { error: delErr } = await admin.auth.admin.deleteUser(user.id);
  if (delErr) return new Response(delErr.message, { status: 500 });
  return new Response(JSON.stringify({ ok: true }), { headers: { "Content-Type": "application/json" } });
});
