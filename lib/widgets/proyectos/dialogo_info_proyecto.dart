import 'package:flutter/material.dart';
import 'package:myapp/main.dart' show supabase;
import 'package:myapp/widgets/app_colores.dart';
import 'package:myapp/widgets/proyectos/stat_chip.dart';
import 'package:myapp/widgets/proyectos/dialogo_confirmacion_borrado.dart';

// ── CONSULTA PARA LAS ESTADÍSTICAS ────────────────────────────────────────
// La movemos aquí porque solo se usa dentro de este diálogo.
// Se obtiene un mapa con el total de tareas, completadas y pendientes
// de un proyecto dado su UUID (antes se usaba el nombre como clave, ahora usamos el ID real).
Future<Map<String, int>> _obtenerEstadisticas(String projectId) async {
  // --- MIGRACIÓN A SUPABASE ---
  // En Firestore buscábamos por el campo 'padre' (nombre en texto).
  // Ahora usamos el UUID del proyecto, que es la forma correcta y fiable.
  final snapshot = await supabase
      .from('tasks')
      .select('id, status')
      .eq('project_id', projectId);

  final total = snapshot.length;
  // En el nuevo esquema el enum task_status usa 'done' para las tareas completadas.
  // Esto equivale al antiguo iscompleted == true de Firestore.
  final completadas = snapshot.where((d) => d['status'] == 'done').length;
  final pendientes  = total - completadas;

  return {
    'total'      : total,
    'completadas': completadas,
    'pendientes' : pendientes,
  };
}

// ── DIÁLOGO DE INFORMACIÓN Y ESTADÍSTICAS (con edición in-line) ──────────────
// Muestra las estadísticas del proyecto ya cargadas con FutureBuilder.
//
// CAMBIO RESPECTO A LA VERSIÓN ANTERIOR:
// Se elimina el botón "Editar" que abría otro popup. Ahora el nombre,
// la descripción y el estado son editables directamente aquí.
// Un solo botón "Guardar cambios" persiste todo en Supabase.
// No hay dependencia de dialogo_edicion_proyecto.dart para la edición básica.
void mostrarDialogoInfoProyecto({
  required BuildContext ctx,
  required String projectName,
  required String projectDescription,
  required String projectEstado,
  required String projectId,
  // Función para eliminar el proyecto en Supabase; viene del widget padre
  required Future<void> Function(String nombre, String id) onEliminar,
  // Función para mostrar snackbars desde el contexto raíz de la pantalla
  required void Function(String mensaje, {bool esError}) onMostrarSnackbar,
}) {
  showDialog(
    context: ctx,
    builder: (BuildContext infoContext) {
      // ── Controladores de texto ─────────────────────────────────────────
      // Los inicializamos con los valores actuales para que el usuario los vea
      // pre-rellenados. Viven aquí para sobrevivir a los rebuilds del diálogo.
      final nombreEditCont = TextEditingController(text: projectName);
      final descEditCont   = TextEditingController(text: projectDescription);

      // ── VARIABLES DE ESTADO MUTABLES ─────────────────────────────────────
      // ⚠️ CRÍTICO — mismo razonamiento que en dialogo_info_tarea.dart:
      //
      // Estas variables deben estar FUERA del builder del StatefulBuilder.
      // Si estuvieran dentro, cada llamada a setStateLocal() recrearía el
      // builder y resetearía estadoEditable a su valor inicial, haciendo que
      // guardarCambios() siempre enviara el estado original a la BD aunque
      // el usuario hubiera elegido otro.
      //
      // Al ponerlas aquí (en el closure del showDialog) se inicializan una
      // sola vez y setStateLocal() las muta sin perder el valor entre rebuilds.
      String estadoEditable = projectEstado;
      bool   guardando      = false;

      return StatefulBuilder(
        builder: (context, setStateLocal) {
          // ── Función de guardado ──────────────────────────────────────────
          // Recoge nombre, descripción y estado actuales (todos del closure
          // externo o de los controllers) y hace el update en un único
          // .update() de Supabase. Sin abrir más diálogos.
          Future<void> guardarCambios() async {
            final nuevoNombre = nombreEditCont.text.trim();
            final nuevaDesc   = descEditCont.text.trim();

            if (nuevoNombre.isEmpty) {
              onMostrarSnackbar('El nombre no puede estar vacío', esError: true);
              return;
            }

            setStateLocal(() => guardando = true);

            try {
              // estadoEditable viene del closure externo: tiene el valor que
              // el usuario eligió en el dropdown, no el inicial.
              await supabase.from('projects').update({
                'name'       : nuevoNombre,
                'description': nuevaDesc,
                'estado'     : estadoEditable, // ← estado elegido en el dropdown
              }).eq('id', projectId);

              if (!context.mounted) return;
              Navigator.pop(infoContext);
              onMostrarSnackbar('¡Proyecto actualizado!');
            } catch (e) {
              print('Error en BD: $e'); // ← log de depuración
              if (!context.mounted) return;
              setStateLocal(() => guardando = false);
              onMostrarSnackbar('Error al guardar: $e', esError: true);
            }
          }

          // ── UI del diálogo ──────────────────────────────────────────────
          return Dialog(
            // insetPadding controla el margen exterior del diálogo respecto a la
            // pantalla esto al reducirlo permite que el diálogo sea más ancho en móviles.
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            backgroundColor: AppColores.bgCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColores.borderColor),
            ),
            child: ConstrainedBox(
              // Aqui limitamos la altura máxima al 85 % del alto de pantalla para que
              // el diálogo nunca sea más alto que la pantalla disponible.
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(infoContext).size.height * 0.85,
                maxWidth: 520,
              ),
              child: Column(
                // mainAxisSize.min: el Column ocupa solo lo necesario hasta el límite
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Cabecera fija (no hace scroll) ──────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [AppColores.orangePrimary, AppColores.orangeLight],
                          ).createShader(bounds),
                          child: const Icon(
                            Icons.bar_chart_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Informacion del proyecto',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          projectName,
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
                          _etiquetaCampo('NOMBRE DEL PROYECTO'),
                          const SizedBox(height: 4),
                          _campoEditable(
                            controller: nombreEditCont,
                            hintText: 'Nombre del proyecto',
                          ),
                          const SizedBox(height: 12),

                          // ── Campo editable de DESCRIPCIÓN ─────────────────
                          _etiquetaCampo('DESCRIPCIÓN'),
                          const SizedBox(height: 4),
                          _campoEditable(
                            controller: descEditCont,
                            hintText: 'Descripción del proyecto',
                            maxLines: 3,
                          ),
                          const SizedBox(height: 12),

                          // ── Dropdown editable de ESTADO ───────────────────
                          // onChanged muta estadoEditable (closure externo) y
                          // llama a setStateLocal para refrescar el prefixIcon.
                          // guardarCambios() lee estadoEditable del closure, no
                          // del builder, así que siempre tiene el valor correcto.
                          _etiquetaCampo('ESTADO DEL PROYECTO'),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: estadoEditable,
                            dropdownColor: AppColores.bgCard,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF23253A),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColores.borderColor),
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
                              // El icono cambia en tiempo real gracias a que
                              // estadoEditable se muta en el closure externo y
                              // setStateLocal fuerza el rebuild del diálogo.
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(10),
                                child: imagenSegunEstado(estadoEditable),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Por iniciar', child: Text('Por iniciar')),
                              DropdownMenuItem(value: 'En curso',    child: Text('En curso')),
                              DropdownMenuItem(value: 'Pausado',     child: Text('Pausado')),
                              DropdownMenuItem(value: 'Finalizado',  child: Text('Finalizado')),
                            ],
                            onChanged: (nuevoEstado) {
                              if (nuevoEstado != null) {
                                // Mutamos el closure externo y pedimos rebuild
                                // para que el prefixIcon se actualice visualmente.
                                setStateLocal(() => estadoEditable = nuevoEstado);
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          // ── Estadísticas de tareas con FutureBuilder ──────────
                          // El FutureBuilder llama a _obtenerEstadisticas() y reconstruye el
                          // widget cuando el Future completa mientras muestra un loader.
                          // Ahora le pasamos el UUID del proyecto en lugar del nombre.
                          FutureBuilder<Map<String, int>>(
                            future: _obtenerEstadisticas(projectId),
                            builder: (context, statsSnapshot) {
                              // Estado de carga: indicador pequeño centrado
                              if (statsSnapshot.connectionState == ConnectionState.waiting) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                        color: AppColores.orangePrimary,
                                        strokeWidth: 2.5,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              // Estado de error
                              if (statsSnapshot.hasError) {
                                return const Text(
                                  'No se pudieron cargar las estadísticas.',
                                  style: TextStyle(
                                    color: AppColores.textMuted,
                                    fontSize: 12,
                                  ),
                                );
                              }

                              // Datos disponibles: extraemos las métricas
                              final stats       = statsSnapshot.data!;
                              final total       = stats['total']!;
                              final completadas = stats['completadas']!;
                              final pendientes  = stats['pendientes']!;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ESTADÍSTICAS',
                                    style: TextStyle(
                                      color: AppColores.textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  // Tres chips de estadística en fila horizontal
                                  Row(
                                    children: [
                                      StatChip(
                                        label: 'Totales',
                                        valor: total.toString(),
                                        icono: Icons.list_alt_rounded,
                                        color: AppColores.orangePrimary,
                                      ),
                                      const SizedBox(width: 8),
                                      StatChip(
                                        label: 'Completadas',
                                        valor: completadas.toString(),
                                        icono: Icons.check_circle_outline_rounded,
                                        color: const Color(0xFF48D136),
                                      ),
                                      const SizedBox(width: 8),
                                      StatChip(
                                        label: 'Pendientes',
                                        valor: pendientes.toString(),
                                        icono: Icons.pending_actions_rounded,
                                        color: const Color(0xFFFFB347),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                ],
                              );
                            },
                          ),

                          // ── Separador y botones de acción ─────────────────
                          const SizedBox(height: 8),
                          const Divider(color: AppColores.borderColor),
                          const SizedBox(height: 8),

                          // ── Botón principal "Guardar cambios" ─────────────
                          // Reemplaza el viejo botón "Editar" que abría otro popup.
                          // Un solo gesto: editar campos → pulsar guardar → hecho.
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColores.orangePrimary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
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

                          // Botón "Eliminar proyecto"
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFFF6B6B),
                                padding: const EdgeInsets.symmetric(vertical: 10),
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
                                'Eliminar proyecto',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              // Pasamos infoContext para que mostrarConfirmacionBorradoProyecto
                              // pueda cerrar este diálogo si el usuario confirma el borrado.
                              onPressed: () => mostrarConfirmacionBorradoProyecto(
                                parentContext: infoContext,
                                projectName: projectName,
                                projectId: projectId,
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
// Mismos helpers que en dialogo_info_tarea.dart para mantener coherencia visual.
// Son funciones privadas de este archivo, no forman parte de la API pública.

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
      // Borde tenue en reposo para que parezca texto normal, no un formulario
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColores.borderColor),
      ),
      // Borde naranja al enfocar: el usuario sabe que está editando
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColores.orangePrimary, width: 2),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
