import type { OrderSnapshot, XenditInvoice } from "./handler.ts";

const INVOICE_ENDPOINT = "https://api.xendit.co/v2/invoices";
const CHECKOUT_HOST = "checkout.xendit.co";
const MAX_CENTS = 999_999_999_999n;

type Fetcher = typeof fetch;

function amountInCents(value: unknown): bigint | null {
  if (typeof value !== "number" && typeof value !== "string") return null;
  if (typeof value === "number" && !Number.isFinite(value)) return null;
  const text = String(value);
  const match = /^(0|[1-9]\d{0,9})(?:\.(\d{1,2}))?$/.exec(text);
  if (!match) return null;
  const cents = BigInt(match[1]) * 100n + BigInt((match[2] ?? "").padEnd(2, "0") || "0");
  return cents > 0n && cents <= MAX_CENTS ? cents : null;
}

function validInvoiceUrl(value: unknown): value is string {
  if (typeof value !== "string" || value.length > 2048) return false;
  try {
    const url = new URL(value);
    return url.protocol === "https:" && url.hostname === CHECKOUT_HOST && url.port === "" &&
      url.username === "" && url.password === "";
  } catch {
    return false;
  }
}

function hasControlCharacters(value: string): boolean {
  for (let index = 0; index < value.length; index++) {
    const code = value.charCodeAt(index);
    if (code < 0x20 || code === 0x7f) return true;
  }
  return false;
}

function validIdentifier(value: unknown): value is string {
  return typeof value === "string" && value.length > 0 && value.length <= 200 &&
    value.trim() === value && !hasControlCharacters(value);
}

export async function requestXenditInvoice(
  secretKey: string,
  order: OrderSnapshot,
  fetcher: Fetcher = fetch,
): Promise<XenditInvoice> {
  if (!/^xnd_development_/.test(secretKey)) {
    throw new Error("A Xendit development key is required");
  }
  if (
    !validIdentifier(order.external_id) || !order.product_name.trim() ||
    order.product_name.length > 200 || order.currency !== "PHP"
  ) {
    throw new Error("Invalid invoice request");
  }
  const orderCents = amountInCents(order.amount);
  if (orderCents === null) throw new Error("Invalid invoice request");

  let authorization: string;
  try {
    authorization = `Basic ${btoa(`${secretKey}:`)}`;
  } catch {
    throw new Error("Invalid Xendit development key");
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15_000);
  let response: Response;
  try {
    response = await fetcher(INVOICE_ENDPOINT, {
      method: "POST",
      headers: {
        authorization,
        "content-type": "application/json",
        accept: "application/json",
      },
      body: JSON.stringify({
        external_id: order.external_id,
        amount: Number(orderCents) / 100,
        currency: "PHP",
        description: order.product_name,
      }),
      signal: controller.signal,
    });
  } catch {
    throw new Error("Invoice provider request failed");
  } finally {
    clearTimeout(timeout);
  }

  if (!response.ok) throw new Error("Invoice provider request failed");
  let payload: unknown;
  try {
    payload = await response.json();
  } catch {
    throw new Error("Invalid invoice response");
  }
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    throw new Error("Invalid invoice response");
  }

  const invoice = payload as Record<string, unknown>;
  if (
    !validIdentifier(invoice.id) || invoice.external_id !== order.external_id ||
    !validInvoiceUrl(invoice.invoice_url) || invoice.currency !== "PHP" ||
    amountInCents(invoice.amount) !== orderCents
  ) {
    throw new Error("Invalid invoice response");
  }
  return {
    id: invoice.id,
    external_id: order.external_id,
    invoice_url: invoice.invoice_url,
    amount: Number(orderCents) / 100,
    currency: "PHP",
  };
}
