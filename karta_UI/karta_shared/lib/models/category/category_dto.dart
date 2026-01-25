class CategoryDto {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? iconUrl;
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;
  final int eventCount;

  CategoryDto({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.iconUrl,
    required this.displayOrder,
    required this.isActive,
    required this.createdAt,
    required this.eventCount,
  });

  factory CategoryDto.fromJson(Map<String, dynamic> json) {
    return CategoryDto(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      iconUrl: json['iconUrl'] as String?,
      displayOrder: json['displayOrder'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      eventCount: json['eventCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'iconUrl': iconUrl,
      'displayOrder': displayOrder,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'eventCount': eventCount,
    };
  }

  @override
  String toString() => 'CategoryDto(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryDto && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
