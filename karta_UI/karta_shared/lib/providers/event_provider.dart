import 'package:flutter/foundation.dart';
import '../models/event/event_dto.dart';
import '../models/event/paged_result.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
class EventProvider extends ChangeNotifier {
  final AuthProvider _authProvider;
  EventProvider(this._authProvider);
  PagedResult<EventDto>? _events;
  bool _isLoading = false;
  String? _error;
  EventDto? _currentEvent;
  bool _isLoadingEvent = false;
  String? _eventError;
  String? _searchQuery;
  String? _category;
  String? _city;
  String? _status;
  DateTime? _fromDate;
  DateTime? _toDate;
  int _currentPage = 1;
  final int _pageSize = 20;
  PagedResult<EventDto>? get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;
  EventDto? get currentEvent => _currentEvent;
  bool get isLoadingEvent => _isLoadingEvent;
  String? get eventError => _eventError;
  String? get searchQuery => _searchQuery;
  String? get category => _category;
  String? get city => _city;
  String? get status => _status;
  DateTime? get fromDate => _fromDate;
  DateTime? get toDate => _toDate;
  int get currentPage => _currentPage;
  int get pageSize => _pageSize;
  Future<void> loadEvents({
    String? query,
    String? category,
    String? city,
    String? status,
    DateTime? from,
    DateTime? to,
    int page = 1,
    bool append = false,
    bool useAdminEndpoint = false,
    bool usePublicEndpoint = false,
  }) async {
    if (!usePublicEndpoint) {
      final token = _authProvider.accessToken;
      if (token == null) {
        _error = 'Not authenticated';
        notifyListeners();
        return;
      }
    }
    _isLoading = true;
    _error = null;
    if (!append) {
      _currentPage = page;
    }
    _searchQuery = query;
    _category = category;
    _city = city;
    _status = status;
    _fromDate = from;
    _toDate = to;
    notifyListeners();
    try {
      final response = usePublicEndpoint
          ? await ApiClient.getPublicEvents(
              query: query,
              category: category,
              city: city,
              page: page,
              size: _pageSize,
            )
          : useAdminEndpoint
              ? await ApiClient.getAllEventsAdmin(
                  _authProvider.accessToken!,
                  query: query,
                  category: category,
                  city: city,
                  status: status,
                  page: page,
                  size: _pageSize,
                )
              : await ApiClient.getAllEvents(
                  _authProvider.accessToken!,
                  query: query,
                  category: category,
                  city: city,
                  page: page,
                  size: _pageSize,
                );
      final pagedResult = PagedResult<EventDto>.fromJson(
        response,
        (json) => EventDto.fromJson(json as Map<String, dynamic>),
      );
      if (append && _events != null) {
        _events = PagedResult<EventDto>(
          items: [..._events!.items, ...pagedResult.items],
          page: pagedResult.page,
          size: pagedResult.size,
          total: pagedResult.total,
        );
      } else {
        _events = pagedResult;
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
      if (!append) {
        _events = null;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  Future<void> loadEvent(String eventId) async {
    final token = _authProvider.accessToken;
    if (token == null) {
      _eventError = 'Not authenticated';
      notifyListeners();
      return;
    }
    _isLoadingEvent = true;
    _eventError = null;
    _currentEvent = null;
    notifyListeners();
    try {
      print('🔵 Loading event: $eventId');
      final response = await ApiClient.getEvent(token, eventId);
      print('🔵 Event response received: ${response.keys}');
      print('🔵 Event response data: $response');
      if (response.isEmpty) {
        throw Exception('Empty response from server');
      }
      _currentEvent = EventDto.fromJson(response);
      _eventError = null;
      print('🔵 Event loaded successfully: ${_currentEvent?.title}');
    } catch (e, stackTrace) {
      print('🔴 Error loading event: $e');
      print('🔴 Stack trace: $stackTrace');
      _eventError = e.toString();
      _currentEvent = null;
    } finally {
      _isLoadingEvent = false;
      notifyListeners();
    }
  }
  Future<bool> createEvent(Map<String, dynamic> eventData) async {
    final token = _authProvider.accessToken;
    if (token == null) {
      _error = 'Not authenticated';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await ApiClient.createEvent(token, eventData);
      await loadEvents(useAdminEndpoint: true);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  Future<bool> updateEvent(String eventId, Map<String, dynamic> eventData) async {
    final token = _authProvider.accessToken;
    if (token == null) {
      _error = 'Not authenticated';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await ApiClient.updateEvent(token, eventId, eventData);
      await Future.wait([
        loadEvent(eventId),
        loadEvents(useAdminEndpoint: true),
      ]);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  Future<bool> deleteEvent(String eventId) async {
    final token = _authProvider.accessToken;
    if (token == null) {
      _error = 'Not authenticated';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await ApiClient.deleteEvent(token, eventId);
      await loadEvents(useAdminEndpoint: true);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  void clearCurrentEvent() {
    _currentEvent = null;
    _eventError = null;
    notifyListeners();
  }
  Future<void> refreshEvents({bool useAdminEndpoint = false}) async {
    await loadEvents(
      query: _searchQuery,
      category: _category,
      city: _city,
      status: _status,
      from: _fromDate,
      to: _toDate,
      page: _currentPage,
      useAdminEndpoint: useAdminEndpoint,
    );
  }
  Future<void> loadNextPage({bool useAdminEndpoint = false}) async {
    if (_events != null && _events!.hasNextPage && !_isLoading) {
      await loadEvents(
        query: _searchQuery,
        category: _category,
        city: _city,
        status: _status,
        from: _fromDate,
        to: _toDate,
        page: _currentPage + 1,
        append: true,
        useAdminEndpoint: useAdminEndpoint,
      );
    }
  }
  void clearFilters() {
    _searchQuery = null;
    _category = null;
    _city = null;
    _status = null;
    _fromDate = null;
    _toDate = null;
    _currentPage = 1;
    notifyListeners();
  }
}