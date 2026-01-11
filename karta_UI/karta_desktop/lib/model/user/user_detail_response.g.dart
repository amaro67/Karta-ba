// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_detail_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserDetailResponse _$UserDetailResponseFromJson(Map<String, dynamic> json) =>
    UserDetailResponse(
      id: json['Id'] as String,
      email: json['Email'] as String,
      firstName: json['FirstName'] as String,
      lastName: json['LastName'] as String,
      emailConfirmed: json['EmailConfirmed'] as bool,
      isOrganizerVerified: json['IsOrganizerVerified'] as bool? ?? false,
      createdAt: DateTime.parse(json['CreatedAt'] as String),
      lastLoginAt: json['LastLoginAt'] == null
          ? null
          : DateTime.parse(json['LastLoginAt'] as String),
      roles: (json['Roles'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$UserDetailResponseToJson(UserDetailResponse instance) =>
    <String, dynamic>{
      'Id': instance.id,
      'Email': instance.email,
      'FirstName': instance.firstName,
      'LastName': instance.lastName,
      'EmailConfirmed': instance.emailConfirmed,
      'IsOrganizerVerified': instance.isOrganizerVerified,
      'CreatedAt': instance.createdAt.toIso8601String(),
      'LastLoginAt': instance.lastLoginAt?.toIso8601String(),
      'Roles': instance.roles,
    };
