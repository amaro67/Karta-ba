// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ticket_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TicketDto _$TicketDtoFromJson(Map<String, dynamic> json) => TicketDto(
  id: json['id'] as String,
  ticketCode: json['ticketCode'] as String,
  status: json['status'] as String,
  issuedAt: DateTime.parse(json['issuedAt'] as String),
  usedAt: json['usedAt'] == null
      ? null
      : DateTime.parse(json['usedAt'] as String),
);

Map<String, dynamic> _$TicketDtoToJson(TicketDto instance) => <String, dynamic>{
  'id': instance.id,
  'ticketCode': instance.ticketCode,
  'status': instance.status,
  'issuedAt': instance.issuedAt.toIso8601String(),
  'usedAt': instance.usedAt?.toIso8601String(),
};
