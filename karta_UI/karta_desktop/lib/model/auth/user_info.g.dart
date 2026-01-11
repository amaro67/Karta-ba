// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserInfo _$UserInfoFromJson(Map<String, dynamic> json) => UserInfo(
      id: json['id'] as String,
      email: json['email'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      emailConfirmed: json['emailConfirmed'] as bool,
      isOrganizerVerified: json['isOrganizerVerified'] is bool
          ? json['isOrganizerVerified'] as bool
          : (json['isOrganizerVerified']?.toString().toLowerCase() == 'true'),
      roles: (json['roles'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$UserInfoToJson(UserInfo instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'firstName': instance.firstName,
  'lastName': instance.lastName,
  'emailConfirmed': instance.emailConfirmed,
      'isOrganizerVerified': instance.isOrganizerVerified,
  'roles': instance.roles,
};
