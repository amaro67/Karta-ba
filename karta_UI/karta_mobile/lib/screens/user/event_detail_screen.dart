import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:karta_shared/karta_shared.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../widgets/event_card.dart';
import '../../services/viewed_events_service.dart';
import '../../services/event_tracking_service.dart';
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key});
  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}
class _EventDetailScreenState extends State<EventDetailScreen> {
  int _quantity = 1;
  PriceTierDto? _selectedTier;
  bool _hasRecordedView = false;
  int get _availableTickets {
    if (_selectedTier == null) return 0;
    return _selectedTier!.capacity - _selectedTier!.sold;
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasRecordedView) {
      final event = ModalRoute.of(context)!.settings.arguments as EventDto;
      print('🔴 EventDetailScreen: Recording view for event: ${event.id} - ${event.title}');
      ViewedEventsService.addViewedEvent(event.id);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated && authProvider.accessToken != null) {
        EventTrackingService.trackEventView(
          event.id,
          token: authProvider.accessToken,
        );
      } else {
        print('⚠️ User not authenticated - skipping backend tracking');
      }
      _hasRecordedView = true;
      print('🔴 EventDetailScreen: View recorded successfully');
    }
  }
  String _formatDateTime(DateTime date) {
    final dateTime = date.toLocal();
    return DateFormat('EEEE - d.M.yyyy - HH:mm\'h\'', 'bs').format(dateTime);
  }
  double _calculateTotal() {
    if (_selectedTier == null) return 0;
    final commission = 0.50;
    return (_selectedTier!.price * _quantity) + (commission * _quantity);
  }
  void _onCheckout(BuildContext context, EventDto event) {
    if (_selectedTier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a ticket tier'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    final available = _selectedTier!.capacity - _selectedTier!.sold;
    if (_quantity > available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Only $available ticket${available != 1 ? 's' : ''} available for ${_selectedTier!.name}'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    Navigator.pushNamed(
      context,
      '/checkout',
      arguments: {
        'eventId': event.id.toString(),
        'priceTierId': _selectedTier!.id.toString(),
        'quantity': _quantity,
        'priceTierPrice': _selectedTier!.price,
        'totalAmount': _calculateTotal(),
      },
    );
  }
  bool _canPurchaseTickets(EventDto event) {
    if (!event.isPublished || event.isDraft) {
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
  @override
  Widget build(BuildContext context) {
    final event = ModalRoute.of(context)!.settings.arguments as EventDto;
    final canPurchase = _canPurchaseTickets(event);
    if (_selectedTier == null && event.priceTiers.isNotEmpty && canPurchase) {
      _selectedTier = event.priceTiers.first;
    }
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                backgroundColor: Colors.white,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.black),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.share, color: Colors.black),
                    ),
                    onPressed: () {
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: event.coverImageUrl != null
                      ? Image.network(
                          ApiClient.getImageUrl(event.coverImageUrl!) ?? '',
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: AppTheme.backgroundGray,
                          child: const Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 64,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 20, color: AppTheme.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _formatDateTime(event.startsAt),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 20, color: AppTheme.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${event.venue}, ${event.city}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Description',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        event.description ?? 'No description available',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (canPurchase && event.priceTiers.isNotEmpty) ...[
                        Text(
                          'Select ticket type',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        ...event.priceTiers.map((tier) {
                          final isSelected = _selectedTier?.id == tier.id;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? AppTheme.primaryColor : AppTheme.backgroundGray,
                                width: 2,
                              ),
                              color: isSelected ? AppTheme.primaryLight.withOpacity(0.1) : null,
                            ),
                            child: ListTile(
                              onTap: () {
                                setState(() {
                                  _selectedTier = tier;
                                });
                              },
                              leading: Radio<PriceTierDto>(
                                value: tier,
                                groupValue: _selectedTier,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedTier = value;
                                  });
                                },
                                activeColor: AppTheme.primaryColor,
                              ),
                              title: Text(tier.name),
                              trailing: Text(
                                '${tier.price.toStringAsFixed(2)} KM',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 24),
                      ] else if (!canPurchase) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundGray,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  event.isDraft 
                                    ? 'This event is not yet published'
                                    : event.endsAt != null && event.endsAt!.isBefore(DateTime.now())
                                      ? 'This event has ended'
                                      : 'Tickets are no longer available for this event',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      Consumer<EventProvider>(
                        builder: (context, eventProvider, child) {
                          final similarEvents = (eventProvider.events?.items ?? [])
                              .where((e) => 
                                e.id != event.id && 
                                e.category == event.category &&
                                e.isPublished &&
                                !e.isDraft
                              )
                              .toList();
                          if (similarEvents.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Other ${event.category} events',
                                    style: Theme.of(context).textTheme.headlineSmall,
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${similarEvents.length}',
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 280,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: similarEvents.length,
                                  itemBuilder: (context, index) {
                                    return EventCard(
                                      event: similarEvents[index],
                                      onTap: () {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const EventDetailScreen(),
                                            settings: RouteSettings(
                                              arguments: similarEvents[index],
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      SizedBox(height: canPurchase ? 280 : 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (canPurchase)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Number of tickets',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (_selectedTier != null)
                                Text(
                                  '${_availableTickets} available',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: _availableTickets > 0 ? AppTheme.textSecondary : AppTheme.error,
                                  ),
                                ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.backgroundGray),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 20),
                                  onPressed: _quantity > 1
                                      ? () {
                                          setState(() {
                                            _quantity--;
                                          });
                                        }
                                      : null,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    '$_quantity',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 20),
                                  onPressed: _quantity < _availableTickets
                                      ? () {
                                          setState(() {
                                            _quantity++;
                                          });
                                        }
                                      : null,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Commission fee',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text(
                            '${(0.50 * _quantity).toStringAsFixed(2)} KM',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _onCheckout(context, event),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Check out for ${_calculateTotal().toStringAsFixed(2)}KM',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}