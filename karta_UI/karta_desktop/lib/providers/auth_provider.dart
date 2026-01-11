import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../model/auth/auth_response.dart';
import '../model/auth/login_request.dart';
import '../model/auth/register_request.dart';
import '../model/auth/refresh_token_request.dart';
import '../model/auth/user_info.dart';
import '../utils/api_client.dart';
class AuthProvider extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  bool get _isWeb => kIsWeb;
  UserInfo? _currentUser;
  String? _accessToken;
  String? _refreshToken;
  bool _isLoading = false;
  String? _error;
  int _userUpdateCounter = 0;
  UserInfo? get currentUser => _currentUser;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null && _accessToken != null;
  int get userUpdateCounter => _userUpdateCounter;
  Future<void> initialize() async {
    if (_currentUser != null && _accessToken != null) {
      print('✅ AuthProvider: Already initialized, skipping...');
      return;
    }
    if (_isLoading) {
      print('⚠️ AuthProvider: Already initializing, skipping...');
      return;
    }
    print('🔵 AuthProvider: Starting initialization from storage... (Platform: ${_isWeb ? "Web" : "Desktop/Mobile"})');
    _setLoading(true);
    try {
      if (_isWeb) {
        final prefs = await SharedPreferences.getInstance();
        _accessToken = prefs.getString(_accessTokenKey);
        _refreshToken = prefs.getString(_refreshTokenKey);
        print('🔵 AuthProvider: Read from SharedPreferences');
      } else {
        _accessToken = await _secureStorage.read(key: _accessTokenKey)
            .timeout(const Duration(seconds: 5), onTimeout: () {
              print('⚠️ AuthProvider: Timeout reading access token from storage');
              return null;
            });
        _refreshToken = await _secureStorage.read(key: _refreshTokenKey)
            .timeout(const Duration(seconds: 5), onTimeout: () {
              print('⚠️ AuthProvider: Timeout reading refresh token from storage');
              return null;
            });
        print('🔵 AuthProvider: Read from FlutterSecureStorage');
      }
      print('🔵 AuthProvider: Token from storage - AccessToken: ${_accessToken != null ? "exists (${_accessToken!.length} chars)" : "null"}, RefreshToken: ${_refreshToken != null ? "exists" : "null"}');
      if (_accessToken != null) {
        final isExpired = JwtDecoder.isExpired(_accessToken!);
        print('🔵 AuthProvider: Token expired: $isExpired');
        if (isExpired) {
          if (_refreshToken != null) {
            print('🔵 AuthProvider: Attempting to refresh token...');
            try {
              await _refreshAccessToken();
              print('✅ AuthProvider: Token refreshed successfully');
            } catch (e) {
              print('🔴 AuthProvider: Failed to refresh token: $e');
              await _clearAuthData();
            }
          } else {
            print('⚠️ AuthProvider: Token expired and no refresh token, clearing auth');
            await _clearAuthData();
          }
        } else {
          try {
            final payload = JwtDecoder.decode(_accessToken!);
            _currentUser = UserInfo.fromJson(payload);
            print('✅ AuthProvider: Successfully decoded user: ${_currentUser?.email}');
          } catch (e) {
            print('🔴 AuthProvider: Error decoding token: $e');
            await _clearAuthData();
          }
        }
      } else {
        print('⚠️ AuthProvider: No access token found in storage');
      }
    } catch (e) {
      print('🔴 AuthProvider: Error initializing auth: $e');
      await _clearAuthData();
    } finally {
      _setLoading(false);
      print('🔵 AuthProvider: Initialization complete. Authenticated: $isAuthenticated');
    }
  }
  String _extractErrorMessage(dynamic error) {
    if (error is Exception) {
      final errorString = error.toString();
      if (errorString.startsWith('Exception: ')) {
        return errorString.substring(11);
      }
      return errorString;
    }
    return error.toString();
  }
  Future<bool> login(String email, String password, {bool rememberMe = false}) async {
    _setLoading(true);
    _clearError();
    try {
      final request = LoginRequest(
        email: email,
        password: password,
        rememberMe: rememberMe,
      );
      final response = await ApiClient.login(request);
      await _saveAuthData(response);
      return true;
    } catch (e) {
      _setError(_extractErrorMessage(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }
  Future<bool> register(String email, String password, String firstName, String lastName) async {
    _setLoading(true);
    _clearError();
    try {
      final request = RegisterRequest(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      await ApiClient.register(request);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
  Future<void> logout() async {
    _setLoading(true);
    await _clearAuthData();
    _setLoading(false);
  }
  Future<bool> forgotPassword(String email) async {
    _setLoading(true);
    _clearError();
    try {
      await ApiClient.forgotPassword(email);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
  Future<bool> resetPassword(String token, String newPassword) async {
    _setLoading(true);
    _clearError();
    try {
      await ApiClient.resetPassword(token, newPassword);
      return true;
    } catch (e) {
      _setError(_extractErrorMessage(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }
  Future<bool> refreshCurrentUser() async {
    print('🔵 AuthProvider.refreshCurrentUser: Refreshing user from server...');
    if (_accessToken == null) {
      print('🔴 AuthProvider.refreshCurrentUser: No access token');
      return false;
    }
    try {
      final userData = await ApiClient.getMyProfile(_accessToken!);
      _currentUser = UserInfo(
        id: userData['id'] as String,
        email: userData['email'] as String,
        firstName: userData['firstName'] as String? ?? '',
        lastName: userData['lastName'] as String? ?? '',
        emailConfirmed: userData['emailConfirmed'] as bool? ?? false,
        isOrganizerVerified: userData['isOrganizerVerified'] as bool? ?? false,
        roles: (userData['roles'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      );
      _userUpdateCounter++;
      print('✅ AuthProvider.refreshCurrentUser: Success - User: ${_currentUser?.firstName} ${_currentUser?.lastName}, Counter: $_userUpdateCounter');
      notifyListeners();
      return true;
    } catch (e) {
      print('🔴 AuthProvider.refreshCurrentUser: Error: $e');
      return false;
    }
  }
  Future<bool> updateProfile(String firstName, String lastName) async {
    print('🔵 AuthProvider.updateProfile: firstName="$firstName", lastName="$lastName"');
    if (_accessToken == null) {
      _setError('Niste prijavljeni');
      print('🔴 AuthProvider.updateProfile: No access token');
      return false;
    }
    _setLoading(true);
    _clearError();
    try {
      print('🔵 AuthProvider.updateProfile: Calling ApiClient...');
      final response = await ApiClient.updateProfile(_accessToken!, firstName, lastName);
      print('🔵 AuthProvider.updateProfile: Got response, saving auth data...');
      await _saveAuthData(response);
      print('✅ AuthProvider.updateProfile: Success - Current user: ${_currentUser?.firstName} ${_currentUser?.lastName}');
      return true;
    } catch (e) {
      print('🔴 AuthProvider.updateProfile: Error: $e');
      _setError(_extractErrorMessage(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }
  Future<bool> refreshAccessToken() async {
    if (_refreshToken == null) return false;
    try {
      final request = RefreshTokenRequest(
        accessToken: _accessToken!,
        refreshToken: _refreshToken!,
      );
      final response = await ApiClient.refreshToken(request);
      await _saveAuthData(response);
      return true;
    } catch (e) {
      await _clearAuthData();
      return false;
    }
  }
  Future<void> _saveAuthData(AuthResponse response) async {
    print('🔵 AuthProvider._saveAuthData: Saving auth data...');
    print('🔵 AuthProvider._saveAuthData: User from response: ${response.user.firstName} ${response.user.lastName}');
    _accessToken = response.accessToken;
    _refreshToken = response.refreshToken;
    _currentUser = response.user;
    print('🔵 AuthProvider._saveAuthData: _currentUser set to: ${_currentUser?.firstName} ${_currentUser?.lastName}');
    print('🔵 AuthProvider: Writing tokens to storage... (Platform: ${_isWeb ? "Web" : "Desktop/Mobile"})');
    if (_isWeb) {
      final prefs = await SharedPreferences.getInstance();
      if (_accessToken != null) {
        await prefs.setString(_accessTokenKey, _accessToken!);
      }
      if (_refreshToken != null) {
        await prefs.setString(_refreshTokenKey, _refreshToken!);
      }
      print('🔵 AuthProvider: Saved to SharedPreferences');
      final savedAccessToken = prefs.getString(_accessTokenKey);
      final savedRefreshToken = prefs.getString(_refreshTokenKey);
      print('✅ AuthProvider: Tokens saved - AccessToken: ${savedAccessToken != null ? "saved (${savedAccessToken.length} chars)" : "NOT SAVED"}, RefreshToken: ${savedRefreshToken != null ? "saved" : "NOT SAVED"}');
    } else {
      try {
        await _secureStorage.write(key: _accessTokenKey, value: _accessToken)
            .timeout(const Duration(seconds: 5));
        await _secureStorage.write(key: _refreshTokenKey, value: _refreshToken)
            .timeout(const Duration(seconds: 5));
        print('🔵 AuthProvider: Saved to FlutterSecureStorage');
        final savedAccessToken = await _secureStorage.read(key: _accessTokenKey)
            .timeout(const Duration(seconds: 5), onTimeout: () => null);
        final savedRefreshToken = await _secureStorage.read(key: _refreshTokenKey)
            .timeout(const Duration(seconds: 5), onTimeout: () => null);
        print('✅ AuthProvider: Tokens saved - AccessToken: ${savedAccessToken != null ? "saved (${savedAccessToken.length} chars)" : "NOT SAVED"}, RefreshToken: ${savedRefreshToken != null ? "saved" : "NOT SAVED"}');
      } catch (e) {
        print('🔴 AuthProvider: Error saving to FlutterSecureStorage: $e');
      }
    }
    print('🔵 AuthProvider._saveAuthData: Calling notifyListeners()...');
    notifyListeners();
    print('✅ AuthProvider._saveAuthData: Complete');
  }
  Future<void> _clearAuthData() async {
    _currentUser = null;
    _accessToken = null;
    _refreshToken = null;
    if (_isWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_accessTokenKey);
      await prefs.remove(_refreshTokenKey);
      print('🔵 AuthProvider: Cleared from SharedPreferences');
    } else {
      try {
        await _secureStorage.delete(key: _accessTokenKey)
            .timeout(const Duration(seconds: 5));
        await _secureStorage.delete(key: _refreshTokenKey)
            .timeout(const Duration(seconds: 5));
        print('🔵 AuthProvider: Cleared from FlutterSecureStorage');
      } catch (e) {
        print('⚠️ AuthProvider: Error clearing FlutterSecureStorage: $e');
      }
    }
    notifyListeners();
  }
  Future<void> _refreshAccessToken() async {
    if (_refreshToken == null) return;
    try {
      final request = RefreshTokenRequest(
        accessToken: _accessToken!,
        refreshToken: _refreshToken!,
      );
      final response = await ApiClient.refreshToken(request)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              print('🔴 AuthProvider: Refresh token timeout');
              throw Exception('Refresh token request timed out');
            },
          );
      await _saveAuthData(response);
    } catch (e) {
      print('🔴 AuthProvider: Error refreshing token: $e');
      await _clearAuthData();
      rethrow;
    }
  }
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }
  void _clearError() {
    _error = null;
    notifyListeners();
  }
  bool hasRole(String role) {
    return _currentUser?.roles.contains(role) ?? false;
  }
  bool get isAdmin => hasRole('Admin');
  bool get isOrganizer => hasRole('Organizer');
  bool get isScanner => hasRole('Scanner');
  bool get isUser => hasRole('User');
  bool get isOrganizerVerified => _currentUser?.isOrganizerVerified ?? false;
  bool get canPublishEvents => isAdmin || (isOrganizer && isOrganizerVerified);
  @override
  void dispose() {
    ApiClient.dispose();
    super.dispose();
  }
}