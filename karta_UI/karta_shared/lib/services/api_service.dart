import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/auth/login_request.dart';
import '../models/auth/register_request.dart';
import '../models/auth/auth_response.dart';
import '../models/auth/refresh_token_request.dart';
class ApiClient {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8080';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:8080';
    } else {
      return 'http://localhost:8080';
    }
  }
  static const String apiPrefix = '/api';
  static String? getImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return null;
    }
    if (imageUrl.contains('example.com/images/event')) {
      final match = RegExp(r'event(\d+)\.jpg').firstMatch(imageUrl);
      if (match != null) {
        final eventNum = int.parse(match.group(1)!);
        final newEventNum = ((eventNum - 1) % 2) + 1;
        imageUrl = '/images/event$newEventNum.jpg';
      } else {
        imageUrl = '/images/event1.jpg';
      }
    }
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    if (imageUrl.startsWith('/')) {
      return '$baseUrl$imageUrl';
    }
    return '$baseUrl/$imageUrl';
  }
  static String clientType = 'karta_mobile';
  static final http.Client _client = http.Client();
  static Map<String, String> _getHeaders({String? token, bool includeClientType = false}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (includeClientType) {
      headers['X-Client-Type'] = clientType;
    }
    return headers;
  }
  static String _extractErrorMessage(dynamic errorData) {
    if (errorData is Map) {
      if (errorData.containsKey('error') && errorData['error'] is Map) {
        final error = errorData['error'] as Map;
        if (error.containsKey('message')) {
          return error['message'] as String;
        }
      }
      if (errorData.containsKey('message')) {
        return errorData['message'] as String;
      }
    }
    return 'An error occurred. Please try again.';
  }
  static Future<AuthResponse> login(LoginRequest request) async {
    try {
      print('🔵 API Request: POST $baseUrl$apiPrefix/Auth/login');
      print('🔵 Request body: ${jsonEncode(request.toJson())}');
      final response = await _client.post(
        Uri.parse('$baseUrl$apiPrefix/Auth/login'),
        headers: _getHeaders(),
        body: jsonEncode(request.toJson()),
      );
      print('🔵 Response status: ${response.statusCode}');
      print('🔵 Response body: ${response.body}');
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return AuthResponse.fromJson(jsonData);
      } else {
        String errorMessage = 'Neispravna email adresa ili lozinka';
        try {
          if (response.body.isNotEmpty) {
            final errorData = jsonDecode(response.body);
            errorMessage = _extractErrorMessage(errorData);
          }
        } catch (e) {
          errorMessage = 'Neispravna email adresa ili lozinka';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('🔴 Login error: $e');
      if (e is SocketException || e.toString().contains('Failed host lookup')) {
        throw Exception('Nema konekcije sa serverom. Provjerite vašu internet konekciju.');
      }
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Neispravna email adresa ili lozinka');
    }
  }
  static Future<void> register(RegisterRequest request) async {
    try {
      print('🔵 API Request: POST $baseUrl$apiPrefix/Auth/register');
      print('🔵 Request body: ${jsonEncode(request.toJson())}');
      final response = await _client.post(
        Uri.parse('$baseUrl$apiPrefix/Auth/register'),
        headers: _getHeaders(includeClientType: true),
        body: jsonEncode(request.toJson()),
      );
      print('🔵 Response status: ${response.statusCode}');
      print('🔵 Response body: ${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      } else {
        String errorMessage = 'Registration failed';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map) {
            if (errorData.containsKey('errors')) {
              final errors = errorData['errors'] as Map<String, dynamic>;
              final errorList = errors.values.expand((e) => e as List).toList();
              errorMessage = errorList.isNotEmpty ? errorList.first.toString() : 'Registration failed';
            } else {
              errorMessage = errorData['message'] ?? errorData.toString();
            }
          } else {
            errorMessage = errorData.toString();
          }
        } catch (e) {
          errorMessage = response.body.isNotEmpty ? response.body : 'Registration failed with status ${response.statusCode}';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('🔴 Register error: $e');
      if (e is SocketException || e.toString().contains('Failed host lookup')) {
        throw Exception('Unable to connect to server. Please check your connection.');
      }
      rethrow;
    }
  }
  static Future<AuthResponse> refreshToken(RefreshTokenRequest request) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl$apiPrefix/Auth/refresh-token'),
        headers: _getHeaders(),
        body: jsonEncode(request.toJson()),
      );
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return AuthResponse.fromJson(jsonData);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Token refresh failed');
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('Unable to connect to server. Please check your connection.');
      }
      rethrow;
    }
  }
  static Future<void> forgotPassword(String email) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl$apiPrefix/Auth/forgot-password'),
        headers: _getHeaders(),
        body: jsonEncode({'email': email}),
      );
      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Password reset request failed');
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('Unable to connect to server. Please check your connection.');
      }
      rethrow;
    }
  }
  static Future<void> resetPassword(String token, String newPassword) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl$apiPrefix/Auth/reset-password'),
        headers: _getHeaders(),
        body: jsonEncode({
          'token': token,
          'newPassword': newPassword,
        }),
      );
      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Password reset failed');
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('Unable to connect to server. Please check your connection.');
      }
      rethrow;
    }
  }
  static Future<AuthResponse> updateProfile(String token, String firstName, String lastName) async {
    print('🔵 ApiClient.updateProfile: firstName="$firstName", lastName="$lastName"');
    try {
      final userData = <String, dynamic>{};
      if (firstName.isNotEmpty) {
        userData['firstName'] = firstName;
      }
      if (lastName.isNotEmpty) {
        userData['lastName'] = lastName;
      }
      print('🔵 ApiClient.updateProfile: Request body: ${jsonEncode(userData)}');
      final response = await _client.put(
        Uri.parse('$baseUrl$apiPrefix/Auth/profile'),
        headers: _getHeaders(token: token),
        body: jsonEncode(userData),
      );
      print('🔵 ApiClient.updateProfile: Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        print('🔵 ApiClient.updateProfile: Response user: ${jsonData['user']['firstName']} ${jsonData['user']['lastName']}');
        final authResponse = AuthResponse.fromJson(jsonData);
        print('✅ ApiClient.updateProfile: Success - User: ${authResponse.user.firstName} ${authResponse.user.lastName}');
        return authResponse;
      } else {
        String errorMessage = 'Greška pri ažuriranju profila';
        try {
          if (response.body.isNotEmpty) {
            final errorData = jsonDecode(response.body);
            errorMessage = _extractErrorMessage(errorData);
          }
        } catch (e) {
          errorMessage = 'Greška pri ažuriranju profila';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (e is SocketException || e.toString().contains('Failed host lookup')) {
        throw Exception('Nema konekcije sa serverom. Provjerite vašu internet konekciju.');
      }
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Greška pri ažuriranju profila');
    }
  }
  static Future<Map<String, dynamic>> getMyProfile(String token) async {
    print('🔵 ApiClient.getMyProfile: Fetching profile from server...');
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl$apiPrefix/Auth/profile'),
        headers: _getHeaders(token: token),
      );
      print('🔵 ApiClient.getMyProfile: Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        print('🔵 ApiClient.getMyProfile: Raw response: $jsonData');
        final result = {
          'id': jsonData['Id'] ?? jsonData['id'],
          'email': jsonData['Email'] ?? jsonData['email'],
          'firstName': jsonData['FirstName'] ?? jsonData['firstName'],
          'lastName': jsonData['LastName'] ?? jsonData['lastName'],
          'emailConfirmed': jsonData['EmailConfirmed'] ?? jsonData['emailConfirmed'],
          'isOrganizerVerified': jsonData['IsOrganizerVerified'] ?? jsonData['isOrganizerVerified'] ?? false,
          'roles': jsonData['Roles'] ?? jsonData['roles'],
        };
        print('✅ ApiClient.getMyProfile: Success - User: ${result['firstName']} ${result['lastName']}');
        return result;
      } else {
        String errorMessage = 'Greška pri učitavanju profila';
        try {
          if (response.body.isNotEmpty) {
            final errorData = jsonDecode(response.body);
            errorMessage = _extractErrorMessage(errorData);
          }
        } catch (e) {
          errorMessage = 'Greška pri učitavanju profila';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (e is SocketException || e.toString().contains('Failed host lookup')) {
        throw Exception('Nema konekcije sa serverom. Provjerite vašu internet konekciju.');
      }
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Greška pri učitavanju profila');
    }
  }
  static Future<Map<String, dynamic>> get(String endpoint, {String? token}) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl$apiPrefix$endpoint'),
        headers: _getHeaders(token: token),
      );
      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Empty response from server');
        }
        final decoded = jsonDecode(response.body);
        if (decoded == null) {
          throw Exception('Null response from server');
        }
        if (decoded is Map<String, dynamic>) {
          return decoded;
        } else if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        } else {
          throw Exception('Unexpected response format: expected Map, got ${decoded.runtimeType}');
        }
      } else {
        String errorMessage = 'Request failed with status ${response.statusCode}';
        try {
          if (response.body.isNotEmpty) {
            final errorData = jsonDecode(response.body);
            if (errorData is Map) {
              if (errorData.containsKey('errors')) {
                final errors = errorData['errors'] as Map<String, dynamic>?;
                if (errors != null && errors.isNotEmpty) {
                  final errorMessages = errors.values
                      .expand((e) => e is List ? e : [e])
                      .map((e) => e.toString())
                      .join(', ');
                  errorMessage = errorMessages;
                } else {
                  errorMessage = errorData['title'] ?? errorData['message'] ?? errorMessage;
                }
              } else {
                errorMessage = errorData['message'] ?? errorData['title'] ?? errorData.toString();
              }
            } else {
              errorMessage = errorData.toString();
            }
          }
        } catch (e) {
          errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('Unable to connect to server. Please check your connection.');
      }
      rethrow;
    }
  }
  static Future<List<dynamic>> getList(String endpoint, {String? token}) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl$apiPrefix$endpoint'),
        headers: _getHeaders(token: token),
      );
      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          return [];
        }
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded;
        }
        throw Exception('Unexpected response format: expected List, got ${decoded.runtimeType}');
      } else {
        String errorMessage = 'Request failed with status ${response.statusCode}';
        if (response.body.isNotEmpty) {
          final errorData = jsonDecode(response.body);
          if (errorData is Map && errorData.containsKey('message')) {
            errorMessage = errorData['message'] as String;
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('Unable to connect to server. Please check your connection.');
      }
      rethrow;
    }
  }
  static Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data, {String? token}) async {
    try {
      final url = '$baseUrl$apiPrefix$endpoint';
      print('🔵 POST Request to: $url');
      print('🔵 Request body: ${jsonEncode(data)}');
      final response = await _client.post(
        Uri.parse(url),
        headers: _getHeaders(token: token),
        body: jsonEncode(data),
      );
      print('🔵 Response status: ${response.statusCode}');
      print('🔵 Response body: ${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.body.isEmpty) {
          throw Exception('Empty response from server');
        }
        try {
          final decoded = jsonDecode(response.body);
          if (decoded == null) {
            throw Exception('Null response from server');
          }
          if (decoded is Map<String, dynamic>) {
            return decoded;
          } else if (decoded is Map) {
            return Map<String, dynamic>.from(decoded);
          } else {
            throw Exception('Unexpected response format: expected Map, got ${decoded.runtimeType}');
          }
        } catch (e) {
          if (e is FormatException) {
            throw Exception('Invalid JSON response from server: ${e.message}');
          }
          rethrow;
        }
      } else {
        String errorMessage = 'Request failed with status ${response.statusCode}';
        try {
          if (response.body.isNotEmpty) {
            final errorData = jsonDecode(response.body);
            if (errorData is Map) {
              errorMessage = errorData['message'] ?? errorData['title'] ?? errorData['detail'] ?? errorMessage;
            } else {
              errorMessage = errorData.toString();
            }
          }
        } catch (e) {
          errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('Unable to connect to server. Please check your connection.');
      }
      rethrow;
    }
  }
  static Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> data, {String? token}) async {
    try {
      final response = await _client.put(
        Uri.parse('$baseUrl$apiPrefix$endpoint'),
        headers: _getHeaders(token: token),
        body: jsonEncode(data),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Request failed');
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('Unable to connect to server. Please check your connection.');
      }
      rethrow;
    }
  }
  static Future<void> delete(String endpoint, {String? token}) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl$apiPrefix$endpoint'),
        headers: _getHeaders(token: token),
      );
      if (response.statusCode != 200 && response.statusCode != 204) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Delete failed');
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('Unable to connect to server. Please check your connection.');
      }
      rethrow;
    }
  }
  static Future<void> postVoid(String endpoint, Map<String, dynamic> data, {String? token}) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl$apiPrefix$endpoint'),
        headers: _getHeaders(token: token),
        body: jsonEncode(data),
      );
      if (response.statusCode != 200 && response.statusCode != 201 && response.statusCode != 204) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Request failed');
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('Unable to connect to server. Please check your connection.');
      }
      rethrow;
    }
  }
  static Future<Map<String, dynamic>> getDashboardStats(String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl$apiPrefix/Dashboard/stats'),
        headers: _getHeaders(token: token),
      );
      if (response.statusCode == 200) {
        if (response.body.isEmpty || response.body.trim().isEmpty) {
          return {
            'totalRevenue': 0.0,
            'numberOfEvents': 0,
            'totalUsersRegistered': 0,
            'kartaBaProfit': 0.0,
          };
        }
        try {
          final data = jsonDecode(response.body);
          print('🔵 Dashboard stats response: $data');
          if (data is Map<String, dynamic>) {
            return data;
          }
          return {
            'totalRevenue': 0.0,
            'numberOfEvents': 0,
            'totalUsersRegistered': 0,
            'kartaBaProfit': 0.0,
          };
        } catch (e) {
          print('⚠️ Error parsing dashboard stats JSON: $e');
          return {
            'totalRevenue': 0.0,
            'numberOfEvents': 0,
            'totalUsersRegistered': 0,
            'kartaBaProfit': 0.0,
          };
        }
      } else {
        String errorMessage = 'Failed to load dashboard stats (${response.statusCode})';
        try {
          if (response.body.isNotEmpty) {
            print('🔴 Dashboard stats error response (${response.statusCode}): ${response.body}');
            final errorData = jsonDecode(response.body);
            errorMessage = errorData['message'] ?? errorData['title'] ?? errorMessage;
          }
        } catch (e) {
          print('🔴 Error parsing error response: $e');
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('Unable to connect to server. Please check your connection.');
      }
      if (e is FormatException) {
        throw Exception('Invalid response from server. Please try again.');
      }
      rethrow;
    }
  }
  static Future<List<dynamic>> getUpcomingEvents(String token, {int limit = 5}) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl$apiPrefix/Dashboard/upcoming-events?limit=$limit'),
        headers: _getHeaders(token: token),
      );
      if (response.statusCode == 200) {
        if (response.body.isEmpty || response.body.trim().isEmpty) {
          return [];
        }
        try {
          final data = jsonDecode(response.body);
          if (data is List) {
            return List<dynamic>.from(data);
          }
          return [];
        } catch (e) {
          print('⚠️ Error parsing upcoming events JSON: $e');
          return [];
        }
      } else {
        String errorMessage = 'Failed to load upcoming events (${response.statusCode})';
        try {
          if (response.body.isNotEmpty) {
            final errorData = jsonDecode(response.body);
            errorMessage = errorData['message'] ?? errorMessage;
          }
        } catch (_) {
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('Unable to connect to server. Please check your connection.');
      }
      if (e is FormatException) {
        throw Exception('Invalid response from server. Please try again.');
      }
      rethrow;
    }
  }
  static Future<List<dynamic>> getAllUsers(String token) async {
    try {
      print('🔵 API Request: GET $baseUrl$apiPrefix/CoreRole/users');
      final response = await _client.get(
        Uri.parse('$baseUrl$apiPrefix/CoreRole/users'),
        headers: _getHeaders(token: token),
      );
      print('🔵 Response status: ${response.statusCode}');
      print('🔵 Response body length: ${response.body.length}');
      if (response.statusCode == 200) {
        if (response.body.isEmpty || response.body.trim().isEmpty) {
          print('⚠️ Empty response body');
          return [];
        }
        try {
          final data = jsonDecode(response.body);
          if (data is List) {
            print('✅ Parsed ${data.length} users');
            return List<dynamic>.from(data);
          }
          print('⚠️ Response is not a List, returning empty list');
          return [];
        } catch (e) {
          print('🔴 Error parsing users JSON: $e');
          print('Response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
          return [];
        }
      } else {
        String errorMessage = 'Failed to load users (${response.statusCode})';
        try {
          if (response.body.isNotEmpty) {
            final errorData = jsonDecode(response.body);
            errorMessage = errorData['message'] ?? errorMessage;
          }
        } catch (_) {
        }
        print('🔴 API Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('🔴 getAllUsers error: $e');
      if (e is SocketException) {
        throw Exception('Unable to connect to server. Please check your connection.');
      }
      if (e is FormatException) {
        throw Exception('Invalid response from server. Please try again.');
      }
      rethrow;
    }
  }
  static Future<Map<String, dynamic>> getUser(String token, String userId) async {
    return await get('/User/$userId', token: token);
  }
  static Future<Map<String, dynamic>> createUser(String token, Map<String, dynamic> userData) async {
    return await post('/User', userData, token: token);
  }
  static Future<Map<String, dynamic>> updateUser(String token, String userId, Map<String, dynamic> userData) async {
    return await put('/User/$userId', userData, token: token);
  }
  static Future<Map<String, dynamic>> setOrganizerVerification(String token, String userId, bool isVerified) async {
    return await post('/User/$userId/organizer-verification', {
      'isVerified': isVerified,
    }, token: token);
  }
  static Future<void> deleteUser(String token, String userId) async {
    return await delete('/User/$userId', token: token);
  }
  static Future<List<dynamic>> getUserOrders(String token, String userId) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl$apiPrefix/User/$userId/orders'),
        headers: _getHeaders(token: token),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<dynamic>.from(data);
        }
        return [];
      } else {
        throw Exception('Failed to load user orders');
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('Unable to connect to server. Please check your connection.');
      }
      rethrow;
    }
  }
  static Future<Map<String, dynamic>> assignRole(String token, String userId, String roleName) async {
    return await post('/CoreRole/assign', {
      'userId': userId,
      'roleName': roleName,
    }, token: token);
  }
  static Future<Map<String, dynamic>> addUserToRole(String token, String userId, String roleName) async {
    return await post('/Role/users', {
      'userId': userId,
      'roleName': roleName,
    }, token: token);
  }
  static Future<void> removeUserFromRole(String token, String userId, String roleName) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl$apiPrefix/Role/users'),
        headers: _getHeaders(token: token),
        body: jsonEncode({
          'userId': userId,
          'roleName': roleName,
        }),
      );
      if (response.statusCode != 200 && response.statusCode != 204) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Remove role failed');
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('Unable to connect to server. Please check your connection.');
      }
      rethrow;
    }
  }
  static Future<Map<String, dynamic>> getPublicEvents({
    String? query,
    String? category,
    String? city,
    int page = 1,
    int size = 20,
  }) async {
    final queryParams = <String>[];
    if (query != null && query.isNotEmpty) {
      queryParams.add('query=${Uri.encodeComponent(query)}');
    }
    if (category != null && category.isNotEmpty) {
      queryParams.add('category=${Uri.encodeComponent(category)}');
    }
    if (city != null && city.isNotEmpty) {
      queryParams.add('city=${Uri.encodeComponent(city)}');
    }
    queryParams.add('page=$page');
    queryParams.add('size=$size');
    final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    return await get('/Event$queryString');
  }
  static Future<Map<String, dynamic>> getAllEvents(String token, {
    String? query,
    String? category,
    String? city,
    int page = 1,
    int size = 20,
  }) async {
    final queryParams = <String>[];
    if (query != null && query.isNotEmpty) queryParams.add('query=$query');
    if (category != null && category.isNotEmpty) queryParams.add('category=$category');
    if (city != null && city.isNotEmpty) queryParams.add('city=$city');
    queryParams.add('page=$page');
    queryParams.add('size=$size');
    final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    return await get('/Event$queryString', token: token);
  }
  static Future<Map<String, dynamic>> getAllEventsAdmin(String token, {
    String? query,
    String? category,
    String? city,
    String? status,
    int page = 1,
    int size = 20,
  }) async {
    final queryParams = <String>[];
    if (query != null && query.isNotEmpty) queryParams.add('query=$query');
    if (category != null && category.isNotEmpty) queryParams.add('category=$category');
    if (city != null && city.isNotEmpty) queryParams.add('city=$city');
    if (status != null && status.isNotEmpty) queryParams.add('status=$status');
    queryParams.add('page=$page');
    queryParams.add('size=$size');
    final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    return await get('/Event/all$queryString', token: token);
  }
  static Future<Map<String, dynamic>> getEvent(String token, String eventId) async {
    return await get('/Event/$eventId', token: token);
  }
  static Future<List<dynamic>> getMyEvents(String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl$apiPrefix/Event/my-events'),
        headers: _getHeaders(token: token),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<dynamic>.from(data);
        }
        throw Exception('Unexpected response format for organizer events');
      } else {
        String errorMessage = 'Failed to load organizer events';
        try {
          if (response.body.isNotEmpty) {
            final errorData = jsonDecode(response.body);
            errorMessage = _extractErrorMessage(errorData);
          }
        } catch (_) {
          errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('Unable to connect to server. Please check your connection.');
      }
      rethrow;
    }
  }
  static Future<Map<String, dynamic>> createEvent(String token, Map<String, dynamic> eventData) async {
    return await post('/Event', eventData, token: token);
  }
  static Future<Map<String, dynamic>> updateEvent(String token, String eventId, Map<String, dynamic> eventData) async {
    return await put('/Event/$eventId', eventData, token: token);
  }
  static Future<void> deleteEvent(String token, String eventId) async {
    return await delete('/Event/$eventId', token: token);
  }
  static Future<List<dynamic>> getScannerEvents(String token) async {
    return await getList('/Scanner/events', token: token);
  }
  static Future<List<dynamic>> getScannerUsers(String token) async {
    return await getList('/Scanner/users', token: token);
  }
  static Future<Map<String, dynamic>> createScanner(String token, Map<String, dynamic> data) async {
    return await post('/Scanner', data, token: token);
  }
  static Future<void> assignScannerToEvent(String token, Map<String, dynamic> data) async {
    return await postVoid('/Scanner/assign', data, token: token);
  }
  static Future<void> removeScannerFromEvent(String token, String eventId, String scannerUserId) async {
    return await delete('/Scanner/assign/$eventId/$scannerUserId', token: token);
  }
  static Future<List<dynamic>> getOrganizerSales(String token) async {
    return await getList('/Order/organizer-sales', token: token);
  }
  static Future<Map<String, dynamic>> getAllOrdersAdmin(String token, {
    String? query,
    String? userId,
    String? status,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int size = 20,
  }) async {
    final queryParams = <String>[];
    if (query != null && query.isNotEmpty) queryParams.add('query=$query');
    if (userId != null && userId.isNotEmpty) queryParams.add('userId=$userId');
    if (status != null && status.isNotEmpty) queryParams.add('status=$status');
    if (from != null) queryParams.add('from=${from.toIso8601String()}');
    if (to != null) queryParams.add('to=${to.toIso8601String()}');
    queryParams.add('page=$page');
    queryParams.add('size=$size');
    final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    return await get('/Order/all$queryString', token: token);
  }
  static Future<Map<String, dynamic>> getOrder(String token, String orderId) async {
    return await get('/Order/$orderId', token: token);
  }
  static Future<Map<String, dynamic>> getOrderAdmin(String token, String orderId) async {
    return await get('/Order/admin/$orderId', token: token);
  }
  static Future<List<dynamic>> getMyOrders(String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl$apiPrefix/Order/my-orders'),
        headers: _getHeaders(token: token),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<dynamic>.from(data);
        }
        return [];
      } else {
        String errorMessage = 'Failed to load orders';
        try {
          if (response.body.isNotEmpty) {
            final errorData = jsonDecode(response.body);
            errorMessage = errorData['message'] ?? errorMessage;
          }
        } catch (_) {
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('Unable to connect to server. Please check your connection.');
      }
      rethrow;
    }
  }
  static Future<Map<String, dynamic>> getAllTicketsAdmin(String token, {
    String? query,
    String? status,
    String? userId,
    String? eventId,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int size = 20,
  }) async {
    final queryParams = <String>[];
    if (query != null && query.isNotEmpty) {
      queryParams.add('query=${Uri.encodeComponent(query)}');
    }
    if (status != null && status.isNotEmpty) {
      queryParams.add('status=${Uri.encodeComponent(status)}');
    }
    if (userId != null && userId.isNotEmpty) {
      queryParams.add('userId=${Uri.encodeComponent(userId)}');
    }
    if (eventId != null && eventId.isNotEmpty) {
      queryParams.add('eventId=${Uri.encodeComponent(eventId)}');
    }
    if (from != null) {
      queryParams.add('from=${Uri.encodeComponent(from.toIso8601String())}');
    }
    if (to != null) {
      queryParams.add('to=${Uri.encodeComponent(to.toIso8601String())}');
    }
    queryParams.add('page=$page');
    queryParams.add('size=$size');
    final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    return await get('/Ticket/all$queryString', token: token);
  }
  static Future<Map<String, dynamic>> getTicketAdmin(String token, String ticketId) async {
    return await get('/Ticket/admin/$ticketId', token: token);
  }
  static Future<Map<String, dynamic>> getTicket(String token, String ticketId) async {
    return await get('/Ticket/$ticketId', token: token);
  }
  static void dispose() {
    _client.close();
  }
}