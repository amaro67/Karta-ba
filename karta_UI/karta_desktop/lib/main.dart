import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/event_provider.dart';
import 'providers/order_provider.dart';
import 'providers/ticket_provider.dart';
import 'providers/organizer_provider.dart';
import 'providers/scanner_provider.dart';
import 'providers/organizer_sales_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/admin/user_detail_screen.dart';
import 'widgets/admin_layout.dart';
import 'widgets/organizer_layout.dart';
import 'widgets/karta_logo.dart';
import 'config/theme.dart';
void main() {
  runApp(const KartaDesktopApp());
}
class KartaDesktopApp extends StatelessWidget {
  const KartaDesktopApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, AdminProvider>(
          create: (_) => AdminProvider(AuthProvider()),
          update: (_, authProvider, adminProvider) {
            adminProvider ??= AdminProvider(authProvider);
            adminProvider.updateAuthProvider(authProvider);
            return adminProvider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, EventProvider>(
          create: (_) => EventProvider(AuthProvider()),
          update: (_, authProvider, __) => EventProvider(authProvider),
        ),
        ChangeNotifierProxyProvider<AuthProvider, OrderProvider>(
          create: (_) => OrderProvider(AuthProvider()),
          update: (_, authProvider, __) => OrderProvider(authProvider),
        ),
        ChangeNotifierProxyProvider<AuthProvider, TicketProvider>(
          create: (_) => TicketProvider(AuthProvider()),
          update: (_, authProvider, __) => TicketProvider(authProvider),
        ),
        ChangeNotifierProxyProvider<AuthProvider, OrganizerProvider>(
          create: (_) => OrganizerProvider(AuthProvider()),
          update: (_, authProvider, organizerProvider) {
            organizerProvider ??= OrganizerProvider(authProvider);
            organizerProvider.updateAuthProvider(authProvider);
            return organizerProvider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, ScannerProvider>(
          create: (_) => ScannerProvider(AuthProvider()),
          update: (_, authProvider, scannerProvider) {
            scannerProvider ??= ScannerProvider(authProvider);
            scannerProvider.updateAuthProvider(authProvider);
            return scannerProvider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, OrganizerSalesProvider>(
          create: (_) => OrganizerSalesProvider(AuthProvider()),
          update: (_, authProvider, salesProvider) {
            salesProvider ??= OrganizerSalesProvider(authProvider);
            salesProvider.updateAuthProvider(authProvider);
            return salesProvider;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Karta Desktop',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AppWrapper(),
      ),
    );
  }
}
class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});
  @override
  State<AppWrapper> createState() => _AppWrapperState();
}
class _AppWrapperState extends State<AppWrapper> {
  bool _isInitializing = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAuth();
    });
  }
  Future<void> _initializeAuth() async {
    if (_isInitializing) {
      print('⚠️ Already initializing, skipping...');
      return;
    }
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser != null && authProvider.accessToken != null) {
      print('✅ Auth already initialized, user: ${authProvider.currentUser?.email}');
      return;
    }
    print('🔵 Initializing auth from storage...');
    _isInitializing = true;
    try {
      await authProvider.initialize();
      print('✅ Auth initialization complete');
    } catch (e) {
      print('🔴 Error initializing auth: $e');
    } finally {
      _isInitializing = false;
    }
  }
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (_isInitializing && authProvider.currentUser == null) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing...'),
                ],
              ),
            ),
          );
        }
        if (!authProvider.isAuthenticated) {
          return const LoginScreen();
        }
        final user = authProvider.currentUser!;
        if (user.isAdmin) {
          return const AdminLayout();
        }
        if (user.isOrganizer) {
          return const OrganizerLayout();
        }
        return const MainApp();
      },
    );
  }
}
class MainApp extends StatefulWidget {
  const MainApp({super.key});
  @override
  State<MainApp> createState() => _MainAppState();
}
class _MainAppState extends State<MainApp> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser!;
        return Scaffold(
          appBar: AppBar(
            title: Text('Karta Desktop - ${user.fullName}'),
            actions: [
              PopupMenuButton<String>(
                key: ValueKey('user_profile_${authProvider.userUpdateCounter}'),
                onSelected: (value) async {
                  if (value == 'profile') {
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final user = authProvider.currentUser;
                    if (user != null) {
                      await Navigator.of(context).push(
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
                      print('🔵 MainApp: Returned from profile, refreshing user data...');
                      await authProvider.refreshCurrentUser();
                      print('✅ MainApp: User data refreshed - ${authProvider.currentUser?.firstName} ${authProvider.currentUser?.lastName}');
                    }
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
                  const PopupMenuItem(
                    value: 'settings',
                    child: ListTile(
                      leading: Icon(Icons.settings),
                      title: Text('Settings'),
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
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const KartaLogo(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  showIcon: true,
                ),
                const SizedBox(height: 24),
                Text(
                  'Welcome to Karta Desktop!',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Role: ${user.roles.join(', ')}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                if (user.isAdmin) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                    },
                    icon: const Icon(Icons.admin_panel_settings),
                    label: const Text('Admin Dashboard'),
                  ),
                  const SizedBox(height: 16),
                ],
                if (user.isOrganizer) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                    },
                    icon: const Icon(Icons.event),
                    label: const Text('Event Management'),
                  ),
                  const SizedBox(height: 16),
                ],
                ElevatedButton.icon(
                  onPressed: () {
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final user = authProvider.currentUser;
                    if (user != null) {
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
                    }
                  },
                  icon: const Icon(Icons.person),
                  label: const Text('My Profile'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}