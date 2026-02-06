import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/venues_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/api_client.dart';
import '../../config/theme.dart';

class VenueManagementScreen extends StatefulWidget {
  const VenueManagementScreen({super.key});

  @override
  State<VenueManagementScreen> createState() => _VenueManagementScreenState();
}

class _VenueManagementScreenState extends State<VenueManagementScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VenuesProvider>().loadVenues(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VenuesProvider>(
      builder: (context, provider, child) {
        final filtered = provider.venues.where((v) {
          if (_searchQuery.isEmpty) return true;
          return v.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              v.city.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              v.address.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search venues by name, city...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) => setState(() => _searchQuery = value),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showVenueDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Venue'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => provider.loadVenues(forceRefresh: true),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('${filtered.length} venues', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              if (provider.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (provider.error != null)
                Center(child: Text('Error: ${provider.error}', style: const TextStyle(color: Colors.red)))
              else
                Expanded(
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Address', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('City', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Capacity', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Events', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: filtered.map((venue) {
                        return DataRow(cells: [
                          DataCell(Text(venue.name)),
                          DataCell(Text(venue.address, overflow: TextOverflow.ellipsis)),
                          DataCell(Text('${venue.city}, ${venue.country}')),
                          DataCell(Text(venue.capacity != null ? '${venue.capacity}' : '-')),
                          DataCell(Text('${venue.eventCount}')),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _showVenueDialog(context, venue: venue),
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, size: 20, color: Colors.red.shade400),
                                onPressed: () => _confirmDelete(context, venue),
                                tooltip: 'Delete',
                              ),
                            ],
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showVenueDialog(BuildContext context, {VenueDto? venue}) {
    final nameController = TextEditingController(text: venue?.name ?? '');
    final addressController = TextEditingController(text: venue?.address ?? '');
    final cityController = TextEditingController(text: venue?.city ?? '');
    final countryController = TextEditingController(text: venue?.country ?? 'Bosna i Hercegovina');
    final capacityController = TextEditingController(text: venue?.capacity?.toString() ?? '');
    final latController = TextEditingController(text: venue?.latitude?.toString() ?? '');
    final lngController = TextEditingController(text: venue?.longitude?.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(venue == null ? 'Add Venue' : 'Edit Venue'),
        content: SizedBox(
          width: 500,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty ? 'Address is required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: cityController,
                          decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
                          validator: (v) => v == null || v.isEmpty ? 'City is required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: countryController,
                          decoration: const InputDecoration(labelText: 'Country', border: OutlineInputBorder()),
                          validator: (v) => v == null || v.isEmpty ? 'Country is required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: capacityController,
                    decoration: const InputDecoration(labelText: 'Capacity (optional)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: latController,
                          decoration: const InputDecoration(labelText: 'Latitude (optional)', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: lngController,
                          decoration: const InputDecoration(labelText: 'Longitude (optional)', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final token = context.read<AuthProvider>().accessToken;
              if (token == null) return;
              final data = {
                'name': nameController.text,
                'address': addressController.text,
                'city': cityController.text,
                'country': countryController.text,
                if (capacityController.text.isNotEmpty) 'capacity': int.tryParse(capacityController.text),
                if (latController.text.isNotEmpty) 'latitude': double.tryParse(latController.text),
                if (lngController.text.isNotEmpty) 'longitude': double.tryParse(lngController.text),
              };
              try {
                if (venue == null) {
                  await ApiClient.post('/Venue', data, token: token);
                } else {
                  await ApiClient.put('/Venue/${venue.id}', data, token: token);
                }
                Navigator.of(dialogContext).pop();
                context.read<VenuesProvider>().loadVenues(forceRefresh: true);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text(venue == null ? 'Venue created' : 'Venue updated'), backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
            child: Text(venue == null ? 'Create' : 'Update'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, VenueDto venue) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Venue'),
        content: Text('Are you sure you want to delete "${venue.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final token = context.read<AuthProvider>().accessToken;
              if (token == null) return;
              try {
                await ApiClient.delete('/Venue/${venue.id}', token: token);
                Navigator.of(dialogContext).pop();
                context.read<VenuesProvider>().loadVenues(forceRefresh: true);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Venue deleted'), backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
