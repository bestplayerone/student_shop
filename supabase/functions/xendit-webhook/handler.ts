export type InvoiceEvent = {
  externalId: string;
  invoiceId: string;
  status: "PAID" | "EXPIRED";
  amount: string;
  currency: "PHP";
};

export type EventResult =
  | "updated"
  | "already_applied"
  | "not_found"
  | "invoice_mismatch"
  | "amount_mismatch"
  | "currency_mismatch";

export type WebhookDependencies = {
  webhookToken: string | undefined;
  applyEvent: (event: InvoiceEvent) => Promise<EventResult>;
};

const JSON_HEADERS = { "cache-control": "no-store" };
const MAX_CENTS = 999_999_999_999n;
const encoder = new TextEncoder();

function json(status: number, body: Record<string, unknown>): Response {
  return Response.json(body, { status, headers: JSON_HEADERS });
}

function constantTimeEqual(left: string, right: string): boolean {
  const leftBytes = encoder.encode(left);
  const rightBytes = encoder.encode(right);
  const length = Math.max(leftBytes.length, rightBytes.length);
  let difference = leftBytes.length ^ rightBytes.length;
  for (let index = 0; index < length; index++) {
    difference |= (leftBytes[index] ?? 0) ^ (rightBytes[index] ?? 0);
  }
  return difference === 0;
}

function canonicalAmount(value: unknown): string | null {
  if (typeof value !== "number" && typeof value !== "string") return null;
  if (typeof value === "number" && !Number.isFinite(value)) return null;
  const match = /^(0|[1-9]\d{0,9})(?:\.(\d{1,2}))?$/.exec(String(value));
  if (!match) return null;
  const cents = BigInt(match[1]) * 100n + BigInt((match[2] ?? "").padEnd(2, "0") || "0");
  if (cents <= 0n || cents > MAX_CENTS) return null;
  return `${match[1]}.${(match[2] ?? "").padEnd(2, "0")}`;
}

function hasControlCharacters(value: string): boolean {
  for (let index = 0; index < value.length; index++) {
    const code = value.charCodeAt(index);
    if (code < 0x20 || code === 0x7f) return true;
  }
  return false;
}

function textField(value: unknown): value is string {
  return typeof value === "string" && value.length > 0 && value.length <= 200 &&
    value.trim() === value && !hasControlCharacters(value);
}

export function createXenditWebhookHandler(
  deps: WebhookDependencies,
): (request: Request) => Promise<Response> {
  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: JSON_HEADERS });
    }
    if (request.method !== "POST") return json(405, { error: "Method not allowed" });

    const configuredToken = deps.webhookToken;
    if (!configuredToken) return json(503, { error: "Webhook is not configured" });
    const suppliedToken = request.headers.get("x-callback-token") ?? "";
    if (!constantTimeEqual(suppliedToken, configuredToken)) {
      return json(401, { error: "Unauthorized" });
    }

    let payload: unknown;
    try {
      payload = await request.json();
    } catch {
      return json(400, { error: "Invalid event" });
    }
    if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
      return json(400, { error: "Invalid event" });
    }

    const event = payload as Record<string, unknown>;
    if (!textField(event.id) || !textField(event.external_id)) {
      return json(400, { error: "Invalid event" });
    }
    const status = typeof event.status === "string" ? event.status.toUpperCase() : "";
    if (status !== "PAID" && status !== "EXPIRED") {
      return json(400, { error: "Unsupported invoice event" });
    }
    const amount = canonicalAmount(event.amount);
    if (amount === null || event.currency !== "PHP") {
      return json(400, { error: "Invalid invoice amount or currency" });
    }

    try {
      const result = await deps.applyEvent({
        externalId: event.external_id,
        invoiceId: event.id,
        status,
        amount,
        currency: "PHP",
      });
      if (result === "updated" || result === "already_applied" || result === "not_found") {
        return json(200, { received: true });
      }
      return json(409, { error: "Invoice does not match the pending order" });
    } catch {
      return json(500, { error: "Could not process invoice event" });
    }
  };
}
