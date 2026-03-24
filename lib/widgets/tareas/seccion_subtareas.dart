import 'package:flutter/material.dart';
import 'package:myapp/main.dart' show supabase;
import 'package:myapp/widgets/app_colores.dart';

// ── SECCIÓN DE SUBTAREAS CONECTADA A SUPABASE ─────────────────────────────────
// Este widget lista las subtareas de la tabla 'subtasks' y permite
// marcar cada una como completada, añadir nuevas y eliminarlas.
// Respeta el diseño oscuro de la app y la paleta de colores de AppColores.
//
// [FASE 1B — CORRECCIÓN DEFINITIVA]
// El enfoque anterior usaba .stream() de Supabase, que mantiene una caché
// interna propia. El problema: cuando llegaba un evento INSERT (nueva subtarea),
// Supabase reconstruía la lista desde su caché, que todavía contenía los
// elementos borrados porque los eventos DELETE de esa caché llegan con retraso.
// Resultado: las subtareas borradas reaparecían al añadir una nueva.
//
// Solución: sustituimos .stream() por fetch manual (_cargarSubtareas).
//   · initState() hace la carga inicial.
//   · Cada operación (toggle, eliminar, añadir) muta la lista local al instante
//     para respuesta inmediata y luego refresca con _cargarSubtareas().
//   · La BD siempre es la fuente de verdad; la lista local solo da velocidad visual.
//   · Sin caché de stream → sin datos fantasma.
class SeccionSubtareas extends StatefulWidget {
  // El ID de la tarea padre para filtrar sus subtareas en Supabase
  final String taskId;

  const SeccionSubtareas({super.key, required this.taskId});

  @override
  State<SeccionSubtareas> createState() => _SeccionSubtareasState();
}

class _SeccionSubtareasState extends State<SeccionSubtareas> {
  // Lista local de subtareas: fuente de verdad visual.
  // Se rellena con _cargarSubtareas() y se muta localmente para respuesta inmediata.
  List<Map<String, dynamic>> _subtareas = [];

  // true solo durante la primera carga para mostrar el spinner inicial
  bool _cargandoInicial = true;

  // Controlador del campo de texto para añadir una nueva subtarea
  final _nuevaSubtareaCont = TextEditingController();

  // Si está en true mostramos el campo de texto para añadir
  bool _mostrandoInput = false;

  // Para evitar que el usuario pulse "Añadir" dos veces seguidas
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarSubtareas();
  }

  @override
  void dispose() {
    _nuevaSubtareaCont.dispose();
    super.dispose();
  }

  // ── CARGA / RECARGA DE SUBTAREAS DESDE LA BD ──────────────────────────────
  // Consulta directa a Supabase sin pasar por ninguna caché de stream.
  // Se llama al inicio y tras cada operación para sincronizar con el estado real.
  Future<void> _cargarSubtareas() async {
    try {
      final datos = await supabase
          .from('subtasks')
          .select()
          .eq('task_id', widget.taskId)
          .order('created_at', ascending: true);

      if (!mounted) return;
      setState(() {
        _subtareas = List<Map<String, dynamic>>.from(datos);
        _cargandoInicial = false;
      });
    } catch (e) {
      debugPrint('Error al cargar subtareas: $e');
      if (mounted) setState(() => _cargandoInicial = false);
    }
  }

  // ── TOGGLE CON ACTUALIZACIÓN LOCAL INSTANTÁNEA ───────────────────────────
  // 1. Muta la lista local → checkbox responde al instante.
  // 2. Actualiza en Supabase.
  // 3. Recarga desde la BD para asegurar consistencia.
  Future<void> _toggleSubtarea(String subtareaId, bool completadaActual) async {
    // Respuesta visual inmediata
    setState(() {
      final idx = _subtareas.indexWhere((s) => s['id'] == subtareaId);
      if (idx != -1) {
        _subtareas[idx] = {
          ..._subtareas[idx],
          'is_completed': !completadaActual,
        };
      }
    });

    try {
      await supabase
          .from('subtasks')
          .update({'is_completed': !completadaActual})
          .eq('id', subtareaId);
    } catch (e) {
      debugPrint('Error al cambiar subtarea: $e');
    }
    // Recargamos para sincronizar con el estado real de la BD
    await _cargarSubtareas();
  }

  // ── ELIMINAR CON REACTIVIDAD INSTANTÁNEA ─────────────────────────────────
  // 1. Quitamos el elemento de la lista local → desaparece al instante.
  // 2. Borramos en Supabase.
  // 3. Recargamos desde la BD.
  // Como la recarga viene de la BD (donde el DELETE ya confirmó),
  // el elemento borrado NO vuelve a aparecer nunca.
  Future<void> _eliminarSubtarea(String subtareaId) async {
    // Eliminación visual inmediata
    setState(() {
      _subtareas.removeWhere((s) => s['id'] == subtareaId);
    });

    try {
      await supabase.from('subtasks').delete().eq('id', subtareaId);
    } catch (e) {
      debugPrint('Error al eliminar subtarea: $e');
    }
    // Recargamos: si el delete fue exitoso la lista queda limpia;
    // si falló, el elemento reaparece (comportamiento correcto).
    await _cargarSubtareas();
  }

  // ── GUARDAR NUEVA SUBTAREA ────────────────────────────────────────────────
  // Inserta en Supabase y recarga la lista para ver el nuevo elemento
  // exactamente como lo devolvió la BD (con id, timestamps, etc.).
  Future<void> _guardarNuevaSubtarea() async {
    final titulo = _nuevaSubtareaCont.text.trim();
    if (titulo.isEmpty) return;

    setState(() => _guardando = true);

    try {
      await supabase.from('subtasks').insert({
        'task_id': widget.taskId,
        'title': titulo,
        'is_completed': false,
      });

      _nuevaSubtareaCont.clear();
      if (mounted) {
        setState(() {
          _mostrandoInput = false;
          _guardando = false;
        });
      }
    } catch (e) {
      debugPrint('Error al crear subtarea: $e');
      if (mounted) setState(() => _guardando = false);
    }
    // Recargamos para que la nueva subtarea aparezca con todos sus campos reales
    await _cargarSubtareas();
  }

  @override
  Widget build(BuildContext context) {
    final completadas = _subtareas
        .where((s) => s['is_completed'] == true)
        .length;
    final total = _subtareas.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Indicador de progreso (solo si hay subtareas) ──────────────
        if (total > 0) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$completadas / $total completadas',
                style: const TextStyle(
                  color: AppColores.textMuted,
                  fontSize: 11,
                ),
              ),
              Text(
                '${(completadas / total * 100).round()}%',
                style: const TextStyle(
                  color: AppColores.orangeLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Barra de progreso visual
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: completadas / total,
              backgroundColor: AppColores.borderColor,
              valueColor: const AlwaysStoppedAnimation(
                AppColores.orangePrimary,
              ),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 10),
        ],

        // ── Estado de carga inicial ────────────────────────────────────
        if (_cargandoInicial)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: AppColores.orangePrimary,
                  strokeWidth: 2,
                ),
              ),
            ),
          )
        // ── Sin subtareas ──────────────────────────────────────────────
        else if (total == 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2030),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColores.borderColor.withOpacity(0.5),
              ),
            ),
            child: const Text(
              'Todavía no hay subtareas',
              style: TextStyle(color: AppColores.textMuted, fontSize: 12),
            ),
          )
        // ── Lista de subtareas ─────────────────────────────────────────
        else
          Column(
            children: _subtareas.map((subtarea) {
              final estaCompletada = subtarea['is_completed'] as bool? ?? false;
              final subtareaId = subtarea['id'] as String;

              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: () => _toggleSubtarea(subtareaId, estaCompletada),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    // Padding generoso para garantizar área de toque 48x48
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        // Checkbox visual animado
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: estaCompletada
                                ? AppColores.orangePrimary
                                : Colors.transparent,
                            border: Border.all(
                              color: estaCompletada
                                  ? AppColores.orangePrimary
                                  : AppColores.borderColor,
                              width: 1.5,
                            ),
                          ),
                          child: estaCompletada
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 12,
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            subtarea['title'] as String? ?? '',
                            style: TextStyle(
                              color: estaCompletada
                                  // Las completadas se muestran más apagadas y tachadas
                                  ? AppColores.textMuted
                                  : Colors.white,
                              fontSize: 13,
                              // Tachamos el texto al completarse
                              decoration: estaCompletada
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              decorationColor: AppColores.textMuted,
                            ),
                          ),
                        ),
                        // Botón de borrar subtarea.
                        // Usamos GestureDetector en lugar de IconButton para
                        // evitar que el tap se propague al InkWell del toggle.
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _eliminarSubtarea(subtareaId),
                            child: const Padding(
                              // Padding de 10 para garantizar área de toque cómoda
                              padding: EdgeInsets.all(10),
                              child: Icon(
                                Icons.delete_outline,
                                size: 16,
                                // Color muted para que no distraiga, pero visible
                                color: AppColores.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

        const SizedBox(height: 8),

        // ── Input para nueva subtarea ──────────────────────────────────
        // Se muestra al pulsar "Añadir subtarea" y se oculta al guardar
        if (_mostrandoInput) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nuevaSubtareaCont,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _guardarNuevaSubtarea(),
                  decoration: InputDecoration(
                    hintText: 'Nombre de la subtarea...',
                    hintStyle: const TextStyle(
                      color: AppColores.textMuted,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1E2030),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: AppColores.borderColor,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: AppColores.borderColor,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: AppColores.orangePrimary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Botón de confirmar
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: IconButton(
                  icon: _guardando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: AppColores.orangePrimary,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.check_rounded,
                          color: AppColores.orangePrimary,
                        ),
                  tooltip: 'Guardar subtarea',
                  // Área mínima de 48x48
                  padding: const EdgeInsets.all(12),
                  onPressed: _guardando ? null : _guardarNuevaSubtarea,
                ),
              ),
              // Botón de cancelar el input
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColores.textMuted,
                  ),
                  tooltip: 'Cancelar',
                  padding: const EdgeInsets.all(12),
                  onPressed: () {
                    setState(() {
                      _mostrandoInput = false;
                      _nuevaSubtareaCont.clear();
                    });
                  },
                ),
              ),
            ],
          ),
        ] else
          // Botón para mostrar el input de nueva subtarea
          TextButton.icon(
            onPressed: () => setState(() => _mostrandoInput = true),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Añadir subtarea'),
            style: TextButton.styleFrom(
              foregroundColor: AppColores.orangeLight,
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }
}
