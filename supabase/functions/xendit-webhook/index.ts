import { createClient } from "@supabase/supabase-js";
import { createXenditWebhookHandler, type EventResult } from "./handler.ts";
import { resolveSupabaseKey } from "../_shared/api_keys.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = resolveSupabaseKey(
  Deno.env.get("SUPABASE_SECRET_KEYS"),
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
);
if (!supabaseUrl) {
  throw new Error("Supabase function environment is not configured");
}

const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, detectSessionInUrl: false, persistSession: false },
});
const knownResults = new Set<EventResult>([
  "updated",
  "already_applied",
  "not_found",
  "invoice_mismatch",
  "amount_mismatch",
  "currency_mismatch",
]);

Deno.serve(createXenditWebhookHandler({
  webhookToken: Deno.env.get("XENDIT_WEBHOOK_TOKEN"),
  applyEvent: async (event) => {
    const { data, error } = await serviceClient.rpc("apply_xendit_invoice_event", {
      p_external_id: event.externalId,
      p_invoice_id: event.invoiceId,
      p_status: event.status,
      p_amount: event.amount,
      p_currency: event.currency,
    });
    if (error || typeof data !== "string" || !knownResults.has(data as EventResult)) {
      throw new Error("Invoice event persistence failed");
    }
    return data as EventResult;
  },
}));
