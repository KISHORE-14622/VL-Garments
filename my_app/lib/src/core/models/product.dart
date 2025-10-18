class ProductCategory {
  final String id;
  final String name;

  const ProductCategory({required this.id, required this.name});
}

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final ProductCategory category;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
  });
}


