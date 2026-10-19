# BMC Campus Store — Flutter + Supabase + Xendit

Android demo matching the supplied BMC finals walkthrough: Mechanical Gaming Keyboard (₱1,500), Wireless Ergonomic Mouse (₱850), and USB-C Hub Multiport Adapter (₱600); hosted Xendit checkout; webhook-verified order history.

## Setup and run

1. Create the Supabase organization `BMC` and project `BMC-ecom1`.
2. Apply the SQL migration in `supabase/migrations/` and run `supabase/seed.sql` in the SQL Editor. The catalog is public-read; order rows are private to the anonymous/authenticated user who created them. Unlike the sample policy in the handout, clients cannot read other customers' orders or write payment statuses.
3. Enable **Anonymous sign-ins** under Supabase Auth. This demo creates a persistent anonymous user on first run so orders can be scoped to the device without a signup screen.
4. In Xendit, select **Test Mode**, make a secret key with Money-In write access, and retrieve that environment's webhook verification token. Never put either value in Flutter or Git.
5. Deploy the `create-invoice` and `xendit-webhook` Edge Functions and set server-side secrets. Follow [`docs/BACKEND.md`](docs/BACKEND.md) for the exact setup and test steps. Register the webhook for Xendit **Invoices paid** and **Invoice expired** events.
6. Copy your Supabase **Project URL** and **anon/public key** into your local ignored `dart_defines.json` (template: `dart_defines.example.json`), then run:

   ```sh
   flutter run --dart-define-from-file=dart_defines.json
   ```

   The public anon key identifies the project and is safe for a client; the Supabase service-role key, Xendit secret key, and webhook token are not.

## Build and tests

```sh
flutter test
flutter analyze
flutter build apk --release --dart-define-from-file=dart_defines.json
```

The APK is `build/app/outputs/flutter-apk/app-release.apk`. A build without real Supabase defines intentionally opens the setup instructions instead of presenting a fake working store.

## Payment demo

Install the release APK on Android. Tap **Buy Now** on the keyboard, complete a test GCash or Maya checkout in the embedded Xendit page, return with **Done**, and let the app poll Supabase. Only the authenticated Xendit webhook can change an order to `PAID`; tapping Done or returning to the store never marks it paid. Open the receipt icon to see the current user's orders and status badges.

No Xendit/Supabase live credentials, deployed project, or Google Drive/GitHub upload are included in this source tree.
