import 'package:flutter/material.dart';
import 'package:myapp/main.dart' show supabase;
import 'package:myapp/widgets/app_colores.dart';

// ── DIÁLOGO DE EDICIÓN DE ESTADO DESDE LA TABLA ──────────────────────────────
// Este popup aparece al hacer clic en una celda de la TablaTarea.
// Es intencionalmente simple: solo permite cambiar el estado, nada más.
// Al guardar, actualiza Supabase y, gracias al stream en tiempo real,
// tanto la tabla como la lista de tareas se actualizan solos.
void mostrarDialogoEdicionEstadoTabla({
  required BuildContext context,
  required String taskId,
  required String taskNombre,
  required String estadoActual,
}) {
  showDialog(
    context: context,
    builder: (ctx) => _DialogoEstadoTabla(
      taskId: taskId,
      taskNombre: taskNombre,
      estadoActual: estadoActual,
    ),
  );
}

class _DialogoEstadoTabla extends StatefulWidget {
  final String taskId;
  final String taskNombre;
  final String estadoActual;

  const _DialogoEstadoTabla({
    required this.taskId,
    required this.taskNombre,
    required this.estadoActual,
  });

  @override
  State<_DialogoEstadoTabla> createState() => _DialogoEstadoTablaState();
}

class _DialogoEstadoTablaState extends State<_DialogoEstadoTabla> {
  // El estado que el usuario tiene seleccionado en este momento (puede cambiar)
  late String _estadoSeleccionado;

  // Para deshabilitar el botón mientras se guarda y evitar doble envío
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    // Empezamos con el estado actual de la tarea ya seleccionado
    _estadoSeleccionado = widget.estadoActual;
  }

  // Guarda el cambio en Supabase y cierra el diálogo.
  // PROBLEMA 4 RESUELTO: se eliminó el SnackBar que generaba una barra gris
  // vacía en la parte inferior de la tabla. No hacía falta: el stream en tiempo
  // real ya actualiza la celda al instante, el usuario ve el cambio solo.
  Future<void> _guardar() async {
    // Si no cambió nada, simplemente cerramos sin hacer petición
    if (_estadoSeleccionado == widget.estadoActual) {
      Navigator.pop(context);
      return;
    }

    setState(() => _guardando = true);

    try {
      // Actualizamos el estado en la tabla 'tasks' de Supabase.
      // statusAEnum traduce 'En curso' → 'in_progress', etc.
      await supabase
          .from('tasks')
          .update({'status': statusAEnum(_estadoSeleccionado)})
          .eq('id', widget.taskId);

      if (!mounted) return;
      // Solo cerramos: el stream se encarga de actualizar la tabla visualmente.
      // No hay SnackBar intencionadamente para no romper la UI de la tabla.
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      // En caso de error sí mostramos feedback, porque ahí el usuario sí necesita saber qué pasó
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating, // floating evita el bug de la barra enorme
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColores.bgCard,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColores.borderColor),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera con el nombre de la tarea
              Row(
                children: [
                  const Icon(Icons.edit_note_rounded, color: AppColores.orangePrimary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.taskNombre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Cambia el estado de esta tarea',
                style: TextStyle(color: AppColores.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 20),

              // ── OPCIONES DE ESTADO ─────────────────────────────────────────
              // Mostramos cada opción como un tile seleccionable con icono y color.
              // Esto es más accesible que un dropdown porque las opciones son pocas
              // y el usuario puede ver todas de un vistazo.
              ..._opcionesEstado.map(
                (opcion) => _TileEstado(
                  label: opcion['label'] as String,
                  icono: opcion['icono'] as IconData,
                  color: opcion['color'] as Color,
                  seleccionado: _estadoSeleccionado == opcion['label'],
                  onTap: () {
                    setState(() => _estadoSeleccionado = opcion['label'] as String);
                  },
                ),
              ),
              const SizedBox(height: 24),

              // ── BOTONES ───────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _guardando ? null : () => Navigator.pop(context),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(color: AppColores.textMuted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColores.orangePrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    // Deshabilitamos el botón mientras se guarda
                    onPressed: _guardando ? null : _guardar,
                    child: _guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Guardar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── TILE DE ESTADO ─────────────────────────────────────────────────────────────
// Cada opción de estado es un tile visual con icono y color.
// Usa InkWell para el efecto táctil (estándar Flutter Material).
class _TileEstado extends StatelessWidget {
  final String label;
  final IconData icono;
  final Color color;
  final bool seleccionado;
  final VoidCallback onTap;

  const _TileEstado({
    required this.label,
    required this.icono,
    required this.color,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: seleccionado ? color.withOpacity(0.15) : const Color(0xFF23253A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: seleccionado ? color : AppColores.borderColor,
                width: seleccionado ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icono, color: seleccionado ? color : AppColores.textMuted, size: 20),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: seleccionado ? Colors.white : AppColores.textMuted,
                    fontWeight: seleccionado ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                // Checkmark solo visible cuando está seleccionado
                if (seleccionado)
                  Icon(Icons.check_circle_rounded, color: color, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Lista de opciones de estado con sus iconos y colores asociados
const _opcionesEstado = [
  {
    'label': 'Por iniciar',
    'icono': Icons.work_outline_rounded,
    'color': Colors.blueGrey,
  },
  {
    'label': 'En curso',
    'icono': Icons.keyboard_double_arrow_right_rounded,
    'color': Colors.orange,
  },
  {
    'label': 'Pausado',
    'icono': Icons.pause_circle_outline_rounded,
    'color': Colors.red,
  },
  {
    'label': 'Finalizado',
    'icono': Icons.playlist_add_check_circle_rounded,
    'color': Color(0xFF48D136),
  },
];
