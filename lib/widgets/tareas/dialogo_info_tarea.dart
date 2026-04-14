import 'package:flutter/material.dart';
import 'package:myapp/main.dart' show supabase;
import 'package:myapp/utils/sanitizer.dart'; // Sanitización de inputs antes de enviar a Supabase
import 'package:myapp/widgets/app_colores.dart';
import 'package:myapp/widgets/tareas/seccion_clickup.dart';
import 'package:myapp/widgets/tareas/dialogo_confirmacion_borrado_tarea.dart';
// ── Secciones reales conectadas a Supabase ───────────────────────────────────
import 'package:myapp/widgets/tareas/seccion_subtareas.dart';
import 'package:myapp/widgets/tareas/seccion_comentarios.dart';
// [FASE 1B] Importamos la nueva sección de adjuntos con subida de archivos
import 'package:myapp/widgets/tareas/seccion_adjuntos.dart';

// ── DIÁLOGO DE INFORMACIÓN DE UNA TAREA (con edición in-line) ────────────────
// Lo sacamos de Tareas.dart para aligerar ese archivo.
// Muestra descripción, estado, fecha límite y las secciones en estilo ClickUp.
//
// CAMBIO RESPECTO A LA VERSIÓN ANTERIOR:
// Ya no hay botón "Editar" que abre otro popup encima de este.
// Ahora los campos de nombre y descripción son TextField directamente en el
// diálogo. El usuario edita ahí mismo y pulsa "Guardar cambios" una sola vez.
// Esto elimina la dependencia de dialogo_edicion_tarea.dart.
void mostrarDialogoInfoTarea({
  required BuildContext ctx,
  required String tareaName,
  required String taskDescription,
  required String taskEstado,
  required String taskId,
  DateTime? fechaLimite, // Puede ser null en tareas antiguas sin fecha límite
  // Prioridad actual de la tarea (null en tareas antiguas → se trata como 'none')
  String? prioridadActual,
  // Días de antelación actuales para calcular el color de urgencia
  required int diasAntelacion,
  // Función para eliminar la tarea en Supabase; viene de Tareas.dart
  required Future<void> Function(String nombre, String id) onEliminar,
  // Función para mostrar snackbars desde el contexto raíz de la pantalla
  required void Function(String mensaje, {bool esError}) onMostrarSnackbar,
}) {
  showDialog(
    context: ctx,
    builder: (BuildContext infoContext) {
      // ── Controladores de texto ────────────────────────────────────────────
      // Los inicializamos con los valores actuales para que el usuario los vea
      // pre-rellenados. Viven aquí para sobrevivir a los rebuilds del diálogo.
      final nombreEditCont = TextEditingController(text: tareaName);
      final descEditCont = TextEditingController(text: taskDescription);

      // ── VARIABLES DE ESTADO MUTABLES ─────────────────────────────────────
      // ⚠️ CRÍTICO — Por qué estas variables están AQUÍ y no dentro del
      // builder del StatefulBuilder:
      //
      // El builder de StatefulBuilder se ejecuta de nuevo cada vez que se
      // llama a setStateLocal(). Si las variables estuvieran dentro de ese
      // builder, se recrearían con sus valores iniciales en cada rebuild.
      // Ejemplo: el usuario elige prioridad 'urgent', setStateLocal()
      // redibuja el diálogo → builder recrea `prioridadEditable = 'none'`
      // → el dropdown vuelve a 'none' visualmente y guardarCambios() envía
      // 'none' a la BD aunque el usuario eligió 'urgent'.
      //
      // Colocándolas aquí (dentro del builder del showDialog, fuera del
      // builder del StatefulBuilder) se inicializan UNA SOLA VEZ cuando el
      // diálogo se abre. setStateLocal() las muta y mantienen su valor
      // entre rebuilds porque son variables del closure externo, no locales
      // del closure interno.
      DateTime? fechaEditable = fechaLimite;
      String prioridadEditable = prioridadActual ?? 'none';
      // [FIX] Estado editable en el closure externo (misma razón que prioridadEditable):
      // vive fuera del StatefulBuilder para no resetearse en cada setStateLocal().
      String statusEditable = taskEstado;
      bool guardando = false;

      return StatefulBuilder(
        builder: (context, setStateLocal) {
          // ── Función de guardado ────────────────────────────────────────
          // Lee los valores actuales de los controllers y de las variables
          // del closure externo (fechaEditable, prioridadEditable) y los
          // envía todos al mismo tiempo en un único .update() de Supabase.
          Future<void> guardarCambios() async {
            final nuevoNombre = nombreEditCont.text.trim();
            final nuevaDesc = descEditCont.text.trim();

            if (nuevoNombre.isEmpty) {
              onMostrarSnackbar(
                'El nombre no puede estar vacío',
                esError: true,
              );
              return;
            }

            setStateLocal(() => guardando = true);

            try {
              // Enviamos todos los campos editables en un único update.
              // En este punto fechaEditable y prioridadEditable tienen los
              // valores que el usuario eligió, NO los valores iniciales,
              // porque viven en el closure externo y sobreviven a los rebuilds.
              // Sanitizamos el input antes de enviarlo a Supabase
              await supabase
                  .from('tasks')
                  .update({
                    'title': Sanitizer.clean(nuevoNombre),
                    'description': Sanitizer.cleanNullable(nuevaDesc),
                    'priority': prioridadEditable, // ← prioridad elegida
                    'due_date': fechaEditable
                        ?.toIso8601String(), // ← fecha elegida (null = borrar)
                    // [FIX] Incluimos también el estado actual para que "Guardar cambios"
                    // persista cualquier estado que el usuario haya elegido en el dropdown.
                    'status': statusAEnum(statusEditable),
                  })
                  .eq('id', taskId);

              if (!context.mounted) return;
              Navigator.pop(infoContext);
              onMostrarSnackbar('¡Cambios guardados!');
            } catch (e) {
              print('Error en BD: $e'); // ← log de depuración
              if (!context.mounted) return;
              setStateLocal(() => guardando = false);
              onMostrarSnackbar('Error al guardar: $e', esError: true);
            }
          }

          // ── UI del diálogo ───────────────────────────────────────────────
          return Dialog(
            // insetPadding controla el margen exterior del diálogo respecto a la
            // pantalla; reducirlo permite que el diálogo sea más ancho en móviles.
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
              // Aqui limitamos la altura máxima al 90 % del alto de pantalla para que
              // el diálogo nunca sea más alto que la pantalla disponible.
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(infoContext).size.height * 0.90,
                maxWidth: 520,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Cabecera fija (no hace scroll) ──────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              AppColores.orangePrimary,
                              AppColores.orangeLight,
                            ],
                          ).createShader(bounds),
                          child: const Icon(
                            Icons.bar_chart_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Informacion de la tarea',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Mostramos el estado como subtítulo para dar contexto visual
                        Text(
                          taskEstado,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColores.orangeLight,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Contenido desplazable ──────────────────────────────────────
                  // Aqui usamos Flexible + SingleChildScrollView para que el contenido ocupe el espacio
                  // restante y, si es más alto que ese espacio, se puede hacer scroll.
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Campo editable de NOMBRE ──────────────────────
                          // Antes era un Text estático. Ahora es un TextField
                          // con un estilo limpio que parece texto normal pero
                          // el usuario puede tocar para editar.
                          _etiquetaCampo('NOMBRE'),
                          const SizedBox(height: 4),
                          _campoEditable(
                            controller: nombreEditCont,
                            hintText: 'Nombre de la tarea',
                          ),
                          const SizedBox(height: 12),

                          // ── Campo editable de DESCRIPCIÓN ─────────────────
                          _etiquetaCampo('DESCRIPCIÓN'),
                          const SizedBox(height: 4),
                          _campoEditable(
                            controller: descEditCont,
                            hintText: 'Descripción de la tarea',
                            maxLines: 3,
                          ),
                          const SizedBox(height: 12),

                          // ── Selector editable de PRIORIDAD ────────────────
                          // El icono de bandera cambia de color en tiempo real.
                          // onChanged llama a setStateLocal para redibujar el
                          // icono, y actualiza prioridadEditable en el closure
                          // externo para que guardarCambios() la lea correctamente.
                          _etiquetaCampo('PRIORIDAD'),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: prioridadEditable,
                            dropdownColor: AppColores.bgCard,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF23253A),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: AppColores.borderColor,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  // El borde toma el color de la prioridad elegida
                                  color: colorPrioridad(prioridadEditable),
                                  width: 2,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              // Banderita de color que cambia según la prioridad
                              prefixIcon: Icon(
                                Icons.flag_rounded,
                                color: colorPrioridad(prioridadEditable),
                                size: 20,
                              ),
                            ),
                            // Reemplazamos emojis por Icon nativos para
                            // renderizado consistente en todas las plataformas
                            items: [
                              const DropdownMenuItem(
                                value: 'none',
                                child: Text('— Sin prioridad'),
                              ),
                              DropdownMenuItem(
                                value: 'low',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.flag_outlined, color: AppColores.prioBaja, size: 14),
                                    SizedBox(width: 6),
                                    Text('Baja'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'normal',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.flag_rounded, color: AppColores.prioNormal, size: 14),
                                    SizedBox(width: 6),
                                    Text('Normal'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'high',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.flag_rounded, color: AppColores.prioAlta, size: 14),
                                    SizedBox(width: 6),
                                    Text('Alta'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'urgent',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.flag_rounded, color: AppColores.prioUrgente, size: 14),
                                    SizedBox(width: 6),
                                    Text('Urgente'),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (nuevaPrio) {
                              if (nuevaPrio != null) {
                                // Actualizamos la variable del closure externo Y
                                // pedimos un rebuild para refrescar el icono.
                                setStateLocal(
                                  () => prioridadEditable = nuevaPrio,
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 12),

                          // [FIX] El bloque de estado de solo lectura se sustituye por un
                          // DropdownButtonFormField editable que hace el UPDATE a Supabase
                          // de forma inmediata al cambiar, sin necesidad de "Guardar cambios".
                          _etiquetaCampo('ESTADO'),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: statusEditable,
                            dropdownColor: AppColores.bgCard,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF23253A),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: AppColores.borderColor,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: AppColores.orangePrimary,
                                  width: 2,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              // El icono de estado cambia en tiempo real según la selección
                              prefixIcon: imagenSegunEstado(statusEditable),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Por iniciar',
                                child: Text('Por iniciar'),
                              ),
                              DropdownMenuItem(
                                value: 'En curso',
                                child: Text('En curso'),
                              ),
                              DropdownMenuItem(
                                value: 'Pausado',
                                child: Text('Pausado'),
                              ),
                              DropdownMenuItem(
                                value: 'Finalizado',
                                child: Text('Finalizado'),
                              ),
                            ],
                            onChanged: (nuevoEstado) async {
                              if (nuevoEstado == null) return;
                              // Actualizamos la variable del closure y reconstruimos
                              // para refrescar el icono del prefixIcon inmediatamente.
                              setStateLocal(() => statusEditable = nuevoEstado);
                              try {
                                // UPDATE inmediato a Supabase sin esperar a "Guardar cambios"
                                await supabase
                                    .from('tasks')
                                    .update({
                                      'status': statusAEnum(nuevoEstado),
                                    })
                                    .eq('id', taskId);
                                onMostrarSnackbar(
                                  'Estado cambiado a "$nuevoEstado"',
                                );
                              } catch (e) {
                                onMostrarSnackbar(
                                  'Error al cambiar estado: $e',
                                  esError: true,
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 12),

                          // ── Fecha límite editable con un toque ─────────────
                          // Al tocar este bloque se abre el selector de fecha.
                          // onTap actualiza fechaEditable en el closure externo
                          // y llama a setStateLocal para refrescar el texto.
                          _etiquetaCampo('FECHA LÍMITE'),
                          const SizedBox(height: 4),
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () async {
                                final fechaPicked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      fechaEditable ??
                                      DateTime.now().add(
                                        const Duration(days: 7),
                                      ),
                                  firstDate: DateTime.now().subtract(
                                    const Duration(days: 365),
                                  ),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365 * 2),
                                  ),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.dark(
                                          primary: AppColores.orangePrimary,
                                          surface: AppColores.bgCard,
                                          onSurface: Colors.white,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (fechaPicked != null) {
                                  // Mutamos la variable del closure externo y
                                  // pedimos rebuild para refrescar el texto.
                                  setStateLocal(
                                    () => fechaEditable = fechaPicked,
                                  );
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF23253A),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: fechaEditable != null
                                        ? AppColores.orangePrimary
                                        : AppColores.borderColor,
                                    width: fechaEditable != null ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      color: fechaEditable != null
                                          ? colorFechaLimite(
                                              fechaEditable!,
                                              diasAntelacion,
                                            )
                                          : AppColores.textMuted,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        fechaEditable != null
                                            ? '${fechaEditable!.day}/${fechaEditable!.month}/${fechaEditable!.year}  •  ${textoFechaLimite(fechaEditable!)}'
                                            : 'Toca para añadir una fecha límite',
                                        style: TextStyle(
                                          color: fechaEditable != null
                                              ? colorFechaLimite(
                                                  fechaEditable!,
                                                  diasAntelacion,
                                                )
                                              : AppColores.textMuted,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    // Botón para quitar la fecha si ya hay una
                                    if (fechaEditable != null)
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => setStateLocal(
                                          () => fechaEditable = null,
                                        ),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4),
                                          child: Icon(
                                            Icons.close_rounded,
                                            color: AppColores.textMuted,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ══════════════════════════════════════════════════
                          // ── SECCIÓN SUBTAREAS (conectada a Supabase) ──────
                          // ══════════════════════════════════════════════════
                          SeccionClickUp(
                            icono: Icons.checklist_rounded,
                            titulo: 'SUBTAREAS',
                            hijo: SeccionSubtareas(taskId: taskId),
                          ),
                          const SizedBox(height: 12),

                          // ══════════════════════════════════════════════════
                          // ── SECCIÓN COMENTARIOS (conectada a Supabase) ────
                          // ══════════════════════════════════════════════════
                          SeccionClickUp(
                            icono: Icons.chat_bubble_outline_rounded,
                            titulo: 'COMENTARIOS',
                            hijo: SeccionComentarios(taskId: taskId),
                          ),
                          const SizedBox(height: 12),

                          // ══════════════════════════════════════════════════
                          // ── SECCIÓN ARCHIVOS ADJUNTOS (conectada a Supabase) ─
                          // ══════════════════════════════════════════════════
                          // [FASE 1B] Sustituimos la maqueta "Próximamente" por
                          // SeccionAdjuntos, que permite subir cualquier tipo de
                          // archivo al bucket 'archivos_tareas' de Supabase Storage
                          // y visualizarlos directamente en el diálogo.
                          SeccionClickUp(
                            icono: Icons.attach_file_rounded,
                            titulo: 'ARCHIVOS ADJUNTOS',
                            hijo: SeccionAdjuntos(taskId: taskId),
                          ),
                          const SizedBox(height: 16),

                          // ── Separador y botones de acción ─────────────────
                          const Divider(color: AppColores.borderColor),
                          const SizedBox(height: 8),

                          // ── Botón principal "Guardar cambios" ─────────────
                          // Un único botón recoge el nombre, la descripción,
                          // la prioridad y la fecha y los envía a Supabase.
                          // No hay segundo popup: todo ocurre aquí mismo.
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColores.orangePrimary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: guardando
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_rounded, size: 18),
                              label: Text(
                                guardando ? 'Guardando...' : 'Guardar cambios',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              onPressed: guardando ? null : guardarCambios,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Botón "Eliminar tarea"
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFFF6B6B),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: const BorderSide(
                                    color: Color(0xFFFF6B6B),
                                    width: 1,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text(
                                'Eliminar tarea',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              // Pasamos infoContext para que mostrarConfirmacionBorradoTarea
                              // pueda cerrar este diálogo si el usuario confirma el borrado.
                              onPressed: () => mostrarConfirmacionBorradoTarea(
                                parentContext: infoContext,
                                taskName: tareaName,
                                taskId: taskId,
                                onEliminar: onEliminar,
                                onMostrarSnackbar: onMostrarSnackbar,
                              ),
                            ),
                          ),
                          // Pequeño padding inferior para que el botón no quede pegado al borde
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),

                  // ── Botón "Cerrar" siempre visible fuera del scroll ───────
                  // El boton "Cerrar" lo ponemos fuera del scroll y lo ponemos en un Padding fijo.
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColores.borderColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 10,
                        ),
                      ),
                      onPressed: () => Navigator.pop(infoContext),
                      child: const Text('Cerrar'),
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

// ── HELPERS DE ESTILO PARA LOS CAMPOS EDITABLES ──────────────────────────────
// Funciones privadas de este archivo para no repetir el mismo Container decorado
// en cada campo editable. Son solo estilo, no tienen lógica.

// Etiqueta pequeña en mayúsculas sobre cada campo (mismo estilo que el resto del diálogo)
Widget _etiquetaCampo(String texto) {
  return Text(
    texto,
    style: const TextStyle(
      color: AppColores.textMuted,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
    ),
  );
}

// Campo de texto con el diseño oscuro de la app.
// Parece texto normal pero es editable: sin borde tosco, fondo sutil.
// Al enfocar aparece el borde naranja para indicar que está activo.
Widget _campoEditable({
  required TextEditingController controller,
  required String hintText,
  int maxLines = 1,
}) {
  return TextField(
    controller: controller,
    maxLines: maxLines,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    decoration: InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: AppColores.textMuted, fontSize: 14),
      filled: true,
      fillColor: const Color(0xFF23253A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      // Borde tenue en reposo: parece texto normal
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColores.borderColor),
      ),
      // Borde naranja al enfocar: indica claramente que estás editando
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColores.orangePrimary, width: 2),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
