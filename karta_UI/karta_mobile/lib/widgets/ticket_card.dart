import 'package:flutter/material.dart';
import 'package:karta_shared/karta_shared.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
class TicketCard extends StatelessWidget {
  final TicketDto ticket;
  final VoidCallback onTap;
  final EventDto? event;
  final OrderItemDto? orderItem;
  const TicketCard({
    super.key,
    required this.ticket,
    required this.onTap,
    this.event,
    this.orderItem,
  });
  String? _getPriceTierName() {
    if (event == null || orderItem == null) return null;
    try {
      final tier = event!.priceTiers.firstWhere(
        (t) => t.id == orderItem!.priceTierId,
      );
      return tier.name;
    } catch (e) {
      return null;
    }
  }
  String _formatDate(DateTime date) {
    final dateTime = date.toLocal();
    return DateFormat('EEEE - d.M.yyyy - HH:mm\'h\'', 'bs').format(dateTime);
  }
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'valid':
      case 'issued':
        return AppTheme.success;
      case 'used':
        return AppTheme.textSecondary;
      case 'refunded':
        return AppTheme.error;
      default:
        return AppTheme.primaryColor;
    }
  }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
            if (event?.coverImageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  ApiClient.getImageUrl(event!.coverImageUrl!) ?? '',
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundGray,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.confirmation_number_outlined,
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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: const Center(
                  child: Icon(
                    Icons.confirmation_number_outlined,
                    size: 48,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(ticket.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      ticket.status.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(ticket.status),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    event?.title ?? 'Event Ticket',
                    style: Theme.of(context).textTheme.headlineSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (_getPriceTierName() != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _getPriceTierName()!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    event != null 
                        ? _formatDate(event!.startsAt.toLocal())
                        : _formatDate(ticket.issuedAt),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (event != null) ...[
                    Text(
                      '${event!.venue}, ${event!.city}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                  ],
                  Row(
                    children: [
                      Icon(
                        Icons.confirmation_number_outlined,
                        size: 14,
                        color: AppTheme.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          ticket.ticketCode,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textTertiary,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}