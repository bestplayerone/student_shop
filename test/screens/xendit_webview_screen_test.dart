import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_shop/screens/xendit_webview_screen.dart';

void main() {
  testWidgets(
    'rejects unsafe checkout links without claiming payment success',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: XenditWebViewScreen(
            invoiceUrl: 'https://checkout.xendit.co.evil.example/a',
            embedCheckout: false,
          ),
        ),
      );

      expect(find.text('Secure Checkout'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Checkout link is invalid'), findsOneWidget);
      expect(find.textContaining('PAID'), findsNothing);
      expect(find.text('Open checkout'), findsNothing);
    },
  );

  testWidgets(
    'desktop opens a real external checkout with honest instructions',
    (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: XenditWebViewScreen(
            invoiceUrl: 'https://checkout.xendit.co/test-invoice',
            embedCheckout: false,
            externalLauncher: (url) async {
              opened.add(url);
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Continue in your browser'), findsOneWidget);
      expect(
        find.textContaining('does not mark a payment as paid'),
        findsOneWidget,
      );
      expect(opened, isEmpty);
      await tester.tap(find.text('Open checkout'));
      await tester.pumpAndSettle();
      expect(
        opened.single.toString(),
        'https://checkout.xendit.co/test-invoice',
      );
      expect(find.text('Re-open checkout'), findsOneWidget);
      expect(find.textContaining('Payment Verified!'), findsNothing);
    },
  );
}
