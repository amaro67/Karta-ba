import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/user/home_screen.dart';
import '../screens/user/event_detail_screen.dart';
import '../screens/user/checkout_screen.dart';
import '../screens/user/ticket_list_screen.dart';
import '../screens/user/ticket_detail_screen.dart';
import '../screens/user/my_events_screen.dart';
import '../screens/user/user_profile_screen.dart';
import '../screens/scanner/scanner_home_screen.dart';
import '../screens/scanner/qr_scanner_screen.dart';
class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String eventDetail = '/event-detail';
  static const String checkout = '/checkout';
  static const String tickets = '/tickets';
  static const String ticketDetail = '/ticket-detail';
  static const String myEvents = '/my-events';
  static const String profile = '/profile';
  static const String scannerHome = '/scanner-home';
  static const String qrScanner = '/qr-scanner';
  static Map<String, WidgetBuilder> routes = {
    login: (context) => const LoginScreen(),
    register: (context) => const RegisterScreen(),
    home: (context) => const HomeScreen(),
    eventDetail: (context) => const EventDetailScreen(),
    checkout: (context) => const CheckoutScreen(),
    tickets: (context) => const TicketListScreen(),
    ticketDetail: (context) => const TicketDetailScreen(),
    myEvents: (context) => const MyEventsScreen(),
    profile: (context) => const UserProfileScreen(),
    scannerHome: (context) => const ScannerHomeScreen(),
    qrScanner: (context) => const QRScannerScreen(),
  };
}