// deno-lint-ignore-file require-await
import { equal, rejects } from "./assert.ts";
import { requestXenditInvoice } from "../functions/create-invoice/xendit.ts";
import { resolveSupabaseKey } from "../functions/_shared/api_keys.ts";

const ORDER = {
  external_id: "checkout-5e19b7f2",
  product_name: "Mechanical Gaming Keyboard",
  amount: "1500.00",
  currency: "PHP",
};

Deno.test("Xendit adapter: sends a test-mode, server-priced PHP invoice with Basic authentication", async () => {
  let capturedUrl = "";
  let capturedInit: RequestInit | undefined;
  const invoice = await requestXenditInvoice("xnd_development_test", ORDER, async (input, init) => {
    capturedUrl = String(input);
    capturedInit = init;
    return Response.json({
      id: "inv-1",
      external_id: ORDER.external_id,
      invoice_url: "https://checkout.xendit.co/web/inv-1",
      amount: 1500,
      currency: "PHP",
    });
  });
  equal(capturedUrl, "https://api.xendit.co/v2/invoices");
  equal(capturedInit?.method, "POST");
  const headers = new Headers(capturedInit?.headers);
  equal(headers.get("authorization"), `Basic ${btoa("xnd_development_test:")}`);
  equal(headers.get("content-type"), "application/json");
  equal(JSON.parse(String(capturedInit?.body)), {
    external_id: ORDER.external_id,
    amount: 1500,
    currency: "PHP",
    description: ORDER.product_name,
  });
  equal(invoice.id, "inv-1");
});

Deno.test("Xendit adapter: refuses live credentials before making a request", async () => {
  let calls = 0;
  await rejects(
    () =>
      requestXenditInvoice("xnd_production_live", ORDER, async () => {
        calls++;
        return Response.json({});
      }),
    /development key/,
  );
  equal(calls, 0);
});

Deno.test("Xendit adapter: rejects invoice URLs outside the trusted HTTPS checkout host", async () => {
  await rejects(
    () =>
      requestXenditInvoice("xnd_development_test", ORDER, async () =>
        Response.json({
          id: "inv-1",
          external_id: ORDER.external_id,
          invoice_url: "https://checkout.xendit.co.attacker.example/invoice",
          amount: 1500,
          currency: "PHP",
        })),
    /Invalid invoice response/,
  );
});

Deno.test("Xendit adapter: rejects mismatched amount, currency, or external ID", async () => {
  for (
    const payload of [
      {
        id: "inv-1",
        external_id: ORDER.external_id,
        invoice_url: "https://checkout.xendit.co/i",
        amount: 1,
        currency: "PHP",
      },
      {
        id: "inv-1",
        external_id: ORDER.external_id,
        invoice_url: "https://checkout.xendit.co/i",
        amount: 1500,
        currency: "USD",
      },
      {
        id: "inv-1",
        external_id: "other",
        invoice_url: "https://checkout.xendit.co/i",
        amount: 1500,
        currency: "PHP",
      },
    ]
  ) {
    await rejects(
      () => requestXenditInvoice("xnd_development_test", ORDER, async () => Response.json(payload)),
      /Invalid invoice response/,
    );
  }
});

Deno.test("Xendit adapter: hides upstream error response bodies", async () => {
  await rejects(
    () =>
      requestXenditInvoice(
        "xnd_development_test",
        ORDER,
        async () => new Response("vendor secret diagnostic", { status: 500 }),
      ),
    /Invoice provider request failed/,
  );
});

Deno.test("Supabase keys: prefers a named publishable or secret key, with legacy fallback", () => {
  equal(
    resolveSupabaseKey('{"default":"sb_publishable_123"}', "legacy-anon"),
    "sb_publishable_123",
  );
  equal(resolveSupabaseKey('{"edge":"sb_secret_456"}', undefined), "sb_secret_456");
  equal(resolveSupabaseKey(undefined, "legacy-service-role"), "legacy-service-role");
});

Deno.test("Supabase keys: rejects malformed or ambiguous key dictionaries", async () => {
  await rejects(
    async () => resolveSupabaseKey("not-json", "legacy-fallback"),
    /invalid Supabase key configuration/i,
  );
  await rejects(
    async () => resolveSupabaseKey('{"one":"k1","two":"k2"}', undefined),
    /invalid Supabase key configuration/i,
  );
});
