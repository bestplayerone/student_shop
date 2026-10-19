import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_shop/widgets/order_status_badge.dart';

void main() {
  testWidgets('paid status has a green label and accessible check icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: OrderStatusBadge(status: 'PAID')),
      ),
    );

    expect(find.text('PAID'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle));
    expect(icon.color, Colors.green.shade700);
    expect(find.bySemanticsLabel('Order status: PAID'), findsOneWidget);
  });

  for (final (status, icon, color) in [
    ('PENDING', Icons.schedule, Colors.orange.shade800),
    ('FAILED', Icons.cancel, Colors.red.shade700),
    ('EXPIRED', Icons.event_busy, Colors.grey.shade700),
    ('UNKNOWN', Icons.help_outline, Colors.grey.shade700),
  ]) {
    testWidgets('$status is not styled as a verified payment', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OrderStatusBadge(status: status)),
        ),
      );
      expect(find.text(status), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(tester.widget<Icon>(find.byIcon(icon)).color, color);
    });
  }
}
