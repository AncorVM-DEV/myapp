import 'dart:typed_data';
import 'dart:ui';
import 'package:myapp/utils/descarga_helper.dart';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/main.dart';
// [FASE 2] Importamos el diálogo de información completa de tarea para abrirlo
// al hacer clic, en lugar del antiguo diálogo de solo edición de estado.
import 'package:myapp/widgets/tareas/dialogo_info_tarea.dart';
import 'package:myapp/widgets/app_colores.dart';

// ── MODELO TAREA ──────────────────────────────────────────────────────────────
// [FASE 2] Extendemos el modelo con todos los campos que necesita
// mostrarDialogoInfoTarea: descripción, prioridad y fecha límite.
class Tarea {
  final String id;
  final String nombre;
  final String descripcion;
  final String estado; // Texto UI: 'Por iniciar', 'En curso', etc.
  final String? prioridad; // Enum DB: 'urgent', 'high', 'normal', 'low', 'none'
  final DateTime? fechaLimite;

  Tarea({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.estado,
    this.prioridad,
    this.fechaLimite,
  });

  factory Tarea.fromMap(Map<String, dynamic> data) {
    return Tarea(
      id: data['id'] as String,
      nombre: data['title'] ?? '',
      descripcion: data['description'] ?? '',
      estado: _traducirStatus(data['status'] as String? ?? 'todo'),
      prioridad: data['priority'] as String?,
      // Parseamos la fecha ISO 8601 si existe; si no, null
      fechaLimite: data['due_date'] != null
          ? DateTime.tryParse(data['due_date'] as String)
          : null,
    );
  }

  // Convierte el enum de PostgreSQL al texto que ve el usuario en la tabla
  static String _traducirStatus(String enumVal) {
    switch (enumVal) {
      case 'in_progress':
        return 'En curso';
      case 'review':
        return 'Pausado';
      case 'done':
        return 'Finalizado';
      default:
        return 'Por iniciar';
    }
  }
}

class TablaTarea extends StatefulWidget {
  final String nombrePadre;
  final String projectId;

  const TablaTarea({
    super.key,
    required this.nombrePadre,
    required this.projectId,
  });

  @override
  State<TablaTarea> createState() => TablaTareaState();
}

class TablaTareaState extends State<TablaTarea> {
  static const _bgDark = Color(0xFF2D3142);
  static const _bgCard = Color(0xFF3A3D52);
  static const _borderColor = Color(0xFF4A4E66);
  static const _orangePrimary = Color(0xFFE8622A);

  final GlobalKey _tableKey = GlobalKey();

  // ── Colores de cabecera por columna ──────────────────────────────────────
  // Cada estado tiene su propio color de acento para el encabezado del Kanban.
  static const _coloresCabecera = {
    'Por iniciar': Color(0xFF4A90E2), // Azul
    'En curso': Color(0xFFE8622A), // Naranja
    'Pausado': Color(0xFFFFB347), // Amarillo
    'Finalizado': Color(0xFF48D136), // Verde
  };

  // ── Iconos de cabecera por columna ───────────────────────────────────────
  static const _iconosCabecera = {
    'Por iniciar': Icons.radio_button_unchecked_rounded,
    'En curso': Icons.play_circle_outline_rounded,
    'Pausado': Icons.pause_circle_outline_rounded,
    'Finalizado': Icons.check_circle_outline_rounded,
  };

  bool web() => kIsWeb;

  // ── Captura de la tabla para descarga ────────────────────────────────────
  Future<Uint8List?> tomarTabla() async {
    try {
      RenderRepaintBoundary boundary =
          _tableKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturando tabla: $e');
      return null;
    }
  }

  Future<void> descarga() async {
    final bytes = await tomarTabla();
    if (bytes == null) return;
    await descargarArchivo(bytes, 'tabla.png');
  }

  // ── Agrupa las tareas por estado ─────────────────────────────────────────
  Map<String, List<Tarea>> agruparPorEstado(List<Tarea> tareas) {
    return {
      'Por iniciar': tareas.where((t) => t.estado == 'Por iniciar').toList(),
      'En curso': tareas.where((t) => t.estado == 'En curso').toList(),
      'Pausado': tareas.where((t) => t.estado == 'Pausado').toList(),
      'Finalizado': tareas.where((t) => t.estado == 'Finalizado').toList(),
    };
  }

  int _maxFilas(Map<String, List<Tarea>> agrupadas) {
    if (agrupadas.values.every((l) => l.isEmpty)) return 0;
    return agrupadas.values
        .map((l) => l.length)
        .reduce((a, b) => a > b ? a : b);
  }

  // ── Eliminar tarea (necesario para el diálogo de detalles) ───────────────
  Future<void> _eliminarTarea(String nombre, String id) async {
    try {
      await supabase.from('tasks').delete().eq('id', id);
      _mostrarSnackbar('Tarea "$nombre" eliminada');
    } catch (e) {
      _mostrarSnackbar('Error al eliminar la tarea: $e', esError: true);
    }
  }

  void _mostrarSnackbar(String msg, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: esError ? Colors.red : null,
      ),
    );
  }

  // ── CELDA CLICABLE DE LA TABLA ────────────────────────────────────────────
  // [FASE 2] Al hacer clic ahora abre mostrarDialogoInfoTarea (detalles
  // completos: descripción, comentarios, adjuntos, subtareas) en lugar del
  // antiguo diálogo que solo cambiaba el estado.
  DataCell _celdaTarea(Tarea? tarea) {
    if (tarea == null) return const DataCell(SizedBox.shrink());

    // Color del indicador de prioridad en el borde izquierdo de la celda
    final colorPrio = colorPrioridad(tarea.prioridad);

    return DataCell(
      MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: () {
            // [FASE 2] Abrimos el diálogo completo de información de la tarea.
            // Antes abría mostrarDialogoEdicionEstadoTabla (solo cambiaba el estado).
            // Ahora el usuario ve descripción, prioridad, fecha, comentarios y adjuntos.
            mostrarDialogoInfoTarea(
              ctx: context,
              tareaName: tarea.nombre,
              taskDescription: tarea.descripcion,
              taskEstado: tarea.estado,
              taskId: tarea.id,
              prioridadActual: tarea.prioridad,
              fechaLimite: tarea.fechaLimite,
              diasAntelacion: 7, // Valor por defecto en la vista de tabla
              onEliminar: _eliminarTarea,
              onMostrarSnackbar: _mostrarSnackbar,
            );
          },
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Barra de prioridad ──────────────────────────────────
                // Franja vertical de color que indica visualmente la prioridad,
                // igual que en la vista de lista de Tareas.dart
                Container(
                  width: 3,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colorPrio,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),

                // ── Nombre de la tarea ──────────────────────────────────
                Flexible(
                  child: Text(
                    tarea.nombre,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                const SizedBox(width: 4),

                // [FIX] Reemplazamos el icono estático por un PopupMenuButton
                // para cambiar el estado directamente desde la celda de la tabla.
                // Al usar 'child' en vez de 'icon', PopupMenuButton usa InkWell
                // internamente y absorbe el tap antes de que llegue al InkWell padre,
                // evitando que se abra el diálogo completo al tocar este botón.
                PopupMenuButton<String>(
                  tooltip: 'Cambiar estado',
                  padding: EdgeInsets.zero,
                  color: AppColores.bgCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: AppColores.borderColor),
                  ),
                  // Icono compacto que indica la acción de cambiar estado
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.swap_vert_rounded,
                      size: 13,
                      color: AppColores.textMuted,
                    ),
                  ),
                  onSelected: (nuevoEstado) {
                    // UPDATE directo a Supabase; el StreamBuilder de la tabla
                    // actualizará la UI automáticamente vía Realtime.
                    supabase
                        .from('tasks')
                        .update({'status': statusAEnum(nuevoEstado)})
                        .eq('id', tarea.id);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'Por iniciar',
                      child: Text(
                        'Por iniciar',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'En curso',
                      child: Text(
                        'En curso',
                        style: TextStyle(color: Colors.orange, fontSize: 13),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'Pausado',
                      child: Text(
                        'Pausado',
                        style: TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'Finalizado',
                      child: Text(
                        'Finalizado',
                        style: TextStyle(
                          color: Color(0xFF48D136),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── CABECERA DE COLUMNA MEJORADA ─────────────────────────────────────────
  // Devuelve el widget de la cabecera con icono, nombre y contador de tareas.
  Widget _cabecera(String estado, int cantidad) {
    final color = _coloresCabecera[estado] ?? AppColores.orangePrimary;
    final icono = _iconosCabecera[estado] ?? Icons.list_alt_rounded;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, color: Colors.white, size: 15),
        const SizedBox(width: 6),
        Text(
          estado,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 6),
        // Badge con el número de tareas en esa columna
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$cantidad',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,

      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_descargar_tabla',
        backgroundColor: _orangePrimary,
        foregroundColor: Colors.white,
        elevation: 6,
        tooltip: 'Descargar tabla como imagen',
        onPressed: descarga,
        child: const Icon(Icons.download_rounded),
      ),

      // ── APPBAR ─────────────────────────────────────────────────────────────
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF232537),
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _orangePrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  _orangePrimary,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.table_chart_rounded,
              color: _orangePrimary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Tabla — ${widget.nombrePadre}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),

      // ── BODY ───────────────────────────────────────────────────────────────
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF232537), _bgDark],
          ),
        ),
        // SafeArea evita que la tabla quede tapada por la barra de navegación
        child: SafeArea(
          top: false,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: supabase
                .from('tasks')
                .stream(primaryKey: ['id'])
                .eq('project_id', widget.projectId),
            builder: (context, snapshot) {
              // ── Estado de carga ────────────────────────────────────────
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: _orangePrimary),
                );
              }

              // ── Sin datos ──────────────────────────────────────────────
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.table_chart_outlined,
                        color: _borderColor,
                        size: 64,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No hay tareas en este proyecto.',
                        style: TextStyle(
                          color: AppColores.textMuted,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Crea tareas desde la vista de lista.',
                        style: TextStyle(color: _borderColor, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }

              final tareas = snapshot.data!.map(Tarea.fromMap).toList();
              final agrupadas = agruparPorEstado(tareas);
              final maxFilas = _maxFilas(agrupadas);
              final estados = [
                'Por iniciar',
                'En curso',
                'Pausado',
                'Finalizado',
              ];

              // ── TABLA KANBAN ──────────────────────────────────────────
              // [FASE 2] Doble scroll: vertical (SingleChildScrollView externo)
              // + horizontal (SingleChildScrollView en el RepaintBoundary).
              // Así en móvil se puede hacer scroll en ambas direcciones sin overflow.
              return SingleChildScrollView(
                // Scroll vertical para tablas con muchas filas
                child: Padding(
                  padding: EdgeInsets.only(
                    top: 16,
                    left: 12,
                    right: 12,
                    // Padding inferior para que el FAB no tape la última fila
                    bottom: 88 + MediaQuery.of(context).padding.bottom,
                  ),
                  child: Center(
                    // Center + ConstrainedBox: en pantallas anchas (web/tablet)
                    // la tabla se centra visualmente. En móvil el scroll
                    // horizontal toma el control cuando supera el ancho de pantalla.
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: SingleChildScrollView(
                        // Scroll horizontal para que no se rompa en pantallas estrechas
                        scrollDirection: Axis.horizontal,
                        child: RepaintBoundary(
                          // [FIX] RepaintBoundary movido DENTRO del scroll horizontal:
                          // al estar dentro del scroll, su tamaño es el del DataTable
                          // completo (no el del viewport). toImage() captura toda la
                          // tabla, solucionando el recorte de imagen en portrait en Android.
                          key: _tableKey,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: DataTable(
                              // ── Cabecera con colores diferenciados por estado ──
                              // Usamos un color neutro de fondo y ponemos el color
                              // de acento en el widget _cabecera() de cada columna.
                              headingRowColor: WidgetStateProperty.all(
                                const Color(0xFF232537),
                              ),
                              headingRowHeight: 48,
                              dataRowColor: WidgetStateProperty.resolveWith((
                                states,
                              ) {
                                // Filas alternadas para mejor legibilidad
                                return _bgCard;
                              }),
                              dataRowMinHeight: 44,
                              dataRowMaxHeight: 56,
                              columnSpacing: 16,
                              horizontalMargin: 16,
                              dividerThickness: 1,
                              border: TableBorder.all(
                                color: _borderColor,
                                width: 1,
                                style: BorderStyle.solid,
                                borderRadius: BorderRadius.circular(16),
                              ),

                              // ── Columnas con cabecera mejorada ────────────────
                              columns: estados.map((estado) {
                                final color =
                                    _coloresCabecera[estado] ?? _orangePrimary;
                                return DataColumn(
                                  label: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      // Cada cabecera tiene su propio color de fondo semitransparente
                                      color: color.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: color.withOpacity(0.4),
                                      ),
                                    ),
                                    child: _cabecera(
                                      estado,
                                      agrupadas[estado]!.length,
                                    ),
                                  ),
                                );
                              }).toList(),

                              // ── Filas de tareas ────────────────────────────────
                              rows: List.generate(
                                maxFilas,
                                (index) => DataRow(
                                  cells: estados.map((estado) {
                                    final lista = agrupadas[estado]!;
                                    return _celdaTarea(
                                      index < lista.length
                                          ? lista[index]
                                          : null,
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ), // RepaintBoundary
                      ), // SingleChildScrollView horizontal
                    ), // ConstrainedBox
                  ), // Center
                ), // Padding
              ); // SingleChildScrollView vertical
            },
          ),
        ),
      ),
    );
  }
}
