
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
void raqeebNotificationActionBackground(
  NotificationResponse response,
) {
  // Dismiss the notification without opening the app.
  if (response.actionId == 'dismiss_incident') {
    debugPrint('Incident notification dismissed');
  }
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance =
      NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

final iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          'raqeeb_incident',
          actions: [
            DarwinNotificationAction.plain(
              'view_incident',
              'View',
              options: {
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'dismiss_incident',
              'Dismiss',
            ),
          ],
        ),
      ],
    );

    final settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final incidentId = response.payload;

        if (response.actionId == 'view_incident') {
          debugPrint('View incident: $incidentId');
        } else if (response.actionId == 'dismiss_incident') {
          debugPrint('Dismiss incident: $incidentId');
        }
      },
      onDidReceiveBackgroundNotificationResponse:
          raqeebNotificationActionBackground,
    );

    _initialized = true;
  }

  Future<void> showIncidentNotification({
    required String incidentId,
    required String title,
    required String body,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'raqeeb_alerts_v1',
      'Raqeeb Threat Alerts',
      channelDescription:
          'Notifications for detected threat incidents',
      importance: Importance.max,
      priority: Priority.high,
      actions: [
        AndroidNotificationAction(
          'view_incident',
          'View',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'dismiss_incident',
          'Dismiss',
          cancelNotification: true,
        ),
      ],
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        categoryIdentifier: 'raqeeb_incident',
      ),
    );

    await _notifications.show(
      id: incidentId.hashCode & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: details,
      payload: incidentId,
    );
  }
}
