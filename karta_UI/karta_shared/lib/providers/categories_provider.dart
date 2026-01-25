import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/category/category_dto.dart';

class CategoriesProvider extends ChangeNotifier {
  List<CategoryDto> _categories = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastFetch;

  List<CategoryDto> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasCategories => _categories.isNotEmpty;

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
      final data = await ApiClient.getCategories();
      _categories = data.map((item) => CategoryDto.fromJson(item)).toList();
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

  CategoryDto? getCategoryBySlug(String slug) {
    try {
      return _categories.firstWhere((c) => c.slug == slug);
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

  void clear() {
    _categories = [];
    _error = null;
    _lastFetch = null;
    notifyListeners();
  }
}
