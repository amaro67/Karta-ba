import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/event/event_dto.dart';

class FavoritesProvider extends ChangeNotifier {
  List<EventDto> _favorites = [];
  Set<String> _favoriteIds = {};
  bool _isLoading = false;
  String? _error;
  String? _token;

  List<EventDto> get favorites => _favorites;
  Set<String> get favoriteIds => _favoriteIds;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setToken(String? token) {
    _token = token;
    if (token == null) {
      _favorites = [];
      _favoriteIds = {};
      notifyListeners();
    }
  }

  bool isFavorite(String eventId) {
    return _favoriteIds.contains(eventId);
  }

  Future<void> loadFavorites() async {
    if (_token == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiClient.getFavorites(_token!);
      _favorites = data.map((item) {
        final eventData = item['event'] as Map<String, dynamic>;
        return EventDto.fromJson(eventData);
      }).toList();
      _favoriteIds = _favorites.map((e) => e.id).toSet();
      _error = null;
    } catch (e) {
      _error = e.toString();
      print('Error loading favorites: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadFavoriteIds() async {
    if (_token == null) return;

    try {
      final ids = await ApiClient.getFavoriteIds(_token!);
      _favoriteIds = ids.toSet();
      notifyListeners();
    } catch (e) {
      print('Error loading favorite IDs: $e');
    }
  }

  Future<bool> toggleFavorite(String eventId, {EventDto? event}) async {
    if (_token == null) return false;

    final wasFavorite = _favoriteIds.contains(eventId);

    // Optimistic update
    if (wasFavorite) {
      _favoriteIds.remove(eventId);
      _favorites.removeWhere((e) => e.id == eventId);
    } else {
      _favoriteIds.add(eventId);
      if (event != null) {
        _favorites.insert(0, event);
      }
    }
    notifyListeners();

    try {
      if (wasFavorite) {
        await ApiClient.removeFavorite(_token!, eventId);
      } else {
        await ApiClient.addFavorite(_token!, eventId);
      }
      return true;
    } catch (e) {
      // Revert optimistic update on error
      if (wasFavorite) {
        _favoriteIds.add(eventId);
        if (event != null) {
          _favorites.insert(0, event);
        }
      } else {
        _favoriteIds.remove(eventId);
        _favorites.removeWhere((e) => e.id == eventId);
      }
      notifyListeners();
      print('Error toggling favorite: $e');
      return false;
    }
  }

  Future<bool> addFavorite(String eventId, {EventDto? event}) async {
    if (_token == null) return false;
    if (_favoriteIds.contains(eventId)) return true;

    // Optimistic update
    _favoriteIds.add(eventId);
    if (event != null) {
      _favorites.insert(0, event);
    }
    notifyListeners();

    try {
      await ApiClient.addFavorite(_token!, eventId);
      return true;
    } catch (e) {
      // Revert on error
      _favoriteIds.remove(eventId);
      _favorites.removeWhere((e) => e.id == eventId);
      notifyListeners();
      print('Error adding favorite: $e');
      return false;
    }
  }

  Future<bool> removeFavorite(String eventId) async {
    if (_token == null) return false;
    if (!_favoriteIds.contains(eventId)) return true;

    // Store for potential revert
    final removedEvent = _favorites.where((e) => e.id == eventId).firstOrNull;
    final index = _favorites.indexWhere((e) => e.id == eventId);

    // Optimistic update
    _favoriteIds.remove(eventId);
    _favorites.removeWhere((e) => e.id == eventId);
    notifyListeners();

    try {
      await ApiClient.removeFavorite(_token!, eventId);
      return true;
    } catch (e) {
      // Revert on error
      _favoriteIds.add(eventId);
      if (removedEvent != null) {
        if (index >= 0 && index < _favorites.length) {
          _favorites.insert(index, removedEvent);
        } else {
          _favorites.insert(0, removedEvent);
        }
      }
      notifyListeners();
      print('Error removing favorite: $e');
      return false;
    }
  }

  void clear() {
    _favorites = [];
    _favoriteIds = {};
    _error = null;
    _token = null;
    notifyListeners();
  }
}
