import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/ticket_provider.dart';
import '../../widgets/loading_widget.dart';
class TicketDetailScreen extends StatefulWidget {
  final String ticketId;
  const TicketDetailScreen({super.key, required this.ticketId});
  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}
class _TicketDetailScreenState extends State<TicketDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TicketProvider>().loadTicket(widget.ticketId);
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket Details'),
      ),
      body: Consumer<TicketProvider>(
        builder: (context, ticketProvider, child) {
          if (ticketProvider.isLoadingTicket) {
            return const LoadingWidget(message: 'Loading ticket...');
          }
          if (ticketProvider.ticketError != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: ${ticketProvider.ticketError}',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ticketProvider.loadTicket(widget.ticketId),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final ticket = ticketProvider.currentTicket;
          if (ticket == null) {
            return const Center(
              child: Text('Ticket not found.'),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ticket Code: ${ticket.ticketCode}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        _StatusChip(status: ticket.status),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _InfoRow(
                      icon: Icons.confirmation_number_outlined,
                      label: 'Ticket ID',
                      value: ticket.id,
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.calendar_today,
                      label: 'Issued At',
                      value: DateFormat('dd/MM/yyyy HH:mm').format(ticket.issuedAt),
                    ),
                    if (ticket.usedAt != null) ...[
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.check_circle_outline,
                        label: 'Used At',
                        value: DateFormat('dd/MM/yyyy HH:mm').format(ticket.usedAt!),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
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
      case 'issued':
        color = Colors.blue;
        break;
      case 'used':
        color = Colors.green;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Chip(
      label: Text(status),
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(color: color, fontSize: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}