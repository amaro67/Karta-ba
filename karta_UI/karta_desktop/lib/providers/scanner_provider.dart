import 'package:flutter/foundation.dart';
import '../providers/auth_provider.dart';
import '../utils/api_client.dart';
class ScannerUserSummary {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  String get fullName => [firstName, lastName].where((e) => e.isNotEmpty).join(' ').trim();
  ScannerUserSummary({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
  });
  factory ScannerUserSummary.fromJson(Map<String, dynamic> json) {
    return ScannerUserSummary(
      id: json['id'] as String? ?? json['Id'] as String? ?? '',
      email: json['email'] as String? ?? json['Email'] as String? ?? '',
      firstName: json['firstName'] as String? ?? json['FirstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? json['LastName'] as String? ?? '',
    );
  }
}
class EventScannerSummary {
  final String eventId;
  final String title;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String city;
  final List<ScannerUserSummary> scanners;
  EventScannerSummary({
    required this.eventId,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.city,
    required this.scanners,
  });
  factory EventScannerSummary.fromJson(Map<String, dynamic> json) {
    final scannersList = (json['scanners'] as List<dynamic>? ?? json['Scanners'] as List<dynamic>? ?? [])
        .map((scanner) => ScannerUserSummary.fromJson(Map<String, dynamic>.from(scanner as Map)))
        .toList();
    final startsAtStr = json['startsAt'] as String? ?? json['StartsAt'] as String? ?? '';
    final endsAtStr = json['endsAt'] as String? ?? json['EndsAt'] as String?;
    return EventScannerSummary(
      eventId: (json['eventId'] ?? json['EventId']).toString(),
      title: json['title'] as String? ?? json['Title'] as String? ?? '',
      startsAt: DateTime.parse(startsAtStr),
      endsAt: endsAtStr != null ? DateTime.parse(endsAtStr) : null,
      city: json['city'] as String? ?? json['City'] as String? ?? '',
      scanners: scannersList,
    );
  }
}
class ScannerProvider extends ChangeNotifier {
  AuthProvider _authProvider;
  ScannerProvider(this._authProvider);
  void updateAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
  }
  List<EventScannerSummary> _eventSummaries = [];
  List<ScannerUserSummary> _scanners = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  List<EventScannerSummary> get eventSummaries => _eventSummaries;
  List<ScannerUserSummary> get scanners => _scanners;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  Future<void> loadOverview() async {
    final token = _authProvider.accessToken;
    if (token == null) {
      _error = 'Not authenticated';
      notifyListeners();
      return;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final eventsResponse = await ApiClient.getScannerEvents(token);
      final scannersResponse = await ApiClient.getScannerUsers(token);
      _eventSummaries = eventsResponse
          .map((event) => EventScannerSummary.fromJson(Map<String, dynamic>.from(event as Map)))
          .toList();
      _scanners = scannersResponse
          .map((scanner) => ScannerUserSummary.fromJson(Map<String, dynamic>.from(scanner as Map)))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  Future<bool> createScanner({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final token = _authProvider.accessToken;
    if (token == null) {
      _error = 'Niste autentifikovani';
      notifyListeners();
      return false;
    }
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final response = await ApiClient.createScanner(token, {
        'Email': email,
        'Password': password,
        'FirstName': firstName,
        'LastName': lastName,
      });
      final scanner = ScannerUserSummary.fromJson(response);
      _scanners = [..._scanners, scanner];
      _error = null;
      // Reload overview to refresh the list
      await loadOverview();
      return true;
    } catch (e) {
      // Extract error message from exception
      String errorMessage = 'Greška pri kreiranju scannera';
      if (e.toString().contains('email')) {
        errorMessage = 'Korisnik sa unesenim emailom već postoji';
      } else if (e.toString().contains('password')) {
        errorMessage = 'Lozinka ne ispunjava zahtjeve';
      } else if (e.toString().isNotEmpty) {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      }
      _error = errorMessage;
      notifyListeners();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
  Future<bool> assignScanner({
    required String eventId,
    required String scannerUserId,
  }) async {
    final token = _authProvider.accessToken;
    if (token == null) {
      _error = 'Not authenticated';
      notifyListeners();
      return false;
    }
    try {
      await ApiClient.assignScannerToEvent(token, {
        'EventId': eventId,
        'ScannerUserId': scannerUserId,
      });
      await loadOverview();
      _error = null;
      return true;
    } catch (e) {
      String errorMessage = 'Greška pri dodjeljivanju scannera';
      if (e.toString().isNotEmpty) {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      }
      _error = errorMessage;
      notifyListeners();
      return false;
    }
  }
  Future<bool> removeScanner({
    required String eventId,
    required String scannerUserId,
  }) async {
    final token = _authProvider.accessToken;
    if (token == null) {
      _error = 'Not authenticated';
      notifyListeners();
      return false;
    }
    try {
      await ApiClient.removeScannerFromEvent(token, eventId, scannerUserId);
      await loadOverview();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
  void clear() {
    _eventSummaries = [];
    _scanners = [];
    _error = null;
    _isLoading = false;
    _isSaving = false;
    notifyListeners();
  }
}