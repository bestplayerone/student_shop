import 'package:flutter_test/flutter_test.dart';
import 'package:student_shop/models/order_model.dart';

void main() {
  test('order history parses paid records and never guesses a paid status', () {
    final map = <String, dynamic>{
      'external_id': 'order_1',
      'product_name': 'Keyboard',
      'amount': 1500.0,
      'status': 'PAID',
      'created_at': '2026-10-19T01:00:00Z',
    };
    final order = ShopOrder.fromMap(map);
    expect(order.productName, 'Keyboard');
    expect(order.amount, 1500);
    expect(order.isPaid, isTrue);
    expect(order.createdAt, DateTime.utc(2026, 10, 19, 1));
    expect(ShopOrder.fromMap({...map, 'status': 'PENDING'}).isPaid, isFalse);
    expect(
      () => ShopOrder.fromMap({...map, 'status': 'unknown'}),
      throwsFormatException,
    );
  });
}
