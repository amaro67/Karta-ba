import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/auth_provider.dart';
import '../providers/admin_provider.dart';
import '../screens/admin/user_detail_screen.dart';
import '../screens/admin/event_detail_screen.dart';
import 'admin_sidebar.dart';
import '../screens/admin/user_management_screen.dart';
import '../screens/admin/event_management_screen.dart';
import '../screens/admin/order_management_screen.dart';
import '../screens/admin/ticket_management_screen.dart';
import '../config/theme.dart';
import '../utils/api_client.dart';
class AdminLayout extends StatefulWidget {
  const AdminLayout({super.key});
  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}
class _AdminLayoutState extends State<AdminLayout> {
  int _selectedIndex = 0;
  Timer? _notificationTimer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);
      adminProvider.loadUnverifiedOrganizers();
      _notificationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        if (mounted) {
          adminProvider.loadUnverifiedOrganizers();
        } else {
          timer.cancel();
        }
      });
    });
  }
  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }
  void _onItemSelected(int index) {
    _navigateToIndex(index);
  }
  void _navigateToIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  Widget _getScreenForIndex(int index) {
    switch (index) {
      case 0:
        return AdminDashboardContent(
          onSeeAllEvents: () => _navigateToIndex(2),
        );
      case 1:
        return const UserManagementScreen();
      case 2:
        return const EventManagementScreen();
      case 3:
        return const OrderManagementScreen();
      case 4:
        return const TicketManagementScreen();
      default:
        return AdminDashboardContent(
          onSeeAllEvents: () => _navigateToIndex(2),
        );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser!;
        return Scaffold(
          body: Row(
            children: [
              AdminSidebar(
                selectedIndex: _selectedIndex,
                onItemSelected: _onItemSelected,
              ),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _getTitleForIndex(_selectedIndex),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade900,
                            ),
                          ),
                          Row(
                            children: [
                              Consumer<AdminProvider>(
                                builder: (context, adminProvider, child) {
                                  final count = adminProvider.unverifiedOrganizersCount;
                                  return Stack(
                                    clipBehavior: Clip.none,
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
                                          onPressed: () {
                                            _showNotificationsDialog(context, adminProvider);
                                          },
                                          tooltip: 'Notifications',
                                        ),
                                      ),
                                      if (count > 0)
                                        Positioned(
                                          right: 0,
                                          top: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                            constraints: const BoxConstraints(
                                              minWidth: 18,
                                              minHeight: 18,
                                            ),
                                            child: Center(
                                              child: Text(
                                                count > 99 ? '99+' : count.toString(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
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
                                    authProvider.logout();
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Theme.of(context).colorScheme.primary,
                                        child: Text(
                                          user.firstName.isNotEmpty
                                              ? user.firstName[0].toUpperCase()
                                              : 'A',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
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
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _getScreenForIndex(_selectedIndex),
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
  void _showNotificationsDialog(BuildContext context, AdminProvider adminProvider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.orange),
            SizedBox(width: 8),
            Text('Neverifikovani organizatori'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: adminProvider.isLoadingUnverifiedOrganizers
              ? const Center(child: CircularProgressIndicator())
              : adminProvider.unverifiedOrganizers.isEmpty
                  ? const Text('Nema organizatora koji čekaju verifikaciju.')
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: adminProvider.unverifiedOrganizers.length,
                      itemBuilder: (context, index) {
                        final organizer = adminProvider.unverifiedOrganizers[index];
                        final firstName = organizer['firstName'] as String? ?? '';
                        final lastName = organizer['lastName'] as String? ?? '';
                        final email = organizer['email'] as String? ?? '';
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              firstName.isNotEmpty
                                  ? firstName[0].toUpperCase()
                                  : email.isNotEmpty
                                      ? email[0].toUpperCase()
                                      : '?',
                            ),
                          ),
                          title: Text('$firstName $lastName'.trim().isEmpty ? email : '$firstName $lastName'),
                          subtitle: Text(email),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => UserDetailScreen(
                                  user: organizer,
                                  isOwnProfile: false,
                                ),
                              ),
                            ).then((_) {
                              adminProvider.loadUnverifiedOrganizers();
                            });
                          },
                        );
                      },
                    ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Zatvori'),
          ),
        ],
      ),
    );
  }
  String _getTitleForIndex(int index) {
    switch (index) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'User Management';
      case 2:
        return 'Event Management';
      case 3:
        return 'Order Management';
      case 4:
        return 'Ticket Management';
      default:
        return 'Dashboard';
    }
  }
}
class AdminDashboardContent extends StatefulWidget {
  final VoidCallback? onSeeAllEvents;
  const AdminDashboardContent({super.key, this.onSeeAllEvents});
  @override
  State<AdminDashboardContent> createState() => _AdminDashboardContentState();
}
class _AdminDashboardContentState extends State<AdminDashboardContent> {
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
        return SingleChildScrollView(
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
                              'Welcome, ${authProvider.currentUser!.fullName}!',
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
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.error_outline, color: Colors.red.shade700),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Greška pri učitavanju statistika',
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  adminProvider.statsError ?? 'Nepoznata greška',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : adminProvider.dashboardStats == null
                          ? const SizedBox.shrink()
                          : _buildStatsRow(context, adminProvider.dashboardStats),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Upcoming Events',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      if (widget.onSeeAllEvents != null) {
                        widget.onSeeAllEvents!();
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const EventManagementScreen(),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('See all'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              adminProvider.isLoadingEvents
                  ? const Center(child: CircularProgressIndicator())
                  : adminProvider.eventsError != null
                      ? Card(
                          color: Colors.orange.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.orange.shade700),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Nema dostupnih nadolazećih događaja',
                                        style: TextStyle(
                                          color: Colors.orange.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Nadolazeći događaji će biti prikazani kada budu dostupni.',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : adminProvider.upcomingEvents.isEmpty
                          ? Card(
                              color: Colors.grey.shade100,
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.event_busy,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Nema nadolazećih događaja',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Trenutno nema događaja koji dolaze u bliskoj budućnosti.',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Colors.grey.shade600,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : SizedBox(
                              height: 200,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: adminProvider.upcomingEvents.length,
                                itemBuilder: (context, index) {
                                  final event = adminProvider.upcomingEvents[index];
                                  return _UpcomingEventCard(event: event);
                                },
                              ),
                            ),
            ],
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
  Widget _buildStatsRow(BuildContext context, Map<String, dynamic>? stats) {
    final totalRevenue = _getNumericValue(stats, 'totalRevenue') ?? 
                         _getNumericValue(stats, 'TotalRevenue') ?? 0.0;
    final numberOfEvents = _getNumericValue(stats, 'numberOfEvents')?.toInt() ?? 
                          _getNumericValue(stats, 'NumberOfEvents')?.toInt() ?? 0;
    final totalUsers = _getNumericValue(stats, 'totalUsersRegistered')?.toInt() ?? 
                      _getNumericValue(stats, 'TotalUsersRegistered')?.toInt() ?? 0;
    final kartaBaProfit = _getNumericValue(stats, 'kartaBaProfit') ?? 
                         _getNumericValue(stats, 'KartaBaProfit') ?? 0.0;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.attach_money,
            title: 'Total Revenue',
            value: _formatCurrency(totalRevenue),
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            icon: Icons.event,
            title: 'Events',
            value: '$numberOfEvents',
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            icon: Icons.people,
            title: 'Users',
            value: '$totalUsers',
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            icon: Icons.trending_up,
            title: 'karta.ba Profit',
            value: _formatCurrency(kartaBaProfit),
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }
  num? _getNumericValue(Map<String, dynamic>? map, String key) {
    if (map == null) return null;
    final value = map[key];
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) {
      final parsed = num.tryParse(value);
      return parsed;
    }
    return null;
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
                      _buildPdfTableCell('Metric', isHeader: true),
                      _buildPdfTableCell('Value', isHeader: true),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildPdfTableCell('Total Revenue'),
                      _buildPdfTableCell(_formatCurrency(stats['totalRevenue'] ?? stats['TotalRevenue'] ?? 0.0)),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildPdfTableCell('Number of Events'),
                      _buildPdfTableCell('${stats['numberOfEvents'] ?? stats['NumberOfEvents'] ?? 0}'),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildPdfTableCell('Total Users Registered'),
                      _buildPdfTableCell('${stats['totalUsersRegistered'] ?? stats['TotalUsersRegistered'] ?? 0}'),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildPdfTableCell('karta.ba Profit'),
                      _buildPdfTableCell(_formatCurrency(stats['kartaBaProfit'] ?? stats['KartaBaProfit'] ?? 0.0)),
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

      // Save PDF directly to downloads folder
      final fileName = 'karta_dashboard_report_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf';
      final bytes = await pdf.save();
      
      // Use Printing.sharePdf to save/download the PDF
      await Printing.sharePdf(
        bytes: bytes,
        filename: fileName,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF report downloaded successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
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

  pw.Widget _buildPdfTableCell(String text, {bool isHeader = false}) {
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
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
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
  num? _getNumericValue(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) {
      final parsed = num.tryParse(value);
      return parsed;
    }
    return null;
  }
  @override
  Widget build(BuildContext context) {
    try {
      final dateFormat = DateFormat('EEEE - d.M.yyyy - HH:mm');
      final startsAtStr = event['startsAt'] as String? ?? event['StartsAt'] as String?;
      if (startsAtStr == null) {
        return const SizedBox.shrink();
      }
      final startsAt = DateTime.parse(startsAtStr);
      final priceFrom = _getNumericValue(event, 'priceFrom') ?? 
                        _getNumericValue(event, 'PriceFrom') ?? 0;
      final currency = event['currency'] as String? ?? 
                      event['Currency'] as String? ?? 'BAM';
      return Container(
        width: 300,
        margin: const EdgeInsets.only(right: 16),
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () => _openEventDetails(context),
            child: IntrinsicHeight(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEventImage(),
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event['title'] as String? ?? event['Title'] as String? ?? 'Event',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFormat.format(startsAt),
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${event['location'] as String? ?? event['Location'] as String? ?? ''}, ${event['city'] as String? ?? event['City'] as String? ?? ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'From $priceFrom $currency',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
  Widget _buildEventImage() {
    final coverImageUrl = event['coverImageUrl'] ?? event['CoverImageUrl'];
    return Container(
      height: 80,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
      ),
      child: coverImageUrl != null && (coverImageUrl as String).isNotEmpty
          ? ClipRRect(
              child: Image.network(
                ApiClient.getImageUrl(coverImageUrl as String) ?? '',
                width: double.infinity,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.image_outlined,
                    size: 40,
                    color: Colors.grey,
                  );
                },
              ),
            )
          : const Icon(Icons.event, size: 40, color: Colors.grey),
    );
  }
}