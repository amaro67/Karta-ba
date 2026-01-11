// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'price_tier_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PriceTierDto _$PriceTierDtoFromJson(Map<String, dynamic> json) => PriceTierDto(
  id: json['id'] as String,
  name: json['name'] as String,
  price: (json['price'] as num).toDouble(),
  currency: json['currency'] as String,
  capacity: (json['capacity'] as num).toInt(),
  sold: (json['sold'] as num).toInt(),
);

Map<String, dynamic> _$PriceTierDtoToJson(PriceTierDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'price': instance.price,
      'currency': instance.currency,
      'capacity': instance.capacity,
      'sold': instance.sold,
    };
