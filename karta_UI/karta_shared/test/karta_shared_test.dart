import 'package:flutter_test/flutter_test.dart';
import 'package:karta_shared/karta_shared.dart';
void main() {
  test('Package exports models correctly', () {
    expect(AuthResponse, isNotNull);
    expect(LoginRequest, isNotNull);
    expect(EventDto, isNotNull);
    expect(TicketDto, isNotNull);
  });
}