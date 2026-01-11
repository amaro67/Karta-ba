import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:karta_shared/karta_shared.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}
class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isLoading = false;
  bool _paymentCompleted = false;
  String? _error;
  String? _orderId;
  double _totalAmount = 0;
  EventDto? _event;
  PriceTierDto? _priceTier;
  int _quantity = 1;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCheckoutData();
    });
  }
  void _loadCheckoutData() {
    if (!mounted) return;
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args == null) return;
    _quantity = args['quantity'] as int? ?? 1;
    if (args.containsKey('totalAmount')) {
      _totalAmount = (args['totalAmount'] as num).toDouble();
    } else if (args.containsKey('priceTierPrice')) {
      final priceTierPrice = (args['priceTierPrice'] as num).toDouble();
      final commission = 0.50;
      _totalAmount = (priceTierPrice * _quantity) + (commission * _quantity);
    }
    if (mounted) {
      setState(() {});
    }
  }
  Future<void> _initPaymentSheet() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      final eventId = args['eventId'] as String;
      final priceTierId = args['priceTierId'] as String;
      final quantity = args['quantity'] as int;
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.accessToken;
      if (token == null) {
        throw Exception('Not authenticated. Please log in again.');
      }
      print('🔵 Creating payment intent direct for eventId: $eventId, priceTierId: $priceTierId, quantity: $quantity');
      final requestData = {
        'eventId': eventId,
        'items': [
          {
            'priceTierId': priceTierId,
            'quantity': quantity,
          }
        ],
        'currency': 'BAM',
      };
      print('🔵 Request data: $requestData');
      print('🔵 Full URL: ${ApiClient.baseUrl}${ApiClient.apiPrefix}/Order/create-payment-intent-direct');
      final response = await ApiClient.post(
        '/Order/create-payment-intent-direct',
        requestData,
        token: token,
      );
      print('🔵 Response received: $response');
      final clientSecret = response['clientSecret'] as String?;
      final orderId = response['orderId'] as String?;
      final customerId = response['customerId'] as String?;
      final ephemeralKey = response['ephemeralKey'] as String?;
      if (clientSecret == null || customerId == null || ephemeralKey == null) {
        throw Exception('Failed to create payment intent. Please try again.');
      }
      _orderId = orderId;
      print('🔵 Initializing Stripe Payment Sheet...');
      print('🔵 Client Secret: ${clientSecret.substring(0, 20)}...');
      print('🔵 Customer ID: $customerId');
      print('🔵 Ephemeral Key: ${ephemeralKey.substring(0, 20)}...');
      try {
        await stripe.Stripe.instance.initPaymentSheet(
          paymentSheetParameters: stripe.SetupPaymentSheetParameters(
            customFlow: false,
            merchantDisplayName: 'Karta.ba',
            paymentIntentClientSecret: clientSecret,
            customerEphemeralKeySecret: ephemeralKey,
            customerId: customerId,
            style: ThemeMode.system,
          ),
        );
        print('✅ Payment Sheet initialized successfully');
      } catch (stripeError) {
        print('❌ Error initializing Payment Sheet: $stripeError');
        rethrow;
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      String errorMessage = 'An error occurred while initializing payment.';
      if (e.toString().contains('FormatException') || e.toString().contains('Unexpected end of input')) {
        errorMessage = 'Invalid response from server. Please check if backend is running and try again.';
      } else if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
        errorMessage = 'Unable to connect to server. Please check your internet connection.';
      } else {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      }
      setState(() {
        _error = errorMessage;
        _isLoading = false;
      });
    }
  }
  Future<void> _processPayment() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      print('🔵 Presenting Stripe Payment Sheet...');
      await stripe.Stripe.instance.presentPaymentSheet();
      print('✅ Payment Sheet presented successfully');
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.accessToken;
      if (token == null) {
        throw Exception('Not authenticated. Please log in again.');
      }
      if (_orderId != null) {
        await ApiClient.post(
          '/Order/confirm-payment',
          {
            'orderId': _orderId,
          },
          token: token,
        );
      } else {
        throw Exception('Order ID not found');
      }
      setState(() {
        _paymentCompleted = true;
        _isLoading = false;
      });
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.tickets,
        (route) => false,
        arguments: {'forceRefresh': true},
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment successful! Your tickets are ready.'),
          backgroundColor: AppTheme.success,
          duration: Duration(seconds: 4),
        ),
      );
    } on stripe.StripeException catch (e) {
      setState(() {
        _error = e.error.message ?? 'Payment failed. Please try again.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }
  Future<void> _handlePayment() async {
    print('🔵 _handlePayment called');
    await _initPaymentSheet();
    print('🔵 After _initPaymentSheet: _error=$_error, _isLoading=$_isLoading');
    if (_error == null && !_isLoading) {
      print('🔵 Calling _processPayment...');
      await _processPayment();
    } else {
      print('⚠️ Skipping _processPayment due to error or loading state');
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _paymentCompleted
          ? _buildSuccessScreen()
          : _buildCheckoutScreen(),
    );
  }
  Widget _buildCheckoutScreen() {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Summary',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quantity:',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        '${args['quantity']}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${_totalAmount.toStringAsFixed(2)} KM',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_error != null)
            Card(
              color: AppTheme.error.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppTheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_error != null) const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handlePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Proceed to Payment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildSuccessScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 50,
                color: AppTheme.success,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Payment Successful!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your tickets have been purchased successfully.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.tickets,
                    (route) => false,
                    arguments: {'forceRefresh': true},
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'View My Tickets',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}