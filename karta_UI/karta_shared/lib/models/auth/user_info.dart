import 'package:json_annotation/json_annotation.dart';
part 'user_info.g.dart';
@JsonSerializable()
class UserInfo {
  final String id;
  final String email;
  @JsonKey(defaultValue: '')
  final String firstName;
  @JsonKey(defaultValue: '')
  final String lastName;
  @JsonKey(defaultValue: false)
  final bool emailConfirmed;
  @JsonKey(defaultValue: false)
  final bool isOrganizerVerified;
  @JsonKey(defaultValue: <String>[])
  final List<String> roles;
  const UserInfo({
    required this.id,
    required this.email,
    this.firstName = '',
    this.lastName = '',
    this.emailConfirmed = false,
    this.isOrganizerVerified = false,
    this.roles = const [],
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