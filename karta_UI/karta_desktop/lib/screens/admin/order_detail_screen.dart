import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/order_provider.dart';
import '../../model/order/order_item_dto.dart';
import '../../model/order/ticket_dto.dart';
import '../../model/event/price_tier_dto.dart';
import '../../widgets/loading_widget.dart';
class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}
class _OrderDetailScreenState extends State<OrderDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().loadOrder(widget.orderId);
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
      ),
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, child) {
          if (orderProvider.isLoadingOrder) {
            return const LoadingWidget(message: 'Loading order...');
          }
          if (orderProvider.orderError != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: ${orderProvider.orderError}',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => orderProvider.loadOrder(widget.orderId),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final order = orderProvider.currentOrder;
          if (order == null) {
            return const Center(
              child: Text('Order not found.'),
            );
          }
          return SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Order #${order.id.substring(0, 8)}',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF212121),
                                ),
                          ),
                          _StatusChip(status: order.status),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _SectionCard(
                              title: 'Order Information',
                              icon: Icons.receipt_long_outlined,
                              child: Column(
                                children: [
                                  _InfoCard(
                                    icon: Icons.calendar_today,
                                    label: 'Created At',
                                    value: _formatDateTime(order.createdAt),
                                  ),
                                  const SizedBox(height: 16),
                                  _InfoCard(
                                    icon: Icons.attach_money,
                                    label: 'Total Amount',
                                    value: '${order.totalAmount.toStringAsFixed(2)} ${order.currency}',
                                  ),
                                  const SizedBox(height: 16),
                                  _InfoCard(
                                    icon: Icons.confirmation_number,
                                    label: 'Total Tickets',
                                    value: '${order.totalTickets}',
                                  ),
                                  const SizedBox(height: 16),
                                  _InfoCard(
                                    icon: Icons.info_outline,
                                    label: 'Order ID',
                                    value: order.id,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _SectionCard(
                              title: 'Customer Information',
                              icon: Icons.person_outline,
                              child: Builder(
                                builder: (context) {
                                  final userDetails = orderProvider.userDetails;
                                  final userDetailsError = orderProvider.userDetailsError;
                                  final isLoadingUserDetails = orderProvider.isLoadingUserDetails;
                                  final userNotFound = userDetailsError != null && 
                                      (userDetailsError.contains('404') || 
                                       userDetailsError.contains('not found') ||
                                       userDetailsError.contains('Korisnik nije pronađen'));
                                  final firstName = userDetails?.firstName ?? order.userFirstName ?? '';
                                  final lastName = userDetails?.lastName ?? order.userLastName ?? '';
                                  final email = userDetails?.email ?? order.userEmail ?? '';
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (userNotFound) ...[
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.warning_amber_rounded,
                                                color: Colors.orange,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'User no longer exists in database',
                                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                        color: Colors.orange.shade700,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                      _InfoCard(
                                        icon: Icons.person_outline,
                                        label: 'First Name',
                                        value: firstName.isEmpty ? (userNotFound ? 'N/A' : '-') : firstName,
                                      ),
                                      const SizedBox(height: 16),
                                      _InfoCard(
                                        icon: Icons.person_outline,
                                        label: 'Last Name',
                                        value: lastName.isEmpty ? (userNotFound ? 'N/A' : '-') : lastName,
                                      ),
                                      const SizedBox(height: 16),
                                      _InfoCard(
                                        icon: Icons.email,
                                        label: 'Email',
                                        value: email.isEmpty ? (userNotFound ? 'N/A' : '-') : email,
                                      ),
                                      const SizedBox(height: 16),
                                      _InfoCard(
                                        icon: Icons.info_outline,
                                        label: 'User ID',
                                        value: order.userId,
                                      ),
                                      if (isLoadingUserDetails && userDetails == null && !userNotFound) ...[
                                        const SizedBox(height: 16),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 16),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              ),
                                              SizedBox(width: 8),
                                              Text('Loading user details...'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _SectionCard(
                        title: 'Order Items',
                        icon: Icons.shopping_cart_outlined,
                        child: Column(
                          children: [
                            ...order.items.asMap().entries.map((entry) {
                              final index = entry.key;
                              final item = entry.value;
                              return Padding(
                                padding: EdgeInsets.only(bottom: index < order.items.length - 1 ? 20 : 0),
                                child: _OrderItemCard(item: item),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.primary.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                            ),
                            Text(
                              '${order.totalAmount.toStringAsFixed(2)} ${order.currency}',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                            ),
                          ],
                        ),
                      ),
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
  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      Theme.of(context).colorScheme.primary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF212121),
                      fontSize: 20,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
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
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});
  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.orange;
        break;
      case 'paid':
        color = Colors.blue;
        break;
      case 'completed':
        color = Colors.green;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      case 'refunded':
        color = Colors.purple;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
class _OrderItemCard extends StatelessWidget {
  final OrderItemDto item;
  const _OrderItemCard({required this.item});
  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, child) {
        final eventDetails = orderProvider.getEventDetails(item.eventId);
        final isLoadingEvent = orderProvider.isLoadingEvent(item.eventId);
        PriceTierDto? priceTier;
        if (eventDetails != null) {
          try {
            priceTier = eventDetails.priceTiers.firstWhere(
              (tier) => tier.id == item.priceTierId,
            );
          } catch (e) {
          }
        }
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE0E0E0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
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
                          eventDetails != null 
                            ? eventDetails.title 
                            : 'Event: ${item.eventId.substring(0, 8)}...',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF212121),
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.qty} × ${item.unitPrice.toStringAsFixed(2)} ${orderProvider.currentOrder?.currency ?? ''}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF757575),
                              ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(item.qty * item.unitPrice).toStringAsFixed(2)} ${orderProvider.currentOrder?.currency ?? ''}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (eventDetails != null) ...[
                _InfoCard(
                  icon: Icons.calendar_today,
                  label: 'Event Date',
                  value: _formatDateTime(eventDetails.startsAt),
                ),
                const SizedBox(height: 12),
                _InfoCard(
                  icon: Icons.location_on,
                  label: 'Location',
                  value: '${eventDetails.venue}, ${eventDetails.city}',
                ),
                const SizedBox(height: 12),
              ] else if (isLoadingEvent) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Loading event details...'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (priceTier != null) ...[
                _InfoCard(
                  icon: Icons.label_outline,
                  label: 'Price Tier',
                  value: priceTier.name,
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: _InfoCard(
                      icon: Icons.shopping_cart_outlined,
                      label: 'Quantity',
                      value: item.qty.toString(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InfoCard(
                      icon: Icons.attach_money,
                      label: 'Unit Price',
                      value: '${item.unitPrice.toStringAsFixed(2)} ${orderProvider.currentOrder?.currency ?? ''}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.confirmation_number,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tickets (${item.tickets.length})',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF212121),
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: item.tickets.map((ticket) => _TicketChip(ticket: ticket)).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
class _TicketChip extends StatelessWidget {
  final TicketDto ticket;
  const _TicketChip({required this.ticket});
  @override
  Widget build(BuildContext context) {
    final isUsed = ticket.usedAt != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isUsed ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUsed ? Colors.green.withOpacity(0.3) : Colors.blue.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUsed ? Icons.check_circle : Icons.confirmation_number,
            size: 16,
            color: isUsed ? Colors.green : Colors.blue,
          ),
          const SizedBox(width: 6),
          Text(
            ticket.ticketCode,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isUsed ? Colors.green.shade700 : Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }
}