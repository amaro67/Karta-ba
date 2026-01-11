import 'package:flutter/foundation.dart';
import '../providers/auth_provider.dart';
import '../utils/api_client.dart';
class OrganizerSale {
  final String orderId;
  final String buyerEmail;
  final DateTime createdAt;
  final double totalAmount;
  final String currency;
  final String status;
  final String eventTitle;
  final String eventId;
  final int ticketsCount;
  OrganizerSale({
    required this.orderId,
    required this.buyerEmail,
    required this.createdAt,
    required this.totalAmount,
    required this.currency,
    required this.status,
    required this.eventTitle,
    required this.eventId,
    required this.ticketsCount,
  });
  factory OrganizerSale.fromJson(Map<String, dynamic> json) {
    final createdAtStr = json['createdAt'] as String? ?? json['CreatedAt'] as String? ?? '';
    return OrganizerSale(
      orderId: (json['orderId'] ?? json['OrderId']).toString(),
      buyerEmail: json['buyerEmail'] as String? ?? json['BuyerEmail'] as String? ?? '',
      createdAt: DateTime.tryParse(createdAtStr) ?? DateTime.now(),
      totalAmount: (json['totalAmount'] as num? ?? json['TotalAmount'] as num? ?? 0).toDouble(),
      currency: json['currency'] as String? ?? json['Currency'] as String? ?? 'BAM',
      status: json['status'] as String? ?? json['Status'] as String? ?? 'Unknown',
      eventTitle: json['eventTitle'] as String? ?? json['EventTitle'] as String? ?? '',
      eventId: (json['eventId'] ?? json['EventId']).toString(),
      ticketsCount: json['ticketsCount'] as int? ?? json['TicketsCount'] as int? ?? 0,
    );
  }
}
class OrganizerSalesProvider extends ChangeNotifier {
  AuthProvider _authProvider;
  OrganizerSalesProvider(this._authProvider);
  void updateAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
  }
  List<OrganizerSale> _sales = [];
  bool _isLoading = false;
  String? _error;
  List<OrganizerSale> get sales => _sales;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Future<void> loadSales() async {
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
      final response = await ApiClient.getOrganizerSales(token);
      _sales = response
          .map((sale) => OrganizerSale.fromJson(Map<String, dynamic>.from(sale as Map)))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  double get totalRevenue => _sales.fold(0.0, (sum, sale) => sum + sale.totalAmount);
  int get totalTicketsSold => _sales.fold(0, (sum, sale) => sum + sale.ticketsCount);
  void clear() {
    _sales = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}