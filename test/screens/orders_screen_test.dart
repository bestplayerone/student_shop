import 'package:flutter_test/flutter_test.dart';
import 'package:student_shop/models/order_model.dart';
import 'package:student_shop/screens/orders_screen.dart';
import 'package:student_shop/widgets/order_status_badge.dart';

import 'screen_test_support.dart';

void main() {
  testWidgets('shows paid and pending orders with distinct status badges', (
    tester,
  ) async {
    final service = FakePaymentService()
      ..orders = [
        ShopOrder(
          externalId: 'order-paid',
          productName: 'Mechanical Gaming Keyboard',
          amount: 1500,
          status: 'PAID',
          createdAt: DateTime.utc(2026, 10, 19, 2),
        ),
        ShopOrder(
          externalId: 'order-pending',
          productName: 'Wireless Ergonomic Mouse',
          amount: 850,
          status: 'PENDING',
          createdAt: DateTime.utc(2026, 10, 19, 1),
        ),
      ];
    await tester.pumpWidget(testApp(OrdersScreen(paymentService: service)));
    await tester.pumpAndSettle();

    expect(find.text('Order History'), findsOneWidget);
    expect(find.text('Mechanical Gaming Keyboard'), findsOneWidget);
    expect(find.text('Wireless Ergonomic Mouse'), findsOneWidget);
    expect(find.text('₱1500.00'), findsOneWidget);
    expect(find.text('₱850.00'), findsOneWidget);
    expect(find.textContaining('Ref: order-paid'), findsOneWidget);
    expect(find.textContaining('Ref: order-pending'), findsOneWidget);
    expect(find.byType(OrderStatusBadge), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh reloads the current account order history', (
    tester,
  ) async {
    final service = FakePaymentService();
    await tester.pumpWidget(testApp(OrdersScreen(paymentService: service)));
    await tester.pumpAndSettle();
    expect(service.orderRequests, 1);
    await tester.tap(find.byTooltip('Refresh orders'));
    await tester.pumpAndSettle();
    expect(service.orderRequests, 2);
  });
}
