// deno-lint-ignore-file require-await
import { assert, equal } from "./assert.ts";
import { createInvoiceHandler } from "../functions/create-invoice/handler.ts";
import { createXenditWebhookHandler } from "../functions/xendit-webhook/handler.ts";

const ORDER = {
  external_id: "checkout-5e19b7f2",
  product_name: "Mechanical Gaming Keyboard",
  amount: "1500.00",
  currency: "PHP",
};

Deno.test("create invoice: reserves server-priced order before Xendit and returns only checkout fields", async () => {
  const events: string[] = [];
  const handler = createInvoiceHandler({
    xenditSecretKey: "xnd_development_test",
    newExternalId: () => ORDER.external_id,
    authenticate: async (token) => token === "valid-user-token" ? { id: "user-1" } : null,
    reserveOrder: async (input) => {
      events.push("reserve");
      equal(input, { userId: "user-1", productId: 1, externalId: ORDER.external_id });
      return ORDER;
    },
    issueInvoice: async (secret, order) => {
      events.push("xendit");
      equal(secret, "xnd_development_test");
      equal(order, ORDER);
      return {
        id: "inv-1",
        external_id: ORDER.external_id,
        invoice_url: "https://checkout.xendit.co/web/inv-1",
        amount: 1500,
        currency: "PHP",
      };
    },
    attachInvoice: async (input) => {
      events.push("attach");
      equal(input, {
        externalId: ORDER.external_id,
        invoiceId: "inv-1",
        invoiceUrl: "https://checkout.xendit.co/web/inv-1",
      });
    },
    markFailed: async () => {
      events.push("failed");
    },
  });

  const response = await handler(
    new Request("https://edge.test/create-invoice", {
      method: "POST",
      headers: { authorization: "Bearer valid-user-token", "content-type": "application/json" },
      body: JSON.stringify({ product_id: 1 }),
    }),
  );
  equal(response.status, 200);
  equal(events, ["reserve", "xendit", "attach"]);
  equal(await response.json(), {
    invoice_url: "https://checkout.xendit.co/web/inv-1",
    external_id: ORDER.external_id,
  });
});

Deno.test("create invoice: rejects client pricing, identity, and extra checkout fields", async () => {
  let reservations = 0;
  const handler = createInvoiceHandler({
    xenditSecretKey: "xnd_development_test",
    authenticate: async () => ({ id: "user-1" }),
    reserveOrder: async () => {
      reservations++;
      return ORDER;
    },
    issueInvoice: async () => {
      throw new Error("must not be called");
    },
    attachInvoice: async () => {},
    markFailed: async () => {},
  });
  const response = await handler(
    new Request("https://edge.test/create-invoice", {
      method: "POST",
      headers: { authorization: "Bearer valid", "content-type": "application/json" },
      body: JSON.stringify({ product_id: 1, amount: 1, user_id: "attacker" }),
    }),
  );
  equal(response.status, 400);
  equal(reservations, 0);
});

Deno.test("create invoice: rejects unauthenticated callers without reserving an order", async () => {
  let reservations = 0;
  const handler = createInvoiceHandler({
    xenditSecretKey: "xnd_development_test",
    authenticate: async () => null,
    reserveOrder: async () => {
      reservations++;
      return ORDER;
    },
    issueInvoice: async () => {
      throw new Error("must not be called");
    },
    attachInvoice: async () => {},
    markFailed: async () => {},
  });
  const response = await handler(
    new Request("https://edge.test/create-invoice", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ product_id: 1 }),
    }),
  );
  equal(response.status, 401);
  equal(reservations, 0);
});

Deno.test("create invoice: upstream failure marks the reserved order failed and hides provider errors", async () => {
  let failedExternalId = "";
  const handler = createInvoiceHandler({
    xenditSecretKey: "xnd_development_test",
    newExternalId: () => ORDER.external_id,
    authenticate: async () => ({ id: "user-1" }),
    reserveOrder: async () => ORDER,
    issueInvoice: async () => {
      throw new Error("secret response body must not escape");
    },
    attachInvoice: async () => {},
    markFailed: async (externalId) => {
      failedExternalId = externalId;
    },
  });
  const response = await handler(
    new Request("https://edge.test/create-invoice", {
      method: "POST",
      headers: { authorization: "Bearer valid", "content-type": "application/json" },
      body: JSON.stringify({ product_id: 1 }),
    }),
  );
  equal(response.status, 502);
  equal(failedExternalId, ORDER.external_id);
  assert(!(await response.text()).includes("secret response body"));
});

Deno.test("Xendit webhook: verifies callback token before applying a paid invoice event", async () => {
  let applied: unknown = null;
  const handler = createXenditWebhookHandler({
    webhookToken: "webhook-secret",
    applyEvent: async (event) => {
      applied = event;
      return "updated";
    },
  });
  const response = await handler(
    new Request("https://edge.test/xendit-webhook", {
      method: "POST",
      headers: { "x-callback-token": "webhook-secret", "content-type": "application/json" },
      body: JSON.stringify({
        id: "inv-1",
        external_id: ORDER.external_id,
        status: "PAID",
        amount: 1500,
        currency: "PHP",
      }),
    }),
  );
  equal(response.status, 200);
  equal(applied, {
    externalId: ORDER.external_id,
    invoiceId: "inv-1",
    status: "PAID",
    amount: "1500.00",
    currency: "PHP",
  });
});

Deno.test("Xendit webhook: rejects an incorrect callback token without touching the database", async () => {
  let calls = 0;
  const handler = createXenditWebhookHandler({
    webhookToken: "webhook-secret",
    applyEvent: async () => {
      calls++;
      return "updated";
    },
  });
  const response = await handler(
    new Request("https://edge.test/xendit-webhook", {
      method: "POST",
      headers: { "x-callback-token": "wrong", "content-type": "application/json" },
      body: JSON.stringify({
        id: "inv-1",
        external_id: ORDER.external_id,
        status: "PAID",
        amount: 1500,
        currency: "PHP",
      }),
    }),
  );
  equal(response.status, 401);
  equal(calls, 0);
});

Deno.test("Xendit webhook: ignores unsupported statuses and rejects malformed or non-PHP amounts", async () => {
  let calls = 0;
  const handler = createXenditWebhookHandler({
    webhookToken: "webhook-secret",
    applyEvent: async () => {
      calls++;
      return "updated";
    },
  });
  for (
    const event of [
      {
        id: "inv-1",
        external_id: ORDER.external_id,
        status: "PENDING",
        amount: 1500,
        currency: "PHP",
      },
      {
        id: "inv-1",
        external_id: ORDER.external_id,
        status: "PAID",
        amount: "NaN",
        currency: "PHP",
      },
      {
        id: "inv-1",
        external_id: ORDER.external_id,
        status: "PAID",
        amount: 1500,
        currency: "USD",
      },
    ]
  ) {
    const response = await handler(
      new Request("https://edge.test/xendit-webhook", {
        method: "POST",
        headers: { "x-callback-token": "webhook-secret", "content-type": "application/json" },
        body: JSON.stringify(event),
      }),
    );
    assert(response.status >= 400);
  }
  equal(calls, 0);
});

Deno.test("Xendit webhook: accepts expiration but never leaks database errors", async () => {
  let appliedStatus = "";
  const handler = createXenditWebhookHandler({
    webhookToken: "webhook-secret",
    applyEvent: async (event) => {
      appliedStatus = event.status;
      return "already_applied";
    },
  });
  const response = await handler(
    new Request("https://edge.test/xendit-webhook", {
      method: "POST",
      headers: { "x-callback-token": "webhook-secret", "content-type": "application/json" },
      body: JSON.stringify({
        id: "inv-1",
        external_id: ORDER.external_id,
        status: "EXPIRED",
        amount: "1500.00",
        currency: "PHP",
      }),
    }),
  );
  equal(response.status, 200);
  equal(appliedStatus, "EXPIRED");
});
