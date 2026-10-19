import 'package:flutter_test/flutter_test.dart';
import 'package:student_shop/main.dart';

void main() {
  testWidgets(
    'shows the supplied configuration steps instead of a fake store',
    (tester) async {
      await tester.pumpWidget(const StudentEcommerceApp());
      expect(find.text('Supabase setup required'), findsOneWidget);
      expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
      expect(find.textContaining('SUPABASE_ANON_KEY'), findsOneWidget);
      expect(find.text('Campus Store'), findsOneWidget);
    },
  );
}
