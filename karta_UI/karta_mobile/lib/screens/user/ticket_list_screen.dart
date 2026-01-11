import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:karta_shared/karta_shared.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../widgets/ticket_card.dart';
class TicketListScreen extends StatefulWidget {
  const TicketListScreen({super.key});
  @override
  State<TicketListScreen> createState() => _TicketListScreenState();
}
class _TicketListScreenState extends State<TicketListScreen> {
  List<TicketDto> _tickets = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedStatus;
  bool _postPaymentRefreshScheduled = false;
  bool _forceRefreshFromArgs = false;
  final Map<String, String> _ticketToEventMap = {};
  final Map<String, EventDto> _eventMap = {};
  final Map<String, OrderItemDto> _ticketToOrderItemMap = {};
  final List<Map<String, dynamic>> _ticketStatuses = [
    {'label': 'All', 'value': null, 'icon': Icons.all_inclusive, 'color': AppTheme.primaryColor},
    {'label': 'Valid', 'value': 'valid', 'icon': Icons.check_circle_outline, 'color': AppTheme.success},
    {'label': 'Used', 'value': 'used', 'icon': Icons.check_circle, 'color': AppTheme.textSecondary},
    {'label': 'Refunded', 'value': 'refunded', 'icon': Icons.money_off, 'color': AppTheme.warning},
  ];
  @override
  void initState() {
    super.initState();
    _hasLoadedOnce = false;
    _loadTickets();
  }
  bool _hasLoadedOnce = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['forceRefresh'] == true) {
      _forceRefreshFromArgs = true;
    }
    if (!_hasLoadedOnce) {
      _hasLoadedOnce = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _loadTickets();
            }
          });
        }
      });
    }
  }
  Future<void> _loadTickets({bool showLoading = true, int retryCount = 0}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
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
      final ticketsResponse = await ApiClient.getList('/Ticket/my-tickets', token: token);
      final allTickets = ticketsResponse
          .map((json) => TicketDto.fromJson(json as Map<String, dynamic>))
          .toList();
      final ordersResponse = await ApiClient.getMyOrders(token);
      final orders = ordersResponse
          .map((json) => OrderDto.fromJson(json as Map<String, dynamic>))
          .toList();
      _ticketToEventMap.clear();
      _ticketToOrderItemMap.clear();
      for (final order in orders) {
        for (final item in order.items) {
          for (final ticket in item.tickets) {
            _ticketToEventMap[ticket.id] = item.eventId;
            _ticketToOrderItemMap[ticket.id] = item;
          }
        }
      }
      final eventIds = _ticketToEventMap.values.toSet().toList();
      _eventMap.clear();
      if (!mounted) return;
      final eventProvider = context.read<EventProvider>();
      for (final eventId in eventIds) {
        if (!mounted) return;
        try {
          await eventProvider.loadEvent(eventId);
          if (!mounted) return;
          if (eventProvider.currentEvent != null) {
            _eventMap[eventId] = eventProvider.currentEvent!;
          }
        } catch (e) {
          debugPrint('Failed to load event $eventId: $e');
        }
      }
      final validTickets = allTickets.where((ticket) {
        final eventId = _ticketToEventMap[ticket.id];
        if (eventId == null) return false;
        final event = _eventMap[eventId];
        return event != null;
      }).toList();
      validTickets.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
      final uniqueStatuses = validTickets.map((t) => t.status).toSet();
      print('🎟️ TicketListScreen: Found ${validTickets.length} tickets with statuses: $uniqueStatuses');
      setState(() {
        _tickets = validTickets;
        _isLoading = false;
      });
      if (!_postPaymentRefreshScheduled) {
        _postPaymentRefreshScheduled = true;
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            _loadTickets(showLoading: false, retryCount: retryCount + 1);
          }
        });
      }
      if ((_forceRefreshFromArgs || validTickets.isEmpty) && retryCount < 5 && mounted && retryCount == 0) {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          _loadTickets(showLoading: false, retryCount: retryCount + 1);
        }
      } else if ((_forceRefreshFromArgs || validTickets.isEmpty) && retryCount > 0 && retryCount < 5 && mounted) {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          _loadTickets(showLoading: false, retryCount: retryCount + 1);
        }
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
                'Error loading tickets',
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
                onPressed: _loadTickets,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_tickets.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadTickets,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (user != null) ...[
              Text(
                "${user.firstName}'s tickets",
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                '0 tickets',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
            ],
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.confirmation_number_outlined,
                      size: 64,
                      color: AppTheme.textTertiary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No tickets yet',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Browse events and purchase your first ticket',
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
            ),
          ],
        ),
      );
    }
    final filteredTickets = _selectedStatus == null
        ? _tickets
        : _tickets.where((ticket) => ticket.status.toLowerCase() == _selectedStatus?.toLowerCase()).toList();
    return RefreshIndicator(
      onRefresh: _loadTickets,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${user.firstName}'s tickets",
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedStatus == null
                            ? '${filteredTickets.length} ${filteredTickets.length == 1 ? 'ticket' : 'tickets'}'
                            : 'Showing ${filteredTickets.length} of ${_tickets.length}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_selectedStatus != null)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedStatus = null;
                      });
                    },
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _ticketStatuses.map((status) {
                final isSelected = _selectedStatus == status['value'];
                final count = status['value'] == null
                    ? _tickets.length
                    : _tickets.where((t) => t.status.toLowerCase() == (status['value'] as String).toLowerCase()).length;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          status['icon'] as IconData,
                          size: 16,
                          color: isSelected ? Colors.white : status['color'] as Color,
                        ),
                        const SizedBox(width: 6),
                        Text('${status['label']} ($count)'),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedStatus = status['value'] as String?;
                      });
                    },
                    backgroundColor: Colors.white,
                    selectedColor: AppTheme.primaryColor,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? AppTheme.primaryColor : (status['color'] as Color).withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          if (filteredTickets.isEmpty && _tickets.isNotEmpty) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.filter_alt_off,
                      size: 64,
                      color: AppTheme.textTertiary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No tickets found',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No tickets match the selected filter',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            ...filteredTickets.map((ticket) {
              final eventId = _ticketToEventMap[ticket.id];
              final event = eventId != null ? _eventMap[eventId] : null;
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
            }),
          ],
        ],
      ),
    );
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
                leading: const Icon(Icons.event_outlined),
                title: const Text('My Events'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AppRoutes.myEvents);
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