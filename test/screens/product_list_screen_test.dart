import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_shop/screens/product_list_screen.dart';

import 'screen_test_support.dart';

void main() {
  testWidgets(
    'renders the backend catalog with peso prices and order history',
    (tester) async {
      final service = FakePaymentService();
      await tester.pumpWidget(
        testApp(ProductListScreen(paymentService: service)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Campus Store'), findsOneWidget);
      expect(find.byTooltip('Order History'), findsOneWidget);
      for (final product in sampleProducts) {
        expect(find.text(product.name), findsOneWidget);
        expect(
          find.text('₱${product.price.toStringAsFixed(2)}'),
          findsOneWidget,
        );
      }
      expect(find.text('Buy Now'), findsNWidgets(3));
      expect(find.byIcon(Icons.image_outlined), findsNWidgets(3));
      expect(service.productRequests, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('only shows verified payment after a paid backend response', (
    tester,
  ) async {
    final service = FakePaymentService()..status = 'PAID';
    await tester.pumpWidget(
      testApp(
        ProductListScreen(
          paymentService: service,
          checkoutBuilder: (url) => Scaffold(
            appBar: AppBar(
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(tester.element(find.byType(Scaffold).last))
                          .pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
            body: Text(url),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();
    expect(
      find.text('https://checkout.xendit.co/test-invoice'),
      findsOneWidget,
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(service.checkedExternalId, 'campus-order-123');
    expect(service.statusRequests, 1);
    expect(
      find.text('Payment Verified! Mechanical Gaming Keyboard is PAID.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
