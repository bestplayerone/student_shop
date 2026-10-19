class ShopOrder {
  const ShopOrder({
    required this.externalId,
    required this.productName,
    required this.amount,
    required this.status,
    required this.createdAt,
  });
  final String externalId;
  final String productName;
  final num amount;
  final String status;
  final DateTime createdAt;
  bool get isPaid => status == 'PAID';
  factory ShopOrder.fromMap(Map<String, dynamic> map) {
    final status = map['status'];
    if (!{'PENDING', 'PAID', 'EXPIRED', 'FAILED'}.contains(status)) {
      throw const FormatException('Unrecognized order status.');
    }
    return ShopOrder(
      externalId: map['external_id'] as String,
      productName: map['product_name'] as String,
      amount: map['amount'] as num,
      status: status as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
