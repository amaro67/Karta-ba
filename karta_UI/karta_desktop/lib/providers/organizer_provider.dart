import 'package:flutter/foundation.dart';
import '../model/event/event_dto.dart';
import 'auth_provider.dart';
import '../utils/api_client.dart';
class OrganizerProvider extends ChangeNotifier {
  AuthProvider _authProvider;
  OrganizerProvider(this._authProvider);
  void updateAuthProvider(AuthProvider authProvider) {
    final previousUserId = _authProvider.currentUser?.id;
    final newUserId = authProvider.currentUser?.id;
    _authProvider = authProvider;
    if (previousUserId != newUserId) {
      clear();
    }
  }
  List<EventDto> _myEvents = [];
  bool _isLoadingMyEvents = false;
  String? _myEventsError;
  List<EventDto> get myEvents => _myEvents;
  bool get isLoadingMyEvents => _isLoadingMyEvents;
  String? get myEventsError => _myEventsError;
  int get totalEvents => _myEvents.length;
  int get publishedEvents => _myEvents.where((event) => event.status.toLowerCase() == 'published').length;
  int get draftEvents => _myEvents.where((event) => event.status.toLowerCase() == 'draft').length;
  int get upcomingEventsCount => _myEvents.where((event) => event.startsAt.isAfter(DateTime.now())).length;
  List<EventDto> get upcomingEvents {
    final now = DateTime.now();
    final events = _myEvents.where((event) => event.startsAt.isAfter(now)).toList();
    events.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return events;
  }
  Future<void> loadMyEvents() async {
    final token = _authProvider.accessToken;
    if (token == null) {
      _myEventsError = 'Not authenticated';
      notifyListeners();
      return;
    }
    _isLoadingMyEvents = true;
    _myEventsError = null;
    notifyListeners();
    try {
      final response = await ApiClient.getMyEvents(token);
      _myEvents = response
          .map((event) => EventDto.fromJson(Map<String, dynamic>.from(event as Map)))
          .toList();
      _myEvents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _myEventsError = null;
    } catch (e) {
      _myEvents = [];
      _myEventsError = e.toString();
    } finally {
      _isLoadingMyEvents = false;
      notifyListeners();
    }
  }
  Future<void> refreshMyEvents() async {
    await loadMyEvents();
  }
  void clear() {
    _myEvents = [];
    _myEventsError = null;
    _isLoadingMyEvents = false;
    notifyListeners();
  }
}