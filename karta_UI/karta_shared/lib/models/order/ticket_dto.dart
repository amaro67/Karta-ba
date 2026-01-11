import 'package:json_annotation/json_annotation.dart';
part 'ticket_dto.g.dart';
@JsonSerializable()
class TicketDto {
  final String id;
  @JsonKey(name: 'ticketCode')
  final String ticketCode;
  final String status;
  @JsonKey(name: 'issuedAt')
  final DateTime issuedAt;
  @JsonKey(name: 'usedAt')
  final DateTime? usedAt;
  const TicketDto({
    required this.id,
    required this.ticketCode,
    required this.status,
    required this.issuedAt,
    this.usedAt,
  });
  factory TicketDto.fromJson(Map<String, dynamic> json) {
    try {
      return _$TicketDtoFromJson(json);
    } catch (e) {
      return TicketDto(
        id: json['id']?.toString() ?? '',
        ticketCode: json['ticketCode']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        issuedAt: json['issuedAt'] != null
            ? DateTime.parse(json['issuedAt'].toString())
            : DateTime.now(),
        usedAt: json['usedAt'] != null
            ? DateTime.parse(json['usedAt'].toString())
            : null,
      );
    }
  }
  Map<String, dynamic> toJson() => _$TicketDtoToJson(this);
}