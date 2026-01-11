import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/auth_provider.dart';
import '../../model/event/event_dto.dart';
import 'event_form_screen.dart';
import 'event_detail_screen.dart';
import '../../utils/error_dialog.dart';
import '../../utils/api_client.dart';
class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});
  @override
  State<EventListScreen> createState() => _EventListScreenState();
}
class _EventListScreenState extends State<EventListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String? _selectedCategory;
  String? _selectedCity;
  String? _selectedStatus;
  Timer? _debounce;
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().loadEvents(useAdminEndpoint: true);
    });
  }
  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      context.read<EventProvider>().loadNextPage(useAdminEndpoint: true);
    }
  }
  void _handleSearch() {
    final query = _searchController.text.trim();
    context.read<EventProvider>().loadEvents(
      query: query.isEmpty ? null : query,
      category: _selectedCategory,
      city: _selectedCity,
      status: _selectedStatus,
      useAdminEndpoint: true,
    );
  }
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _handleSearch();
    });
    setState(() {});
  }
  void _handleFilter() {
    showDialog(
      context: context,
      builder: (context) => _FilterDialog(
        category: _selectedCategory,
        city: _selectedCity,
        status: _selectedStatus,
        onApply: (category, city, status) {
          setState(() {
            _selectedCategory = category;
            _selectedCity = city;
            _selectedStatus = status;
          });
          context.read<EventProvider>().loadEvents(
            category: category,
            city: city,
            status: status,
            useAdminEndpoint: true,
          );
        },
      ),
    );
  }
  void _handleCreateEvent() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const EventFormScreen(),
      ),
    ).then((_) {
      context.read<EventProvider>().refreshEvents(useAdminEndpoint: true);
    });
  }
  void _handleEventTap(EventDto event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventDetailScreen(eventId: event.id),
      ),
    );
  }
  Future<void> _handleDeleteEvent(EventDto event) async {
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
    if (confirmed == true) {
      final eventProvider = context.read<EventProvider>();
      final success = await eventProvider.deleteEvent(event.id);
      if (success && mounted) {
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
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final canCreateEvents = authProvider.isAdmin || authProvider.isOrganizer;
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Pretraži evente po nazivu, gradu, kategoriji...',
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
                    onChanged: _onSearchChanged,
                    onSubmitted: (_) => _handleSearch(),
                  ),
                ),
                const SizedBox(width: 12),
                if (canCreateEvents)
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _handleCreateEvent,
                    tooltip: 'Kreiraj event',
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: _selectedCategory != null || _selectedCity != null || _selectedStatus != null,
                  label: Text('${[_selectedCategory, _selectedCity, _selectedStatus].where((f) => f != null).length}'),
                  child: IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: _handleFilter,
                    tooltip: 'Filtriraj evente',
                    style: IconButton.styleFrom(
                      backgroundColor: (_selectedCategory != null || _selectedCity != null || _selectedStatus != null)
                          ? Theme.of(context).colorScheme.primaryContainer
                          : const Color(0xFFF5F5F5),
                      foregroundColor: (_selectedCategory != null || _selectedCity != null || _selectedStatus != null)
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : const Color(0xFF212121),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => context.read<EventProvider>().refreshEvents(useAdminEndpoint: true),
                  tooltip: 'Osvježi evente',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF5F5F5),
                    foregroundColor: const Color(0xFF212121),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          if (_selectedCategory != null || _selectedCity != null || _selectedStatus != null || _searchController.text.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_searchController.text.isNotEmpty)
                    Chip(
                      avatar: const Icon(Icons.search, size: 16),
                      label: Text('Pretraga: "${_searchController.text}"'),
                      onDeleted: () {
                        _searchController.clear();
                        _handleSearch();
                      },
                      deleteIcon: const Icon(Icons.close, size: 18),
                    ),
                  if (_selectedCategory != null)
                    Chip(
                      avatar: const Icon(Icons.category, size: 16),
                      label: Text('Kategorija: $_selectedCategory'),
                      onDeleted: () {
                        setState(() => _selectedCategory = null);
                        _handleSearch();
                      },
                      deleteIcon: const Icon(Icons.close, size: 18),
                    ),
                  if (_selectedCity != null)
                    Chip(
                      avatar: const Icon(Icons.location_city, size: 16),
                      label: Text('Grad: $_selectedCity'),
                      onDeleted: () {
                        setState(() => _selectedCity = null);
                        _handleSearch();
                      },
                      deleteIcon: const Icon(Icons.close, size: 18),
                    ),
                  if (_selectedStatus != null)
                    Chip(
                      avatar: const Icon(Icons.info, size: 16),
                      label: Text('Status: $_selectedStatus'),
                      onDeleted: () {
                        setState(() => _selectedStatus = null);
                        _handleSearch();
                      },
                      deleteIcon: const Icon(Icons.close, size: 18),
                    ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _selectedCategory = null;
                        _selectedCity = null;
                        _selectedStatus = null;
                      });
                      _handleSearch();
                    },
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Obriši sve filtere'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Consumer<EventProvider>(
              builder: (context, eventProvider, child) {
                if (eventProvider.isLoading && eventProvider.events == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (eventProvider.error != null && eventProvider.events == null) {
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
                          'Error loading events',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          eventProvider.error!,
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => eventProvider.refreshEvents(useAdminEndpoint: true),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                final events = eventProvider.events?.items ?? [];
                if (events.isEmpty) {
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
                          'No events found',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your first event to get started',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (canCreateEvents) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _handleCreateEvent,
                            icon: const Icon(Icons.add),
                            label: const Text('Create Event'),
                          ),
                        ],
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => eventProvider.refreshEvents(useAdminEndpoint: true),
                  child: GridView.builder(
                    controller: _scrollController,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.75,
                    ),
                    padding: const EdgeInsets.all(16),
                    itemCount: events.length + (eventProvider.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == events.length) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      final event = events[index];
                      return _EventCard(
                        event: event,
                        onTap: () => _handleEventTap(event),
                        onDelete: canCreateEvents
                            ? () => _handleDeleteEvent(event)
                            : null,
                        onEdit: canCreateEvents
                            ? () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        EventFormScreen(event: event),
                                  ),
                                ).then((_) {
                                  eventProvider.refreshEvents(useAdminEndpoint: true);
                                });
                              }
                            : null,
                      );
                    },
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
class _EventCard extends StatelessWidget {
  final EventDto event;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  const _EventCard({
    required this.event,
    required this.onTap,
    this.onDelete,
    this.onEdit,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = '${event.startsAt.day}/${event.startsAt.month}/${event.startsAt.year}';
    final timeFormat = '${event.startsAt.hour.toString().padLeft(2, '0')}:${event.startsAt.minute.toString().padLeft(2, '0')}';
    final lowestPrice = event.priceTiers.isNotEmpty
        ? event.priceTiers.map((tier) => tier.price).reduce((a, b) => a < b ? a : b)
        : 0.0;
    return Container(
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
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: event.coverImageUrl != null && event.coverImageUrl!.isNotEmpty
                    ? Image.network(
                        ApiClient.getImageUrl(event.coverImageUrl!) ?? '',
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _ImagePlaceholder(),
                      )
                    : _ImagePlaceholder(),
              ),
              if (onEdit != null || onDelete != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: PopupMenuButton<String>(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.more_vert,
                        size: 20,
                        color: Color(0xFF212121),
                      ),
                    ),
                    onSelected: (value) {
                      if (value == 'edit' && onEdit != null) {
                        onEdit!();
                      } else if (value == 'delete' && onDelete != null) {
                        onDelete!();
                      }
                    },
                    itemBuilder: (context) => [
                      if (onEdit != null)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                      if (onDelete != null)
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
                  ),
                ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: const Color(0xFF212121),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${event.venue}, ${event.city}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$dateFormat at $timeFormat',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (event.description != null && event.description!.isNotEmpty) ...[
                    Text(
                      event.description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _StatusChip(status: event.status),
                      _CategoryChip(category: event.category),
                    ],
                  ),
                  const Spacer(),
                  if (event.priceTiers.isNotEmpty) ...[
                    Text(
                      '${event.totalSold}/${event.totalCapacity} tickets sold',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (lowestPrice > 0)
                    Text(
                      'From ${lowestPrice.toStringAsFixed(2)} ${event.priceTiers.first.currency}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF212121),
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(
                    color: Color(0xFF212121),
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  'View Details',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF212121),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _ImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      color: const Color(0xFFE0E0E0),
      child: const Icon(
        Icons.event,
        size: 64,
        color: Color(0xFF9E9E9E),
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
      case 'published':
        color = Colors.green;
        break;
      case 'draft':
        color = Colors.grey;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      case 'archived':
        color = Colors.orange;
        break;
      default:
        color = Colors.blue;
    }
    return Chip(
      label: Text(status),
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(color: color, fontSize: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
class _CategoryChip extends StatelessWidget {
  final String category;
  const _CategoryChip({required this.category});
  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(category),
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onPrimaryContainer,
        fontSize: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
class _FilterDialog extends StatefulWidget {
  final String? category;
  final String? city;
  final String? status;
  final Function(String?, String?, String?) onApply;
  const _FilterDialog({
    required this.category,
    required this.city,
    required this.status,
    required this.onApply,
  });
  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}
class _FilterDialogState extends State<_FilterDialog> {
  late String? _category;
  late String? _city;
  late String? _status;
  final List<String> _commonCategories = [
    'Muzika',
    'Sport',
    'Kultura',
    'Zabava',
    'Biznis',
    'Obrazovanje',
    'Tehnologija',
    'Umjetnost',
    'Film',
    'Festival',
  ];
  final List<String> _commonCities = [
    'Sarajevo',
    'Banja Luka',
    'Tuzla',
    'Zenica',
    'Mostar',
    'Bijeljina',
    'Brčko',
    'Prijedor',
  ];
  @override
  void initState() {
    super.initState();
    _category = widget.category;
    _city = widget.city;
    _status = widget.status;
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filtriraj evente'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kategorija',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _commonCategories.map((cat) {
                final isSelected = _category == cat;
                return FilterChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _category = selected ? cat : null;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Grad',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _commonCities.map((city) {
                final isSelected = _city == city;
                return FilterChip(
                  label: Text(city),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _city = selected ? city : null;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Status',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Svi')),
                DropdownMenuItem(value: 'Draft', child: Text('Draft')),
                DropdownMenuItem(value: 'Published', child: Text('Published')),
                DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
                DropdownMenuItem(value: 'Archived', child: Text('Archived')),
              ],
              onChanged: (value) {
                setState(() {
                  _status = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _category = null;
              _city = null;
              _status = null;
            });
          },
          child: const Text('Obriši'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Otkaži'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApply(_category, _city, _status);
            Navigator.of(context).pop();
          },
          child: const Text('Primijeni'),
        ),
      ],
    );
  }
}