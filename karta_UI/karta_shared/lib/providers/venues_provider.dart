import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/venue/venue_dto.dart';

class VenuesProvider extends ChangeNotifier {
  List<VenueDto> _venues = [];
  bool _isLoading = false;
  String? _error;
  String? _token;
  DateTime? _lastFetch;

  List<VenueDto> get venues => _venues;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasVenues => _venues.isNotEmpty;

  // Cache duration: 5 minutes
  static const _cacheDuration = Duration(minutes: 5);

  void setToken(String? token) {
    _token = token;
    if (token == null) {
      _venues = [];
      _lastFetch = null;
      notifyListeners();
    }
  }

  bool get _shouldRefetch {
    if (_lastFetch == null) return true;
    return DateTime.now().difference(_lastFetch!) > _cacheDuration;
  }

  Future<void> loadVenues({String? city, bool forceRefresh = false}) async {
    if (!forceRefresh && !_shouldRefetch && _venues.isNotEmpty) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiClient.getVenues(city: city);
      _venues = data.map((item) => VenueDto.fromJson(item)).toList();
      // Sort by name
      _venues.sort((a, b) => a.name.compareTo(b.name));
      _lastFetch = DateTime.now();
      _error = null;
    } catch (e) {
      _error = e.toString();
      print('Error loading venues: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMyVenues() async {
    if (_token == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiClient.getMyVenues(_token!);
      _venues = data.map((item) => VenueDto.fromJson(item)).toList();
      _venues.sort((a, b) => a.name.compareTo(b.name));
      _lastFetch = DateTime.now();
      _error = null;
    } catch (e) {
      _error = e.toString();
      print('Error loading my venues: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  VenueDto? getVenueById(String id) {
    try {
      return _venues.firstWhere((v) => v.id == id);
    } catch (e) {
      return null;
    }
  }

  List<VenueDto> getVenuesByCity(String city) {
    return _venues.where((v) => v.city.toLowerCase() == city.toLowerCase()).toList();
  }

  List<String> get uniqueCities {
    return _venues.map((v) => v.city).toSet().toList()..sort();
  }

  void clear() {
    _venues = [];
    _error = null;
    _token = null;
    _lastFetch = null;
    notifyListeners();
  }
}
