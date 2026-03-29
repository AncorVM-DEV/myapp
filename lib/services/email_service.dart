// ── SERVICIO DE NOTIFICACIONES POR CORREO ────────────────────────────────────
// Sustituye completamente el antiguo NotificationService (push local).
// En lugar de programar alarmas nativas del dispositivo, invocamos una
// Edge Function de Supabase que se encarga de enviar el email desde el servidor.
//
// Ventajas sobre las push locales:
//   • Funciona en todas las plataformas (web, móvil, escritorio) sin permisos.
//   • El correo llega aunque la app esté cerrada.
//   • Fácil de personalizar la plantilla HTML en el servidor.
//
// USO:
//   // Avisar de una invitación a proyecto:
//   await EmailService.notificarInvitacion(
//     emailDestinatario: 'colaborador@ejemplo.com',
//     nombreDestinatario: 'Colaborador',
//     nombreProyecto: 'Mi Proyecto',
//     nombreInvitador: 'Tu Nombre',
//   );
//
//   // Avisar de una tarea asignada:
//   await EmailService.notificarTareaAsignada(
//     emailDestinatario: 'colaborador@ejemplo.com',
//     nombreDestinatario: 'Colaborador',
//     nombreTarea: 'Revisar diseño',
//     nombreProyecto: 'Mi Proyecto',
//     nombreAsignador: 'Tu Nombre',
//     fechaLimite: DateTime(2025, 12, 31),
//   );

import 'package:myapp/main.dart' show supabase;

class EmailService {
  // ── NOMBRE DE LA EDGE FUNCTION ────────────────────────────────────────────
  // Debe coincidir exactamente con el nombre del archivo en
  // supabase/functions/enviar_email/index.ts de tu proyecto Supabase.
  static const String _functionName = 'enviar_email';

  // ── NOTIFICAR INVITACIÓN A PROYECTO ───────────────────────────────────────
  // Llama a la Edge Function para enviar un correo de invitación.
  // Devuelve true si el envío fue exitoso, false si hubo algún error.
  //
  // Parámetros:
  //   emailDestinatario  → Dirección de correo del usuario invitado
  //   nombreDestinatario → Nombre completo del usuario invitado
  //   nombreProyecto     → Nombre del proyecto al que se invita
  //   nombreInvitador    → Nombre del usuario que hace la invitación
  static Future<bool> notificarInvitacion({
    required String emailDestinatario,
    required String nombreDestinatario,
    required String nombreProyecto,
    required String nombreInvitador,
  }) async {
    return _invocarEdgeFunction({
      'tipo': 'invitacion_proyecto', // Tipo de email para la plantilla en el servidor
      'email_destinatario': emailDestinatario,
      'nombre_destinatario': nombreDestinatario,
      'nombre_proyecto': nombreProyecto,
      'nombre_invitador': nombreInvitador,
    });
  }

  // ── NOTIFICAR TAREA ASIGNADA ───────────────────────────────────────────────
  // Llama a la Edge Function para avisar por correo de una nueva tarea asignada.
  // Devuelve true si el envío fue exitoso, false si hubo algún error.
  //
  // Parámetros:
  //   emailDestinatario  → Dirección de correo del usuario al que se asigna
  //   nombreDestinatario → Nombre completo del usuario al que se asigna
  //   nombreTarea        → Título de la tarea
  //   nombreProyecto     → Nombre del proyecto al que pertenece
  //   nombreAsignador    → Nombre del usuario que asigna la tarea
  //   fechaLimite        → Fecha límite opcional de la tarea
  static Future<bool> notificarTareaAsignada({
    required String emailDestinatario,
    required String nombreDestinatario,
    required String nombreTarea,
    required String nombreProyecto,
    required String nombreAsignador,
    DateTime? fechaLimite,
  }) async {
    return _invocarEdgeFunction({
      'tipo': 'tarea_asignada', // Tipo de email para la plantilla en el servidor
      'email_destinatario': emailDestinatario,
      'nombre_destinatario': nombreDestinatario,
      'nombre_tarea': nombreTarea,
      'nombre_proyecto': nombreProyecto,
      'nombre_asignador': nombreAsignador,
      // Enviamos la fecha en ISO 8601 si existe, null si no hay fecha límite
      'fecha_limite': fechaLimite?.toIso8601String(),
    });
  }

  // ── MÉTODO PRIVADO: INVOCAR EDGE FUNCTION ─────────────────────────────────
  // Centraliza la llamada a Supabase para que los métodos públicos sean limpios.
  // Captura cualquier excepción de red o de la función y devuelve false en ese caso.
  static Future<bool> _invocarEdgeFunction(
    Map<String, dynamic> cuerpo,
  ) async {
    try {
      // supabase.functions.invoke() llama a la Edge Function con el cuerpo JSON.
      // Supabase se encarga de añadir el JWT del usuario autenticado en la cabecera
      // Authorization automáticamente, así la función puede verificar quién la llama.
      await supabase.functions.invoke(_functionName, body: cuerpo);

      print('✅ EMAIL: notificación enviada correctamente. Tipo: ${cuerpo['tipo']}');
      return true;
    } catch (e) {
      // Si hay error de red, la Edge Function no existe todavía o devuelve un error,
      // lo registramos pero NO interrumpimos el flujo de la app.
      // El usuario no debe ver un error si solo falla el correo de aviso.
      print('🔴 EMAIL: error al invocar Edge Function "$_functionName" → $e');
      return false;
    }
  }
}
