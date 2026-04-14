import 'package:flutter/material.dart';
import 'package:myapp/widgets/app_colores.dart';

// ── MODELO DE FILTROS ─────────────────────────────────────────────────────────
// Un objeto sencillo que agrupa todas las opciones de filtrado.
// Lo usamos como "la foto" del estado de los filtros en un momento dado.
class FiltrosTareas {
  // null = sin filtro de prioridad; String = solo mostrar esa prioridad
  final String? prioridad;

  // null = todas las prioridades; si no, filtramos por esta
  final String? estado;

  // Cómo ordenar la lista ('prioridad', 'fecha', 'nombre', 'creacion')
  final String ordenarPor;

  // Si true, los más urgentes aparecen primero; si false, los menos urgentes
  final bool ascendente;

  const FiltrosTareas({
    this.prioridad,
    this.estado,
    this.ordenarPor = 'prioridad', // Por defecto ordenamos por urgencia
    this.ascendente = true,
  });

  // Devuelve true si hay algún filtro activo (para mostrar el badge naranja)
  bool get hayFiltrosActivos =>
      prioridad != null || estado != null || ordenarPor != 'prioridad';

  // Crea una copia del objeto cambiando solo los campos que necesitemos.
  // Usamos copyWith para no mutar el original (inmutabilidad).
  FiltrosTareas copyWith({
    Object? prioridad = _sentinel,
    Object? estado = _sentinel,
    String? ordenarPor,
    bool? ascendente,
  }) {
    return FiltrosTareas(
      prioridad: prioridad == _sentinel ? this.prioridad : prioridad as String?,
      estado: estado == _sentinel ? this.estado : estado as String?,
      ordenarPor: ordenarPor ?? this.ordenarPor,
      ascendente: ascendente ?? this.ascendente,
    );
  }

  // Objeto centinela para distinguir "no pasé el parámetro" de "pasé null"
  static const _sentinel = Object();
}

// ── FUNCIÓN PRINCIPAL: ABRIR EL DIÁLOGO DE FILTROS ──────────────────────────
// Llamamos a esta función desde la cabecera de Tareas.dart.
// Devuelve los filtros nuevos cuando el usuario pulsa "Aplicar",
// o null si cancela sin cambiar nada.
Future<FiltrosTareas?> mostrarDialogoFiltros({
  required BuildContext context,
  required FiltrosTareas filtrosActuales,
}) {
  return showDialog<FiltrosTareas>(
    context: context,
    builder: (ctx) => _DialogoFiltros(filtrosActuales: filtrosActuales),
  );
}

// ── WIDGET INTERNO DEL DIÁLOGO ────────────────────────────────────────────────
// Es StatefulWidget porque necesita recordar las selecciones mientras el usuario
// hace clic en las opciones, antes de pulsar "Aplicar".
class _DialogoFiltros extends StatefulWidget {
  final FiltrosTareas filtrosActuales;

  const _DialogoFiltros({required this.filtrosActuales});

  @override
  State<_DialogoFiltros> createState() => _DialogoFiltrosState();
}

class _DialogoFiltrosState extends State<_DialogoFiltros> {
  // Copia local de los filtros; se actualiza al hacer clic, pero no se aplica
  // hasta que el usuario pulse "Aplicar"
  late FiltrosTareas _filtros;

  @override
  void initState() {
    super.initState();
    // Empezamos con una copia de los filtros actuales para que el diálogo
    // muestre el estado actual al abrirse
    _filtros = widget.filtrosActuales;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      backgroundColor: AppColores.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColores.borderColor),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera del diálogo
              Row(
                children: [
                  const Icon(Icons.tune_rounded, color: AppColores.orangePrimary),
                  const SizedBox(width: 10),
                  const Text(
                    'Filtros y ordenación',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  // Botón para limpiar todos los filtros de golpe
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() {
                          _filtros = const FiltrosTareas();
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          'Limpiar todo',
                          style: TextStyle(
                            color: _filtros.hayFiltrosActivos
                                ? AppColores.orangeLight
                                : AppColores.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── SECCIÓN: PRIORIDAD ────────────────────────────────────────
              _etiquetaSeccion('FILTRAR POR PRIORIDAD'),
              const SizedBox(height: 8),
              // Wrap para que los chips se reorganicen en pantallas pequeñas
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // El chip "Todas" limpia el filtro de prioridad
                  _chipFiltro(
                    label: 'Todas',
                    seleccionado: _filtros.prioridad == null,
                    color: AppColores.borderColor,
                    onTap: () => setState(() {
                      _filtros = _filtros.copyWith(prioridad: null);
                    }),
                  ),
                  _chipFiltro(
                    label: 'Urgente',
                    seleccionado: _filtros.prioridad == 'urgent',
                    color: AppColores.prioUrgente,
                    icono: const Icon(Icons.flag_rounded, color: AppColores.prioUrgente, size: 14),
                    onTap: () => setState(() {
                      _filtros = _filtros.copyWith(prioridad: 'urgent');
                    }),
                  ),
                  _chipFiltro(
                    label: 'Alta',
                    seleccionado: _filtros.prioridad == 'high',
                    color: AppColores.prioAlta,
                    icono: const Icon(Icons.flag_rounded, color: AppColores.prioAlta, size: 14),
                    onTap: () => setState(() {
                      _filtros = _filtros.copyWith(prioridad: 'high');
                    }),
                  ),
                  _chipFiltro(
                    label: 'Normal',
                    seleccionado: _filtros.prioridad == 'normal',
                    color: AppColores.prioNormal,
                    icono: const Icon(Icons.flag_rounded, color: AppColores.prioNormal, size: 14),
                    onTap: () => setState(() {
                      _filtros = _filtros.copyWith(prioridad: 'normal');
                    }),
                  ),
                  _chipFiltro(
                    label: 'Baja',
                    seleccionado: _filtros.prioridad == 'low',
                    color: AppColores.prioBaja,
                    icono: const Icon(Icons.flag_outlined, color: AppColores.prioBaja, size: 14),
                    onTap: () => setState(() {
                      _filtros = _filtros.copyWith(prioridad: 'low');
                    }),
                  ),
                  _chipFiltro(
                    label: '— Sin prio',
                    seleccionado: _filtros.prioridad == 'none',
                    color: AppColores.prioNinguna,
                    onTap: () => setState(() {
                      _filtros = _filtros.copyWith(prioridad: 'none');
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── SECCIÓN: ESTADO ────────────────────────────────────────────
              _etiquetaSeccion('FILTRAR POR ESTADO'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chipFiltro(
                    label: 'Todos',
                    seleccionado: _filtros.estado == null,
                    color: AppColores.borderColor,
                    onTap: () => setState(() {
                      _filtros = _filtros.copyWith(estado: null);
                    }),
                  ),
                  _chipFiltro(
                    label: 'Por iniciar',
                    seleccionado: _filtros.estado == 'Por iniciar',
                    color: Colors.blueGrey,
                    icono: const Icon(Icons.work, color: Colors.blueGrey, size: 14),
                    onTap: () => setState(() {
                      _filtros = _filtros.copyWith(estado: 'Por iniciar');
                    }),
                  ),
                  _chipFiltro(
                    label: 'En curso',
                    seleccionado: _filtros.estado == 'En curso',
                    color: Colors.orange,
                    icono: const Icon(Icons.keyboard_double_arrow_right_sharp, color: Colors.orange, size: 14),
                    onTap: () => setState(() {
                      _filtros = _filtros.copyWith(estado: 'En curso');
                    }),
                  ),
                  _chipFiltro(
                    label: 'Pausado',
                    seleccionado: _filtros.estado == 'Pausado',
                    color: Colors.red,
                    icono: const Icon(Icons.pause_circle_outline, color: Colors.red, size: 14),
                    onTap: () => setState(() {
                      _filtros = _filtros.copyWith(estado: 'Pausado');
                    }),
                  ),
                  _chipFiltro(
                    label: 'Finalizado',
                    seleccionado: _filtros.estado == 'Finalizado',
                    color: const Color(0xFF48D136),
                    icono: const Icon(Icons.playlist_add_check_circle, color: Color(0xFF48D136), size: 14),
                    onTap: () => setState(() {
                      _filtros = _filtros.copyWith(estado: 'Finalizado');
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── SECCIÓN: ORDENAR ───────────────────────────────────────────
              _etiquetaSeccion('ORDENAR POR'),
              const SizedBox(height: 8),
              // Usamos un DropdownButtonFormField para la opción de orden
              DropdownButtonFormField<String>(
                value: _filtros.ordenarPor,
                dropdownColor: AppColores.bgCard,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF23253A),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColores.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColores.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColores.orangePrimary, width: 2),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'prioridad', child: Text('Prioridad (urgente primero)')),
                  DropdownMenuItem(value: 'fecha', child: Text('Fecha límite')),
                  DropdownMenuItem(value: 'nombre', child: Text('Nombre (A → Z)')),
                  DropdownMenuItem(value: 'creacion', child: Text('Más recientes primero')),
                ],
                onChanged: (valor) {
                  if (valor != null) {
                    setState(() {
                      _filtros = _filtros.copyWith(ordenarPor: valor);
                    });
                  }
                },
              ),
              const SizedBox(height: 24),

              // ── BOTONES DE ACCIÓN ──────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context), // Cancela sin cambios
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
                    onPressed: () {
                      // Devolvemos los filtros elegidos al padre
                      Navigator.pop(context, _filtros);
                    },
                    child: const Text('Aplicar filtros'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── HELPER: etiqueta de sección ───────────────────────────────────────────
  Widget _etiquetaSeccion(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        color: AppColores.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }

  // ── HELPER: chip de filtro seleccionable ──────────────────────────────────
  // Usamos MouseRegion para el cursor "manita" en web, y GestureDetector
  // con HitTestBehavior.opaque para garantizar los 48x48 px de toque en móvil.
  // El parámetro [icono] es opcional; si se pasa, se muestra antes del texto.
  Widget _chipFiltro({
    required String label,
    required bool seleccionado,
    required Color color,
    required VoidCallback onTap,
    Widget? icono,
  }) {
    final estiloTexto = TextStyle(
      color: seleccionado ? color : AppColores.textMuted,
      fontSize: 12,
      fontWeight: seleccionado ? FontWeight.w600 : FontWeight.normal,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            // Si está seleccionado usamos el color con opacidad; si no, fondo neutro
            color: seleccionado ? color.withOpacity(0.2) : const Color(0xFF23253A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: seleccionado ? color : AppColores.borderColor,
              width: seleccionado ? 1.5 : 1,
            ),
          ),
          // Si hay icono, mostramos icono + texto en fila; si no, solo texto
          child: icono != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icono,
                    const SizedBox(width: 6),
                    Text(label, style: estiloTexto),
                  ],
                )
              : Text(label, style: estiloTexto),
        ),
      ),
    );
  }
}
