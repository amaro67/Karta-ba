import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/order_provider.dart';
import '../../model/order/order_dto.dart';
import 'order_detail_screen.dart';
import '../../widgets/loading_widget.dart';
class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});
  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}
class _OrderListScreenState extends State<OrderListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String? _selectedStatus;
  DateTime? _fromDate;
  DateTime? _toDate;
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().loadOrders();
    });
  }
  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      context.read<OrderProvider>().loadNextPage();
    }
  }
  void _handleSearch() {
    final query = _searchController.text.trim();
    context.read<OrderProvider>().loadOrders(
      query: query.isEmpty ? null : query,
      status: _selectedStatus,
      from: _fromDate,
      to: _toDate,
    );
  }
  void _handleFilter() {
    showDialog(
      context: context,
      builder: (context) => _FilterDialog(
        status: _selectedStatus,
        fromDate: _fromDate,
        toDate: _toDate,
        onApply: (status, from, to) {
          setState(() {
            _selectedStatus = status;
            _fromDate = from;
            _toDate = to;
          });
          context.read<OrderProvider>().loadOrders(
            query: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
            status: status,
            from: from,
            to: to,
          );
        },
      ),
    );
  }
  void _handleOrderTap(OrderDto order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OrderDetailScreen(orderId: order.id),
      ),
    );
  }
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: StatefulBuilder(
                    builder: (context, setState) => TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by Order ID, Name, Email...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                  _handleSearch();
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _handleSearch(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _handleFilter,
                  tooltip: 'Filter Orders',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF5F5F5),
                    foregroundColor: const Color(0xFF212121),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _selectedStatus = null;
                      _fromDate = null;
                      _toDate = null;
                    });
                    context.read<OrderProvider>().refreshOrders();
                  },
                  tooltip: 'Refresh Orders',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF5F5F5),
                    foregroundColor: const Color(0xFF212121),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<OrderProvider>(
              builder: (context, orderProvider, child) {
          if (orderProvider.isLoading && orderProvider.orders == null) {
            return const LoadingWidget(message: 'Loading orders...');
          }
          if (orderProvider.error != null && orderProvider.orders == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: ${orderProvider.error}',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => orderProvider.refreshOrders(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final orders = orderProvider.orders?.items ?? [];
          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No orders found',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => orderProvider.refreshOrders(),
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.vertical,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: DataTable(
                    headingRowHeight: 56,
                    dataRowMinHeight: 64,
                    dataRowMaxHeight: 80,
                    columnSpacing: 20,
                    showCheckboxColumn: false,
                    headingRowColor: WidgetStateProperty.all(
                      const Color(0xFFF5F5F5),
                    ),
                    columns: const [
                          DataColumn(
                            label: Text(
                              'Order ID',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF212121),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Customer',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF212121),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Date',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF212121),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Status',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF212121),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Items',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF212121),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Total',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF212121),
                              ),
                            ),
                          ),
                    ],
                    rows: [
                          ...orders.map((order) {
                            return DataRow(
                              onSelectChanged: (_) => _handleOrderTap(order),
                              cells: [
                                DataCell(
                                  Text(
                                    order.id.substring(0, 8),
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        order.userDisplayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (order.userEmail != null)
                                        Text(
                                          order.userEmail!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _formatDate(order.createdAt),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                DataCell(_StatusChip(status: order.status)),
                                DataCell(
                                  Text(
                                    '${order.totalTickets} ticket(s)',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '${order.totalAmount.toStringAsFixed(2)} ${order.currency}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.primary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                          if (orderProvider.isLoading)
                            DataRow(
                              cells: List.generate(
                                6,
                                (_) => const DataCell(
                                  Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                ),
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
class _FilterDialog extends StatefulWidget {
  final String? status;
  final DateTime? fromDate;
  final DateTime? toDate;
  final Function(String?, DateTime?, DateTime?) onApply;
  const _FilterDialog({
    required this.status,
    required this.fromDate,
    required this.toDate,
    required this.onApply,
  });
  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}
class _FilterDialogState extends State<_FilterDialog> {
  late String? _status;
  late DateTime? _fromDate;
  late DateTime? _toDate;
  @override
  void initState() {
    super.initState();
    _status = widget.status;
    _fromDate = widget.fromDate;
    _toDate = widget.toDate;
  }
  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? (_fromDate ?? DateTime.now()) : (_toDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter Orders'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('All')),
                DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
                DropdownMenuItem(value: 'Refunded', child: Text('Refunded')),
              ],
              onChanged: (value) {
                setState(() {
                  _status = value;
                });
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDate(context, true),
                    child: AbsorbPointer(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'From Date',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        controller: TextEditingController(
                          text: _fromDate?.toLocal().toString().split(' ')[0] ?? '',
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDate(context, false),
                    child: AbsorbPointer(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'To Date',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        controller: TextEditingController(
                          text: _toDate?.toLocal().toString().split(' ')[0] ?? '',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _status = null;
              _fromDate = null;
              _toDate = null;
            });
          },
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApply(_status, _fromDate, _toDate);
            Navigator.of(context).pop();
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}