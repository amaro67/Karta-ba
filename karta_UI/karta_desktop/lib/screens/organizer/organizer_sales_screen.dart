import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/organizer_sales_provider.dart';
class OrganizerSalesScreen extends StatefulWidget {
  const OrganizerSalesScreen({super.key});
  @override
  State<OrganizerSalesScreen> createState() => _OrganizerSalesScreenState();
}
class _OrganizerSalesScreenState extends State<OrganizerSalesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<OrganizerSalesProvider>().loadSales();
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'BAM', decimalDigits: 2);
    return Consumer<OrganizerSalesProvider>(
      builder: (context, provider, child) {
        final sales = provider.sales;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Sales overview',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: provider.isLoading ? null : provider.loadSales,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              if (provider.isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(),
                ),
              if (provider.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    provider.error!,
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _SalesStatCard(
                      title: 'Total revenue',
                      value: currencyFormat.format(provider.totalRevenue),
                      icon: Icons.attach_money,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _SalesStatCard(
                      title: 'Tickets sold',
                      value: provider.totalTicketsSold.toString(),
                      icon: Icons.confirmation_number,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _SalesStatCard(
                      title: 'Orders',
                      value: sales.length.toString(),
                      icon: Icons.shopping_cart,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: sales.isEmpty
                    ? _EmptySalesState(onRefresh: provider.loadSales)
                    : ListView.separated(
                        itemCount: sales.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final sale = sales[index];
                          return _SaleCard(
                            sale: sale,
                            currencyFormat: currencyFormat,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
class _SalesStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _SalesStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
class _SaleCard extends StatelessWidget {
  final OrganizerSale sale;
  final NumberFormat currencyFormat;
  const _SaleCard({
    required this.sale,
    required this.currencyFormat,
  });
  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d. MMM yyyy • HH:mm');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sale.eventTitle,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(sale.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                _StatusChip(status: sale.status),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    sale.buyerEmail,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.confirmation_number_outlined, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  '${sale.ticketsCount} ticket(s)',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Spacer(),
                Text(
                  currencyFormat.format(sale.totalAmount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
          ],
        ),
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
      case 'paid':
      case 'completed':
        color = Colors.green;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
class _EmptySalesState extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptySalesState({required this.onRefresh});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insights, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No sales yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Ovdje će se prikazivati narudžbe kada kupci kupe ulaznice za vaše događaje.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRefresh,
            child: const Text('Osvježi'),
          ),
        ],
      ),
    );
  }
}