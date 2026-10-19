# Supabase + Xendit backend

This backend is source-only; no Supabase or Xendit project was linked or deployed. The Xendit adapter deliberately accepts **test-mode** API keys beginning with `xnd_development_` and rejects live keys. This is a safeguard for the demo, not a production payment rollout.

## Security model

- `products` is public-read. `orders` is readable only by its authenticated owner. Clients have no order insert/update/delete privileges. This intentionally rejects the handout's public-read orders policy: it would expose customers' order history and payment data.
- `create-invoice` requires a Supabase user JWT at the gateway (`verify_jwt = true`) and validates the bearer token again with Supabase Auth `getUser`. It accepts only `{ "product_id": <positive integer> }`; identity, name, price, and currency come from the verified user and database.
- `create_checkout_order` is a `SECURITY DEFINER` RPC executable only by `service_role`. It snapshots the catalog name/price into a `PENDING` PHP order before contacting Xendit. A cryptographically random external ID is generated server-side.
- The function sends a server-priced invoice to Xendit using HTTP Basic auth. It accepts only a test secret key, and checks the provider's external ID, amount, currency, and HTTPS `checkout.xendit.co` URL before saving the invoice ID/URL. Its HTTP response contains only `invoice_url` and `external_id`. Provider failures mark a still-pending order `FAILED`; errors and provider response bodies are not returned to the client.
- `xendit-webhook` alone has gateway JWT verification disabled so Xendit can call it. It requires an exact `x-callback-token` match before parsing the event, accepts only `PAID` and `EXPIRED`, and sends the event to a service-only database RPC. The RPC locks the row and verifies persisted invoice ID, PHP currency, and exact amount before changing state. Repeated events are idempotent; an `EXPIRED` event cannot downgrade a `PAID` order.
- The service/secret key, Xendit API key, and callback token must never be included in Flutter, a checked-in file, or a client response. Anonymous Auth users are `authenticated` database users—not the public `anon` role—and are still isolated by owner RLS.

## Apply schema and seed

### Hosted Supabase project

1. Create/open the intended project and retain its project reference and URL.
2. In **SQL Editor**, execute [`supabase/migrations/20261019000100_bmc_store.sql`](../supabase/migrations/20261019000100_bmc_store.sql), then execute [`supabase/seed.sql`](../supabase/seed.sql). The seed is repeatable.
3. Or apply the migration through the CLI from the repository root. Review the dry run before applying it:

   ```sh
   supabase login
   supabase link --project-ref YOUR_PROJECT_REF
   supabase db push --dry-run
   supabase db push
   ```

   The CLI's normal seed workflow runs `supabase/seed.sql` on local `supabase start` and `supabase db reset`; for a hosted project, execute the seed in SQL Editor if the catalog needs the demo products. Do not run a destructive database reset against a hosted project.

4. In Supabase Dashboard, enable **Anonymous sign-ins** in the Auth sign-in providers. Anonymous users use the `authenticated` Postgres role, which is how the owner-only order policy is applied. For a public production app, add CAPTCHA/bot protection and appropriate abuse controls before enabling anonymous account creation.

## Local function secrets and checks

The root `.gitignore` ignores `.env` files. Create `supabase/functions/.env` locally (never commit it):

```dotenv
XENDIT_SECRET_KEY=xnd_development_REPLACE_WITH_TEST_SECRET
XENDIT_WEBHOOK_TOKEN=REPLACE_WITH_TEST_CALLBACK_TOKEN
```

Supabase supplies `SUPABASE_URL` and the `SUPABASE_PUBLISHABLE_KEYS` / `SUPABASE_SECRET_KEYS` dictionaries to Edge Functions. The code selects the `default` key (or the sole named key) and supports legacy `SUPABASE_ANON_KEY` / `SUPABASE_SERVICE_ROLE_KEY` values as a fallback. Never put a Supabase secret/service-role key in the Flutter defines file.

Run the deterministic handler/provider tests and TypeScript checks from `supabase/`:

```sh
deno task test
deno task check
```

The database integration suite uses a disposable PostgreSQL instance and makes no network calls to a hosted Supabase project:

```sh
PG_BIN=/path/to/postgresql/bin python3 tests/run_db_tests.py
```

`PG_BIN` must contain `initdb`, `pg_ctl`, and `postgres`; the script creates and removes its temporary database under `TMPDIR` (defaulting to the Hermes scratch directory when available). It refuses non-loopback URLs and creates only a disposable `bmc_test` database.

For local Edge Runtime serving, start Supabase locally and serve each function with the local secret file:

```sh
supabase start
supabase functions serve create-invoice --env-file supabase/functions/.env
supabase functions serve xendit-webhook --env-file supabase/functions/.env
```

Run the two `functions serve` commands in separate terminals. `create-invoice` is invoked with a real local Supabase user session (the Flutter demo creates an anonymous session); a local Xendit webhook needs a publicly reachable HTTPS tunnel if you want Xendit itself to deliver it.

## Hosted secrets, functions, and Xendit webhook

After the database is set up and **only after reviewing the target project**, link the Supabase CLI and set the two Xendit secrets. The secret file above contains only Xendit secrets; Supabase's own API keys are injected by the platform:

```sh
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase secrets set --env-file supabase/functions/.env
supabase functions deploy create-invoice
supabase functions deploy xendit-webhook
```

The checked-in `supabase/config.toml` keeps JWT verification enabled for `create-invoice` and disables it only for the external webhook. Do not add `--no-verify-jwt` when deploying or serving `create-invoice`.

In Xendit **Test Mode**, configure the legacy **Invoices paid** and **Invoice expired** callbacks to:

```text
https://YOUR_PROJECT_REF.supabase.co/functions/v1/xendit-webhook
```

Use the callback verification token for that same Xendit test environment as `XENDIT_WEBHOOK_TOKEN`. Do not put the token in the URL or request body. The endpoint expects the legacy invoice callback's `id`, `external_id`, `status`, `amount`, and `currency` fields and the `x-callback-token` header. Xendit retries non-2xx webhook deliveries, so inspect the function and Xendit webhook delivery logs if a callback is rejected.

**API lifecycle note:** this implementation uses Xendit's legacy `POST /v2/invoices` flow and its `Invoices paid` / `Invoice expired` events to match the assignment. Xendit's current migration guide describes Payment Sessions as the replacement; those use a different request/response model and different event names. Before enabling live payments, migrate the provider adapter, webhook parser, stored invoice/session identifiers, and tests together. Merely replacing the test secret with a live key is blocked by code and is not a supported production switch.

## Flutter app configuration

The Flutter `pubspec.yaml` already depends on `supabase_flutter`. Copy `dart_defines.example.json` to the ignored `dart_defines.json`, then set the project URL and the project's public publishable key (legacy anon key is also supported under this existing define name):

```json
{
  "SUPABASE_URL": "https://YOUR_PROJECT_REF.supabase.co",
  "SUPABASE_ANON_KEY": "YOUR_PUBLIC_PUBLISHABLE_OR_LEGACY_ANON_KEY"
}
```

Run or build with the existing argument:

```sh
flutter run --dart-define-from-file=dart_defines.json
flutter build apk --release --dart-define-from-file=dart_defines.json
```

The app calls `create-invoice` with the current user's bearer token and a product ID only. It reads order status/history through owner-scoped RLS; it never decides that a redirect means payment succeeded. For a manual invocation, include both the project's public key and a real user JWT:

```sh
curl --request POST 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/create-invoice' \
  --header 'apikey: YOUR_PUBLIC_PUBLISHABLE_KEY' \
  --header 'Authorization: Bearer YOUR_USER_ACCESS_TOKEN' \
  --header 'Content-Type: application/json' \
  --data '{"product_id":1}'
```

## Important operational limits

- This source has not been deployed or exercised with real Supabase/Xendit credentials. Production setup must be verified in the intended projects first.
- The development-key guard intentionally prevents live Xendit charges. Do not remove it without migrating to the current Xendit API, testing live-mode configuration in a controlled environment, and reviewing webhook/authentication behavior.
- Anonymous sessions are device-local: a user who clears app data or changes devices cannot recover that anonymous account's orders unless the app adds an identity-linking/sign-in flow.
- The schema protects order rows, but server-side service credentials can bypass RLS. Keep the service/secret key confined to the Edge Runtime and rotate it if exposed.

## Official references

- [Supabase Edge Function secrets and environment variables](https://supabase.com/docs/guides/functions/secrets)
- [Supabase Edge Function authorization headers and `verify_jwt`](https://supabase.com/docs/guides/functions/auth-headers)
- [Supabase Edge Function deployment](https://supabase.com/docs/guides/functions/deploy)
- [Supabase anonymous sign-ins](https://supabase.com/docs/guides/auth/auth-anonymous)
- [Xendit webhook behavior](https://docs.xendit.co/apidocs/webhook-behavior)
- [Xendit webhook verification](https://docs.xendit.co/docs/handling-webhooks)
- [Xendit legacy Invoice to Payment Session migration](https://docs.xendit.co/docs/migrate-to-payment-session)
