import 'dart:typed_data';
import 'dart:ui';
// Este archivo actúa como "puente inteligente": en Web carga la versión con
// dart:html, y en Android/iOS/Windows carga la versión con dart:io.
// Solo necesitamos importar este único archivo aquí.
import 'package:myapp/utils/descarga_helper.dart';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/main.dart';
// Este archivo se crea nuevo y contiene el popup que aparece al hacer clic
// en el nombre de una tarea en la tabla. No toca nada del código existente.
import 'package:myapp/widgets/tareas/dialogo_edicion_estado_tabla.dart';
import 'package:myapp/widgets/app_colores.dart';

//construimos desde un Map<String, dynamic> que devuelve Supabase.
// También cambia el campo 'name' por 'title' según el nuevo esquema SQL.
class Tarea {
  final String id;
  final String nombre;
  final String descripcion;
  final String estado;

  Tarea({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.estado,
  });

  // Renombramos el constructor: ya no viene de Firestore sino de un mapa de Supabase.
  // Además tenemos que traducir el enum de PostgreSQL ('todo', 'in_progress', etc.)
  // al texto en español que esperan el resto de widgets de la app.
  factory Tarea.fromMap(Map<String, dynamic> data) {
    // El campo 'title' en el nuevo esquema equivale al antiguo 'name'
    return Tarea(
      id: data['id'] as String,
      nombre: data['title'] ?? '',
      descripcion: data['description'] ?? '',
      // Traducimos el enum de PostgreSQL al español para la tabla visual
      estado: _traducirStatus(data['status'] as String? ?? 'todo'),
    );
  }

  // Convierte el valor del enum de PostgreSQL al texto que ve el usuario en la tabla
  static String _traducirStatus(String enumVal) {
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
}

class TablaTarea extends StatefulWidget {
  final String nombrePadre;
  // Añadimos el UUID del proyecto para filtrar las tareas por ID real,
  // igual que hicimos en Tareas.dart. Adiós al campo 'padre' en texto.
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
  // Declaramos los colores que usaremos en la tabla
  static const _bgDark = Color(0xFF2D3142);
  static const _bgCard = Color(0xFF3A3D52);
  static const _borderColor = Color(0xFF4A4E66);
  static const _orangePrimary = Color(0xFFE8622A);

  //variable necesaria para descargar la tabla
  final GlobalKey _tableKey = GlobalKey();

  bool web() {
    return kIsWeb;
  }


  //tomamos la tabla con este metodo en una sucesion de llamadas que ocurre cuando el 
  //usuario pulsa el boton de descargar, concretamente este toma una "captura" de la tabla
  //y la pasa al siguiente metodo
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
      debugPrint("Error capturando tabla: $e");
      return null;
    }
  }

  Future<void> descarga() async {
    final bytes = await tomarTabla();

    if (bytes == null) return;

   //de aqui tomamos la "imagen" anteriormente obtenida y la pasamos al siguiente
    await descargarArchivo(bytes, 'tabla.png');
  }
// creamos 4 listas para cada estado y dependiendo del estado que extraigamos en el if
// lo añadimos a la lista correspondiente
  Map<String, List<Tarea>> agruparPorEstado(List<Tarea> tareas) {
    Map<String, List<Tarea>> agrupadas = {
      "Por iniciar": [],
      "En curso": [],
      "Pausado": [],
      "Finalizado": [],
    };

    for (var tarea in tareas) {
      if (agrupadas.containsKey(tarea.estado)) {
        agrupadas[tarea.estado]!.add(tarea);
      }
    }

    return agrupadas;
  }
  //declaramos en este metodo el tamaño maximo de la tabla
  int _maxFilas(Map<String, List<Tarea>> tareasAgrupadas) {
    if (tareasAgrupadas.values.every((lista) => lista.isEmpty)) {
      return 0;
    }

    return tareasAgrupadas.values
        .map((lista) => lista.length)
        .reduce((a, b) => a > b ? a : b);
  }

  @override
  void initState() {
    super.initState();
    print(widget.nombrePadre); 
  }

  // ── HELPER: construye la celda clicable de la tabla ─────────────────────────
  // Antes las celdas eran solo un Text con el nombre.
  // Ahora las envolvemos en un InkWell para que al hacer clic se abra
  // el diálogo de edición de estado. Las celdas vacías no son clicables.
  DataCell _celdaTarea(Tarea? tarea) {
    // Celda vacía: solo texto vacío, sin interacción
    if (tarea == null) {
      return const DataCell(SizedBox.shrink());
    }

    // Celda con tarea: InkWell con efecto táctil y cursor "manita" en web
    return DataCell(
      MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: () {
            // Al hacer clic abrimos el popup de edición de estado
            mostrarDialogoEdicionEstadoTabla(
              context: context,
              taskId: tarea.id,
              taskNombre: tarea.nombre,
              estadoActual: tarea.estado,
            );
          },
          borderRadius: BorderRadius.circular(6),
          // Pequeño padding para que el efecto ripple no quede pegado al texto
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nombre de la tarea en blanco
                Flexible(
                  child: Text(
                    tarea.nombre,
                    style: const TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                // Pequeño icono de lápiz que indica que es editable
                // Solo aparece si hay texto (no en celdas vacías)
                const Icon(
                  Icons.edit_rounded,
                  size: 12,
                  color: AppColores.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,

      // ── APPBAR ────────────────────────────────────────────────────────────
      // Añadimos el AppBar con el mismo estilo que el resto de la app.
      // La flecha de volver atrás se incluye automáticamente gracias al
      // botón "leading" que Flutter pone cuando hay una ruta anterior en la pila.
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF232537),
        foregroundColor: Colors.white,
        elevation: 0,
        // Icono de volver al color de la marca para que sea coherente visualmente
        iconTheme: const IconThemeData(color: _orangePrimary),
        // Línea naranja decorativa en la parte inferior del AppBar (mismo estilo que el resto de pantallas)
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
        // Título con icono de tabla y el nombre del proyecto padre
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.table_chart_rounded,
              color: _orangePrimary,
              size: 20,
            ),
            const SizedBox(width: 8),
            // Flexible para que el nombre largo no desborde en móviles
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

      // ── BODY ──────────────────────────────────────────────────────────────
      // Mantenemos el body exactamente igual que estaba: solo añadimos el
      // fondo degradado para que sea consistente con el resto de la app y
      // envolvemos el contenido existente en un Center para centrarlo en pantalla.
      floatingActionButton: FloatingActionButton(
        backgroundColor: _orangePrimary,
        foregroundColor: Colors.white,
        elevation: 6,
        onPressed: () {
          descarga();
        },
        child: const Icon(Icons.download),
      ),

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF232537), _bgDark],
          ),
        ),
        child: Center(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: supabase
                .from('tasks')
                .stream(primaryKey: ['id'])
                .eq('project_id', widget.projectId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text(
                  "No hay tareas",
                  style: TextStyle(color: Colors.white),
                );
              }

              List<Tarea> tareas = snapshot.data!
                  .map((data) => Tarea.fromMap(data))
                  .toList();

              final tareasAgrupadas = agruparPorEstado(tareas);
              //Devolvemos una vista en la que mostramos la tabla en la que por defecto esta implementado el scroll
              //Esto para evitar errores visuales si hubiese MUCHAS tareas
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                //Añadimos este componenete para pintar la tabla en una imagen mas tarde
                child: RepaintBoundary(
                  key: _tableKey,
                  //Todo se crea en este componente que recorta el contenido como se le indica para que no sobrepase el mismo el borde
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    //Creamos la tabla con la clase de datos para añadir los datos de manera dinamica
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        //Con este parametro pone el color de la primera fila
                        headingRowColor: WidgetStateProperty.all(
                          _orangePrimary,
                        ),
                        //Con este el de el resto
                        dataRowColor: WidgetStateProperty.all(_bgCard),
                        //ponemos que la primera linea sea en negrita para mas impacto
                        headingTextStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                        //y se seleccionan las opciones del borde para visualizacion mas amena
                        border: TableBorder.all(
                          color: _borderColor,
                          width: 2,
                          style: BorderStyle.solid,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        //Declaramos los campos
                        columns: const [
                          DataColumn(
                            label: Text(
                              "Por iniciar",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "En curso",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "Pausado",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "Finalizado",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                        //tomamos los datos de las taras de la bd
                        rows: List.generate(
                          _maxFilas(tareasAgrupadas),
                          (index) => DataRow(
                            cells: [
                              // ── Celdas ahora clicables ───────────────────
                              // Antes cada celda era un DataCell(Text(...)).
                              // Ahora usamos _celdaTarea() que añade InkWell
                              // y el cursor "manita" sin cambiar la estructura.
                              _celdaTarea(
                                index < tareasAgrupadas["Por iniciar"]!.length
                                    ? tareasAgrupadas["Por iniciar"]![index]
                                    : null,
                              ),
                              _celdaTarea(
                                index < tareasAgrupadas["En curso"]!.length
                                    ? tareasAgrupadas["En curso"]![index]
                                    : null,
                              ),
                              _celdaTarea(
                                index < tareasAgrupadas["Pausado"]!.length
                                    ? tareasAgrupadas["Pausado"]![index]
                                    : null,
                              ),
                              _celdaTarea(
                                index < tareasAgrupadas["Finalizado"]!.length
                                    ? tareasAgrupadas["Finalizado"]![index]
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
