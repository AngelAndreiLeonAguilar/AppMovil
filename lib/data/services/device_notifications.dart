import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Recordatorio programado de una visita.
///
/// [at] se interpreta en hora de Bécal (America/Merida).
class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    this.payload,
  });

  final int id;
  final DateTime at;
  final String title;
  final String body;
  final String? payload;
}

/// Notificaciones que llegan a la barra del teléfono.
///
/// La app lo usa a través de esta interfaz para que las pruebas puedan usar
/// [SilentDeviceNotifications] sin plugins nativos.
abstract interface class DeviceNotifications {
  /// Prepara el canal. Debe llamarse una vez al arrancar.
  Future<void> init();

  /// Pide permiso al usuario (Android 13+ e iOS). Devuelve si quedó activo.
  Future<bool> requestPermission();

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  });

  /// Sustituye todos los recordatorios programados por [reminders].
  Future<void> replaceReminders(List<ScheduledReminder> reminders);

  Future<void> cancelAll();

  /// Toques del usuario sobre una notificación (payload).
  Stream<String?> get taps;
}

/// Implementación sin efectos (pruebas y plataformas sin soporte).
class SilentDeviceNotifications implements DeviceNotifications {
  final List<String> shown = [];
  final List<ScheduledReminder> scheduled = [];

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async => shown.add(title);

  @override
  Future<void> replaceReminders(List<ScheduledReminder> reminders) async {
    scheduled
      ..clear()
      ..addAll(reminders);
  }

  @override
  Future<void> cancelAll() async {
    shown.clear();
    scheduled.clear();
  }

  @override
  Stream<String?> get taps => const Stream.empty();
}

/// Implementación real con `flutter_local_notifications`.
class LocalDeviceNotifications implements DeviceNotifications {
  LocalDeviceNotifications();

  static const _channelId = 'bel_aaktun_reservas';
  static const _channelName = 'Reservaciones';
  static const _channelDescription =
      'Solicitudes, confirmaciones y recordatorios de visitas.';

  /// Los recordatorios usan ids en este rango para poder reemplazarlos.
  static const reminderIdBase = 500000;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String?> _taps = StreamController.broadcast();
  final Set<int> _scheduledIds = {};
  bool _ready = false;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Stream<String?> get taps => _taps.stream;

  @override
  Future<void> init() async {
    if (_ready || !_supported) return;
    try {
      tz_data.initializeTimeZones();
      // Bécal está en Campeche (UTC-6 todo el año): los horarios de visita
      // son siempre en hora local del pueblo.
      tz.setLocalLocation(tz.getLocation('America/Merida'));

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) =>
            _taps.add(response.payload),
      );

      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        final payload = launch!.notificationResponse?.payload;
        scheduleMicrotask(() => _taps.add(payload));
      }

      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDescription,
              importance: Importance.high,
            ),
          );
      _ready = true;
    } catch (error) {
      debugPrint('No se pudieron preparar las notificaciones: $error');
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    await init();
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await android?.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  NotificationDetails get _details => const NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
      category: AndroidNotificationCategory.event,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
    ),
  );

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_supported) return;
    await init();
    if (!_ready) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _details,
        payload: payload,
      );
    } catch (error) {
      debugPrint('No se pudo mostrar la notificación: $error');
    }
  }

  @override
  Future<void> replaceReminders(List<ScheduledReminder> reminders) async {
    if (!_supported) return;
    await init();
    if (!_ready) return;
    try {
      for (final id in _scheduledIds) {
        await _plugin.cancel(id: id);
      }
      // También limpia recordatorios de una sesión anterior de la app.
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        if (request.id >= reminderIdBase) {
          await _plugin.cancel(id: request.id);
        }
      }
      _scheduledIds.clear();

      final now = tz.TZDateTime.now(tz.local);
      for (final reminder in reminders) {
        // La hora de la visita está escrita en hora de Bécal.
        final at = reminder.at;
        final when = tz.TZDateTime(
          tz.local,
          at.year,
          at.month,
          at.day,
          at.hour,
          at.minute,
        );
        if (!when.isAfter(now)) continue;
        await _plugin.zonedSchedule(
          id: reminder.id,
          scheduledDate: when,
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: reminder.title,
          body: reminder.body,
          payload: reminder.payload,
        );
        _scheduledIds.add(reminder.id);
      }
    } catch (error) {
      debugPrint('No se pudieron programar recordatorios: $error');
    }
  }

  @override
  Future<void> cancelAll() async {
    if (!_supported) return;
    try {
      await _plugin.cancelAll();
      _scheduledIds.clear();
    } catch (_) {}
  }
}
