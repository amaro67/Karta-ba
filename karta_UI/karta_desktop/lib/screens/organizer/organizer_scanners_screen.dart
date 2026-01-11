import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/scanner_provider.dart';
class OrganizerScannersScreen extends StatefulWidget {
  const OrganizerScannersScreen({super.key});
  @override
  State<OrganizerScannersScreen> createState() => _OrganizerScannersScreenState();
}
class _OrganizerScannersScreenState extends State<OrganizerScannersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ScannerProvider>().loadOverview();
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    return Consumer<ScannerProvider>(
      builder: (context, scannerProvider, child) {
        if (scannerProvider.isLoading && scannerProvider.eventSummaries.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (scannerProvider.error != null && scannerProvider.eventSummaries.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade600, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Greška pri učitavanju',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  scannerProvider.error ?? '',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red.shade600),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => scannerProvider.loadOverview(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Pokušaj ponovo'),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scanner tim',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Upravljajte osobljem koje je zaduženo za skeniranje ulaznica.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () {
                      print('🔵 Dodaj scannera button clicked');
                      _openCreateScannerDialog(scannerProvider);
                    },
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Dodaj scannera'),
                  ),
                ],
              ),
              if (scannerProvider.isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              const SizedBox(height: 24),
              // Show all scanners section
              if (scannerProvider.scanners.isNotEmpty) ...[
                Text(
                  'Svi scanneri (${scannerProvider.scanners.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: scannerProvider.scanners.map((scanner) {
                    final label = scanner.fullName.isEmpty ? scanner.email : scanner.fullName;
                    return Chip(
                      avatar: const CircleAvatar(
                        radius: 14,
                        child: Icon(Icons.person, size: 16),
                      ),
                      label: Text(label),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],
              // Events section
              if (scannerProvider.eventSummaries.isNotEmpty) ...[
                Text(
                  'Događaji',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: scannerProvider.eventSummaries.isEmpty
                    ? _EmptyEventsState(onCreateScanner: () => _openCreateScannerDialog(scannerProvider))
                    : ListView.separated(
                        itemCount: scannerProvider.eventSummaries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final event = scannerProvider.eventSummaries[index];
                          return _EventScannerCard(
                            event: event,
                            onAssign: () => _openAssignScannerSheet(event, scannerProvider),
                            onRemove: (scannerId) => _confirmRemove(event, scannerId, scannerProvider),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
  Future<void> _openCreateScannerDialog(ScannerProvider provider) async {
    print('🔵 _openCreateScannerDialog called');
    if (!mounted) {
      print('🔴 Widget not mounted, cannot show dialog');
      return;
    }
    final formKey = GlobalKey<FormState>();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isSubmitting = false;
    
    print('🔵 Showing dialog...');
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        print('🔵 Dialog builder called');
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Novi scanner'),
            content: Form(
              key: formKey,
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: firstNameController,
                      decoration: const InputDecoration(labelText: 'Ime'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: lastNameController,
                      decoration: const InputDecoration(labelText: 'Prezime'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email *'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email je obavezan';
                        }
                        if (!value.contains('@')) {
                          return 'Unesite validan email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordController,
                      decoration: const InputDecoration(labelText: 'Privremena lozinka *'),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.length < 8) {
                          return 'Lozinka mora imati najmanje 8 karaktera';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                child: const Text('Otkaži'),
              ),
              FilledButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setState(() => isSubmitting = true);
                        final success = await provider.createScanner(
                          email: emailController.text.trim(),
                          password: passwordController.text,
                          firstName: firstNameController.text.trim(),
                          lastName: lastNameController.text.trim(),
                        );
                        setState(() => isSubmitting = false);
                        if (context.mounted) {
                          if (success) {
                            Navigator.of(context).pop();
                            // Force refresh the UI
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Scanner je uspješno kreiran'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            // Show error message
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(provider.error ?? 'Greška pri kreiranju scannera'),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Sačuvaj'),
              ),
            ],
          ),
        );
      },
    );
  }
  Future<void> _openAssignScannerSheet(EventScannerSummary event, ScannerProvider provider) async {
    if (provider.scanners.isEmpty) {
      _openCreateScannerDialog(provider);
      return;
    }
    String? selectedScannerId;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dodijeli scannera',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                event.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Odaberi scannera',
                  border: OutlineInputBorder(),
                ),
                items: provider.scanners
                    .where((scanner) => !event.scanners.any((assigned) => assigned.id == scanner.id))
                    .map((scanner) => DropdownMenuItem(
                          value: scanner.id,
                          child: Text(scanner.fullName.isEmpty ? scanner.email : scanner.fullName),
                        ))
                    .toList(),
                onChanged: (value) {
                  selectedScannerId = value;
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Otkaži'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      if (selectedScannerId == null) return;
                      final success = await provider.assignScanner(
                        eventId: event.eventId,
                        scannerUserId: selectedScannerId!,
                      );
                      if (success && context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Scanner dodijeljen događaju')),
                        );
                      }
                    },
                    child: const Text('Dodijeli'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  Future<void> _confirmRemove(
    EventScannerSummary event,
    String scannerId,
    ScannerProvider provider,
  ) async {
    final scanner = event.scanners.firstWhere((s) => s.id == scannerId);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ukloni scannera'),
        content: Text('Želite li ukloniti ${scanner.fullName.isEmpty ? scanner.email : scanner.fullName} sa događaja "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Ne'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Da, ukloni'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final success = await provider.removeScanner(eventId: event.eventId, scannerUserId: scannerId);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scanner uklonjen')),
        );
      }
    }
  }
}
class _EventScannerCard extends StatelessWidget {
  final EventScannerSummary event;
  final VoidCallback onAssign;
  final ValueChanged<String> onRemove;
  const _EventScannerCard({
    required this.event,
    required this.onAssign,
    required this.onRemove,
  });
  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d. MMM yyyy • HH:mm');
    final subtitle = [
      dateFormat.format(event.startsAt),
      if (event.city.isNotEmpty) event.city,
    ].join(' • ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: onAssign,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Dodijeli scannera'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (event.scanners.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade100,
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Još nije dodijeljen nijedan scanner.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: event.scanners.map((scanner) {
                  final label = scanner.fullName.isEmpty ? scanner.email : scanner.fullName;
                  return InputChip(
                    avatar: const CircleAvatar(
                      radius: 14,
                      child: Icon(Icons.person, size: 16),
                    ),
                    label: Text(label),
                    onDeleted: () => onRemove(scanner.id),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
class _EmptyEventsState extends StatelessWidget {
  final VoidCallback onCreateScanner;
  const _EmptyEventsState({required this.onCreateScanner});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Još nema kreiranih događaja',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Kreirajte događaj i zatim dodajte scannere kako biste kontrolisali ulaz.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onCreateScanner,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Dodaj scannera'),
          ),
        ],
      ),
    );
  }
}