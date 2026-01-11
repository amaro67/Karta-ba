import 'dart:convert';
import 'package:karta_shared/karta_shared.dart';
class EventTrackingService {
  static Future<Map<String, dynamic>?> trackEventView(String eventId, {String? token}) async {
    try {
      print('📊 Tracking event view: $eventId');
      final data = await ApiClient.post(
        '/event/track-view',
        {'eventId': eventId},
        token: token,
      );
      print('✅ Event view tracked: $data');
      if (data['emailTriggered'] == true) {
        print('🔔 Email triggered! User will receive recommendations.');
      }
      return data;
    } catch (e) {
      print('❌ Error tracking event view: $e');
      return null;
    }
  }
}