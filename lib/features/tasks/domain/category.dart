class Category {
  const Category({
    required this.id,
    required this.name,
    this.color,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final String? color;
  final bool isDefault;

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      color: map['color'] as String?,
      isDefault: map['is_default'] as bool? ?? false,
    );
  }
}