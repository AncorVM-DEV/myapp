import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:permission_handler/permission_handler.dart';

import 'package:android_intent_plus/android_intent.dart';

import 'dart:io' show Platform;

// ── SERVICIO DE NOTIFICACIONES PUSH LOCALES ──────────────────────────────────
// Esta clase centraliza toda la lógica de notificaciones nativas del dispositivo.
// En web simplemente no hace nada (kIsWeb), así la app no explota en esa plataforma.
// En Android e iOS programa una notificación real que aparece en la barra de estado
// del móvil cuando falta N días para la fecha límite de una tarea.

class NotificationService {
  // Instancia única del plugin (patrón singleton ligero)
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Flag para saber si ya inicializamos el servicio y evitar doble inicialización
  static bool _initialized = false;

  // ── INICIALIZACIÓN ─────────────────────────────────────────────────────────
  // Llama a este método una sola vez desde main() antes de runApp().
  // Configura los canales de Android y pide permisos en iOS.
  static Future<void> init() async {
    // En web no hay notificaciones nativas, salimos sin hacer nada
    if (kIsWeb) return;

    // Inicializamos las zonas horarias (necesarias para programar notificaciones
    // a una hora exacta en la zona local del usuario)
    tz_data.initializeTimeZones();

    // ── ZONA HORARIA: usamos UTC como referencia interna ──────────────────────
    // No necesitamos ningún paquete externo para esto.
    // La clase DateTime de Dart YA conoce la zona horaria del sistema operativo
    // del dispositivo. Cuando creamos un DateTime local (ej. las 9:00 de hoy)
    // y lo convertimos con .toUtc(), Dart aplica automáticamente el desfase
    // correcto del dispositivo (UTC+0 en Canarias en invierno, UTC+1 en verano,
    // UTC+1 en Madrid en invierno, UTC+2 en verano, etc.).
    // Usamos tz.UTC como zona del plugin solo como contenedor: la hora ya llega
    // correctamente convertida desde el paso anterior.
    tz.setLocalLocation(tz.UTC);

    // Configuración específica para Android: usa el ícono del launcher de la app
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // Configuración para iOS/macOS: pedimos los tres permisos básicos al arrancar
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Inicializamos el plugin con las configuraciones de cada plataforma
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // ── PERMISOS EN TIEMPO DE EJECUCIÓN (Android 12/13+) ─────────────────────
    // En Android 13+ el permiso POST_NOTIFICATIONS es obligatorio en runtime
    // o el sistema descarta las notificaciones en silencio.
    // En Android 12+ el permiso de alarmas exactas también lo debe conceder
    // el usuario manualmente. Los pedimos aquí al arrancar la app por primera vez.
    // En versiones anteriores de Android estas llamadas no hacen nada: son seguras.
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      // Permiso para mostrar notificaciones (requerido en Android 13+)
      await androidPlugin.requestNotificationsPermission();
      // Permiso para alarmas exactas (requerido en Android 12+)
      await androidPlugin.requestExactAlarmsPermission();
    }

    // ── SAMSUNG / ONE UI: eximir la app de optimización de batería ────────────
    // BBA2 (Battery Background Advisor) de Samsung mata las alarmas exactas
    // cuando la app está en segundo plano aunque SCHEDULE_EXACT_ALARM esté activo.
    // Pedimos al usuario que exima la app del ahorro de batería para que las
    // notificaciones programadas lleguen con el móvil en segundo plano o bloqueado.
    // En otros fabricantes este permiso no tiene efecto pero tampoco causa daño.
    if (Platform.isAndroid) {
      final ignoreBattery = await Permission.ignoreBatteryOptimizations.status;
      if (!ignoreBattery.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
        final intent = AndroidIntent(
          action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
          data: 'package:com.example.myapp',
        );
        await intent.launch();
      }
    }
    _initialized = true;
    print('✅ NOTIF: servicio inicializado correctamente');
  }

  // ── PROGRAMAR NOTIFICACIÓN ─────────────────────────────────────────────────
  // Programa una notificación push para que aparezca 'diasAntelacion' días ANTES
  // de la 'fechaLimite'. Si la fecha ya pasó no hace nada (evitamos spam).
  //
  // Parámetros:
  //   id              → ID único de la notificación (para poder cancelarla luego)
  //   nombreTarea     → Nombre de la tarea para mostrar en la notificación
  //   nombreProyecto  → Nombre del proyecto al que pertenece la tarea
  //   fechaLimite     → Cuándo vence la tarea
  //   diasAntelacion  → Con cuántos días de adelanto queremos el aviso
  static Future<void> programarNotificacion({
    required int id,
    required String nombreTarea,
    required String nombreProyecto,
    required DateTime fechaLimite,
    required int diasAntelacion,
  }) async {
    // ── LOG: comprobamos si el servicio arrancó correctamente ─────────────────
    if (kIsWeb || !_initialized) {
      print('🔴 NOTIF: servicio no inicializado o plataforma web. Saliendo.');
      return;
    }

    // ── MODO TEST: dispara en 2 minutos desde ahora ───────────────────────────
    // Cuando confirmes que la notificación llega correctamente, elimina este
    // bloque y descomenta el bloque de producción que está debajo.
    final ahora = DateTime.now();
    final fechaNotificacionLocal = ahora.add(const Duration(minutes: 2));

    // ── PRODUCCIÓN (descomenta esto cuando el test funcione) ──────────────────
    // final diaAviso = fechaLimite.subtract(Duration(days: diasAntelacion));
    // final fechaNotificacionLocal = DateTime(
    //   diaAviso.year,
    //   diaAviso.month,
    //   diaAviso.day,
    //   9, // 9:00 AM en la hora local del dispositivo
    //   0,
    // );

    // Convertimos a UTC: Dart aplica el desfase de la zona del dispositivo solo
    final fechaNotificacionUTC = fechaNotificacionLocal.toUtc();

    // ── LOGS DE DIAGNÓSTICO ───────────────────────────────────────────────────
    print(
      '🟡 NOTIF: ahora son las ${ahora.hour}:${ahora.minute.toString().padLeft(2, '0')} (hora local)',
    );
    print(
      '🟡 NOTIF: programando disparo para las ${fechaNotificacionLocal.hour}:${fechaNotificacionLocal.minute.toString().padLeft(2, '0')} (hora local)',
    );
    print(
      '🟡 NOTIF: en UTC → ${fechaNotificacionUTC.hour}:${fechaNotificacionUTC.minute.toString().padLeft(2, '0')}',
    );
    print(
      '🟡 NOTIF: tarea="$nombreTarea" | proyecto="$nombreProyecto" | id=$id',
    );

    // Si ese momento ya pasó, no tiene sentido programar nada
    if (fechaNotificacionUTC.isBefore(DateTime.now().toUtc())) {
      print(
        '🔴 NOTIF: la fecha calculada ya está en el pasado. No se programa nada.',
      );
      print(
        '🔴 NOTIF: fecha calculada=$fechaNotificacionUTC | ahora UTC=${DateTime.now().toUtc()}',
      );
      return;
    }

    // Empaquetamos la fecha UTC en el formato que entiende el plugin de notificaciones
    final tzFecha = tz.TZDateTime.from(fechaNotificacionUTC, tz.UTC);
    print('🟡 NOTIF: TZDateTime final = $tzFecha');

    // Detalles de la notificación para Android
    const androidDetails = AndroidNotificationDetails(
      'protask_alertas', // ID del canal (único por app)
      'ProTask - Alertas de tareas', // Nombre visible en ajustes del móvil
      channelDescription:
          'Avisa cuando una tarea está próxima a su fecha límite.',
      importance: Importance.high, // Aparece como banner en pantalla
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFE8622A), // Naranja de ProTask para el ícono de notif
    );

    // Detalles para iOS/macOS
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true, // Muestra el banner aunque la app esté abierta
      presentBadge: true,
      presentSound: true,
    );

    // Programamos la notificación en el momento calculado
    try {
      await _plugin.zonedSchedule(
        id,
        '⏰ ProTask — Fecha límite próxima',
        'Faltan $diasAntelacion día(s) para "$nombreTarea" en "$nombreProyecto".',
        tzFecha,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
        // exactAllowWhileIdle: la notificación llega aunque el móvil esté en ahorro de batería
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      // TEST INMEDIATO — borra esto después de confirmar
      await _plugin.show(
        99999,
        '🔔 Test inmediato',
        'Si ves esto, las notificaciones funcionan.',
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
      );
      print(
        '✅ NOTIF: zonedSchedule registrado correctamente. Espera 2 minutos.',
      );
    } catch (e) {
      // ── LOG: capturamos cualquier error del sistema al programar la alarma ──
      print('🔴 NOTIF: error en zonedSchedule → $e');
    }
  }

  // ── CANCELAR NOTIFICACIÓN ──────────────────────────────────────────────────
  // Útil si el usuario elimina la tarea o cambia la fecha antes de que llegue el aviso
  static Future<void> cancelarNotificacion(int id) async {
    if (kIsWeb || !_initialized) return;
    await _plugin.cancel(id);
  }
}
