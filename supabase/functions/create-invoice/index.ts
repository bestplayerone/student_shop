import { createClient } from "@supabase/supabase-js";
import { createInvoiceHandler, type OrderSnapshot, ProductNotFoundError } from "./handler.ts";
import { requestXenditInvoice } from "./xendit.ts";
import { resolveSupabaseKey } from "../_shared/api_keys.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const anonKey = resolveSupabaseKey(
  Deno.env.get("SUPABASE_PUBLISHABLE_KEYS"),
  Deno.env.get("SUPABASE_ANON_KEY"),
);
const serviceRoleKey = resolveSupabaseKey(
  Deno.env.get("SUPABASE_SECRET_KEYS"),
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
);
if (!supabaseUrl) {
  throw new Error("Supabase function environment is not configured");
}

const authClient = createClient(supabaseUrl, anonKey, {
  auth: { autoRefreshToken: false, detectSessionInUrl: false, persistSession: false },
});
const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, detectSessionInUrl: false, persistSession: false },
});

Deno.serve(createInvoiceHandler({
  xenditSecretKey: Deno.env.get("XENDIT_SECRET_KEY"),
  authenticate: async (accessToken) => {
    const { data, error } = await authClient.auth.getUser(accessToken);
    if (error) {
      if (error.status === 401 || error.status === 403) return null;
      throw new Error("Supabase Auth is unavailable");
    }
    return data.user ? { id: data.user.id } : null;
  },
  reserveOrder: async ({ userId, productId, externalId }) => {
    const { data, error } = await serviceClient.rpc("create_checkout_order", {
      p_user_id: userId,
      p_product_id: productId,
      p_external_id: externalId,
    });
    if (error) {
      if (error.message.includes("PRODUCT_NOT_FOUND")) throw new ProductNotFoundError();
      throw new Error("Order reservation failed");
    }
    const row = Array.isArray(data) ? data[0] : data;
    if (
      !row || row.external_id !== externalId || typeof row.product_name !== "string" ||
      (typeof row.amount !== "string" && typeof row.amount !== "number") || row.currency !== "PHP"
    ) {
      throw new Error("Invalid order reservation response");
    }
    return { ...row, amount: String(row.amount) } as OrderSnapshot;
  },
  issueInvoice: requestXenditInvoice,
  attachInvoice: async ({ externalId, invoiceId, invoiceUrl }) => {
    const { data, error } = await serviceClient
      .from("orders")
      .update({ xendit_invoice_id: invoiceId, invoice_url: invoiceUrl })
      .eq("external_id", externalId)
      .eq("status", "PENDING")
      .select("external_id")
      .maybeSingle();
    if (error || !data) throw new Error("Invoice persistence failed");
  },
  markFailed: async (externalId) => {
    const { error } = await serviceClient
      .from("orders")
      .update({ status: "FAILED" })
      .eq("external_id", externalId)
      .eq("status", "PENDING");
    if (error) throw new Error("Order failure update failed");
  },
}));
