import 'package:flutter/foundation.dart';
import '../utils/api_client.dart';

class CategoryDto {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? iconUrl;
  final int displayOrder;
  final bool isActive;
  final int eventCount;

  CategoryDto({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.iconUrl,
    required this.displayOrder,
    required this.isActive,
    required this.eventCount,
  });

  factory CategoryDto.fromJson(Map<String, dynamic> json) {
    return CategoryDto(
      id: json['id']?.toString() ?? json['Id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['Name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? json['Slug']?.toString() ?? '',
      description: json['description']?.toString() ?? json['Description']?.toString(),
      iconUrl: json['iconUrl']?.toString() ?? json['IconUrl']?.toString(),
      displayOrder: json['displayOrder'] ?? json['DisplayOrder'] ?? 0,
      isActive: json['isActive'] ?? json['IsActive'] ?? true,
      eventCount: json['eventCount'] ?? json['EventCount'] ?? 0,
    );
  }
}

class CategoriesProvider extends ChangeNotifier {
  List<CategoryDto> _categories = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastFetch;
  String? _token;

  List<CategoryDto> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasCategories => _categories.isNotEmpty;

  void setToken(String? token) {
    _token = token;
  }

  // Cache duration: 5 minutes
  static const _cacheDuration = Duration(minutes: 5);

  bool get _shouldRefetch {
    if (_lastFetch == null) return true;
    return DateTime.now().difference(_lastFetch!) > _cacheDuration;
  }

  Future<void> loadCategories({bool forceRefresh = false}) async {
    if (!forceRefresh && !_shouldRefetch && _categories.isNotEmpty) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiClient.getCategories(includeInactive: true, token: _token);
      _categories = data.map((item) => CategoryDto.fromJson(item as Map<String, dynamic>)).toList();
      // Sort by displayOrder
      _categories.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      _lastFetch = DateTime.now();
      _error = null;
    } catch (e) {
      _error = e.toString();
      print('Error loading categories: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  CategoryDto? getCategoryById(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  CategoryDto? getCategoryByName(String name) {
    try {
      return _categories.firstWhere(
        (c) => c.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  List<CategoryDto> get activeCategories =>
      _categories.where((c) => c.isActive).toList();

  List<String> get categoryNames => _categories.map((c) => c.name).toList();

  void clear() {
    _categories = [];
    _error = null;
    _lastFetch = null;
    notifyListeners();
  }
}
