import 'package:flutter/foundation.dart';
import '../utils/api_client.dart';
import '../providers/auth_provider.dart';
class AdminProvider extends ChangeNotifier {
  AuthProvider _authProvider;
  AdminProvider(this._authProvider);
  void updateAuthProvider(AuthProvider authProvider) {
    final previousUserId = _authProvider.currentUser?.id;
    final newUserId = authProvider.currentUser?.id;
    _authProvider = authProvider;
    if (previousUserId != newUserId) {
      clear();
    }
  }
  Map<String, dynamic>? _dashboardStats;
  bool _isLoadingStats = false;
  String? _statsError;
  List<dynamic> _upcomingEvents = [];
  bool _isLoadingEvents = false;
  String? _eventsError;
  List<dynamic> _users = [];
  bool _isLoadingUsers = false;
  String? _usersError;
  Map<String, dynamic>? get dashboardStats => _dashboardStats;
  bool get isLoadingStats => _isLoadingStats;
  String? get statsError => _statsError;
  List<dynamic> get upcomingEvents => _upcomingEvents;
  bool get isLoadingEvents => _isLoadingEvents;
  String? get eventsError => _eventsError;
  List<dynamic> get users => _users;
  bool get isLoadingUsers => _isLoadingUsers;
  String? get usersError => _usersError;
  List<dynamic> _userOrders = [];
  bool _isLoadingUserOrders = false;
  String? _userOrdersError;
  List<dynamic> get userOrders => _userOrders;
  bool get isLoadingUserOrders => _isLoadingUserOrders;
  String? get userOrdersError => _userOrdersError;
  Future<void> loadDashboardStats() async {
    final token = _authProvider.accessToken;
    if (token == null) {
      _statsError = 'Not authenticated';
      notifyListeners();
      return;
    }
    _isLoadingStats = true;
    _statsError = null;
    notifyListeners();
    try {
      _dashboardStats = await ApiClient.getDashboardStats(token);
      print('🔵 Dashboard stats loaded: $_dashboardStats');
      _statsError = null;
    } catch (e) {
      print('🔴 Error loading dashboard stats: $e');
      _statsError = e.toString();
      _dashboardStats = null;
    } finally {
      _isLoadingStats = false;
      notifyListeners();
    }
  }
  Future<void> loadUpcomingEvents({int limit = 5}) async {
    final token = _authProvider.accessToken;
    if (token == null) {
      _eventsError = 'Not authenticated';
      notifyListeners();
      return;
    }
    _isLoadingEvents = true;
    _eventsError = null;
    notifyListeners();
    try {
      _upcomingEvents = await ApiClient.getUpcomingEvents(token, limit: limit);
      print('🔵 Upcoming events loaded: ${_upcomingEvents.length} events');
      if (_upcomingEvents.isNotEmpty) {
        print('🔵 First event sample: ${_upcomingEvents.first}');
      }
      _eventsError = null;
    } catch (e) {
      print('🔴 Error loading upcoming events: $e');
      _eventsError = e.toString();
      _upcomingEvents = [];
    } finally {
      _isLoadingEvents = false;
      notifyListeners();
    }
  }
  Future<void>? _loadUsersFuture;
  Future<void> loadUsers() async {
    final token = _authProvider.accessToken;
    if (token == null) {
      print('⚠️ AdminProvider: No access token available');
      _usersError = 'Not authenticated';
      notifyListeners();
      return;
    }
    if (_loadUsersFuture != null) {
      print('🔵 AdminProvider: loadUsers() already in progress, waiting for completion...');
      await _loadUsersFuture;
      return;
    }
    print('🔵 AdminProvider: Loading users...');
    _loadUsersFuture = _performLoadUsers(token);
    try {
      await _loadUsersFuture;
    } finally {
      _loadUsersFuture = null;
    }
  }
  Future<void> _performLoadUsers(String token) async {
    _isLoadingUsers = true;
    _usersError = null;
    notifyListeners();
    try {
      final newUsers = await ApiClient.getAllUsers(token);
      _users = newUsers;
      print('✅ AdminProvider: Loaded ${_users.length} users');
      _usersError = null;
    } catch (e) {
      print('🔴 AdminProvider: Error loading users: $e');
      _usersError = e.toString();
      if (_users.isEmpty) {
        _users = [];
      }
    } finally {
      _isLoadingUsers = false;
      notifyListeners();
    }
  }
  Future<void> refreshDashboard() async {
    await Future.wait([
      loadDashboardStats(),
      loadUpcomingEvents(),
    ]);
  }
  String? _createUserError;
  String? get createUserError => _createUserError;
  Future<bool> createUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? roleName,
  }) async {
    final token = _authProvider.accessToken;
    _createUserError = null;
    if (token == null) {
      _createUserError = 'Not authenticated';
      return false;
    }
    try {
      final userData = {
        'email': email,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
        if (roleName != null && roleName.isNotEmpty) 'roleName': roleName,
      };
      await ApiClient.createUser(token, userData);
      await loadUsers();
      _createUserError = null;
      return true;
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('Exception:')) {
        errorMessage = errorMessage.split('Exception:').last.trim();
      }
      _createUserError = errorMessage;
      return false;
    }
  }
  Future<bool> updateUser({
    required String userId,
    String? firstName,
    String? lastName,
    String? email,
    bool? emailConfirmed,
  }) async {
    final token = _authProvider.accessToken;
    if (token == null) {
      _usersError = 'Not authenticated';
      notifyListeners();
      return false;
    }
    try {
      final userData = <String, dynamic>{};
      if (firstName != null && firstName.isNotEmpty) {
        userData['firstName'] = firstName;
      }
      if (lastName != null && lastName.isNotEmpty) {
        userData['lastName'] = lastName;
      }
      if (email != null && email.isNotEmpty) {
        userData['email'] = email;
      }
      if (emailConfirmed != null) {
        userData['emailConfirmed'] = emailConfirmed;
      }
      await ApiClient.updateUser(token, userId, userData);
      _usersError = null;
      return true;
    } catch (e) {
      _usersError = e.toString();
      notifyListeners();
      return false;
    }
  }
  Future<bool> setOrganizerVerification(String userId, bool isVerified) async {
    final token = _authProvider.accessToken;
    if (token == null) {
      _usersError = 'Not authenticated';
      notifyListeners();
      return false;
    }
    try {
      await ApiClient.setOrganizerVerification(token, userId, isVerified);
      _usersError = null;
      await loadUsers();
      await loadUnverifiedOrganizers();
      if (_authProvider.currentUser?.id == userId) {
        await _authProvider.refreshCurrentUser();
      }
      return true;
    } catch (e) {
      _usersError = e.toString();
      notifyListeners();
      return false;
    }
  }
  Future<bool> deleteUser(String userId) async {
    print('🔵 PROVIDER: deleteUser() called for userId: $userId');
    final token = _authProvider.accessToken;
    if (token == null) {
      print('❌ PROVIDER: No token available');
      _usersError = 'Not authenticated';
      notifyListeners();
      return false;
    }
    try {
      print('🔵 PROVIDER: Calling API to delete user...');
      await ApiClient.deleteUser(token, userId);
      print('✅ PROVIDER: User deleted from API successfully');
      print('🔵 PROVIDER: Calling loadUsers()...');
      await loadUsers();
      print('✅ PROVIDER: loadUsers() completed');
      return true;
    } catch (e) {
      print('❌ PROVIDER: Error deleting user: $e');
      _usersError = e.toString();
      notifyListeners();
      return false;
    }
  }
  Future<bool> addUserToRole(String userId, String roleName) async {
    final token = _authProvider.accessToken;
    if (token == null) {
      _usersError = 'Not authenticated';
      notifyListeners();
      return false;
    }
    try {
      await ApiClient.addUserToRole(token, userId, roleName);
      await loadUsers();
      return true;
    } catch (e) {
      _usersError = e.toString();
      notifyListeners();
      return false;
    }
  }
  Future<bool> removeUserFromRole(String userId, String roleName) async {
    final token = _authProvider.accessToken;
    if (token == null) {
      _usersError = 'Not authenticated';
      notifyListeners();
      return false;
    }
    try {
      await ApiClient.removeUserFromRole(token, userId, roleName);
      await loadUsers();
      return true;
    } catch (e) {
      _usersError = e.toString();
      notifyListeners();
      return false;
    }
  }
  Future<void> loadUserOrders(String userId) async {
    final token = _authProvider.accessToken;
    if (token == null) {
      _userOrdersError = 'Not authenticated';
      notifyListeners();
      return;
    }
    _isLoadingUserOrders = true;
    _userOrdersError = null;
    notifyListeners();
    try {
      _userOrders = await ApiClient.getUserOrders(token, userId);
      _userOrdersError = null;
    } catch (e) {
      _userOrdersError = e.toString();
      _userOrders = [];
    } finally {
      _isLoadingUserOrders = false;
      notifyListeners();
    }
  }
  List<dynamic> _unverifiedOrganizers = [];
  bool _isLoadingUnverifiedOrganizers = false;
  String? _unverifiedOrganizersError;
  List<dynamic> get unverifiedOrganizers => _unverifiedOrganizers;
  bool get isLoadingUnverifiedOrganizers => _isLoadingUnverifiedOrganizers;
  String? get unverifiedOrganizersError => _unverifiedOrganizersError;
  int get unverifiedOrganizersCount => _unverifiedOrganizers.length;
  Future<void> loadUnverifiedOrganizers() async {
    final token = _authProvider.accessToken;
    if (token == null) {
      _unverifiedOrganizersError = 'Not authenticated';
      notifyListeners();
      return;
    }
    _isLoadingUnverifiedOrganizers = true;
    _unverifiedOrganizersError = null;
    notifyListeners();
    try {
      _unverifiedOrganizers = await ApiClient.getUnverifiedOrganizers(token);
      _unverifiedOrganizersError = null;
    } catch (e) {
      _unverifiedOrganizersError = e.toString();
      _unverifiedOrganizers = [];
    } finally {
      _isLoadingUnverifiedOrganizers = false;
      notifyListeners();
    }
  }
  void clear() {
    _loadUsersFuture = null;
    _dashboardStats = null;
    _upcomingEvents = [];
    _users = [];
    _statsError = null;
    _eventsError = null;
    _usersError = null;
    _createUserError = null;
    _userOrders = [];
    _userOrdersError = null;
    _unverifiedOrganizers = [];
    _unverifiedOrganizersError = null;
    notifyListeners();
  }
}