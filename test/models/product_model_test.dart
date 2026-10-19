import 'package:flutter_test/flutter_test.dart';
import 'package:student_shop/models/product_model.dart';

void main() {
  test('parses catalog product with numeric database price', () {
    final product = Product.fromMap({
      'id': 1,
      'name': 'Mechanical Gaming Keyboard',
      'price': 1500,
      'image_url': null,
    });
    expect(product.id, 1);
    expect(product.name, 'Mechanical Gaming Keyboard');
    expect(product.price, 1500);
    expect(product.imageUrl, '');
  });
}
