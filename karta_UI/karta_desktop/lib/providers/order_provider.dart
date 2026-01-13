import 'package:flutter/foundation.dart';
import '../model/order/order_dto.dart';
import '../model/event/paged_result.dart';
import '../model/event/event_dto.dart';
import '../model/user/user_detail_response.dart';
import '../utils/api_client.dart';
import '../providers/auth_provider.dart';
import '../providers/organizer_sales_provider.dart';
import '../model/order/order_item_dto.dart';
import '../model/order/ticket_dto.dart';
class OrderProvider extends ChangeNotifier {
  final AuthProvider _authProvider;
  OrderProvider(this._authProvider);
  PagedResult<OrderDto>? _orders;
  bool _isLoading = false;
  String? _error;
  OrderDto? _currentOrder;
  bool _isLoadingOrder = false;
  String? _orderError;
  UserDetailResponse? _userDetails;
  bool _isLoadingUserDetails = false;
  String? _userDetailsError;
  final Map<String, EventDto> _eventDetails = {};
  final Set<String> _loadingEventIds = {};
  String? _searchQuery;
  String? _userId;
  String? _status;
  DateTime? _fromDate;
  DateTime? _toDate;
  int _currentPage = 1;
  final int _pageSize = 20;
  PagedResult<OrderDto>? get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  OrderDto? get currentOrder => _currentOrder;
  bool get isLoadingOrder => _isLoadingOrder;
  String? get orderError => _orderError;
  UserDetailResponse? get userDetails => _userDetails;
  bool get isLoadingUserDetails => _isLoadingUserDetails;
  String? get userDetailsError => _userDetailsError;
  EventDto? getEventDetails(String eventId) => _eventDetails[eventId];
  bool isLoadingEvent(String eventId) => _loadingEventIds.contains(eventId);
  String? get searchQuery => _searchQuery;
  String? get userId => _userId;
  String? get status => _status;
  DateTime? get fromDate => _fromDate;
  DateTime? get toDate => _toDate;
  int get currentPage => _currentPage;
  int get pageSize => _pageSize;
  Future<void> loadOrders({
    String? query,
    String? userId,
    String? status,
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
    _userId = userId;
    _status = status;
    _fromDate = from;
    _toDate = to;
    notifyListeners();
    try {
      final response = await ApiClient.getAllOrdersAdmin(
        token,
        query: query,
        userId: userId,
        status: status,
        from: from,
        to: to,
        page: page,
        size: _pageSize,
      );
      final pagedResult = PagedResult<OrderDto>.fromJson(
        response,
        (json) => OrderDto.fromJson(json as Map<String, dynamic>),
      );
      if (append && _orders != null) {
        _orders = PagedResult<OrderDto>(
          items: [..._orders!.items, ...pagedResult.items],
          page: pagedResult.page,
          size: pagedResult.size,
          total: pagedResult.total,
        );
      } else {
        _orders = pagedResult;
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
      if (!append) {
        _orders = null;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  Future<void> loadOrder(String orderId, {bool useAdminEndpoint = true}) async {
    final token = _authProvider.accessToken;
    if (token == null) {
      _orderError = 'Not authenticated';
      notifyListeners();
      return;
    }
    _isLoadingOrder = true;
    _orderError = null;
    notifyListeners();
    try {
      final response = useAdminEndpoint
          ? await ApiClient.getOrderAdmin(token, orderId)
          : await ApiClient.getOrder(token, orderId);
      _currentOrder = OrderDto.fromJson(response);
      _orderError = null;
      if (_currentOrder != null && _currentOrder!.userId.isNotEmpty) {
        await loadUserDetails(_currentOrder!.userId);
      }
      if (_currentOrder != null) {
        final eventIds = _currentOrder!.items.map((item) => item.eventId).toSet();
        for (final eventId in eventIds) {
          await loadEventDetails(eventId);
        }
      }
    } catch (e) {
      _orderError = e.toString();
      _currentOrder = null;
    } finally {
      _isLoadingOrder = false;
      notifyListeners();
    }
  }
  Future<void> loadUserDetails(String userId) async {
    final token = _authProvider.accessToken;
    if (token == null) {
      _userDetailsError = 'Not authenticated';
      notifyListeners();
      return;
    }
    _isLoadingUserDetails = true;
    _userDetailsError = null;
    notifyListeners();
    try {
      final response = await ApiClient.getUser(token, userId);
      _userDetails = UserDetailResponse.fromJson(response);
      _userDetailsError = null;
    } catch (e) {
      _userDetailsError = e.toString();
      _userDetails = null;
    } finally {
      _isLoadingUserDetails = false;
      notifyListeners();
    }
  }
  Future<void> loadEventDetails(String eventId) async {
    final token = _authProvider.accessToken;
    if (token == null) return;
    if (_loadingEventIds.contains(eventId) || _eventDetails.containsKey(eventId)) {
      return;
    }
    _loadingEventIds.add(eventId);
    notifyListeners();
    try {
      final response = await ApiClient.getEvent(token, eventId);
      final event = EventDto.fromJson(response);
      _eventDetails[eventId] = event;
    } catch (e) {
      print('Error loading event details: $e');
    } finally {
      _loadingEventIds.remove(eventId);
      notifyListeners();
    }
  }
  void clearCurrentOrder() {
    _currentOrder = null;
    _orderError = null;
    _userDetails = null;
    _userDetailsError = null;
    _eventDetails.clear();
    _loadingEventIds.clear();
    notifyListeners();
  }
  Future<void> refreshOrders() async {
    // Clear all filters and reset to first page to show all orders
    await loadOrders(
      query: null,
      userId: null,
      status: null,
      from: null,
      to: null,
      page: 1,
    );
  }
  Future<void> loadNextPage() async {
    if (_orders != null && _orders!.hasNextPage && !_isLoading) {
      await loadOrders(
        query: _searchQuery,
        userId: _userId,
        status: _status,
        from: _fromDate,
        to: _toDate,
        page: _currentPage + 1,
        append: true,
      );
    }
  }
  void clearFilters() {
    _searchQuery = null;
    _userId = null;
    _status = null;
    _fromDate = null;
    _toDate = null;
    _currentPage = 1;
    notifyListeners();
  }

  // Get orders for a specific event
  Future<List<OrderDto>> getOrdersForEvent(String eventId) async {
    final token = _authProvider.accessToken;
    if (token == null) {
      return [];
    }
    try {
      // Provjeri da li je korisnik Admin ili Organizer
      if (_authProvider.isAdmin) {
        // Admin koristi postojeći endpoint
        final allOrders = <OrderDto>[];
        int page = 1;
        bool hasMore = true;
        
        while (hasMore) {
          final response = await ApiClient.getAllOrdersAdmin(
            token,
            status: null, // Get all statuses
            page: page,
            size: 100, // Load more per page
          );
          final pagedResult = PagedResult<OrderDto>.fromJson(
            response,
            (json) => OrderDto.fromJson(json as Map<String, dynamic>),
          );
          
          // Filter orders that contain items for this event
          final eventOrders = pagedResult.items.where((order) {
            return order.items.any((item) => item.eventId == eventId);
          }).toList();
          
          allOrders.addAll(eventOrders);
          
          hasMore = pagedResult.hasNextPage;
          page++;
          
          // Safety limit to prevent infinite loops
          if (page > 50) break;
        }
        
        return allOrders;
      } else if (_authProvider.isOrganizer) {
        // Organizer koristi organizer-sales endpoint
        final response = await ApiClient.getOrganizerSales(token);
        final sales = response
            .map((sale) => OrganizerSale.fromJson(Map<String, dynamic>.from(sale as Map)))
            .toList();
        
        // Filtriraj po eventId i konvertuj u OrderDto format
        final eventSales = sales.where((sale) => sale.eventId == eventId).toList();
        
        // Konvertuj OrganizerSale u OrderDto
        return eventSales.map((sale) {
          // Kreiraj OrderItemDto za event
          final orderItem = OrderItemDto(
            id: sale.orderId, // Koristimo orderId kao itemId
            eventId: sale.eventId,
            priceTierId: '', // OrganizerSale nema priceTierId
            qty: sale.ticketsCount,
            unitPrice: sale.totalAmount / sale.ticketsCount, // Procijenjena cijena po karti
            tickets: [], // OrganizerSale nema detalje o ticketima
          );
          
          return OrderDto(
            id: sale.orderId,
            userId: '', // OrganizerSale nema userId
            totalAmount: sale.totalAmount,
            currency: sale.currency,
            status: sale.status,
            createdAt: sale.createdAt,
            items: [orderItem],
            userEmail: sale.buyerEmail,
          );
        }).toList();
      } else {
        // Korisnik nije ni Admin ni Organizer
        return [];
      }
    } catch (e) {
      print('Error loading orders for event: $e');
      return [];
    }
  }
}
