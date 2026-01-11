import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:karta_shared/karta_shared.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'config/theme.dart';
import 'config/routes.dart';
const bool isDemoMode = false;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: 'assets/.env');
  } catch (e) {
    print('Warning: Could not load .env file, using hardcoded values');
  }
  stripe.Stripe.publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? 
      'pk_test_51S1vuqRtea3eAVbD0w930SERvYaN3agPwsDCxH0Dl5sCe5fxUPcujcWSL4LZDyNNG3eADETOL5DhdxSEqXvuwnHJ00RuqVEpYt';
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
        ChangeNotifierProxyProvider<AuthProvider, EventProvider>(
          create: (context) => EventProvider(context.read<AuthProvider>()),
          update: (context, auth, previous) => EventProvider(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, TicketProvider>(
          create: (context) => TicketProvider(context.read<AuthProvider>()),
          update: (context, auth, previous) => TicketProvider(auth),
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