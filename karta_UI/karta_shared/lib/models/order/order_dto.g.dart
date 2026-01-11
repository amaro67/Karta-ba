// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderDto _$OrderDtoFromJson(Map<String, dynamic> json) => OrderDto(
  id: json['id'] as String,
  userId: json['userId'] as String,
  totalAmount: (json['totalAmount'] as num).toDouble(),
  currency: json['currency'] as String,
  status: json['status'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  items: (json['items'] as List<dynamic>)
      .map((e) => OrderItemDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  userFirstName: json['userFirstName'] as String?,
  userLastName: json['userLastName'] as String?,
  userEmail: json['userEmail'] as String?,
);

Map<String, dynamic> _$OrderDtoToJson(OrderDto instance) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'totalAmount': instance.totalAmount,
  'currency': instance.currency,
  'status': instance.status,
  'createdAt': instance.createdAt.toIso8601String(),
  'items': instance.items,
  'userFirstName': instance.userFirstName,
  'userLastName': instance.userLastName,
  'userEmail': instance.userEmail,
};
