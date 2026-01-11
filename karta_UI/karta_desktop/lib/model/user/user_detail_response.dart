import 'package:json_annotation/json_annotation.dart';
part 'user_detail_response.g.dart';
@JsonSerializable()
class UserDetailResponse {
  @JsonKey(name: 'Id')
  final String id;
  @JsonKey(name: 'Email')
  final String email;
  @JsonKey(name: 'FirstName')
  final String firstName;
  @JsonKey(name: 'LastName')
  final String lastName;
  @JsonKey(name: 'EmailConfirmed')
  final bool emailConfirmed;
  @JsonKey(name: 'IsOrganizerVerified')
  final bool isOrganizerVerified;
  @JsonKey(name: 'CreatedAt')
  final DateTime createdAt;
  @JsonKey(name: 'LastLoginAt')
  final DateTime? lastLoginAt;
  @JsonKey(name: 'Roles')
  final List<String> roles;
  const UserDetailResponse({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.emailConfirmed,
    required this.isOrganizerVerified,
    required this.createdAt,
    this.lastLoginAt,
    required this.roles,
  });
  factory UserDetailResponse.fromJson(Map<String, dynamic> json) =>
      _$UserDetailResponseFromJson(json);
  Map<String, dynamic> toJson() => _$UserDetailResponseToJson(this);
  String get displayName {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '$firstName $lastName';
    } else if (firstName.isNotEmpty) {
      return firstName;
    } else if (lastName.isNotEmpty) {
      return lastName;
    }
    return email;
  }
}