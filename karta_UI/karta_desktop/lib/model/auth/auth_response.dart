import 'package:json_annotation/json_annotation.dart';
import 'user_info.dart';
part 'auth_response.g.dart';
@JsonSerializable()
class AuthResponse {
  final String accessToken;
  final String refreshToken;
  @JsonKey(name: 'expiresAt')
  final DateTime expiresAt;
  final UserInfo user;
  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
  });
  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);
  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);
}