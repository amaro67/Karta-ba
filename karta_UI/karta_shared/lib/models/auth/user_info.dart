import 'package:json_annotation/json_annotation.dart';
part 'user_info.g.dart';
@JsonSerializable()
class UserInfo {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final bool emailConfirmed;
  final bool isOrganizerVerified;
  final List<String> roles;
  const UserInfo({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.emailConfirmed,
    required this.isOrganizerVerified,
    required this.roles,
  });
  factory UserInfo.fromJson(Map<String, dynamic> json) =>
      _$UserInfoFromJson(json);
  Map<String, dynamic> toJson() => _$UserInfoToJson(this);
  String get fullName => '$firstName $lastName';
  bool get isAdmin => roles.contains('Admin');
  bool get isOrganizer => roles.contains('Organizer');
  bool get isScanner => roles.contains('Scanner');
  bool get isUser => roles.contains('User');
  bool get canPublishEvents => isAdmin || (isOrganizer && isOrganizerVerified);
}