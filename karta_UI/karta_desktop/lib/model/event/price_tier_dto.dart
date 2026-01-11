import 'package:json_annotation/json_annotation.dart';
part 'price_tier_dto.g.dart';
@JsonSerializable()
class PriceTierDto {
  final String id;
  final String name;
  final double price;
  final String currency;
  final int capacity;
  final int sold;
  const PriceTierDto({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    required this.capacity,
    required this.sold,
  });
  factory PriceTierDto.fromJson(Map<String, dynamic> json) {
    try {
      return _$PriceTierDtoFromJson(json);
    } catch (e) {
      return PriceTierDto(
        id: json['id']?.toString() ?? json['Id']?.toString() ?? '',
        name: json['name']?.toString() ?? json['Name']?.toString() ?? '',
        price: (json['price'] as num?)?.toDouble() ?? (json['Price'] as num?)?.toDouble() ?? 0.0,
        currency: json['currency']?.toString() ?? json['Currency']?.toString() ?? 'BAM',
        capacity: (json['capacity'] as num?)?.toInt() ?? (json['Capacity'] as num?)?.toInt() ?? 0,
        sold: (json['sold'] as num?)?.toInt() ?? (json['Sold'] as num?)?.toInt() ?? 0,
      );
    }
  }
  Map<String, dynamic> toJson() => _$PriceTierDtoToJson(this);
  int get available => capacity - sold;
  double get soldPercentage => capacity > 0 ? (sold / capacity) * 100 : 0;
}