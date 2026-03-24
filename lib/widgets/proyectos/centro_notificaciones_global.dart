import 'package:flutter/material.dart';
import 'package:myapp/widgets/app_colores.dart';
import 'package:myapp/main.dart' show supabase;

// ── CENTRO DE NOTIFICACIONES GLOBAL ──────────────────────────────────────
// Busca TODAS las tareas del usuario (sin filtrar por proyecto) que tienen
// fecha límite dentro del rango de alerta. Así el usuario ve de un vistazo
// qué le urge en toda la aplicación, no solo en un proyecto concreto.
void mostrarCentroNotificacionesGlobal({
  required BuildContext ctx,
  // Días de antelación actuales para pre-seleccionar el chip correcto
  required int diasAntelacion,
  // IDs de notificaciones que el usuario ya descartó en esta sesión
  required Set<String> notificacionesLeidas,
  // Caché con los nombres de los proyectos para mostrar en las notificaciones
  required Map<String, String> proyectosCache,
  // Callback para que el padre actualice su estado cuando el usuario cambia los días
  required void Function(int nuevosDias) onCambiarDias,
  // Callback para que el padre actualice su estado cuando el usuario descarta una notif
  required void Function() onActualizarEstado,
}) {
  showDialog(
    context: ctx,
    builder: (BuildContext notifCtx) {
      // Copia local del valor para el selector; se sincroniza con el estado principal.
      int diasTemp = diasAntelacion;

      return StatefulBuilder(
        builder: (context, setStateNotif) {
          final ahora = DateTime.now();
          final limiteAlerta = ahora.add(Duration(days: diasTemp));

          // --- MIGRACIÓN A SUPABASE ---
          // El UUID del usuario actual lo sacamos de la sesión activa de Supabase.
          final userId = supabase.auth.currentUser!.id;

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            backgroundColor: AppColores.bgCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColores.borderColor),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(notifCtx).size.height * 0.80,
                maxWidth: 480,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Cabecera ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_rounded,
                            color: AppColores.orangePrimary, size: 26),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Notificaciones globales',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: AppColores.textMuted, size: 20),
                          onPressed: () => Navigator.pop(notifCtx),
                        ),
                      ],
                    ),
                  ),

                  // ── Control de días de antelación (chips en lugar de Slider) ──
                  // Reemplazamos el Slider anterior por botones fijos y claros:
                  // 1, 3, 7 o 15 días. Así es más rápido de usar y evita valores
                  // extraños. Al pulsar uno actualiza el estado inmediatamente.
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF23253A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColores.borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.tune_rounded,
                                  color: AppColores.orangePrimary, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Avisar con $diasTemp día(s) de antelación',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Fila de chips con las opciones disponibles
                          // Wrap para que en pantallas pequeñas no haya overflow
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [1, 3, 7, 15].map((opcion) {
                              final seleccionado = diasTemp == opcion;
                              return ChoiceChip(
                                label: Text(
                                  '$opcion ${opcion == 1 ? 'día' : 'días'}',
                                ),
                                selected: seleccionado,
                                // Color de fondo del chip seleccionado: naranja ProTask
                                selectedColor: AppColores.orangePrimary,
                                // Color del chip sin seleccionar: fondo oscuro
                                backgroundColor: const Color(0xFF2D3142),
                                labelStyle: TextStyle(
                                  color: seleccionado
                                      ? Colors.white
                                      : AppColores.textMuted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                side: BorderSide(
                                  color: seleccionado
                                      ? AppColores.orangePrimary
                                      : AppColores.borderColor,
                                ),
                                onSelected: (_) {
                                  // Actualizamos tanto el estado del diálogo como el global
                                  setStateNotif(() => diasTemp = opcion);
                                  onCambiarDias(opcion);
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Lista de tareas con alerta ───────────────────────
                  // --- MIGRACIÓN A SUPABASE ---
                  // Cambiamos el StreamBuilder de Firestore (QuerySnapshot) por uno de Supabase.
                  // Escuchamos en tiempo real las tareas creadas por el usuario actual.
                  // ⚠️ Para que el stream funcione, asegúrate de habilitar Realtime
                  // en la tabla 'tasks' desde tu panel de Supabase → Database → Replication.
                  Flexible(
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: supabase
                          .from('tasks')
                          .stream(primaryKey: ['id'])
                          .eq('created_by', userId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                                color: AppColores.orangePrimary),
                          );
                        }

                        if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return _buildEstadoVacioNotif(
                              'No tienes tareas en ningún proyecto.');
                        }

                        // Filtramos las tareas que deben aparecer en el panel:
                        // 1) Que tengan fecha límite dentro del rango
                        // 2) Que NO estén finalizadas (en el nuevo esquema status == 'done')
                        // 3) Que el usuario no las haya descartado en esta sesión
                        final tareasEnAlerta =
                            snapshot.data!.where((data) {
                          // En el nuevo esquema 'done' equivale al antiguo iscompleted == true
                          if (data['status'] == 'done') return false;

                          // Si el usuario la marcó como leída en esta sesión la ocultamos
                          if (notificacionesLeidas.contains(data['id'] as String)) return false;

                          if (data['due_date'] == null) return false;

                          // Supabase devuelve las fechas como String ISO 8601,
                          // así que las parseamos a DateTime para poder compararlas.
                          final fecha = DateTime.parse(data['due_date'] as String);
                          return fecha.isBefore(limiteAlerta) ||
                              fecha.isAtSameMomentAs(limiteAlerta);
                        }).toList();

                        if (tareasEnAlerta.isEmpty) {
                          return _buildEstadoVacioNotif(
                            '¡Todo al día! No hay tareas que venzan en los próximos $diasTemp día(s).',
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                          itemCount: tareasEnAlerta.length,
                          itemBuilder: (context, index) {
                            final data = tareasEnAlerta[index];
                            // Supabase devuelve la fecha como String, la parseamos
                            final fecha = DateTime.parse(data['due_date'] as String);
                            final color = colorFechaLimite(fecha, diasTemp);
                            final dias = diasRestantes(fecha);

                            // En el nuevo esquema el nombre de la tarea es 'title', no 'name'
                            final nombreTarea = data['title'] ?? 'Sin nombre';

                            // Buscamos el nombre del proyecto en nuestra caché local.
                            // Si no está cacheado todavía mostramos el ID abreviado como fallback.
                            final projectId = data['project_id'] as String?;
                            final nombreProyecto = projectId != null
                                ? (proyectosCache[projectId] ?? 'Proyecto ${projectId.substring(0, 8)}...')
                                : 'Sin proyecto';

                            // ── Texto con el formato exacto solicitado ──
                            // "Quedan X días para que la tarea: '[nombre]'
                            // del proyecto: '[proyecto]' llegue a su fecha límite."
                            // Casos especiales: ya venció, vence hoy, vence mañana.
                            String mensajeNotif;
                            if (dias < 0) {
                              mensajeNotif =
                                  "La tarea: '$nombreTarea' del proyecto: '$nombreProyecto' venció hace ${-dias} día(s).";
                            } else if (dias == 0) {
                              mensajeNotif =
                                  "¡Hoy es la fecha límite de la tarea: '$nombreTarea' del proyecto: '$nombreProyecto'!";
                            } else {
                              mensajeNotif =
                                  "Quedan $dias día(s) para que la tarea: '$nombreTarea' del proyecto: '$nombreProyecto' llegue a su fecha límite.";
                            }

                            return Container(
                              margin:
                                  const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF23253A),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: color.withOpacity(0.5)),
                              ),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  // Barra de color de urgencia a la izquierda
                                  Container(
                                    width: 4,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      mensajeNotif,
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(Icons.alarm_rounded,
                                      color: color, size: 20),

                                  // ── Botón "Marcar como leída" ───────────
                                  // Al pulsar la X, el ID del documento se añade
                                  // al set local y la notificación desaparece de
                                  // la lista y se descuenta del badge.
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () {
                                      // --- MIGRACIÓN A SUPABASE ---
                                      // El ID ahora viene en data['id'] como String UUID,
                                      // no como doc.id de Firestore.
                                      setStateNotif(() {
                                        notificacionesLeidas.add(data['id'] as String);
                                      });
                                      // También reconstruimos el badge del AppBar
                                      onActualizarEstado();
                                    },
                                    child: const Tooltip(
                                      message: 'Marcar como leída',
                                      child: Icon(
                                        Icons.check_circle_outline,
                                        color: AppColores.textMuted,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// ── HELPER: ESTADO VACÍO PARA EL PANEL DE NOTIFICACIONES ─────────────────
// Widget reutilizable para cuando no hay nada que mostrar
Widget _buildEstadoVacioNotif(String mensaje) {
  return Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.notifications_off_rounded,
            color: AppColores.borderColor, size: 48),
        const SizedBox(height: 12),
        Text(
          mensaje,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColores.textMuted, fontSize: 13),
        ),
      ],
    ),
  );
}
