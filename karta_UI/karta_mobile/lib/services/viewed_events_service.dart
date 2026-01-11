import 'package:shared_preferences/shared_preferences.dart';
class ViewedEventsService {
  static const String _viewedEventsKey = 'viewed_events';
  static const int _maxViewedEvents = 10;
  static Future<void> addViewedEvent(String eventId) async {
    print('🔵 ViewedEventsService: Adding event ID: $eventId');
    final prefs = await SharedPreferences.getInstance();
    List<String> viewedEvents = prefs.getStringList(_viewedEventsKey) ?? [];
    print('🔵 ViewedEventsService: Current viewed events before: $viewedEvents');
    viewedEvents.remove(eventId);
    viewedEvents.insert(0, eventId);
    if (viewedEvents.length > _maxViewedEvents) {
      viewedEvents = viewedEvents.sublist(0, _maxViewedEvents);
    }
    print('🔵 ViewedEventsService: Updated viewed events: $viewedEvents');
    await prefs.setStringList(_viewedEventsKey, viewedEvents);
    final saved = prefs.getStringList(_viewedEventsKey);
    print('🔵 ViewedEventsService: Verified saved events: $saved');
  }
  static Future<List<String>> getViewedEvents() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_viewedEventsKey) ?? [];
  }
  static Future<void> clearViewedEvents() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_viewedEventsKey);
  }
  static Future<void> removeViewedEvent(String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> viewedEvents = prefs.getStringList(_viewedEventsKey) ?? [];
    viewedEvents.remove(eventId);
    await prefs.setStringList(_viewedEventsKey, viewedEvents);
  }
}