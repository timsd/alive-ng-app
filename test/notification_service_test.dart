import 'package:flutter_test/flutter_test.dart';
import 'package:alive_flutter_app/services/notification_service.dart';
import 'package:alive_flutter_app/services/appwrite_push_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('NotificationService and AppwritePushService instances exist', () {
    final notifService = NotificationService.instance;
    expect(notifService, isNotNull);

    final pushService = AppwritePushService.instance;
    expect(pushService, isNotNull);
  });
}
