// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_item_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderItemDto _$OrderItemDtoFromJson(Map<String, dynamic> json) => OrderItemDto(
  id: json['id'] as String,
  eventId: json['eventId'] as String,
  priceTierId: json['priceTierId'] as String,
  qty: (json['qty'] as num).toInt(),
  unitPrice: (json['unitPrice'] as num).toDouble(),
  tickets: (json['tickets'] as List<dynamic>)
      .map((e) => TicketDto.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$OrderItemDtoToJson(OrderItemDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'eventId': instance.eventId,
      'priceTierId': instance.priceTierId,
      'qty': instance.qty,
      'unitPrice': instance.unitPrice,
      'tickets': instance.tickets,
    };
