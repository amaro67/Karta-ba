import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:karta_shared/karta_shared.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/reviews_provider.dart';
class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({super.key});
  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}
class _TicketDetailScreenState extends State<TicketDetailScreen> {
  EventDto? _event;
  OrderItemDto? _orderItem;
  TicketDto? _ticket;
  bool _isLoading = true;
  String? _error;
  bool _hasInitialized = false;
  bool _canReview = false;
  ReviewDto? _userReview;
  bool _isLoadingReviewStatus = false;
  @override
  void initState() {
    super.initState();
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitialized && mounted) {
      _hasInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _initializeData();
        }
      });
    }
  }
  void _initializeData() {
    if (!mounted) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args == null) {
      setState(() {
        _error = 'No ticket data provided';
        _isLoading = false;
      });
      return;
    }
    TicketDto? preloadedTicket;
    EventDto? preloadedEvent;
    OrderItemDto? preloadedOrderItem;
    if (args is Map<String, dynamic>) {
      preloadedTicket = args['ticket'] as TicketDto?;
      preloadedEvent = args['event'] as EventDto?;
      preloadedOrderItem = args['orderItem'] as OrderItemDto?;
    } else if (args is TicketDto) {
      preloadedTicket = args;
    }
    if (preloadedTicket != null && preloadedEvent != null && preloadedOrderItem != null) {
      setState(() {
        _ticket = preloadedTicket;
        _event = preloadedEvent;
        _orderItem = preloadedOrderItem;
        _isLoading = false;
      });
      _loadReviewStatus(preloadedEvent.id);
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _loadTicketData();
  }
  Future<void> _loadTicketData() async {
    final args = ModalRoute.of(context)!.settings.arguments;
    TicketDto ticket;
    EventDto? preloadedEvent;
    OrderItemDto? preloadedOrderItem;
    if (args is Map<String, dynamic>) {
      ticket = args['ticket'] as TicketDto;
      preloadedEvent = args['event'] as EventDto?;
      preloadedOrderItem = args['orderItem'] as OrderItemDto?;
    } else {
      ticket = args as TicketDto;
    }
    _ticket = ticket;
    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.accessToken;
      if (token == null) {
        setState(() {
          _error = 'Not authenticated';
          _isLoading = false;
        });
        return;
      }
      if (preloadedEvent != null && preloadedOrderItem == null) {
        final ordersResponse = await ApiClient.getMyOrders(token);
        final orders = ordersResponse
            .map((json) => OrderDto.fromJson(json as Map<String, dynamic>))
            .toList();
        OrderItemDto? foundOrderItem;
        for (final order in orders) {
          for (final item in order.items) {
            if (item.tickets.any((t) => t.id == ticket.id)) {
              foundOrderItem = item;
              break;
            }
          }
          if (foundOrderItem != null) break;
        }
        setState(() {
          _event = preloadedEvent;
          _orderItem = foundOrderItem;
          _isLoading = false;
        });
        _loadReviewStatus(preloadedEvent.id);
        return;
      }
      final ordersResponse = await ApiClient.getMyOrders(token);
      final orders = ordersResponse
          .map((json) => OrderDto.fromJson(json as Map<String, dynamic>))
          .toList();
      OrderItemDto? foundOrderItem;
      for (final order in orders) {
        for (final item in order.items) {
          if (item.tickets.any((t) => t.id == ticket.id)) {
            foundOrderItem = item;
            break;
          }
        }
        if (foundOrderItem != null) break;
      }
      if (foundOrderItem == null) {
        setState(() {
          _error = 'Order item not found for this ticket';
          _isLoading = false;
        });
        return;
      }
      _orderItem = foundOrderItem;
      final eventProvider = context.read<EventProvider>();
      await eventProvider.loadEvent(foundOrderItem.eventId);
      if (eventProvider.currentEvent != null) {
        _event = eventProvider.currentEvent;
      }
      setState(() {
        _isLoading = false;
      });
      if (_event != null) {
        _loadReviewStatus(_event!.id);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  String _formatDate(DateTime date) {
    return DateFormat('d.M.yyyy').format(date);
  }
  String _formatDateTime(DateTime date) {
    return DateFormat('EEEE - d.M.yyyy - HH:mm\'h\'', 'bs').format(date);
  }
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'used':
        return AppTheme.textSecondary;
      case 'refunded':
      case 'cancelled':
        return AppTheme.error;
      default:
        return AppTheme.success;
    }
  }
  String? _getPriceTierName() {
    if (_event == null || _orderItem == null) return null;
    try {
      final tier = _event!.priceTiers.firstWhere(
        (t) => t.id == _orderItem!.priceTierId,
      );
      return tier.name;
    } catch (e) {
      return null;
    }
  }

  Future<void> _loadReviewStatus(String eventId) async {
    if (!mounted) return;

    setState(() {
      _isLoadingReviewStatus = true;
    });

    final authProvider = context.read<AuthProvider>();
    final token = authProvider.accessToken;

    if (token == null) {
      setState(() {
        _canReview = false;
        _isLoadingReviewStatus = false;
      });
      return;
    }

    try {
      // Check if user can review
      final canReview = await ApiClient.canUserReviewEvent(token, eventId);

      // Load user's existing review if any
      ReviewDto? userReview;
      final reviewData = await ApiClient.getUserReviewForEvent(token, eventId);
      if (reviewData != null) {
        userReview = ReviewDto.fromJson(reviewData);
      }

      if (mounted) {
        setState(() {
          _canReview = canReview;
          _userReview = userReview;
          _isLoadingReviewStatus = false;
        });
      }
    } catch (e) {
      print('Error loading review status: $e');
      if (mounted) {
        setState(() {
          _canReview = false;
          _isLoadingReviewStatus = false;
        });
      }
    }
  }

  Future<void> _navigateToWriteReview() async {
    if (_event == null) return;

    final result = await Navigator.of(context).pushNamed(
      AppRoutes.writeReview,
      arguments: {
        'eventId': _event!.id,
        'eventTitle': _event!.title,
        'existingReview': _userReview,
      },
    );

    // Reload review status if a review was submitted
    if (result == true) {
      _loadReviewStatus(_event!.id);
    }
  }
  @override
  Widget build(BuildContext context) {
    if (_isLoading || _ticket == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('karta.ba'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('karta.ba'),
        ),
        body: Center(
          child: Text('Error: $_error'),
        ),
      );
    }
    final ticket = _ticket!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('karta.ba'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _event?.title ?? 'Event Ticket',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.backgroundGray, width: 2),
            ),
            child: Column(
              children: [
                QrImageView(
                  data: ticket.ticketCode,
                  version: QrVersions.auto,
                  size: 250,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(ticket.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    ticket.status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(ticket.status),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoRow(context, 'Ticket no:', ticket.ticketCode.substring(0, 12)),
          const Divider(height: 24),
          if (_getPriceTierName() != null) ...[
            _buildInfoRow(context, 'Ticket type:', _getPriceTierName()!),
            const Divider(height: 24),
          ],
          if (_orderItem != null) ...[
            _buildInfoRow(context, 'Price:', '${_orderItem!.unitPrice.toStringAsFixed(2)} KM'),
            const Divider(height: 24),
          ],
          _buildInfoRow(context, 'Date', _formatDate(ticket.issuedAt.toLocal())),
          const Divider(height: 24),
          _buildInfoRow(
            context, 
            'Place', 
            _event != null ? '${_event!.venue}, ${_event!.city}' : 'Venue Name, City'
          ),
          const SizedBox(height: 32),
          if (_event?.coverImageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                ApiClient.getImageUrl(_event!.coverImageUrl!) ?? '',
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundGray,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.image_outlined,
                        size: 48,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: AppTheme.backgroundGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(
                  Icons.image_outlined,
                  size: 48,
                  color: AppTheme.textTertiary,
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (_event != null) ...[
            Text(
              _formatDateTime(_event!.startsAt.toLocal()),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              '${_event!.venue}, ${_event!.city}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            if (_event!.description != null && _event!.description!.isNotEmpty) ...[
              Text(
                'Description',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _event!.description!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                ),
              ),
            ],
          ] else ...[
            Text(
              _formatDateTime(ticket.issuedAt.toLocal()),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              'Venue Name, City',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 32),
          if (ticket.status.toLowerCase() == 'issued' || ticket.status.toLowerCase() == 'valid') ...[
            OutlinedButton(
              onPressed: () {
                _showCancelDialog(context, ticket);
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Cancel ticket'),
            ),
            const SizedBox(height: 12),
          ],
          // Review button
          if (_event != null && !_isLoadingReviewStatus) ...[
            if (_canReview || _userReview != null)
              ElevatedButton.icon(
                onPressed: _navigateToWriteReview,
                icon: Icon(_userReview != null ? Icons.edit : Icons.rate_review),
                label: Text(_userReview != null ? 'Uredi recenziju' : 'Napiši recenziju'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
          if (_isLoadingReviewStatus) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
  void _showCancelDialog(BuildContext context, TicketDto ticket) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel ticket?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to cancel this ticket? This action cannot be undone.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: AppTheme.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cancellation policy: Tickets can only be cancelled at least 24 hours before the event starts.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Keep ticket'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _cancelTicket(ticket);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.error,
            ),
            child: const Text('Cancel ticket'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelTicket(TicketDto ticket) async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.accessToken;

    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not authenticated'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final updatedTicketData = await ApiClient.cancelTicket(token, ticket.id);
      final updatedTicket = TicketDto.fromJson(updatedTicketData);

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        setState(() {
          _ticket = updatedTicket;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket cancelled successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}