import 'package:json_annotation/json_annotation.dart';
part 'paged_result.g.dart';
@JsonSerializable(genericArgumentFactories: true)
class PagedResult<T> {
  @JsonKey(name: 'items')
  final List<T> items;
  @JsonKey(name: 'page')
  final int page;
  @JsonKey(name: 'size')
  final int size;
  @JsonKey(name: 'total')
  final int total;
  const PagedResult({
    required this.items,
    required this.page,
    required this.size,
    required this.total,
  });
  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) {
    try {
      return _$PagedResultFromJson(json, fromJsonT);
    } catch (e) {
      final itemsJson = json['items'];
      final items = itemsJson == null
          ? <T>[]
          : (itemsJson as List<dynamic>).map(fromJsonT).toList();
      return PagedResult<T>(
        items: items,
        page: (json['page'] as num?)?.toInt() ?? 1,
        size: (json['size'] as num?)?.toInt() ?? 20,
        total: (json['total'] as num?)?.toInt() ?? 0,
      );
    }
  }
  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) =>
      _$PagedResultToJson(this, toJsonT);
  int get totalPages => (total / size).ceil();
  bool get hasNextPage => page < totalPages;
  bool get hasPreviousPage => page > 1;
}