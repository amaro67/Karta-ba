import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:karta_shared/karta_shared.dart';
import '../../config/theme.dart';
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});
  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}
class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool _isProcessing = false;
  bool _flashOn = false;
  final _manualCodeController = TextEditingController();
  @override
  void initState() {
    super.initState();
    controller.start();
  }
  @override
  void dispose() {
    controller.dispose();
    _manualCodeController.dispose();
    super.dispose();
  }
  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (_isProcessing || barcodes.isEmpty) return;
    final String? code = barcodes.first.rawValue;
    if (code != null) {
      _validateTicket(code);
    }
  }
  Future<void> _validateTicket(String ticketCode) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });
    await controller.stop();
    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.accessToken;
      if (token == null) {
        _showErrorDialog('Not authenticated');
        return;
      }
      final response = await ApiClient.post(
        '/Ticket/validate',
        {'ticketCode': ticketCode},
        token: token,
      );
      final ticket = TicketDto.fromJson(response);
      if (!mounted) return;
      _showValidationResult(ticket, ticketCode);
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }
  void _showValidationResult(TicketDto ticket, String ticketCode) {
    final isValid = ticket.status.toLowerCase() == 'issued';
    final isUsed = ticket.status.toLowerCase() == 'used';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isValid ? Icons.check_circle : Icons.cancel,
              size: 64,
              color: isValid ? AppTheme.success : (isUsed ? AppTheme.warning : AppTheme.error),
            ),
            const SizedBox(height: 16),
            Text(
              isValid ? 'Ticket Valid' : (isUsed ? 'Already Used' : 'Invalid Ticket'),
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Ticket:', ticketCode.substring(0, 12)),
            if (ticket.usedAt != null)
              _buildInfoRow('Used at:', ticket.usedAt!.toLocal().toString().substring(0, 16)),
          ],
        ),
        actions: [
          if (isValid) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _resumeScanning();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _markAsUsed(ticketCode);
                if (mounted) {
                  Navigator.pop(context);
                  _resumeScanning();
                }
              },
              child: const Text('Mark as Used'),
            ),
          ] else ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _resumeScanning();
              },
              child: const Text('OK'),
            ),
          ],
        ],
      ),
    );
  }
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  Future<void> _markAsUsed(String ticketCode) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.accessToken;
      if (token == null) return;
      await ApiClient.post(
        '/Ticket/scan',
        {
          'TicketCode': ticketCode,
          'GateId': authProvider.currentUser?.id ?? '',
          'Signature': null,
        },
        token: token,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket marked as used'),
            backgroundColor: AppTheme.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resumeScanning();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  void _resumeScanning() async {
    await Future.delayed(const Duration(milliseconds: 500));
    controller.start();
  }
  void _toggleFlash() async {
    await controller.toggleTorch();
    setState(() {
      _flashOn = !_flashOn;
    });
  }
  void _showManualEntryDialog() {
    controller.stop();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Ticket Code'),
        content: TextField(
          controller: _manualCodeController,
          decoration: const InputDecoration(
            hintText: 'Ticket code',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              _manualCodeController.clear();
              Navigator.pop(context);
              _resumeScanning();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = _manualCodeController.text.trim();
              if (code.isNotEmpty) {
                Navigator.pop(context);
                _manualCodeController.clear();
                _validateTicket(code);
              }
            },
            child: const Text('Validate'),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final eventTitle = args?['eventTitle'] ?? 'Event';
    return Scaffold(
      appBar: AppBar(
        title: Text(eventTitle),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.7,
              height: MediaQuery.of(context).size.width * 0.7,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppTheme.primaryColor,
                  width: 4,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: _toggleFlash,
                      icon: Icon(
                        _flashOn ? Icons.flash_on : Icons.flash_off,
                        color: Colors.white,
                        size: 32,
                      ),
                      tooltip: 'Toggle flash',
                    ),
                    ElevatedButton.icon(
                      onPressed: _showManualEntryDialog,
                      icon: const Icon(Icons.keyboard),
                      label: const Text('Manual Entry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}