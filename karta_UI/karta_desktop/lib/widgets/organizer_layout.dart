import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../model/auth/user_info.dart';
import '../model/event/event_dto.dart';
import '../providers/auth_provider.dart';
import '../providers/event_provider.dart';
import '../providers/organizer_provider.dart';
import '../screens/organizer/organizer_scanners_screen.dart';
import '../screens/organizer/organizer_sales_screen.dart';
import '../screens/admin/event_detail_screen.dart';
import '../screens/admin/event_form_screen.dart';
import '../screens/admin/user_detail_screen.dart';
import '../utils/error_dialog.dart';
import 'organizer_sidebar.dart';
class OrganizerLayout extends StatefulWidget {
  const OrganizerLayout({super.key});
  @override
  State<OrganizerLayout> createState() => _OrganizerLayoutState();
}
mixin OrganizerEventActions<T extends StatefulWidget> on State<T> {
  Future<void> openCreateEventForm() async {
    final organizerProvider = context.read<OrganizerProvider>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const EventFormScreen(),
      ),
    );
    if (!mounted) return;
    await organizerProvider.refreshMyEvents();
  }
  Future<void> openEditEvent(EventDto event) async {
    final organizerProvider = context.read<OrganizerProvider>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventFormScreen(event: event),
      ),
    );
    if (!mounted) return;
    await organizerProvider.refreshMyEvents();
  }
  void openEventDetails(EventDto event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventDetailScreen(eventId: event.id),
      ),
    );
  }
  Future<void> deleteEvent(EventDto event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete event'),
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
    if (confirmed != true || !mounted) return;
    final eventProvider = context.read<EventProvider>();
    final success = await eventProvider.deleteEvent(event.id);
    if (!mounted) return;
    if (success) {
      final organizerProvider = context.read<OrganizerProvider>();
      await organizerProvider.refreshMyEvents();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event deleted successfully')),
      );
    } else {
      if (!mounted) return;
      ErrorDialog.show(
        context,
        title: 'Error',
        message: eventProvider.error ?? 'Failed to delete event',
      );
    }
  }
}
class _OrganizerLayoutState extends State<OrganizerLayout> {
  int _selectedIndex = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrganizerProvider>().loadMyEvents();
    });
  }
  void _handleNavigation(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser!;
        return Scaffold(
          body: Row(
            children: [
              OrganizerSidebar(
                selectedIndex: _selectedIndex,
                onItemSelected: _handleNavigation,
              ),
              Expanded(
                child: Column(
                  children: [
                    _OrganizerTopBar(
                      title: _getTitleForIndex(_selectedIndex),
                      user: user,
                      onLogout: authProvider.logout,
                    ),
                    Expanded(
                      child: _buildContent(),
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
  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return OrganizerDashboardContent(
          onCreateEvent: _openCreateEvent,
          onViewAllEvents: () => _handleNavigation(1),
        );
      case 1:
        return const OrganizerEventsScreen();
      case 2:
        return const OrganizerScannersScreen();
      case 3:
        return const OrganizerSalesScreen();
      default:
        return OrganizerDashboardContent(
          onCreateEvent: _openCreateEvent,
          onViewAllEvents: () => _handleNavigation(1),
        );
    }
  }
  Future<void> _openCreateEvent() async {
    final organizerProvider = context.read<OrganizerProvider>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const EventFormScreen(),
      ),
    );
    if (!mounted) return;
    await organizerProvider.refreshMyEvents();
  }
  String _getTitleForIndex(int index) {
    switch (index) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'My Events';
      case 2:
        return 'Scanners';
      case 3:
        return 'Sales';
      default:
        return 'Dashboard';
    }
  }
}
class _OrganizerTopBar extends StatelessWidget {
  final String title;
  final UserInfo user;
  final VoidCallback onLogout;
  const _OrganizerTopBar({
    required this.title,
    required this.user,
    required this.onLogout,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.notifications_outlined,
                    color: Colors.grey.shade700,
                    size: 20,
                  ),
                  onPressed: () {},
                  tooltip: 'Notifications',
                ),
              ),
              const SizedBox(width: 12),
              PopupMenuButton<String>(
                offset: const Offset(0, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) {
                  if (value == 'profile') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => UserDetailScreen(
                          isOwnProfile: true,
                          user: {
                            'id': user.id,
                            'email': user.email,
                            'firstName': user.firstName,
                            'lastName': user.lastName,
                            'emailConfirmed': user.emailConfirmed,
                            'roles': user.roles,
                          },
                        ),
                      ),
                    );
                  } else if (value == 'logout') {
                    onLogout();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, size: 20, color: Colors.grey.shade700),
                        const SizedBox(width: 12),
                        Text(
                          'Profile',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 20, color: Colors.red.shade600),
                        const SizedBox(width: 12),
                        Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        user.fullName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
class OrganizerDashboardContent extends StatefulWidget {
  final VoidCallback? onCreateEvent;
  final VoidCallback? onViewAllEvents;
  const OrganizerDashboardContent({
    super.key,
    this.onCreateEvent,
    this.onViewAllEvents,
  });
  @override
  State<OrganizerDashboardContent> createState() => _OrganizerDashboardContentState();
}
class _OrganizerDashboardContentState extends State<OrganizerDashboardContent> with OrganizerEventActions {
  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, OrganizerProvider>(
      builder: (context, authProvider, organizerProvider, child) {
        final user = authProvider.currentUser!;
        final events = organizerProvider.myEvents;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(
                          Icons.event_available,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back, ${user.fullName}',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage your events, sales and attendees from one place.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: _OrganizerStatCard(
                      label: 'Total events',
                      value: organizerProvider.totalEvents.toString(),
                      icon: Icons.event,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _OrganizerStatCard(
                      label: 'Published',
                      value: organizerProvider.publishedEvents.toString(),
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _OrganizerStatCard(
                      label: 'Drafts',
                      value: organizerProvider.draftEvents.toString(),
                      icon: Icons.edit,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _OrganizerStatCard(
                      label: 'Upcoming',
                      value: organizerProvider.upcomingEventsCount.toString(),
                      icon: Icons.schedule,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My events',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: widget.onViewAllEvents,
                        child: const Text('See all'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: widget.onCreateEvent ?? openCreateEventForm,
                        icon: const Icon(Icons.add),
                        label: const Text('Create event'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _OrganizerEventsSection(
                isLoading: organizerProvider.isLoadingMyEvents,
                error: organizerProvider.myEventsError,
                events: events,
                onRefresh: organizerProvider.refreshMyEvents,
                onCreateEvent: widget.onCreateEvent ?? openCreateEventForm,
                onDelete: deleteEvent,
                onEdit: openEditEvent,
                onView: openEventDetails,
                embedInScroll: true,
              ),
            ],
          ),
        );
      },
    );
  }
}
class OrganizerEventsScreen extends StatefulWidget {
  const OrganizerEventsScreen({super.key});
  @override
  State<OrganizerEventsScreen> createState() => _OrganizerEventsScreenState();
}
class _OrganizerEventsScreenState extends State<OrganizerEventsScreen> with OrganizerEventActions {
  @override
  Widget build(BuildContext context) {
    return Consumer<OrganizerProvider>(
      builder: (context, organizerProvider, child) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All events',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  FilledButton.icon(
                    onPressed: openCreateEventForm,
                    icon: const Icon(Icons.add),
                    label: const Text('New event'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _OrganizerEventsSection(
                  isLoading: organizerProvider.isLoadingMyEvents,
                  error: organizerProvider.myEventsError,
                  events: organizerProvider.myEvents,
                  onRefresh: organizerProvider.refreshMyEvents,
                  onCreateEvent: openCreateEventForm,
                  onDelete: deleteEvent,
                  onEdit: openEditEvent,
                  onView: openEventDetails,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
class _OrganizerEventsSection extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final List<EventDto> events;
  final Future<void> Function()? onRefresh;
  final VoidCallback onCreateEvent;
  final void Function(EventDto) onView;
  final void Function(EventDto) onEdit;
  final void Function(EventDto) onDelete;
  final bool embedInScroll;
  const _OrganizerEventsSection({
    required this.isLoading,
    required this.error,
    required this.events,
    required this.onRefresh,
    required this.onCreateEvent,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    this.embedInScroll = false,
  });
  @override
  Widget build(BuildContext context) {
    if (isLoading && events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && events.isEmpty) {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700, size: 32),
              const SizedBox(height: 12),
              Text(
                error!,
                style: TextStyle(color: Colors.red.shade700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: onRefresh == null ? null : () => onRefresh!.call(),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    if (events.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_busy, size: 48, color: Colors.grey.shade500),
              const SizedBox(height: 16),
              Text(
                'No events yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Create your first event to get started.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onCreateEvent,
                icon: const Icon(Icons.add),
                label: const Text('Create event'),
              ),
            ],
          ),
        ),
      );
    }
    final grid = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount = 1;
        if (width >= 1400) {
          crossAxisCount = 3;
        } else if (width >= 900) {
          crossAxisCount = 2;
        }
        return GridView.builder(
          shrinkWrap: embedInScroll,
          physics: embedInScroll
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.4,
          ),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            return _OrganizerEventCard(
              event: event,
              onView: () => onView(event),
              onEdit: () => onEdit(event),
              onDelete: () => onDelete(event),
            );
          },
        );
      },
    );
    if (embedInScroll) {
      return grid;
    }
    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      child: grid,
    );
  }
}
class _OrganizerEventCard extends StatelessWidget {
  final EventDto event;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _OrganizerEventCard({
    required this.event,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d. MMM yyyy • HH:mm');
    final statusColor = _statusColor(event.status, context);
    final lowestPrice = event.priceTiers.isNotEmpty
        ? event.priceTiers.map((tier) => tier.price).reduce((a, b) => a < b ? a : b)
        : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'view':
                        onView();
                        break;
                      case 'edit':
                        onEdit();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: ListTile(
                        leading: Icon(Icons.visibility_outlined),
                        title: Text('View'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Delete'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                event.status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateFormat.format(event.startsAt),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${event.venue}, ${event.city}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _EventMetric(
                  label: 'Tickets sold',
                  value: '${event.totalSold}/${event.totalCapacity}',
                  icon: Icons.confirmation_number_outlined,
                ),
                _EventMetric(
                  label: 'Available',
                  value: '${event.totalAvailable}',
                  icon: Icons.event_available,
                ),
                _EventMetric(
                  label: 'Price from',
                  value: '${lowestPrice.toStringAsFixed(2)} BAM',
                  icon: Icons.attach_money,
                ),
              ],
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: TextButton(
                onPressed: onView,
                child: const Text('View details'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Color _statusColor(String status, BuildContext context) {
    switch (status.toLowerCase()) {
      case 'published':
        return Colors.green.shade600;
      case 'draft':
        return Colors.orange.shade600;
      case 'archived':
        return Colors.red.shade600;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }
}
class _EventMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _EventMetric({
    required this.label,
    required this.value,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}
class _OrganizerStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _OrganizerStatCard({
    required this.label,
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
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
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