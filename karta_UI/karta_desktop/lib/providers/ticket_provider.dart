import 'package:flutter/foundation.dart';
import '../model/order/ticket_dto.dart';
import '../model/event/paged_result.dart';
import '../utils/api_client.dart';
import '../providers/auth_provider.dart';
class TicketProvider extends ChangeNotifier {
  final AuthProvider _authProvider;
  TicketProvider(this._authProvider);
  PagedResult<TicketDto>? _tickets;
  bool _isLoading = false;
  String? _error;
  TicketDto? _currentTicket;
  bool _isLoadingTicket = false;
  String? _ticketError;
  String? _searchQuery;
  String? _status;
  String? _userId;
  String? _eventId;
  DateTime? _fromDate;
  DateTime? _toDate;
  int _currentPage = 1;
  final int _pageSize = 20;
  PagedResult<TicketDto>? get tickets => _tickets;
  bool get isLoading => _isLoading;
  String? get error => _error;
  TicketDto? get currentTicket => _currentTicket;
  bool get isLoadingTicket => _isLoadingTicket;
  String? get ticketError => _ticketError;
  String? get searchQuery => _searchQuery;
  String? get status => _status;
  String? get userId => _userId;
  String? get eventId => _eventId;
  DateTime? get fromDate => _fromDate;
  DateTime? get toDate => _toDate;
  int get currentPage => _currentPage;
  int get pageSize => _pageSize;
  Future<void> loadTickets({
    String? query,
    String? status,
    String? userId,
    String? eventId,
    DateTime? from,
    DateTime? to,
    int page = 1,
    bool append = false,
  }) async {
    final token = _authProvider.accessToken;
    if (token == null) {
      _error = 'Not authenticated';
      notifyListeners();
      return;
    }
    _isLoading = true;
    _error = null;
    if (!append) {
      _currentPage = page;
    }
    _searchQuery = query;
    _status = status;
    _userId = userId;
    _eventId = eventId;
    _fromDate = from;
    _toDate = to;
    notifyListeners();
    try {
      final response = await ApiClient.getAllTicketsAdmin(
        token,
        query: query,
        status: status,
        userId: userId,
        eventId: eventId,
        from: from,
        to: to,
        page: page,
        size: _pageSize,
      );
      final pagedResult = PagedResult<TicketDto>.fromJson(
        response,
        (json) => TicketDto.fromJson(json as Map<String, dynamic>),
      );
      if (append && _tickets != null) {
        _tickets = PagedResult<TicketDto>(
          items: [..._tickets!.items, ...pagedResult.items],
          page: pagedResult.page,
          size: pagedResult.size,
          total: pagedResult.total,
        );
      } else {
        _tickets = pagedResult;
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
      if (!append) {
        _tickets = null;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  Future<void> loadTicket(String ticketId, {bool useAdminEndpoint = true}) async {
    final token = _authProvider.accessToken;
    if (token == null) {
      _ticketError = 'Not authenticated';
      notifyListeners();
      return;
    }
    _isLoadingTicket = true;
    _ticketError = null;
    notifyListeners();
    try {
      final response = useAdminEndpoint
          ? await ApiClient.getTicketAdmin(token, ticketId)
          : await ApiClient.getTicket(token, ticketId);
      _currentTicket = TicketDto.fromJson(response);
      _ticketError = null;
    } catch (e) {
      _ticketError = e.toString();
      _currentTicket = null;
    } finally {
      _isLoadingTicket = false;
      notifyListeners();
    }
  }
  void clearCurrentTicket() {
    _currentTicket = null;
    _ticketError = null;
    notifyListeners();
  }
  Future<void> refreshTickets() async {
    await loadTickets(
      query: _searchQuery,
      status: _status,
      userId: _userId,
      eventId: _eventId,
      from: _fromDate,
      to: _toDate,
      page: _currentPage,
    );
  }
  Future<void> loadNextPage() async {
    if (_tickets != null && _tickets!.hasNextPage && !_isLoading) {
      await loadTickets(
        query: _searchQuery,
        status: _status,
        userId: _userId,
        eventId: _eventId,
        from: _fromDate,
        to: _toDate,
        page: _currentPage + 1,
        append: true,
      );
    }
  }
  void clearFilters() {
    _searchQuery = null;
    _status = null;
    _userId = null;
    _eventId = null;
    _fromDate = null;
    _toDate = null;
    _currentPage = 1;
    notifyListeners();
  }
}