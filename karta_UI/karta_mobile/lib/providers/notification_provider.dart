import 'package:flutter/foundation.dart';
import 'package:karta_shared/karta_shared.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationDto {
  final String id;
  final String title;
  final String content;
  final String type;
  final bool isRead;
  final String? relatedEntityId;
  final String? relatedEntityType;
  final DateTime createdAt;

  NotificationDto({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.isRead,
    this.relatedEntityId,
    this.relatedEntityType,
    required this.createdAt,
  });

  factory NotificationDto.fromJson(Map<String, dynamic> json) {
    return NotificationDto(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      isRead: json['isRead'] ?? false,
      relatedEntityId: json['relatedEntityId']?.toString(),
      relatedEntityType: json['relatedEntityType']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class NotificationProvider extends ChangeNotifier {
  final AuthProvider _authProvider;
  List<NotificationDto> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;

  NotificationProvider(this._authProvider);

  List<NotificationDto> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  String? get _token => _authProvider.accessToken;

  Future<void> loadNotifications({int page = 1, int size = 20}) async {
    if (_token == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiClient.get('/Notification?page=$page&size=$size', token: _token);
      final items = (data['items'] as List?) ?? [];
      _notifications = items.map((item) => NotificationDto.fromJson(item as Map<String, dynamic>)).toList();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUnreadCount() async {
    if (_token == null) return;
    try {
      final response = await http.Client().get(
        Uri.parse('${ApiClient.baseUrl}${ApiClient.apiPrefix}/Notification/unread-count'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        _unreadCount = int.tryParse(response.body) ?? 0;
        notifyListeners();
      }
    } catch (e) {
      // silently fail
    }
  }

  Future<void> markAsRead(String id) async {
    if (_token == null) return;
    try {
      final response = await http.Client().put(
        Uri.parse('${ApiClient.baseUrl}${ApiClient.apiPrefix}/Notification/$id/read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 204 || response.statusCode == 200) {
        final index = _notifications.indexWhere((n) => n.id == id);
        if (index != -1) {
          _notifications[index] = NotificationDto(
            id: _notifications[index].id,
            title: _notifications[index].title,
            content: _notifications[index].content,
            type: _notifications[index].type,
            isRead: true,
            relatedEntityId: _notifications[index].relatedEntityId,
            relatedEntityType: _notifications[index].relatedEntityType,
            createdAt: _notifications[index].createdAt,
          );
          _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
          notifyListeners();
        }
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    if (_token == null) return;
    try {
      final response = await http.Client().put(
        Uri.parse('${ApiClient.baseUrl}${ApiClient.apiPrefix}/Notification/read-all'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 204 || response.statusCode == 200) {
        _notifications = _notifications.map((n) => NotificationDto(
          id: n.id, title: n.title, content: n.content,
          type: n.type, isRead: true, relatedEntityId: n.relatedEntityId,
          relatedEntityType: n.relatedEntityType, createdAt: n.createdAt,
        )).toList();
        _unreadCount = 0;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteNotification(String id) async {
    if (_token == null) return;
    try {
      await ApiClient.delete('/Notification/$id', token: _token);
      final wasUnread = _notifications.any((n) => n.id == id && !n.isRead);
      _notifications.removeWhere((n) => n.id == id);
      if (wasUnread && _unreadCount > 0) _unreadCount--;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
