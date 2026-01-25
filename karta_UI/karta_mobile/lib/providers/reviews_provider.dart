import 'package:flutter/foundation.dart';
import 'package:karta_shared/karta_shared.dart';

class ReviewsProvider extends ChangeNotifier {
  final AuthProvider _authProvider;

  EventReviewsDto? _eventReviews;
  ReviewDto? _userReview;
  bool _canReview = false;
  bool _isLoading = false;
  String? _error;
  String? _currentEventId;

  ReviewsProvider(this._authProvider);

  EventReviewsDto? get eventReviews => _eventReviews;
  ReviewDto? get userReview => _userReview;
  bool get canReview => _canReview;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get averageRating => _eventReviews?.averageRating ?? 0;
  int get totalCount => _eventReviews?.totalCount ?? 0;
  List<ReviewDto> get reviews => _eventReviews?.reviews ?? [];

  String? get _token => _authProvider.accessToken;

  Future<void> loadEventReviews(String eventId, {int page = 1, int pageSize = 10}) async {
    _isLoading = true;
    _error = null;
    _currentEventId = eventId;
    notifyListeners();

    try {
      final data = await ApiClient.getEventReviews(eventId, page: page, pageSize: pageSize);
      _eventReviews = EventReviewsDto.fromJson(data);
      _error = null;
    } catch (e) {
      _error = e.toString();
      print('Error loading event reviews: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> checkCanReview(String eventId) async {
    if (_token == null) {
      _canReview = false;
      notifyListeners();
      return;
    }

    try {
      _canReview = await ApiClient.canUserReviewEvent(_token!, eventId);
    } catch (e) {
      _canReview = false;
      print('Error checking can review: $e');
    }
    notifyListeners();
  }

  Future<void> loadUserReview(String eventId) async {
    if (_token == null) {
      _userReview = null;
      notifyListeners();
      return;
    }

    try {
      final data = await ApiClient.getUserReviewForEvent(_token!, eventId);
      if (data != null) {
        _userReview = ReviewDto.fromJson(data);
      } else {
        _userReview = null;
      }
    } catch (e) {
      _userReview = null;
      // 404 is expected if user hasn't reviewed
    }
    notifyListeners();
  }

  Future<bool> createReview(String eventId, CreateReviewRequest request) async {
    if (_token == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiClient.createReview(_token!, eventId, request.toJson());
      _userReview = ReviewDto.fromJson(data);
      _canReview = false;

      // Reload reviews to update the list
      await loadEventReviews(eventId);

      return true;
    } catch (e) {
      _error = e.toString();
      print('Error creating review: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateReview(String reviewId, UpdateReviewRequest request) async {
    if (_token == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiClient.updateReview(_token!, reviewId, request.toJson());
      _userReview = ReviewDto.fromJson(data);

      // Reload reviews to update the list
      if (_currentEventId != null) {
        await loadEventReviews(_currentEventId!);
      }

      return true;
    } catch (e) {
      _error = e.toString();
      print('Error updating review: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteReview(String reviewId) async {
    if (_token == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await ApiClient.deleteReview(_token!, reviewId);
      _userReview = null;
      _canReview = true;

      // Reload reviews to update the list
      if (_currentEventId != null) {
        await loadEventReviews(_currentEventId!);
      }

      return true;
    } catch (e) {
      _error = e.toString();
      print('Error deleting review: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _eventReviews = null;
    _userReview = null;
    _canReview = false;
    _error = null;
    _currentEventId = null;
    notifyListeners();
  }
}
