// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EventDto _$EventDtoFromJson(Map<String, dynamic> json) => EventDto(
  id: json['id'] as String,
  title: json['title'] as String,
  slug: json['slug'] as String,
  description: json['description'] as String?,
  venue: json['venue'] as String,
  city: json['city'] as String,
  country: json['country'] as String,
  startsAt: DateTime.parse(json['startsAt'] as String),
  endsAt: json['endsAt'] == null
      ? null
      : DateTime.parse(json['endsAt'] as String),
  category: json['category'] as String,
  tags: json['tags'] as String?,
  status: json['status'] as String,
  coverImageUrl: json['coverImageUrl'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  priceTiers: (json['priceTiers'] as List<dynamic>)
      .map((e) => PriceTierDto.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$EventDtoToJson(EventDto instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'slug': instance.slug,
  'description': instance.description,
  'venue': instance.venue,
  'city': instance.city,
  'country': instance.country,
  'startsAt': instance.startsAt.toIso8601String(),
  'endsAt': instance.endsAt?.toIso8601String(),
  'category': instance.category,
  'tags': instance.tags,
  'status': instance.status,
  'coverImageUrl': instance.coverImageUrl,
  'createdAt': instance.createdAt.toIso8601String(),
  'priceTiers': instance.priceTiers,
};
