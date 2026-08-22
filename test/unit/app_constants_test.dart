import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_edu/core/constants/app_constants.dart';

void main() {
  test('offlineMessage single source', () {
    expect(AppConstants.offlineMessage, contains("You're offline"));
    expect(AppConstants.offlineMessage, contains('reconnect'));
  });

  test('aiSafetyMessage not empty', () {
    expect(AppConstants.aiSafetyMessage.isNotEmpty, true);
  });

  test('serverUnreachableMessage', () {
    expect(AppConstants.serverUnreachableMessage, contains("Couldn't reach"));
  });
}
