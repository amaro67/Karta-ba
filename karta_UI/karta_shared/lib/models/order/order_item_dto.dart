import 'package:json_annotation/json_annotation.dart';
import 'ticket_dto.dart';
part 'order_item_dto.g.dart';
@JsonSerializable()
class OrderItemDto {
  final String id;
  @JsonKey(name: 'eventId')
  final String eventId;
  @JsonKey(name: 'priceTierId')
  final String priceTierId;
  final int qty;
  @JsonKey(name: 'unitPrice')
  final double unitPrice;
  final List<TicketDto> tickets;
  const OrderItemDto({
    required this.id,
    required this.eventId,
    required this.priceTierId,
    required this.qty,
    required this.unitPrice,
    required this.tickets,
  });
  factory OrderItemDto.fromJson(Map<String, dynamic> json) {
    try {
      return _$OrderItemDtoFromJson(json);
    } catch (e) {
      return OrderItemDto(
        id: json['id']?.toString() ?? '',
        eventId: json['eventId']?.toString() ?? '',
        priceTierId: json['priceTierId']?.toString() ?? '',
        qty: (json['qty'] as num?)?.toInt() ?? 0,
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
        tickets: json['tickets'] != null
            ? (json['tickets'] as List<dynamic>)
                .map((e) => TicketDto.fromJson(e as Map<String, dynamic>))
                .toList()
            : <TicketDto>[],
      );
    }
  }
  Map<String, dynamic> toJson() => _$OrderItemDtoToJson(this);
}