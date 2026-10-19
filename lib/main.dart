import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'screens/product_list_screen.dart';
import 'screens/setup_required_screen.dart';
import 'services/payment_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.isConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  }
  runApp(const StudentEcommerceApp());
}

class StudentEcommerceApp extends StatelessWidget {
  const StudentEcommerceApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Campus Store',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4E5F9D),
        surface: const Color(0xFFF9F7FC),
      ),
      scaffoldBackgroundColor: const Color(0xFFF9F7FC),
      cardTheme: CardThemeData(
        color: const Color(0xFFF2EFF8),
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      useMaterial3: true,
    ),
    home: AppConfig.isConfigured
        ? ProductListScreen(
            paymentService: SupabasePaymentService(Supabase.instance.client),
          )
        : const SetupRequiredScreen(),
  );
}
