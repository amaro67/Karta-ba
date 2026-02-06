import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/categories_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/api_client.dart';
import '../../config/theme.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoriesProvider>().loadCategories(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoriesProvider>(
      builder: (context, provider, child) {
        final filtered = provider.categories.where((c) {
          if (_searchQuery.isEmpty) return true;
          return c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (c.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
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
                        hintText: 'Search categories...',
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
                    onPressed: () => _showCategoryDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Category'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => provider.loadCategories(forceRefresh: true),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('${filtered.length} categories', style: TextStyle(color: Colors.grey.shade600)),
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
                        DataColumn(label: Text('Slug', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Order', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Active', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Events', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: filtered.map((category) {
                        return DataRow(cells: [
                          DataCell(Text(category.name)),
                          DataCell(Text(category.slug)),
                          DataCell(Text('${category.displayOrder}')),
                          DataCell(Icon(
                            category.isActive ? Icons.check_circle : Icons.cancel,
                            color: category.isActive ? Colors.green : Colors.red,
                            size: 20,
                          )),
                          DataCell(Text('${category.eventCount}')),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _showCategoryDialog(context, category: category),
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, size: 20, color: Colors.red.shade400),
                                onPressed: () => _confirmDelete(context, category),
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

  void _showCategoryDialog(BuildContext context, {CategoryDto? category}) {
    final nameController = TextEditingController(text: category?.name ?? '');
    final descController = TextEditingController(text: category?.description ?? '');
    bool isActive = category?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(category == null ? 'Add Category' : 'Edit Category'),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
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
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (v) => setDialogState(() => isActive = v),
                  ),
                ],
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
                  'description': descController.text,
                  'iconUrl': category?.iconUrl ?? '/icons/default-category.png',
                  'displayOrder': category?.displayOrder ?? 0,
                  'isActive': isActive,
                };
                try {
                  if (category == null) {
                    await ApiClient.post('/Category', data, token: token);
                  } else {
                    await ApiClient.put('/Category/${category.id}', data, token: token);
                  }
                  Navigator.of(dialogContext).pop();
                  context.read<CategoriesProvider>().loadCategories(forceRefresh: true);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text(category == null ? 'Category created' : 'Category updated'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
              child: Text(category == null ? 'Create' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, CategoryDto category) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final token = context.read<AuthProvider>().accessToken;
              if (token == null) return;
              try {
                await ApiClient.delete('/Category/${category.id}', token: token);
                Navigator.of(dialogContext).pop();
                context.read<CategoriesProvider>().loadCategories(forceRefresh: true);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Category deleted'), backgroundColor: Colors.green),
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
