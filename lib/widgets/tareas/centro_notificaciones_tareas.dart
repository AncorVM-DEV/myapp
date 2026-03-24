import 'package:flutter/material.dart';
import 'package:myapp/widgets/app_colores.dart';
import 'package:myapp/main.dart' show supabase;

// ── CENTRO DE NOTIFICACIONES ─────────────────────────────────────────────
// Al pulsar la campana se abre este diálogo que muestra todas las tareas
// que tienen fecha límite dentro del rango de alerta configurado.
// El usuario también puede cambiar aquí los días de antelación.
void mostrarCentroNotificacionesTareas({
  required BuildContext ctx,
  // UUID del proyecto para filtrar solo las tareas de este proyecto
  required String projectId,
  // Nombre del proyecto para mostrarlo en los mensajes de las notificaciones
  required String nombreProyecto,
  // Días de antelación actuales para pre-seleccionar el chip correcto
  required int diasAntelacion,
  // IDs de notificaciones que el usuario ya descartó en esta sesión
  required Set<String> notificacionesLeidas,
  // Callback para que el padre actualice su estado cuando el usuario cambia los días
  required void Function(int nuevosDias) onCambiarDias,
  // Callback para que el padre actualice su estado cuando el usuario descarta una notif
  required void Function() onActualizarEstado,
}) {
  // Usamos un StatefulBuilder porque el usuario puede cambiar _diasAntelacion
  // desde dentro del diálogo y queremos que la lista se actualice al instante.
  showDialog(
    context: ctx,
    builder: (BuildContext notifCtx) {
      // Creamos una copia local para el StatefulBuilder; cuando el usuario
      // confirme el cambio actualizaremos el estado principal del widget.
      int diasTemp = diasAntelacion;

      return StatefulBuilder(
        builder: (context, setStateNotif) {
          // Calculamos la fecha límite del rango de alerta
          final ahora = DateTime.now();
          final limiteAlerta = ahora.add(Duration(days: diasTemp));

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
                  // ── Cabecera del panel de notificaciones ─────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.notifications_rounded,
                          color: AppColores.orangePrimary,
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Centro de notificaciones',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        // Botón para cerrar el diálogo desde la cabecera
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: AppColores.textMuted,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(notifCtx),
                        ),
                      ],
                    ),
                  ),

                  // ── Control de días de antelación (chips en lugar de Slider) ──
                  // Aquí el usuario elige con cuántos días de antelación quiere ver
                  // las alertas. Usamos chips fijos (1, 3, 7, 15) en lugar del
                  // Slider anterior: es más rápido de usar y evita valores raros.
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
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
                              const Icon(
                                Icons.tune_rounded,
                                color: AppColores.orangePrimary,
                                size: 18,
                              ),
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
                          // Wrap de chips: si no caben en una fila bajan solos
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
                                // Naranja ProTask para el chip activo
                                selectedColor: AppColores.orangePrimary,
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
                                  // Actualizamos el diálogo y el estado principal
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

                  // ── Lista de tareas con alerta ───────────────────────────
                  // StreamBuilder para que la lista se actualice en tiempo real
                  // si alguien crea o edita tareas mientras el diálogo está abierto.
                  // --- MIGRACIÓN A SUPABASE ---
                  // Cambiamos el stream de Firestore por el de Supabase.
                  // Filtramos por el UUID del proyecto en lugar del nombre.
                  Flexible(
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: supabase
                          .from('tasks')
                          .stream(primaryKey: ['id'])
                          .eq('project_id', projectId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppColores.orangePrimary,
                            ),
                          );
                        }

                        if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return _buildEstadoVacioNotif(
                            'No hay tareas en este proyecto.',
                          );
                        }

                        // Filtramos las tareas que deben aparecer:
                        // 1) Que tengan fecha y estén dentro del rango
                        // 2) Que NO estén finalizadas (status == 'done')
                        // 3) Que el usuario no las haya descartado en esta sesión
                        final tareasEnAlerta = snapshot.data!.where((data) {
                          // En el nuevo esquema 'done' equivale a iscompleted == true
                          if (data['status'] == 'done') return false;
                          // Si el usuario ya la marcó como leída la ocultamos
                          if (notificacionesLeidas.contains(data['id'] as String))
                            return false;
                          // Si no tiene 'due_date' la descartamos silenciosamente
                          if (data['due_date'] == null) return false;
                          // Supabase devuelve la fecha como String ISO 8601, la parseamos
                          final fecha = DateTime.parse(data['due_date'] as String);
                          // Mostramos las que vencen ANTES del límite de alerta
                          // incluyendo las que ya vencieron (fecha en el pasado)
                          return fecha.isBefore(limiteAlerta) ||
                              fecha.isAtSameMomentAs(limiteAlerta);
                        }).toList();

                        if (tareasEnAlerta.isEmpty) {
                          return _buildEstadoVacioNotif(
                            '¡Todo bien! No hay tareas que venzan en los próximos $diasTemp día(s).',
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                          itemCount: tareasEnAlerta.length,
                          itemBuilder: (context, index) {
                            final data = tareasEnAlerta[index];
                            // Parseamos la fecha ISO 8601 que nos devuelve Supabase
                            final fecha = DateTime.parse(data['due_date'] as String);
                            final color = colorFechaLimite(fecha, diasTemp);
                            // En el nuevo esquema el nombre de la tarea es 'title'
                            final nombreTarea = data['title'] ?? 'Sin nombre';
                            // El nombre del proyecto es nombreProyecto
                            // porque en Tareas.dart solo se muestran tareas del proyecto actual.
                            final dias = fecha
                                .difference(
                                  DateTime(
                                    DateTime.now().year,
                                    DateTime.now().month,
                                    DateTime.now().day,
                                  ),
                                )
                                .inDays;

                            // Construimos el mensaje con el formato solicitado
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
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF23253A),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: color.withOpacity(0.5),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Indicador de color de urgencia
                                  Container(
                                    width: 4,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(4),
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
                                  Icon(
                                    Icons.alarm_rounded,
                                    color: color,
                                    size: 20,
                                  ),
                                  // ── Botón "Marcar como leída" ───────────
                                  // Al pulsar el ✓ el ID se guarda en el set local
                                  // y la notificación desaparece de la lista + badge.
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () {
                                      // --- MIGRACIÓN A SUPABASE ---
                                      // El ID ahora es un UUID String, no un doc.id de Firestore
                                      setStateNotif(() {
                                        notificacionesLeidas.add(data['id'] as String);
                                      });
                                      // Reconstruimos el badge del AppBar
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
// Pequeño widget reutilizable para cuando no hay nada que mostrar en las notifs
Widget _buildEstadoVacioNotif(String mensaje) {
  return Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.notifications_off_rounded,
          color: AppColores.borderColor,
          size: 48,
        ),
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
