import 'package:json_annotation/json_annotation.dart';
import 'order_item_dto.dart';
part 'order_dto.g.dart';
@JsonSerializable()
class OrderDto {
  final String id;
  @JsonKey(name: 'userId')
  final String userId;
  @JsonKey(name: 'totalAmount')
  final double totalAmount;
  final String currency;
  final String status;
  @JsonKey(name: 'createdAt')
  final DateTime createdAt;
  final List<OrderItemDto> items;
  @JsonKey(name: 'userFirstName')
  final String? userFirstName;
  @JsonKey(name: 'userLastName')
  final String? userLastName;
  @JsonKey(name: 'userEmail')
  final String? userEmail;
  const OrderDto({
    required this.id,
    required this.userId,
    required this.totalAmount,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.items,
    this.userFirstName,
    this.userLastName,
    this.userEmail,
  });
  factory OrderDto.fromJson(Map<String, dynamic> json) {
    try {
      return _$OrderDtoFromJson(json);
    } catch (e) {
      return OrderDto(
        id: json['id']?.toString() ?? '',
        userId: json['userId']?.toString() ?? '',
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
        currency: json['currency']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'].toString())
            : DateTime.now(),
        items: json['items'] != null
            ? (json['items'] as List<dynamic>)
                .map((e) => OrderItemDto.fromJson(e as Map<String, dynamic>))
                .toList()
            : <OrderItemDto>[],
        userFirstName: json['userFirstName']?.toString(),
        userLastName: json['userLastName']?.toString(),
        userEmail: json['userEmail']?.toString(),
      );
    }
  }
  Map<String, dynamic> toJson() => _$OrderDtoToJson(this);
  bool get isPending => status.toLowerCase() == 'pending';
  bool get isPaid => status.toLowerCase() == 'paid';
  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isCancelled => status.toLowerCase() == 'cancelled';
  bool get isRefunded => status.toLowerCase() == 'refunded';
  int get totalTickets => items.fold(0, (sum, item) => sum + item.qty);
  String get userDisplayName {
    if (userFirstName != null && userLastName != null) {
      return '$userFirstName $userLastName';
    } else if (userFirstName != null) {
      return userFirstName!;
    } else if (userLastName != null) {
      return userLastName!;
    } else if (userEmail != null) {
      return userEmail!;
    }
    return userId.substring(0, 8);
  }
}