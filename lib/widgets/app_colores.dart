import 'package:flutter/material.dart';

// ── COLORES COMPARTIDOS DE LA PALETA DEL LOGO ────────────────────────────────
// Antes cada pantalla declaraba estos colores como constantes privadas (_bgDark,
// _bgCard, etc.). Los movemos aquí para que proyectos.dart y Tareas.dart no
// los dupliquen y siempre usen los mismos valores.
class AppColores {
  static const bgDark = Color(0xFF2D3142);
  static const bgCard = Color(0xFF3A3D52);
  static const borderColor = Color(0xFF4A4E66);
  static const orangePrimary = Color(0xFFE8622A);
  static const orangeLight = Color(0xFFF0944D);
  static const textMuted = Color(0xFFAAADBF);

  // ── COLORES PARA LAS PRIORIDADES DE LAS TAREAS ───────────────────────────
  // Cada nivel de urgencia tiene su color distintivo para la franja lateral
  // de la tarjeta y para los filtros. Son los mismos colores que usaría ClickUp.
  static const prioUrgente = Color(0xFFFF4757); // Rojo vivo → urgente de verdad
  static const prioAlta    = Color(0xFFFFD43B); // Amarillo → hay que estar al tanto
  static const prioNormal  = Color(0xFF4FC3F7); // Azul claro → flujo normal
  static const prioBaja    = Color(0xFF90A4AE); // Gris azulado → cuando se pueda
  static const prioNinguna = Color(0xFF4A4E66); // Igual que el borde → sin urgencia
}

// ── HELPER: ICONO SEGÚN EL ESTADO ────────────────────────────────────────────
// Antes este método existía duplicado en proyectos.dart y Tareas.dart.
// Lo extraemos aquí como función libre para que ambas pantallas lo reutilicen
// sin tener que mantener dos copias del mismo código.
Widget imagenSegunEstado(String estado) {
  switch (estado) {
    case "En curso":
      return const Icon(
        Icons.keyboard_double_arrow_right_sharp,
        color: Colors.orange,
      );
    case "Pausado":
      return const Icon(Icons.pause_circle_outline, color: Colors.red);
    case "Finalizado":
      return const Icon(
        Icons.playlist_add_check_circle,
        color: Color.fromARGB(255, 72, 209, 54),
      );
    default:
      return const Icon(Icons.work, color: Colors.blueGrey);
  }
}

// ── HELPER: COLOR SEGÚN LA URGENCIA DE LA FECHA LÍMITE ───────────────────────
// Verde = hay tiempo, naranja = dentro del rango de alerta, rojo = ya venció.
// Recibe diasAntelacion como parámetro porque cada pantalla puede tener un
// valor diferente configurado por el usuario.
Color colorFechaLimite(DateTime fecha, int diasAntelacion) {
  final hoy = DateTime.now();
  final diferencia =
      fecha.difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
  if (diferencia < 0) return const Color(0xFFFF6B6B); // Venció → rojo
  if (diferencia <= diasAntelacion) return const Color(0xFFFFB347); // Próximo → naranja
  return const Color(0xFF48D136); // Con tiempo → verde
}

// ── HELPER: TEXTO DESCRIPTIVO PARA LA FECHA LÍMITE ───────────────────────────
// Convierte los días que faltan en un texto amigable para el usuario.
String textoFechaLimite(DateTime fecha) {
  final hoy = DateTime.now();
  final diferencia =
      fecha.difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
  if (diferencia < 0) return 'Venció hace ${-diferencia} día(s)';
  if (diferencia == 0) return '¡Vence hoy!';
  if (diferencia == 1) return 'Vence mañana';
  return 'Vence en $diferencia días';
}

// ── HELPER: NÚMERO DE DÍAS RESTANTES (entero) ─────────────────────────────────
// Devuelve cuántos días quedan hasta la fecha límite (negativo si ya venció).
int diasRestantes(DateTime fecha) {
  final hoy = DateTime.now();
  return fecha.difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
}

// --- MIGRACIÓN A SUPABASE ---
// El esquema de Supabase usa un enum task_status con valores en inglés:
// 'todo', 'in_progress', 'review', 'done'.
// La UI sigue mostrando los valores en español, así que necesitamos
// dos funciones para traducir entre el mundo de la UI y el de la base de datos.
// Las movemos aquí para que Tareas.dart y TablaTarea.dart las puedan compartir.

// Convierte el texto que ve el usuario al valor que entiende PostgreSQL
String statusAEnum(String statusUI) {
  switch (statusUI) {
    case 'En curso':
      return 'in_progress';
    case 'Pausado':
      return 'review';
    case 'Finalizado':
      return 'done';
    default:
      return 'todo'; // 'Por iniciar' y cualquier otro valor → 'todo'
  }
}

// Convierte el valor del enum de PostgreSQL al texto que ve el usuario
String enumAStatus(String enumVal) {
  switch (enumVal) {
    case 'in_progress':
      return 'En curso';
    case 'review':
      return 'Pausado';
    case 'done':
      return 'Finalizado';
    default:
      return 'Por iniciar'; // 'todo' y cualquier valor desconocido
  }
}

// ── HELPERS DE PRIORIDAD ─────────────────────────────────────────────────────
// Estas funciones convierten el enum de PostgreSQL ('urgent', 'high', etc.)
// en colores, emojis y texto para la UI. Están aquí para que cualquier
// parte de la app (Tareas.dart, la tabla, los filtros...) las use igual.

// Devuelve el color de la franja lateral según la prioridad de la tarea
Color colorPrioridad(String? prioridad) {
  switch (prioridad) {
    case 'urgent': return AppColores.prioUrgente;
    case 'high':   return AppColores.prioAlta;
    case 'normal': return AppColores.prioNormal;
    case 'low':    return AppColores.prioBaja;
    default:       return AppColores.prioNinguna; // 'none' y cualquier otro
  }
}

// Devuelve el emoji de la prioridad para mostrar junto al nombre
String emojiPrioridad(String? prioridad) {
  switch (prioridad) {
    case 'urgent': return '🔴';
    case 'high':   return '🟡';
    case 'normal': return '🔵';
    case 'low':    return '⚪';
    default:       return '—'; // Sin prioridad
  }
}

// Devuelve el texto legible para el humano
String textoPrioridad(String? prioridad) {
  switch (prioridad) {
    case 'urgent': return 'Urgente';
    case 'high':   return 'Alta';
    case 'normal': return 'Normal';
    case 'low':    return 'Baja';
    default:       return 'Sin prioridad';
  }
}

// Devuelve un número para ordenar de mayor a menor urgencia.
// Menor número = más urgente → aparecerá primero en la lista.
int ordenPrioridad(String? prioridad) {
  switch (prioridad) {
    case 'urgent': return 0;
    case 'high':   return 1;
    case 'normal': return 2;
    case 'low':    return 3;
    default:       return 4; // 'none' va al final
  }
}
