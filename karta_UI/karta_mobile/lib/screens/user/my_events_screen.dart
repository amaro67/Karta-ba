import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:karta_shared/karta_shared.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../widgets/ticket_card.dart';
class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});
  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}
class _MyEventsScreenState extends State<MyEventsScreen> {
  Map<String, EventDto> _events = {};
  Map<String, List<TicketDto>> _eventTickets = {};
  Map<String, OrderItemDto> _ticketToOrderItemMap = {};
  Map<String, DateTime> _eventToOrderCreatedAt = {};
  bool _isLoading = true;
  String? _error;
  bool _hasLoadedOnce = false;
  bool _postPaymentRefreshScheduled = false;
  bool _forceRefreshFromArgs = false;
  @override
  void initState() {
    super.initState();
    _loadMyEvents();
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['forceRefresh'] == true) {
      _forceRefreshFromArgs = true;
    }
    if (!_hasLoadedOnce) {
      _hasLoadedOnce = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isLoading) {
          _loadMyEvents();
        }
      });
    }
  }
  Future<void> _loadMyEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
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
      final ordersResponse = await ApiClient.getMyOrders(token);
      final orders = ordersResponse
          .map((json) => OrderDto.fromJson(json as Map<String, dynamic>))
          .toList();
      final eventIds = <String>{};
      final eventTicketsMap = <String, List<TicketDto>>{};
      final ticketToOrderItemMap = <String, OrderItemDto>{};
      final eventToOrderCreatedAtMap = <String, DateTime>{};
      for (final order in orders) {
        if (order.status.toLowerCase() != 'paid') {
          continue;
        }
        for (final item in order.items) {
          eventIds.add(item.eventId);
          if (!eventTicketsMap.containsKey(item.eventId)) {
            eventTicketsMap[item.eventId] = [];
          }
          if (!eventToOrderCreatedAtMap.containsKey(item.eventId) || 
              order.createdAt.isAfter(eventToOrderCreatedAtMap[item.eventId]!)) {
            eventToOrderCreatedAtMap[item.eventId] = order.createdAt;
          }
          if (item.tickets.isNotEmpty) {
            eventTicketsMap[item.eventId]!.addAll(item.tickets);
            for (final ticket in item.tickets) {
              ticketToOrderItemMap[ticket.id] = item;
            }
          }
        }
      }
      final eventProvider = context.read<EventProvider>();
      final eventsMap = <String, EventDto>{};
      for (final eventId in eventIds) {
        try {
          await eventProvider.loadEvent(eventId);
          if (eventProvider.currentEvent != null) {
            final event = eventProvider.currentEvent!;
            if (!event.isDraft) {
              eventsMap[eventId] = event;
            }
          }
        } catch (e) {
          print('Failed to load event $eventId: $e');
        }
      }
      for (final entry in eventTicketsMap.entries) {
        entry.value.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
      }
      setState(() {
        _events = eventsMap;
        _eventTickets = eventTicketsMap;
        _ticketToOrderItemMap = ticketToOrderItemMap;
        _eventToOrderCreatedAt = eventToOrderCreatedAtMap;
        _isLoading = false;
      });
      if (!_postPaymentRefreshScheduled) {
        _postPaymentRefreshScheduled = true;
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            _loadMyEvents();
          }
        });
      }
      if (_forceRefreshFromArgs && mounted) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _loadMyEvents();
          }
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('karta.ba'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              _showMenu(context);
            },
          ),
        ],
      ),
      body: _buildBody(user),
    );
  }
  Widget _buildBody(UserInfo? user) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading events',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadMyEvents,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.event_outlined,
                size: 64,
                color: AppTheme.textTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                'No events yet',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Purchase tickets to see your events here',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, AppRoutes.home);
                },
                child: const Text('Browse Events'),
              ),
            ],
          ),
        ),
      );
    }
    final sortedEvents = _events.values.toList()
      ..sort((a, b) {
        final aOrderDate = _eventToOrderCreatedAt[a.id] ?? DateTime(1970);
        final bOrderDate = _eventToOrderCreatedAt[b.id] ?? DateTime(1970);
        return bOrderDate.compareTo(aOrderDate);
      });
    return RefreshIndicator(
      onRefresh: _loadMyEvents,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user != null) ...[
            Text(
              "${user.firstName}'s Events",
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 24),
          ],
          ...sortedEvents.map((event) {
            final tickets = _eventTickets[event.id] ?? [];
            return _buildEventSection(event, tickets);
          }),
        ],
      ),
    );
  }
  bool _canPurchaseTickets(EventDto event) {
    if (event.status.toLowerCase() == 'archived' || 
        event.status.toLowerCase() == 'cancelled' ||
        event.isDraft) {
      return false;
    }
    if (!event.isPublished) {
      return false;
    }
    final now = DateTime.now();
    if (event.startsAt.isAfter(now)) {
      return true;
    } else if (event.endsAt != null && event.endsAt!.isAfter(now)) {
      return true;
    }
    return false;
  }
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'archived':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      case 'published':
        return Colors.green;
      default:
        return AppTheme.textSecondary;
    }
  }
  Widget _buildEventSection(EventDto event, List<TicketDto> tickets) {
    final canPurchase = _canPurchaseTickets(event);
    final isArchived = event.status.toLowerCase() == 'archived';
    final isCancelled = event.status.toLowerCase() == 'cancelled';
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              Navigator.pushNamed(
                context,
                AppRoutes.eventDetail,
                arguments: event,
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isArchived || isCancelled) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(event.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        event.status.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(event.status),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundGray,
                      borderRadius: BorderRadius.circular(12),
                      image: event.coverImageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(ApiClient.getImageUrl(event.coverImageUrl!) ?? ''),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: event.coverImageUrl == null
                        ? const Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 64,
                              color: AppTheme.textTertiary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    event.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(event.startsAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${event.venue}, ${event.city}',
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (!canPurchase && (isArchived || isCancelled)) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundGray,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isCancelled 
                                ? 'This event has been cancelled'
                                : 'This event has been archived',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (tickets.isNotEmpty) ...[
            const Divider(height: 1),
            ExpansionTile(
              title: Text(
                'Tickets (${tickets.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              leading: const Icon(Icons.confirmation_number_outlined),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: tickets.map((ticket) {
                      final orderItem = _ticketToOrderItemMap[ticket.id];
                      return TicketCard(
                        ticket: ticket,
                        event: event,
                        orderItem: orderItem,
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.ticketDetail,
                            arguments: {
                              'ticket': ticket,
                              'event': event,
                              'orderItem': orderItem,
                            },
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  String _formatDate(DateTime date) {
    final dateTime = date.toLocal();
    return DateFormat('EEEE - d.M.yyyy - HH:mm\'h\'', 'bs').format(dateTime);
  }
  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final authProvider = context.read<AuthProvider>();
        final user = authProvider.currentUser;
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (user != null) ...[
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.profile);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${user.firstName.isNotEmpty ? user.firstName[0] : ''}${user.lastName.isNotEmpty ? user.lastName[0] : ''}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${user.firstName} ${user.lastName}',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                user.email,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 32),
              ],
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text('Home'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, AppRoutes.home);
                },
              ),
              ListTile(
                leading: const Icon(Icons.confirmation_number_outlined),
                title: const Text('My Tickets'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AppRoutes.tickets);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('My Profile'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AppRoutes.profile);
                },
              ),
              const Divider(height: 16),
              ListTile(
                leading: const Icon(Icons.logout, color: AppTheme.error),
                title: const Text('Logout', style: TextStyle(color: AppTheme.error)),
                onTap: () async {
                  await authProvider.logout();
                  if (context.mounted) {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}