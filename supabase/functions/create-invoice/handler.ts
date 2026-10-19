export type UserIdentity = { id: string };

export type OrderSnapshot = {
  external_id: string;
  product_name: string;
  amount: string;
  currency: string;
};

export type XenditInvoice = {
  id: string;
  external_id: string;
  invoice_url: string;
  amount: number;
  currency: string;
};

export type CreateInvoiceDependencies = {
  xenditSecretKey: string | undefined;
  authenticate: (accessToken: string) => Promise<UserIdentity | null>;
  reserveOrder: (input: {
    userId: string;
    productId: number;
    externalId: string;
  }) => Promise<OrderSnapshot>;
  issueInvoice: (secret: string, order: OrderSnapshot) => Promise<XenditInvoice>;
  attachInvoice: (input: {
    externalId: string;
    invoiceId: string;
    invoiceUrl: string;
  }) => Promise<void>;
  markFailed: (externalId: string) => Promise<void>;
  newExternalId?: () => string;
};

export class ProductNotFoundError extends Error {
  constructor() {
    super("Product not found");
    this.name = "ProductNotFoundError";
  }
}

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-allow-headers": "authorization, apikey, content-type, x-client-info",
  "cache-control": "no-store",
};

function json(status: number, body: Record<string, unknown>): Response {
  return Response.json(body, { status, headers: CORS_HEADERS });
}

function productIdFrom(body: unknown): number | null {
  if (!body || typeof body !== "object" || Array.isArray(body)) return null;
  const record = body as Record<string, unknown>;
  if (Object.keys(record).length !== 1 || !Object.hasOwn(record, "product_id")) return null;
  const productId = record.product_id;
  return typeof productId === "number" && Number.isSafeInteger(productId) && productId > 0
    ? productId
    : null;
}

export function createInvoiceHandler(
  deps: CreateInvoiceDependencies,
): (request: Request) => Promise<Response> {
  const newExternalId = deps.newExternalId ?? (() => crypto.randomUUID());

  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }
    if (request.method !== "POST") return json(405, { error: "Method not allowed" });

    const secret = deps.xenditSecretKey;
    if (!secret || !/^xnd_development_/.test(secret)) {
      return json(503, { error: "Checkout is not configured" });
    }

    const authorization = request.headers.get("authorization") ?? "";
    const bearer = /^Bearer\s+(\S+)$/i.exec(authorization);
    if (!bearer) return json(401, { error: "Authentication required" });

    let user: UserIdentity | null;
    try {
      user = await deps.authenticate(bearer[1]);
    } catch {
      return json(503, { error: "Authentication is temporarily unavailable" });
    }
    if (!user?.id) return json(401, { error: "Invalid authentication" });

    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return json(400, { error: "Invalid request" });
    }
    const productId = productIdFrom(body);
    if (productId === null) return json(400, { error: "Expected only a positive product_id" });

    const externalId = newExternalId();
    let order: OrderSnapshot;
    try {
      order = await deps.reserveOrder({ userId: user.id, productId, externalId });
    } catch (error) {
      if (error instanceof ProductNotFoundError) return json(404, { error: "Product not found" });
      return json(500, { error: "Could not create checkout" });
    }

    try {
      const invoice = await deps.issueInvoice(secret, order);
      await deps.attachInvoice({
        externalId: order.external_id,
        invoiceId: invoice.id,
        invoiceUrl: invoice.invoice_url,
      });
      return json(200, { invoice_url: invoice.invoice_url, external_id: order.external_id });
    } catch {
      try {
        await deps.markFailed(order.external_id);
      } catch {
        // Keep the public error generic; pending-order recovery is handled operationally.
      }
      return json(502, { error: "Could not create payment invoice" });
    }
  };
}
