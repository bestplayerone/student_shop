class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
  });

  final int id;
  final String name;
  final num price;
  final String imageUrl;

  factory Product.fromMap(Map<String, dynamic> map) => Product(
    id: (map['id'] as num).toInt(),
    name: map['name'] as String,
    price: map['price'] as num,
    imageUrl: map['image_url'] as String? ?? '',
  );
}
