import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/event_provider.dart';
import '../../providers/order_provider.dart';
import '../../model/event/event_dto.dart';
import '../../model/order/order_dto.dart';
import 'event_form_screen.dart';
import '../../utils/error_dialog.dart';
import '../../utils/api_client.dart';
class EventDetailScreen extends StatefulWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});
  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}
class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _isLoadingSales = false;
  Map<DateTime, int> _salesByDate = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final eventProvider = context.read<EventProvider>();
      eventProvider.clearCurrentEvent();
      eventProvider.loadEvent(widget.eventId);
      _loadSalesData();
    });
  }

  Future<void> _loadSalesData() async {
    setState(() {
      _isLoadingSales = true;
    });
    try {
      final orderProvider = context.read<OrderProvider>();
      final orders = await orderProvider.getOrdersForEvent(widget.eventId);
      
      // Filter only completed/paid orders
      final validOrders = orders.where((order) {
        return order.status.toLowerCase() == 'completed' || 
               order.status.toLowerCase() == 'paid';
      }).toList();
      
      // Group by date
      final salesByDate = <DateTime, int>{};
      for (final order in validOrders) {
        final date = DateTime(
          order.createdAt.year,
          order.createdAt.month,
          order.createdAt.day,
        );
        final eventItems = order.items.where((item) => item.eventId == widget.eventId);
        final totalTickets = eventItems.fold(0, (sum, item) => sum + item.qty);
        
        salesByDate[date] = (salesByDate[date] ?? 0) + totalTickets;
      }
      
      setState(() {
        _salesByDate = salesByDate;
        _isLoadingSales = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingSales = false;
      });
      print('Error loading sales data: $e');
    }
  }
  @override
  void dispose() {
    // Ne koristimo context.read u dispose jer context možda nije više validan
    // clearCurrentEvent će biti pozvan u initState sljedećeg ekrana
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
        actions: [
          Selector<EventProvider, EventDto?>(
            selector: (_, provider) => provider.currentEvent,
            builder: (context, event, child) {
              if (event == null) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit Event',
                onPressed: () {
                  final eventProvider = context.read<EventProvider>();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => EventFormScreen(event: event),
                    ),
                  ).then((_) {
                    eventProvider.loadEvent(widget.eventId);
                  });
                },
              );
            },
          ),
          Selector<EventProvider, EventDto?>(
            selector: (_, provider) => provider.currentEvent,
            builder: (context, event, child) {
              if (event == null) return const SizedBox.shrink();
              return PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    _handleDelete(event);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<EventProvider>(
        builder: (context, eventProvider, child) {
          if (eventProvider.isLoadingEvent) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading event...',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            );
          }
          if (eventProvider.eventError != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading event',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    eventProvider.eventError!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Go Back'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () => eventProvider.loadEvent(widget.eventId),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }
          final event = eventProvider.currentEvent;
          if (event == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Event not found',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }
          return SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.title,
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF212121),
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _StatusChip(status: event.status),
                                    Chip(
                                      label: Text(event.category),
                                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                      labelStyle: TextStyle(
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                _InfoCard(
                                  icon: Icons.location_on,
                                  label: 'Location',
                                  value: '${event.venue}\n${event.city}, ${event.country}',
                                ),
                                const SizedBox(height: 12),
                                _InfoCard(
                                  icon: Icons.calendar_today,
                                  label: 'Date & Time',
                                  value: '${DateFormat('MMM dd, yyyy').format(event.startsAt)}\n${DateFormat('HH:mm').format(event.startsAt)}',
                                ),
                                const SizedBox(height: 12),
                                if (event.description != null && event.description!.isNotEmpty)
                                  _InfoCard(
                                    icon: Icons.description,
                                    label: 'Description',
                                    value: event.description!,
                                  ),
                                if (event.tagList.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  _InfoCard(
                                    icon: Icons.tag,
                                    label: 'Tags',
                                    value: event.tagList.join(', '),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: event.coverImageUrl != null && event.coverImageUrl!.isNotEmpty
                                  ? Image.network(
                                      ApiClient.getImageUrl(event.coverImageUrl!) ?? '',
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Container(
                                          width: double.infinity,
                                          height: 400,
                                          color: const Color(0xFFE0E0E0),
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              value: loadingProgress.expectedTotalBytes != null
                                                  ? loadingProgress.cumulativeBytesLoaded /
                                                      loadingProgress.expectedTotalBytes!
                                                  : null,
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        width: double.infinity,
                                        height: 400,
                                        color: const Color(0xFFE0E0E0),
                                        child: const Icon(
                                          Icons.event,
                                          size: 60,
                                          color: Color(0xFF9E9E9E),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: double.infinity,
                                      height: 400,
                                      color: const Color(0xFFE0E0E0),
                                      child: const Icon(
                                        Icons.event,
                                        size: 60,
                                        color: Color(0xFF9E9E9E),
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      if (event.priceTiers.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _SectionCard(
                                  title: 'Price Tiers',
                                  child: Column(
                                    children: event.priceTiers.map((tier) {
                                      return Container(
                                        margin: EdgeInsets.only(
                                          bottom: event.priceTiers.last == tier ? 0 : 16,
                                        ),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF5F5F5),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: const Color(0xFFE0E0E0),
                                            width: 1,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        tier.name,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleMedium
                                                            ?.copyWith(
                                                              fontWeight: FontWeight.bold,
                                                              color: const Color(0xFF212121),
                                                            ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '${tier.price.toStringAsFixed(2)} ${tier.currency}',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyLarge
                                                            ?.copyWith(
                                                              fontWeight: FontWeight.w600,
                                                              color: const Color(0xFF212121),
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: tier.available > 0
                                                        ? Colors.green.withOpacity(0.1)
                                                        : Colors.red.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    '${tier.available}/${tier.capacity}',
                                                    style: TextStyle(
                                                      color: tier.available > 0
                                                          ? Colors.green
                                                          : Colors.red,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: (tier.soldPercentage / 100).clamp(0.0, 1.0),
                                                minHeight: 8,
                                                backgroundColor: Colors.grey[300],
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  tier.soldPercentage > 80
                                                      ? Colors.red
                                                      : tier.soldPercentage > 50
                                                          ? Colors.orange
                                                          : Colors.green,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _SectionCard(
                                  title: 'Statistics',
                                  child: Column(
                                    children: [
                                      _StatItem(
                                        label: 'Total Capacity',
                                        value: event.totalCapacity.toString(),
                                        icon: Icons.event_seat,
                                      ),
                                      const SizedBox(height: 12),
                                      _StatItem(
                                        label: 'Total Sold',
                                        value: event.totalSold.toString(),
                                        icon: Icons.shopping_cart,
                                      ),
                                      const SizedBox(height: 12),
                                      _StatItem(
                                        label: 'Available',
                                        value: event.totalAvailable.toString(),
                                        icon: Icons.check_circle,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _SectionCard(
                          title: 'Sales Over Time',
                          titleAction: IconButton(
                            icon: _isLoadingSales
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh),
                            onPressed: _isLoadingSales ? null : _loadSalesData,
                            tooltip: 'Refresh sales data',
                            iconSize: 20,
                          ),
                          child: _isLoadingSales
                              ? const Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : _salesByDate.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(40),
                                      child: Center(
                                        child: Column(
                                          children: [
                                            Icon(
                                              Icons.show_chart,
                                              size: 48,
                                              color: Colors.grey[400],
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'No sales data available',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    color: Colors.grey[600],
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : SizedBox(
                                      height: 300,
                                      child: _SalesChart(salesByDate: _salesByDate),
                                    ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  Future<void> _handleDelete(EventDto event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final eventProvider = context.read<EventProvider>();
      final success = await eventProvider.deleteEvent(event.id);
      if (success && mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event deleted successfully')),
        );
      } else if (mounted) {
        ErrorDialog.show(
          context,
          title: 'Error',
          message: eventProvider.error ?? 'Failed to delete event',
        );
      }
    }
  }
}
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});
  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    switch (status.toLowerCase()) {
      case 'published':
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        break;
      case 'draft':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        break;
      case 'cancelled':
        backgroundColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red;
        break;
      case 'archived':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey;
    }
    return Chip(
      label: Text(status),
      backgroundColor: backgroundColor,
      labelStyle: TextStyle(color: textColor, fontSize: 12),
      side: BorderSide.none,
    );
  }
}
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF212121),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF757575),
                        fontSize: 11,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF212121),
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? titleAction;
  const _SectionCard({
    required this.title,
    required this.child,
    this.titleAction,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF212121),
                    ),
              ),
              if (titleAction != null) titleAction!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF212121),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF212121),
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF757575),
                        fontSize: 12,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class _SalesChart extends StatelessWidget {
  final Map<DateTime, int> salesByDate;
  const _SalesChart({required this.salesByDate});
  @override
  Widget build(BuildContext context) {
    if (salesByDate.isEmpty) {
      return const Center(child: Text('No sales data'));
    }
    // Sort dates
    final sortedDates = salesByDate.keys.toList()..sort();
    // Prepare data for chart
    final spots = <FlSpot>[];
    for (int i = 0; i < sortedDates.length; i++) {
      spots.add(FlSpot(i.toDouble(), salesByDate[sortedDates[i]]!.toDouble()));
    }
    // Find max value for scaling
    final maxValue = salesByDate.values.reduce((a, b) => a > b ? a : b);
    final maxY = (maxValue * 1.2).ceil().toDouble(); // Add 20% padding
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: sortedDates.length > 7 ? (sortedDates.length / 7).ceil().toDouble() : 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= sortedDates.length) return const Text('');
                final date = sortedDates[value.toInt()];
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    DateFormat('MMM dd').format(date),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: maxY / 5,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        minX: 0,
        maxX: (sortedDates.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}
