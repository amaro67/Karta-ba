import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:karta_shared/karta_shared.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'providers/reviews_provider.dart';
import 'providers/notification_provider.dart' as mobile_notif;
const bool isDemoMode = false;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: 'assets/.env');
  } catch (e) {
    print('Warning: Could not load .env file, using hardcoded values');
  }
  final stripeKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'];
  if (stripeKey == null || stripeKey.isEmpty) {
    throw Exception('STRIPE_PUBLISHABLE_KEY is not set in .env file');
  }
  stripe.Stripe.publishableKey = stripeKey;
  stripe.Stripe.merchantIdentifier = 'merchant.com.karta.ba';
  await initializeDateFormatting('bs', null);
  ApiClient.clientType = 'karta_mobile';
  runApp(const KartaMobileApp());
}
class KartaMobileApp extends StatelessWidget {
  const KartaMobileApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CategoriesProvider()),
        ChangeNotifierProxyProvider<AuthProvider, VenuesProvider>(
          create: (context) {
            final provider = VenuesProvider();
            final auth = context.read<AuthProvider>();
            provider.setToken(auth.accessToken);
            return provider;
          },
          update: (context, auth, previous) {
            final provider = previous ?? VenuesProvider();
            provider.setToken(auth.accessToken);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, EventProvider>(
          create: (context) => EventProvider(context.read<AuthProvider>()),
          update: (context, auth, previous) => EventProvider(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, TicketProvider>(
          create: (context) => TicketProvider(context.read<AuthProvider>()),
          update: (context, auth, previous) => TicketProvider(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, FavoritesProvider>(
          create: (context) {
            final provider = FavoritesProvider();
            final auth = context.read<AuthProvider>();
            provider.setToken(auth.accessToken);
            if (auth.isAuthenticated) {
              provider.loadFavoriteIds();
            }
            return provider;
          },
          update: (context, auth, previous) {
            final provider = previous ?? FavoritesProvider();
            provider.setToken(auth.accessToken);
            if (auth.isAuthenticated && previous?.favoriteIds.isEmpty == true) {
              provider.loadFavoriteIds();
            }
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, ReviewsProvider>(
          create: (context) => ReviewsProvider(context.read<AuthProvider>()),
          update: (context, auth, previous) => previous ?? ReviewsProvider(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, mobile_notif.NotificationProvider>(
          create: (context) => mobile_notif.NotificationProvider(context.read<AuthProvider>()),
          update: (context, auth, previous) => previous ?? mobile_notif.NotificationProvider(auth),
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return MaterialApp(
            title: 'Karta.ba',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: const SplashScreen(),
            routes: AppRoutes.routes,
          );
        },
      ),
    );
  }
}
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }
  Future<void> _initializeApp() async {
    if (isDemoMode) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      return;
    }
    final authProvider = context.read<AuthProvider>();
    await authProvider.initialize();
    if (!mounted) return;
    if (authProvider.isAuthenticated) {
      final user = authProvider.currentUser;
      if (user != null) {
        if (user.roles.contains('Scanner')) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.scannerHome);
        } else {
          Navigator.of(context).pushReplacementNamed(AppRoutes.home);
        }
      } else {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      }
    } else {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'karta.ba',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}