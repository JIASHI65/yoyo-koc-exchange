import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, apikey",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders });
  if (req.method !== "POST") return json({ ok: false, error: "Method not allowed" }, 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
    const adminPassword = Deno.env.get("REGISTRATION_ADMIN_PASSWORD") || "";
    if (!supabaseUrl || !serviceRoleKey) return json({ ok: false, error: "Server configuration missing" }, 500);

    const db = createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false } });
    const { action, data = {}, admin_password = "" } = await req.json();

    if (action === "submit") {
      const application = {
        discord_name: String(data.discord_name || "").trim(),
        account_id: String(data.account_id || "").trim(),
        uid: String(data.uid || "").trim(),
        name: String(data.name || "").trim(),
        server: String(data.server || "").trim(),
        address: String(data.address || "").trim(),
        city: String(data.city || "").trim(),
        state: String(data.state || "").trim(),
        postal_code: String(data.postal_code || "").trim(),
        country: String(data.country || "").trim(),
        phone: String(data.phone || "").trim(),
        notes: String(data.notes || ""),
      };
      if (!application.discord_name || !application.uid || !/^\d{19}$/.test(application.account_id) || !application.name || !application.server) {
        return json({ ok: false, error: "Required registration information is incomplete" }, 400);
      }

      const { data: existingKoc } = await db.from("kocs").select("uid").or(`uid.eq.${application.uid},account_id.eq.${application.account_id}`).limit(1);
      if (existingKoc?.length) return json({ ok: false, error: "This creator is already registered. Please use Creator Login." }, 409);

      const { data: existingApplication } = await db.from("registration_applications")
        .select("id,status,review_notes")
        .or(`uid.eq.${application.uid},account_id.eq.${application.account_id}`)
        .in("status", ["pending", "approved"])
        .order("created_at", { ascending: false })
        .limit(1);
      if (existingApplication?.length) {
        return json({ ok: true, duplicate: true, application: existingApplication[0] });
      }

      const { data: inserted, error } = await db.from("registration_applications")
        .insert({ ...application, status: "pending" })
        .select("id,status,created_at")
        .single();
      if (error) return json({ ok: false, error: error.message }, 400);
      return json({ ok: true, application: inserted });
    }

    if (!adminPassword || admin_password !== adminPassword) return json({ ok: false, error: "Admin verification failed" }, 403);

    if (action === "list") {
      const { data: applications, error } = await db.from("registration_applications")
        .select("*")
        .order("created_at", { ascending: false });
      if (error) return json({ ok: false, error: error.message }, 400);
      return json({ ok: true, applications: applications || [] });
    }

    if (action === "approve") {
      const applicationId = Number(data.id);
      const { data: application, error: loadError } = await db.from("registration_applications")
        .select("*").eq("id", applicationId).single();
      if (loadError || !application) return json({ ok: false, error: "Application not found" }, 404);
      if (application.status !== "pending") return json({ ok: false, error: "Application has already been reviewed" }, 409);

      const { error: insertError } = await db.from("kocs").insert({
        uid: application.uid,
        discord_name: application.discord_name,
        name: application.name,
        account_id: application.account_id,
        server: application.server,
        address: application.address,
        city: application.city,
        state: application.state,
        postal_code: application.postal_code,
        country: application.country,
        phone: application.phone,
        notes: application.notes,
        status: "active",
        created_at: new Date().toISOString(),
      });
      if (insertError) return json({ ok: false, error: `Unable to create creator account: ${insertError.message}` }, 400);

      const period = new Date().toISOString().slice(0, 7);
      const { error: giftError } = await db.from("redemption_orders").insert({
        uid: application.uid,
        discord_name: application.discord_name,
        koc_name: application.name,
        option_type: "merch",
        option_name: "🎁 New Creator Welcome Gift",
        points_spent: 0,
        reward_amount: "Random Merchandise × 1",
        contact_info: "",
        status: "pending",
        admin_notes: "Welcome gift - created automatically on registration approval",
        period,
        created_at: new Date().toISOString(),
      });
      if (giftError) {
        await db.from("kocs").delete().eq("uid", application.uid);
        return json({ ok: false, error: `Unable to create mandatory welcome gift: ${giftError.message}` }, 400);
      }

      const { error: updateError } = await db.from("registration_applications").update({
        status: "approved",
        reviewed_at: new Date().toISOString(),
        reviewed_by: "admin",
        review_notes: String(data.review_notes || ""),
      }).eq("id", applicationId);
      if (updateError) return json({ ok: false, error: updateError.message }, 400);
      return json({ ok: true });
    }

    if (action === "reject") {
      const applicationId = Number(data.id);
      const { error } = await db.from("registration_applications").update({
        status: "rejected",
        reviewed_at: new Date().toISOString(),
        reviewed_by: "admin",
        review_notes: String(data.review_notes || "Not approved"),
      }).eq("id", applicationId).eq("status", "pending");
      if (error) return json({ ok: false, error: error.message }, 400);
      return json({ ok: true });
    }

    return json({ ok: false, error: "Unknown action" }, 400);
  } catch (error) {
    return json({ ok: false, error: error instanceof Error ? error.message : String(error) }, 500);
  }
});
