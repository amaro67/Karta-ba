import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_provider.dart';
import '../../config/theme.dart';
import '../../utils/api_client.dart';
import 'event_detail_screen.dart';
import 'user_detail_screen.dart';
import 'user_management_screen.dart';
import 'event_management_screen.dart';
import 'order_management_screen.dart';
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}
class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);
      adminProvider.refreshDashboard();
    });
  }
  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, AdminProvider>(
      builder: (context, authProvider, adminProvider, child) {
        print('🔄 Consumer2 builder called - upcomingEvents: ${adminProvider.upcomingEvents.length}, isLoading: ${adminProvider.isLoadingEvents}');
        final user = authProvider.currentUser!;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Admin Dashboard'),
            actions: [
              PopupMenuButton<String>(
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
                    authProvider.logout();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'profile',
                    child: ListTile(
                      leading: Icon(Icons.person),
                      title: Text('Profile'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'logout',
                    child: ListTile(
                      leading: Icon(Icons.logout),
                      title: Text('Logout'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.admin_panel_settings,
                            size: 32,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome, ${user.fullName}!',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Administrator Panel',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Quick Stats',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _generatePdfReport(context, adminProvider),
                          icon: const Icon(Icons.picture_as_pdf, size: 20),
                          label: const Text('Download PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7B2CBF), // Purple color
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () {
                            adminProvider.refreshDashboard();
                          },
                          tooltip: 'Refresh',
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                adminProvider.isLoadingStats
                    ? const Center(child: CircularProgressIndicator())
                    : adminProvider.statsError != null
                        ? Card(
                            color: Colors.red.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Error loading stats: ${adminProvider.statsError}',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.attach_money,
                                  title: 'Total Revenue',
                                  value: _formatCurrency(
                                    adminProvider.dashboardStats?['totalRevenue'] ?? 0.0,
                                  ),
                                  color: AppTheme.primaryColor,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => const OrderManagementScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.event,
                                  title: 'Events',
                                  value: '${adminProvider.dashboardStats?['numberOfEvents'] ?? 0}',
                                  color: AppTheme.primaryColor,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => const EventManagementScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.people,
                                  title: 'Users',
                                  value: '${adminProvider.dashboardStats?['totalUsersRegistered'] ?? 0}',
                                  color: AppTheme.primaryColor,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => const UserManagementScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.trending_up,
                                  title: 'karta.ba Profit',
                                  value: _formatCurrency(
                                    adminProvider.dashboardStats?['kartaBaProfit'] ?? 0.0,
                                  ),
                                  color: AppTheme.primaryColor,
                                  onTap: () {
                                  },
                                ),
                              ),
                            ],
                          ),
                const SizedBox(height: 32),
                Builder(
                  builder: (context) {
                    print('📍 Upcoming Events Section - isLoading: ${adminProvider.isLoadingEvents}, count: ${adminProvider.upcomingEvents.length}, error: ${adminProvider.eventsError}');
                    return Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Upcoming Events',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const EventManagementScreen(),
                                  ),
                                );
                              },
                              child: const Text('See all'),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                adminProvider.isLoadingEvents
                    ? const Center(child: CircularProgressIndicator())
                    : adminProvider.eventsError != null
                        ? Card(
                            color: Colors.red.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'Error: ${adminProvider.eventsError}',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          )
                        : adminProvider.upcomingEvents.isEmpty
                            ? Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    'No upcoming events',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              )
                            : Builder(
                                builder: (context) {
                                  print('📋 Building ListView with ${adminProvider.upcomingEvents.length} events');
                                  return SizedBox(
                                    height: 200,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: adminProvider.upcomingEvents.length,
                                      itemBuilder: (context, index) {
                                        final event = adminProvider.upcomingEvents[index];
                                        print('🔨 Creating card for event #$index: ${event['title']}');
                                        return _UpcomingEventCard(event: event);
                                      },
                                    ),
                                  );
                                },
                              ),
                const SizedBox(height: 32),
                const SizedBox(height: 32),
                Text(
                  'Management',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 2.5,
                  children: [
                    _ManagementCard(
                      icon: Icons.people_outline,
                      title: 'User Management',
                      subtitle: 'Manage users and roles',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const UserManagementScreen(),
                          ),
                        );
                      },
                    ),
                    _ManagementCard(
                      icon: Icons.event_note,
                      title: 'Event Management',
                      subtitle: 'View and manage all events',
                      color: Colors.green,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const EventManagementScreen(),
                          ),
                        );
                      },
                    ),
                    _ManagementCard(
                      icon: Icons.assignment,
                      title: 'Order Management',
                      subtitle: 'View and manage orders',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const OrderManagementScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  String _formatCurrency(dynamic value) {
    if (value == null) return '0.00 BAM';
    final amount = value is int ? value.toDouble() : value as double;
    return '${amount.toStringAsFixed(2)} BAM';
  }

  Future<void> _generatePdfReport(BuildContext context, AdminProvider adminProvider) async {
    try {
      final stats = adminProvider.dashboardStats;
      if (stats == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No data available. Please refresh the dashboard first.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Create PDF document
      final pdf = pw.Document();
      final now = DateTime.now();
      final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              // Header
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Karta.ba Dashboard Report',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.purple,
                      ),
                    ),
                    pw.Text(
                      dateFormat.format(now),
                      style: pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Welcome Section
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Administrator Dashboard Report',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Generated on: ${dateFormat.format(now)}',
                      style: pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Quick Stats Section
              pw.Text(
                'Quick Statistics',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 16),

              // Stats Grid
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableCell('Metric', isHeader: true),
                      _buildTableCell('Value', isHeader: true),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildTableCell('Total Revenue'),
                      _buildTableCell(_formatCurrency(stats['totalRevenue'] ?? 0.0)),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildTableCell('Number of Events'),
                      _buildTableCell('${stats['numberOfEvents'] ?? 0}'),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildTableCell('Total Users Registered'),
                      _buildTableCell('${stats['totalUsersRegistered'] ?? 0}'),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildTableCell('karta.ba Profit'),
                      _buildTableCell(_formatCurrency(stats['kartaBaProfit'] ?? 0.0)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Summary
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.blue200),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Summary',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'This report contains the current statistics from the Karta.ba administrator dashboard. '
                      'The data includes total revenue, number of events, registered users, and platform profit.',
                      style: pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      // Close loading dialog
      Navigator.of(context).pop();

      // Show PDF preview and allow printing/saving
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF report generated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 14 : 12,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
class _UpcomingEventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  const _UpcomingEventCard({required this.event});
  String? _extractEventId() {
    final possibleKeys = ['id', 'Id', 'eventId', 'EventId'];
    for (final key in possibleKeys) {
      final value = event[key];
      if (value != null) {
        return value.toString();
      }
    }
    return null;
  }
  void _openEventDetails(BuildContext context) {
    final eventId = _extractEventId();
    if (eventId == null || eventId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open event details. Missing event ID.'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventDetailScreen(eventId: eventId),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    print('🏗️ Building _UpcomingEventCard for: ${event['title']}');
    try {
      final dateFormat = DateFormat('EEEE - d.M.yyyy - HH:mm');
      final startsAtStr = event['startsAt'] as String?;
      if (startsAtStr == null) {
        print('⚠️ No startsAt for event: ${event['title']}');
        return const SizedBox.shrink();
      }
      final startsAt = DateTime.parse(startsAtStr);
      final priceFrom = event['priceFrom'] as num? ?? 0;
      final currency = event['currency'] as String? ?? 'BAM';
      print('📅 Event details: $startsAt, From: $priceFrom $currency');
      return Container(
        width: 300,
        margin: const EdgeInsets.only(right: 16),
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () => _openEventDetails(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEventImage(event),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event['title'] as String? ?? 'Event',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dateFormat.format(startsAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${event['location'] as String? ?? ''}, ${event['city'] as String? ?? ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'From $priceFrom $currency',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      return Container(
        width: 300,
        margin: const EdgeInsets.only(right: 16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error loading event: $e'),
          ),
        ),
      );
    }
  }
  Widget _buildEventImage(Map<String, dynamic> event) {
    final coverImageUrl = event['coverImageUrl'];
    print('🖼️ Event: ${event['title']}, coverImageUrl: $coverImageUrl');
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: coverImageUrl != null && (coverImageUrl as String).isNotEmpty
          ? ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Builder(
                builder: (context) {
                  final fullUrl = ApiClient.getImageUrl(coverImageUrl as String) ?? '';
                  print('🖼️ Full image URL: $fullUrl');
                  return Image.network(
                    fullUrl,
                    width: double.infinity,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      print('🔴 Image load error for $fullUrl: $error');
                      return const Icon(
                        Icons.image_outlined,
                        size: 48,
                        color: Colors.grey,
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        print('✅ Image loaded successfully: $fullUrl');
                        return child;
                      }
                      print('⏳ Loading image: $fullUrl (${loadingProgress.cumulativeBytesLoaded}/${loadingProgress.expectedTotalBytes ?? "?"})');
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    },
                  );
                },
              ),
            )
          : Builder(
              builder: (context) {
                print('⚠️ No cover image for event: ${event['title']}');
                return const Icon(Icons.event, size: 48, color: Colors.grey);
              },
            ),
    );
  }
}
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback onTap;
  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _ManagementCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ManagementCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}