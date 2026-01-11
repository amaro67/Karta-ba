// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paged_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PagedResult<T> _$PagedResultFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) => PagedResult<T>(
  items: (json['items'] as List<dynamic>).map(fromJsonT).toList(),
  page: (json['page'] as num).toInt(),
  size: (json['size'] as num).toInt(),
  total: (json['total'] as num).toInt(),
);

Map<String, dynamic> _$PagedResultToJson<T>(
  PagedResult<T> instance,
  Object? Function(T value) toJsonT,
) => <String, dynamic>{
  'items': instance.items.map(toJsonT).toList(),
  'page': instance.page,
  'size': instance.size,
  'total': instance.total,
};
