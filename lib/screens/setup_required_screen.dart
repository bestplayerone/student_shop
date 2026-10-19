import 'package:flutter/material.dart';

class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Campus Store')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Supabase setup required',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'Build the app with your Supabase project URL and public anon key. '
                'These identify the project; never put the Xendit secret or webhook token in the app.',
              ),
              const SizedBox(height: 16),
              const SelectableText(
                'flutter build apk --release '
                '--dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co '
                '--dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY',
                style: TextStyle(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Then enable Anonymous sign-ins in Supabase Auth, apply the SQL migration and seed, '
                'and deploy the two Edge Functions. See README.md.',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
