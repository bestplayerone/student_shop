import 'package:flutter_test/flutter_test.dart';
import 'package:student_shop/models/invoice_model.dart';

void main() {
  test('accepts only secure Xendit checkout links and an order reference', () {
    final invoice = Invoice.fromMap({
      'invoice_url': 'https://checkout.xendit.co/web/abc',
      'external_id': 'order_123',
    });
    expect(invoice.externalId, 'order_123');
    expect(invoice.invoiceUrl, 'https://checkout.xendit.co/web/abc');
    for (final url in [
      'http://checkout.xendit.co/a',
      'https://evil.example/a',
      'javascript:alert(1)',
      'https://checkout.xendit.co.evil.example/a',
    ]) {
      expect(
        () => Invoice.fromMap({'invoice_url': url, 'external_id': 'order_123'}),
        throwsFormatException,
      );
    }
    expect(
      () => Invoice.fromMap({
        'invoice_url': 'https://checkout.xendit.co/a',
        'external_id': '',
      }),
      throwsFormatException,
    );
  });
}
