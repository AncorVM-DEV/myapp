import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:myapp/main.dart' show supabase, MyApp;
import 'package:myapp/proyectos.dart';
import 'package:myapp/tablaTarea.dart';
import 'package:myapp/widgets/app_colores.dart';
import 'package:myapp/widgets/tareas/dialogo_info_tarea.dart';
import 'package:myapp/widgets/tareas/centro_notificaciones_tareas.dart';
import 'package:myapp/widgets/tareas/barra_busqueda.dart';
import 'package:myapp/widgets/tareas/dialogo_filtros.dart';
// Quitamos cloud_firestore y firebase_auth.
// Todo lo que necesitamos (auth + base de datos) viene en este único paquete.
import 'package:supabase_flutter/supabase_flutter.dart';

class Tareas extends StatefulWidget {
  final String nombreUsuario;
  final String nombreProyecto;
  // Añadimos el UUID del proyecto porque ahora las tareas se relacionan
  // con él por ID real, no por el nombre en texto como antes.
  final String projectId;

  const Tareas({
    super.key,
    required this.nombreUsuario,
    required this.nombreProyecto,
    required this.projectId,
  });

  @override
  State<Tareas> createState() => TareasState();
}

class TareasState extends State<Tareas> {
  final nombreCont = TextEditingController();
  final descripcionCont = TextEditingController();

  // ── DÍAS DE ANTELACIÓN PARA LAS NOTIFICACIONES ───────────────────────────
  // Por defecto avisamos 7 días antes de la fecha límite. El usuario puede
  // cambiar este valor desde el centro de notificaciones (icono campana)
  // Solo se permiten los valores: 1, 3, 7 o 15 días
  // Esto para evitar que el usuario pueda introducir cualquier valor invalido
  int _diasAntelacion = 7;

  // ── IDs de notificaciones leídas (descartadas) en esta sesión ────────────
  // Guardamos los IDs de los documentos que el usuario descartó.
  // Al reiniciar la app se resetea (solución ligera sin backend adicional).
  final Set<String> _notificacionesLeidas = {};

  // ── ESTADO DE BÚSQUEDA Y FILTROS ─────────────────────────────────────────
  // Si lo declaramos dentro de build(), cada vez que Flutter repinta el widget
  // (por ejemplo cuando el stream de Supabase emite datos nuevos) se crea un
  // TextEditingController nuevo, lo que destruye el TextField y hace que el
  // teclado pierda el foco. Declarándolo aquí, en el State, sobrevive a todos
  // los repintados y el usuario puede escribir sin interrupciones.
  final TextEditingController _busquedaCont = TextEditingController();

  // Texto actual de búsqueda. Lo guardamos en una variable separada para que
  // el setState() que lo actualiza no afecte al controller ni al TextField.
  String _textoBusqueda = '';

  // Objeto con todos los filtros activos (prioridad, estado, orden)
  FiltrosTareas _filtros = const FiltrosTareas();

  // ── Últimos datos recibidos del stream ────────────────────────────────────
  // Guardamos aquí la última lista que nos llegó de Supabase para poder
  // aplicar los filtros sin esperar a que el stream emita de nuevo.
  // Esto es clave para que el filtrado sea instantáneo al escribir.
  List<Map<String, dynamic>> _ultimosDatos = [];

  @override
  void dispose() {
    //Liberamos todos los controladores para evitar errores
    nombreCont.dispose();
    descripcionCont.dispose();
    _busquedaCont.dispose();
    super.dispose();
  }

  // ── Colores de la paleta del logo ────────────
  static const _bgDark = AppColores.bgDark;
  static const _bgCard = AppColores.bgCard;
  static const _borderColor = AppColores.borderColor;
  static const _orangePrimary = AppColores.orangePrimary;
  static const _orangeLight = AppColores.orangeLight;
  static const _textMuted = AppColores.textMuted;

  Future<void> eliminarTarea(String taskName, String taskId) async {
    // Eliminamos la tarea de la tabla 'tasks' por su UUID.
    // Las subtareas, comentarios y adjuntos se borran solos gracias al CASCADE.
    await supabase.from('tasks').delete().eq('id', taskId);
  }

  // Función auxiliar para mostrar un snackbar desde el contexto raíz de esta pantalla.
  // La pasamos como callback a los widgets hijos (diálogos) para que puedan
  // mostrar mensajes sin necesidad de tener acceso directo al contexto del Scaffold.
  void _mostrarSnackbar(String mensaje, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: esError ? Colors.red : null,
      ),
    );
  }

  // ── FILTRADO Y ORDENACIÓN EN CLIENTE ─────────────────────────────────────
  // Aplicamos búsqueda, filtros y orden sobre la lista que ya tenemos en memoria.
  // De esta forma no hacemos peticiones adicionales a Supabase: la consulta
  // principal sigue siendo la misma; solo filtramos lo que ya llegó por el stream.
  List<Map<String, dynamic>> _aplicarFiltros(List<Map<String, dynamic>> todas) {
    var lista = List<Map<String, dynamic>>.from(todas);

    //Filtramos por texto de búsqueda (compara contra el título)
    if (_textoBusqueda.isNotEmpty) {
      final query = _textoBusqueda.toLowerCase();
      lista = lista.where((t) {
        final titulo = (t['title'] as String? ?? '').toLowerCase();
        return titulo.contains(query);
      }).toList();
    }

    //Filtramos por prioridad si hay alguna seleccionada
    if (_filtros.prioridad != null) {
      lista = lista.where((t) => t['priority'] == _filtros.prioridad).toList();
    }

    //Filtramos por estado si hay alguno seleccionado
    if (_filtros.estado != null) {
      lista = lista.where((t) {
        final estadoUI = enumAStatus(t['status'] as String? ?? 'todo');
        return estadoUI == _filtros.estado;
      }).toList();
    }

    // Ordenamos según el criterio elegido por el usuario
    lista.sort((a, b) {
      switch (_filtros.ordenarPor) {
        case 'fecha':
          final fA = a['due_date'] != null
              ? DateTime.parse(a['due_date'] as String)
              : null;
          final fB = b['due_date'] != null
              ? DateTime.parse(b['due_date'] as String)
              : null;
          if (fA == null && fB == null) return 0;
          if (fA == null) return 1;
          if (fB == null) return -1;
          return fA.compareTo(fB);
        case 'nombre':
          return (a['title'] as String? ?? '').compareTo(
            b['title'] as String? ?? '',
          );
        case 'creacion':
          final cA = a['created_at'] != null
              ? DateTime.parse(a['created_at'] as String)
              : DateTime(0);
          final cB = b['created_at'] != null
              ? DateTime.parse(b['created_at'] as String)
              : DateTime(0);
          return cB.compareTo(cA);
        default: // 'prioridad' — urgente primero
          return ordenPrioridad(
            a['priority'] as String?,
          ).compareTo(ordenPrioridad(b['priority'] as String?));
      }
    });

    return lista;
  }

  // Genera un texto corto que resume los filtros activos para el usuario
  String _resumenFiltros() {
    final partes = <String>[];
    if (_filtros.prioridad != null) {
      partes.add('Prio: ${textoPrioridad(_filtros.prioridad)}');
    }
    if (_filtros.estado != null) {
      partes.add('Estado: ${_filtros.estado}');
    }
    if (_filtros.ordenarPor != 'prioridad') {
      const etiquetas = {
        'fecha': 'Fecha',
        'nombre': 'Nombre',
        'creacion': 'Recientes',
      };
      partes.add(
        'Orden: ${etiquetas[_filtros.ordenarPor] ?? _filtros.ordenarPor}',
      );
    }
    return partes.join('  •  ');
  }

  Future<void> subir(
    //Se declaran todos los campos que subiremos en vada tarea
    String estadoSeleccionado,
    DateTime? fechaLimite,
    String prioridadSeleccionada,
  ) async {
    String nombreT = nombreCont.text;
    String descripcionT = descripcionCont.text;

    if (nombreT.isEmpty || descripcionT.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, rellena todos los campos')),
      );
      return;
    } else {
      // Creamos el documento en la colección 'users' de Firestore
      try {
        //aqui tuvimos que permitir nulls en cosas como fecha limite para evitar errores con tareas antiguas

        // --- MIGRACIÓN A SUPABASE ---
        // Construimos el mapa de datos con los nombres de columna de PostgreSQL.
        // Los campos cambian: 'name' → 'title', 'padre' → 'project_id' (UUID),
        // 'owner' → 'created_by' (UUID), 'dueDate' → 'due_date' (ISO string).
        // El campo 'status' ahora acepta el enum en inglés, así que lo traducimos.
        final userId = supabase.auth.currentUser!.id;

        final Map<String, dynamic> datosTarea = {
          'project_id':
              widget.projectId, // UUID del proyecto, no el nombre en texto
          'title': nombreT, // En el nuevo esquema es 'title', no 'name'
          'description': descripcionT,
          'status': statusAEnum(
            estadoSeleccionado,
          ), // Traducimos a enum de PostgreSQL
          // guardamos la prioridad elegida por el usuario
          // El valor ya viene en formato de enum de PostgreSQL directamente
          // ('urgent', 'high', 'normal', 'low', 'none').
          'priority': prioridadSeleccionada,
          'created_by': userId, // UUID del usuario, no su nombre
          'assigned_to': userId, // Por defecto se asigna al creador
          // Si hay fecha límite la convertimos a ISO 8601 (el formato que espera Supabase).
          // Si no hay fecha, mandamos null y PostgreSQL lo guarda como NULL.
          'due_date': fechaLimite?.toIso8601String(),
        };

        // Insertamos en la tabla 'tasks' de Supabase
        await supabase.from('tasks').insert(datosTarea);

        print("Subida exitosa"); // DEBUG

        // ── FASE 2: NOTIFICACIÓN POR EMAIL (pendiente de conectar) ──────────
        // Las notificaciones push locales se eliminaron en la Fase 2.
        // Aquí irá la llamada a EmailService.notificarTareaAsignada() cuando
        // se implemente la lógica de invitar miembros en el siguiente paso.
        // Ejemplo de uso futuro:
        //   if (assignedUserEmail != null) {
        //     await EmailService.notificarTareaAsignada(
        //       emailDestinatario: assignedUserEmail,
        //       nombreDestinatario: assignedUserName,
        //       nombreTarea: nombreT,
        //       nombreProyecto: widget.nombreProyecto,
        //       nombreAsignador: widget.nombreUsuario,
        //       fechaLimite: fechaLimite,
        //     );
        //   }

        // Limpiamos
        nombreCont.clear();
        descripcionCont.clear();

        if (!mounted)
          return; // Seguridad por si el usuario salió de la pantalla

        // Feedback y Cerrar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Tarea creada con éxito!')),
        );

        // Cerramos el diálogo
        Navigator.of(context).pop();
      } catch (e) {
        // Si llega a fallar se muestra en consola
        print("ERROR AL SUBIR: $e"); // Mira tu consola de depuración
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,

      // ── FLOATING ACTION BUTTONS ───────────────────────────────────────────
      // [FIX UX] Los FABs pasan de Column (apilados verticalmente en la esquina
      // inferior derecha) a Row (uno al lado del otro en la parte inferior central).
      // Así dejan libres los iconos de las tarjetas (⋮ e info) que quedaban tapados.
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        //Añadimos un margen para los botones
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              //Esta variable la añadimos para que tenga internamente una diferenciacion completa
              heroTag: 'fab_crear_tarea',
              backgroundColor: _orangePrimary,
              foregroundColor: Colors.white,
              elevation: 6,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    // Declaramos el valor inicial del dropdownbutton de estado
                    String valorSeleccionado = "Por iniciar";
                    // Variable local para la fecha límite seleccionada en el diálogo
                    // Empieza en null porque no es obligatorio poner una fecha.
                    DateTime? fechaLimiteSeleccionada;
                    // Por defecto 'none' (sin prioridad) para no forzar al usuario
                    // a elegir una. Coincide con el DEFAULT de la columna en PostgreSQL.
                    String prioridadSeleccionada = 'none';
                    // Cuando el usuario pulsa Guardar ponemos esto a true para
                    // mostrar un spinner y bloquear el botón hasta que termine.
                    bool guardando = false;

                    // Usamos un StatefulBuilder para manejar el estado del diálogo de forma independiente.
                    // A continuacion creamos un formulario simple para la creacion de las tareas
                    return StatefulBuilder(
                      builder: (context, setStateInDialog) {
                        return AlertDialog(
                          backgroundColor: _bgCard,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: _borderColor),
                          ),
                          title: const Text(
                            'Crear tarea',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: nombreCont,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Nombre de la tarea',
                                    labelStyle: const TextStyle(
                                      color: _textMuted,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFF23253A),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: _borderColor,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: _borderColor,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: _orangePrimary,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: descripcionCont,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Descripcion de la tarea',
                                    labelStyle: const TextStyle(
                                      color: _textMuted,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFF23253A),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: _borderColor,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: _borderColor,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: _orangePrimary,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // ── Selector de ESTADO ────────────────────────
                                DropdownButtonFormField<String>(
                                  value: valorSeleccionado,
                                  dropdownColor: _bgCard,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: _borderColor,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: _borderColor,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: _orangePrimary,
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFF23253A),
                                    labelText: "Estado de la tarea",
                                    labelStyle: const TextStyle(
                                      color: _textMuted,
                                    ),
                                  ),
                                  items:
                                      <String>[
                                        'Por iniciar',
                                        'En curso',
                                        'Pausado',
                                        'Finalizado',
                                      ].map<DropdownMenuItem<String>>((
                                        String value,
                                      ) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(value),
                                        );
                                      }).toList(),
                                  onChanged: (String? nuevoValor) {
                                    setStateInDialog(() {
                                      valorSeleccionado = nuevoValor!;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),

                                // El selector de prioridad dropdown con los 5 niveles de urgencia + su emoji
                                // para que sea fácil de entender de un vistazo.
                                // El valor se guarda en formato de enum de PostgreSQL
                                // ('none', 'low', 'normal', 'high', 'urgent').
                                DropdownButtonFormField<String>(
                                  value: prioridadSeleccionada,
                                  dropdownColor: _bgCard,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: _borderColor,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: _borderColor,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      // El borde izquierdo del campo toma el color de la prioridad elegida
                                      borderSide: BorderSide(
                                        color: colorPrioridad(
                                          prioridadSeleccionada,
                                        ),
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFF23253A),
                                    labelText: "Prioridad",
                                    labelStyle: const TextStyle(
                                      color: _textMuted,
                                    ),
                                    // Una pequeña pastilla de color a la izquierda
                                    // que cambia en tiempo real al seleccionar una prioridad
                                    prefixIcon: Icon(
                                      Icons.flag_rounded,
                                      color: colorPrioridad(
                                        prioridadSeleccionada,
                                      ),
                                      size: 20,
                                    ),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'none',
                                      child: Text('— Sin prioridad'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'low',
                                      child: Text('⚪  Baja'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'normal',
                                      child: Text('🔵  Normal'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'high',
                                      child: Text('🟡  Alta'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'urgent',
                                      child: Text('🔴  Urgente'),
                                    ),
                                  ],
                                  onChanged: (String? nuevaPrio) {
                                    setStateInDialog(() {
                                      prioridadSeleccionada =
                                          nuevaPrio ?? 'none';
                                    });
                                  },
                                ),

                                // Sección nueva: el usuario puede elegir una fecha límite.
                                // Al pulsar el botón se abre el selector de fecha nativo
                                // de Flutter. Si no elige fecha, la tarea se guarda sin ella
                                // (retrocompatible con el sistema antiguo).
                                const SizedBox(height: 16),
                                InkWell(
                                  onTap: () async {
                                    // Abrimos el selector de fecha nativo de Flutter.
                                    // La fecha inicial es "hoy + 7 días" como sugerencia.
                                    final DateTime?
                                    fechaPicked = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now().add(
                                        const Duration(days: 7),
                                      ),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 365),
                                      ),
                                      builder: (context, child) {
                                        // Aplicamos nuestro tema oscuro al selector de fecha
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme: const ColorScheme.dark(
                                              primary: _orangePrimary,
                                              surface: _bgCard,
                                              onSurface: Colors.white,
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );

                                    // Si el usuario eligió una fecha (no canceló) la guardamos
                                    if (fechaPicked != null) {
                                      setStateInDialog(() {
                                        fechaLimiteSeleccionada = fechaPicked;
                                      });
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF23253A),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: fechaLimiteSeleccionada != null
                                            ? _orangePrimary
                                            : _borderColor,
                                        width: fechaLimiteSeleccionada != null
                                            ? 2
                                            : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today_rounded,
                                          color: fechaLimiteSeleccionada != null
                                              ? _orangePrimary
                                              : _textMuted,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            fechaLimiteSeleccionada != null
                                                ? 'Fecha límite: ${fechaLimiteSeleccionada!.day}/${fechaLimiteSeleccionada!.month}/${fechaLimiteSeleccionada!.year}'
                                                : 'Sin fecha límite (opcional)',
                                            style: TextStyle(
                                              color:
                                                  fechaLimiteSeleccionada !=
                                                      null
                                                  ? Colors.white
                                                  : _textMuted,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        if (fechaLimiteSeleccionada != null)
                                          GestureDetector(
                                            onTap: () {
                                              setStateInDialog(() {
                                                fechaLimiteSeleccionada = null;
                                              });
                                            },
                                            child: const Icon(
                                              Icons.close_rounded,
                                              color: _textMuted,
                                              size: 18,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              // Si está guardando bloqueamos Cancelar para no
                              // cerrar el diálogo a medias de la operación
                              onPressed: guardando
                                  ? null
                                  : () => Navigator.pop(context),
                              child: const Text(
                                'Cancelar',
                                style: TextStyle(color: _textMuted),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _orangePrimary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              // ── BOTÓN CON LOADER ─────────────────────────────
                              // Si guardando == true pasamos null → botón deshabilitado.
                              // Esto evita que el usuario pulse varias veces y
                              // genere tareas duplicadas mientras se guarda.
                              onPressed: guardando
                                  ? null
                                  : () async {
                                      // Activamos el spinner antes de llamar a subir()
                                      setStateInDialog(() => guardando = true);

                                      await subir(
                                        valorSeleccionado,
                                        fechaLimiteSeleccionada,
                                        prioridadSeleccionada,
                                      );

                                      // subir() cierra el diálogo en caso de éxito.
                                      // Si llegamos aquí es porque falló la validación
                                      // (campos vacíos), así que volvemos a habilitar el botón.
                                      if (mounted) {
                                        setStateInDialog(
                                          () => guardando = false,
                                        );
                                      }
                                    },
                              // El botón muestra spinner o texto según el estado
                              child: guardando
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Guardar'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
              child: const Icon(Icons.add),
            ),
            // Separación horizontal entre los dos botones
            const SizedBox(width: 16),
            //boton de mostrar la tabla
            FloatingActionButton(
              // String único para este segundo FAB. Diferente a 'fab_crear_tarea'
              // para que Flutter no confunda los dos botones flotantes al navegar.
              heroTag: 'fab_ver_tabla',
              backgroundColor: _orangePrimary,
              foregroundColor: Colors.white,
              elevation: 6,
              onPressed: () {
                // Pasamos también el projectId a TablaTarea para que pueda
                // filtrar las tareas por UUID del proyecto, no por nombre.
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TablaTarea(
                      nombrePadre: widget.nombreProyecto,
                      projectId: widget.projectId,
                    ),
                  ),
                );
              },
              child: const Icon(Icons.calendar_month),
            ),
          ],
        ),
      ),

      drawer: Drawer(
        backgroundColor: _bgCard,
        child: Column(
          children: [
            // Cabecera del drawer con logo y nombre de la app
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF232537), _bgCard],
                ),
                border: Border(
                  bottom: BorderSide(color: _borderColor, width: 1),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset("media/proyecto.png", height: 64, width: 64),
                  const SizedBox(height: 12),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [_orangePrimary, _orangeLight],
                    ).createShader(bounds),
                    child: const Text(
                      'Pro Task',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Tareas - " + widget.nombreProyecto,
                    style: const TextStyle(color: _textMuted, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Opciones de navegación
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.home_rounded, color: _orangePrimary),
              title: const Text(
                "Volver a los proyectos",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              onTap: () {
                // TODO, aqui va el de los proyectos compartidos pero todavia no tenemos la bd
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        Proyectos(nombreUsuario: widget.nombreUsuario),
                  ),
                );
              },
            ),

            // Empuja "Cerrar sesión" al fondo
            const Spacer(),

            //usamos SafeArea(top: false) por que añade automáticamente el padding correcto
            //para la barra de navegación del sistema en cualquier dispositivo,
            //sin importar si es alta, baja o tiene gestos en lugar de botones.
            SafeArea(
              top:
                  false, // Solo nos interesa el margen inferior, no el superior
              child: Column(
                children: [
                  const Divider(color: _borderColor, indent: 16, endIndent: 16),
                  // Opción de cerrar sesión separada y destacada en la parte inferior
                  ListTile(
                    leading: const Icon(Icons.logout, color: Color(0xFFFF6B6B)),
                    title: const Text(
                      'Cerrar sesion',
                      style: TextStyle(
                        color: Color(0xFFFF6B6B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    onTap: () async {
                      // --- MIGRACIÓN A SUPABASE ---
                      // Cambiamos FirebaseAuth.instance.signOut() por el equivalente de Supabase.
                      await supabase.auth.signOut();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const MyApp()),
                        (Route<dynamic> route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // ── APPBAR ────────────────────────────────────────────────────────────
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF232537),
        foregroundColor: Colors.white,
        elevation: 0,
        // Línea naranja sutil en la parte inferior del AppBar
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
            const Icon(Icons.task_alt_rounded, color: _orangePrimary, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                "Tareas - " + widget.nombreProyecto,
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
        iconTheme: const IconThemeData(color: _orangePrimary),

        // ── CAMPANA DE NOTIFICACIONES EN EL APPBAR ────────────────────────
        // Usamos un StreamBuilder para contar en tiempo real cuántas tareas
        // tienen fecha límite próxima y mostrar el número en un badge rojo.
        // Ahora filtramos finalizadas y ya descartadas.
        actions: [
          // Filtramos por el UUID del proyecto para contar las alertas activas.
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: supabase
                .from('tasks')
                .stream(primaryKey: ['id'])
                .eq('project_id', widget.projectId),
            builder: (context, snapshot) {
              // Calculamos cuántas tareas están en el rango de alerta
              int contadorAlertas = 0;
              if (snapshot.hasData) {
                final ahora = DateTime.now();
                final limiteAlerta = ahora.add(Duration(days: _diasAntelacion));
                contadorAlertas = snapshot.data!.where((data) {
                  // Retrocompatibilidad: si no tiene 'due_date' lo ignoramos
                  if (data['due_date'] == null) return false;
                  // No contamos las tareas finalizadas en el badge (status == 'done')
                  if (data['status'] == 'done') return false;
                  // No contamos las que el usuario ya descartó
                  if (_notificacionesLeidas.contains(data['id'] as String))
                    return false;
                  // Parseamos la fecha ISO 8601 que nos devuelve Supabase
                  final fecha = DateTime.parse(data['due_date'] as String);
                  return fecha.isBefore(limiteAlerta) ||
                      fecha.isAtSameMomentAs(limiteAlerta);
                }).length;
              }

              return Stack(
                children: [
                  //Usamos a partir de aqui mouse region lo cual es una funcion para detectar donde
                  //el usuario para el cursor, esto para saber donde esta el usuario en todo momento
                  //y cargar ciertos eventos, dependiendo de que queramos en cada momento
                  // documentacion: https://api.flutter.dev/flutter/widgets/MouseRegion-class.html
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: IconButton(
                      icon: const Icon(Icons.notifications_rounded),
                      color: _orangePrimary,
                      tooltip: 'Notificaciones',
                      padding: const EdgeInsets.all(12),
                      onPressed: () => mostrarCentroNotificacionesTareas(
                        ctx: context,
                        projectId: widget.projectId,
                        nombreProyecto: widget.nombreProyecto,
                        diasAntelacion: _diasAntelacion,
                        notificacionesLeidas: _notificacionesLeidas,
                        onCambiarDias: (nuevosDias) {
                          setState(() => _diasAntelacion = nuevosDias);
                        },
                        onActualizarEstado: () {
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                  if (contadorAlertas > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF6B6B),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            contadorAlertas > 9 ? '9+' : '$contadorAlertas',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          // ── Botón de filtros en el AppBar ────────────────────────────────
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.tune_rounded),
                  color: _orangePrimary,
                  tooltip: 'Filtros y ordenación',
                  padding: const EdgeInsets.all(12),
                  onPressed: () async {
                    final nuevosFiltros = await mostrarDialogoFiltros(
                      context: context,
                      filtrosActuales: _filtros,
                    );
                    if (nuevosFiltros != null) {
                      setState(() => _filtros = nuevosFiltros);
                    }
                  },
                ),
                if (_filtros.hayFiltrosActivos)
                  const Positioned(
                    right: 8,
                    top: 8,
                    child: IgnorePointer(
                      child: CircleAvatar(
                        radius: 4,
                        backgroundColor: AppColores.orangePrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),

      // ── BODY ──────────────────────────────────────────────────────────────
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF232537), _bgDark],
          ),
        ),
        // ── SAFE AREA EN EL BODY ───────────────────────────────────────────
        // Evita que la lista de tareas quede tapada por la barra de navegación
        // del sistema (botones inicio/atrás en Android, home indicator en iPhone).
        // top: false porque el AppBar ya gestiona el margen superior.
        // En Web el padding es cero, sin efecto en esa plataforma.
        // Esto lo hacemos para que sea completamente responsive, antes de esto daba errores en movil
        child: SafeArea(
          top: false,
          child: Center(
            // En web/tablet el listado no se estira más de 900px y en móvil ocupa todo el ancho
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: Column(
                      children: [
                        BarraBusqueda(
                          controller: _busquedaCont,
                          placeholder: 'Buscar tarea por nombre...',
                          onChanged: (texto) {
                            // setState solo actualiza _textoBusqueda.
                            // El controller (_busquedaCont) no se toca, así que
                            // el TextField mantiene el foco y el cursor.
                            setState(() => _textoBusqueda = texto);
                          },
                        ),
                        // Resumen de filtros activos (se muestra solo si hay alguno)
                        if (_filtros.hayFiltrosActivos)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.filter_list_rounded,
                                  size: 14,
                                  color: AppColores.orangeLight,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _resumenFiltros(),
                                    style: const TextStyle(
                                      color: AppColores.orangeLight,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      setState(() {
                                        _filtros = const FiltrosTareas();
                                        _busquedaCont.clear();
                                        _textoBusqueda = '';
                                      });
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Text(
                                        'Limpiar',
                                        style: TextStyle(
                                          color: AppColores.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ── EL STREAMBUILDER SOLO MANEJA LA LISTA ─────────────────
                  // Ahora el StreamBuilder es responsable únicamente de construir
                  // las tarjetas. Los controles de búsqueda están fuera y a salvo.
                  Expanded(
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: supabase
                          .from('tasks')
                          .stream(primaryKey: ['id'])
                          .eq('project_id', widget.projectId),
                      builder: (context, snapshot) {
                        // Manejo de estados (Carga, Error, Vacío)
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Algo salió mal: ${snapshot.error}',
                              style: const TextStyle(color: _textMuted),
                            ),
                          );
                        }

                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            _ultimosDatos.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: _orangePrimary,
                            ),
                          );
                        }

                        // Guardamos los datos más recientes del stream para que
                        // _aplicarFiltros siempre trabaje con la lista actualizada
                        if (snapshot.hasData) {
                          _ultimosDatos = snapshot.data!;
                        }

                        if (_ultimosDatos.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.checklist_rounded,
                                  color: _borderColor,
                                  size: 72,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No tienes tareas creados aún.',
                                  style: TextStyle(
                                    color: _textMuted,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Pulsa + para añadir tu primera tarea.',
                                  style: TextStyle(
                                    color: _borderColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // Aplicamos filtros y búsqueda sobre los datos en memoria
                        final tareasFiltradas = _aplicarFiltros(_ultimosDatos);

                        if (tareasFiltradas.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.search_off_rounded,
                                  color: _borderColor,
                                  size: 56,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Sin resultados para tu búsqueda.',
                                  style: TextStyle(
                                    color: _textMuted,
                                    fontSize: 15,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Prueba con otros términos o limpia los filtros.',
                                  style: TextStyle(
                                    color: _borderColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // ── PADDING INFERIOR DINÁMICO ─────────────────────────
                        // Sumamos la altura de la barra de navegación del sistema
                        // al padding inferior para que la última tarea siempre sea
                        // accesible. En Web este valor es 0, sin efecto.
                        return ListView.builder(
                          padding: EdgeInsets.only(
                            top: 8,
                            left: 12,
                            right: 12,
                            // [FIX UX] 100px extra para que la última tarea
                            // quede siempre por encima de los botones flotantes
                            // y el usuario pueda tocarla sin dificultad.
                            bottom: 100 + MediaQuery.of(context).padding.bottom,
                          ),
                          itemCount: tareasFiltradas.length,
                          itemBuilder: (context, index) {
                            // --- MIGRACIÓN A SUPABASE ---
                            // El stream de Supabase ya nos devuelve una lista de mapas,
                            // no hay que llamar a tarea.data() como en Firestore.
                            final data = tareasFiltradas[index];
                            final taskId = data['id'] as String;

                            // ── Retrocompatibilidad con 'due_date' ──────────────────
                            // Supabase devuelve la fecha como String ISO 8601 o null.
                            // La parseamos a DateTime solo si no es null.
                            final String? dueDateStr =
                                data['due_date'] as String?;
                            final DateTime? fechaLimite = dueDateStr != null
                                ? DateTime.parse(dueDateStr)
                                : null;

                            // Convertimos el status del enum al texto en español para
                            // mostrarlo en el icono y en el diálogo de información.
                            final String statusUI = enumAStatus(
                              data['status'] as String? ?? 'todo',
                            );

                            // ── Prioridad de la tarea ──────────────────────────────
                            final String? prioridad =
                                data['priority'] as String?;

                            return Card(
                              color: _bgCard,
                              elevation: 4,
                              shadowColor: Colors.black45,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                                side: const BorderSide(
                                  color: _borderColor,
                                  width: 1,
                                ),
                              ),
                              // ── Tarjeta con franja lateral de prioridad ──────────
                              // [FIX] Eliminamos ListTile porque su `trailing` tiene un
                              // ancho máximo implícito en Flutter que causa overflow cuando
                              // hay varios widgets (imagen + popupmenu + iconbutton).
                              // Reemplazamos por Row + Column explícitos sin restricciones
                              // de altura fija, lo que permite que el contenido crezca
                              // libremente y los iconos queden centrados siempre.
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                // [FIX] IntrinsicHeight es imprescindible cuando
                                // Row usa crossAxisAlignment.stretch sin alturas
                                // explícitas: le dice a Flutter que calcule la
                                // altura del Row a partir de los hijos antes de
                                // aplicar el stretch. Sin él, la altura resultante
                                // es 0 y las tarjetas desaparecen visualmente.
                                child: IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      // Franja lateral vertical con el color de la prioridad
                                      Container(
                                        width: 4,
                                        decoration: BoxDecoration(
                                          color: colorPrioridad(prioridad),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(15),
                                            bottomLeft: Radius.circular(15),
                                          ),
                                        ),
                                      ),
                                      // Icono de estado a la izquierda del texto
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 12,
                                        ),
                                        child: imagenSegunEstado(statusUI),
                                      ),
                                      // Bloque de texto central: ocupa todo el espacio libre
                                      // Expanded evita que empuje a los iconos fuera de pantalla
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Título de la tarea
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    emojiPrioridad(prioridad),
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      // el nombre de la tarea es 'title'
                                                      data['title'] ??
                                                          'Sin nombre',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              // Descripción y autor
                                              Text(
                                                // Mostramos la descripción; el 'owner' ahora es un UUID,
                                                // así que mostramos el nombre del usuario de la sesión actual.
                                                "${data['description'] ?? 'Sin descripción'} • Por: ${widget.nombreUsuario}",
                                                style: const TextStyle(
                                                  color: _textMuted,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              // Fecha límite (solo si existe)
                                              if (fechaLimite != null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 4,
                                                      ),
                                                  child: Row(
                                                    // [FIX] crossAxisAlignment.center alinea
                                                    // el icono y el texto verticalmente
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                        Icons.alarm_rounded,
                                                        size: 12,
                                                        color: colorFechaLimite(
                                                          fechaLimite,
                                                          _diasAntelacion,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      // [FIX] Flexible evita que el texto de fecha
                                                      // largo (ej. "Venció hace 5 días") se recorte
                                                      Flexible(
                                                        child: Text(
                                                          textoFechaLimite(
                                                            fechaLimite,
                                                          ),
                                                          style: TextStyle(
                                                            color:
                                                                colorFechaLimite(
                                                                  fechaLimite,
                                                                  _diasAntelacion,
                                                                ),
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Bloque de controles a la derecha: imagen + menú + info
                                      // Usamos IntrinsicHeight + Column en lugar de trailing
                                      // para que no haya límite de ancho implícito
                                      // Bloque de controles: mainAxisSize.min evita
                                      // que la Column intente ser infinitamente alta
                                      // cuando se le da altura sin límite en el cross axis.
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Image.asset(
                                            "media/proyecto.png",
                                            width: 32,
                                          ),
                                          //TODO desplegable para cambiar el estado
                                          PopupMenuButton<String>(
                                            color: _bgCard,
                                            iconColor: _textMuted,
                                            onSelected: (String result) async {
                                              try {
                                                await supabase
                                                    .from('tasks')
                                                    .update({
                                                      'status': statusAEnum(
                                                        result,
                                                      ),
                                                    })
                                                    .eq('id', taskId);
                                              } catch (e) {
                                                print(
                                                  'Error actualizando tarea: $e',
                                                );
                                              }
                                            },
                                            itemBuilder:
                                                //Drawer de los estados de las tareas
                                                (BuildContext context) =>
                                                    const <
                                                      PopupMenuEntry<String>
                                                    >[
                                                      PopupMenuItem<String>(
                                                        value: 'Por iniciar',
                                                        child: Text(
                                                          'Por iniciar',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                      PopupMenuItem<String>(
                                                        value: 'En curso',
                                                        child: Text(
                                                          'En curso',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                      PopupMenuItem<String>(
                                                        value: 'Pausado',
                                                        child: Text(
                                                          'Pausado',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                      PopupMenuItem<String>(
                                                        value: 'Finalizado',
                                                        child: Text(
                                                          'Finalizado',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                          ),
                                          MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: IconButton(
                                              icon: const Icon(
                                                Icons.info,
                                                color: _textMuted,
                                              ),
                                              padding: const EdgeInsets.all(8),
                                              tooltip: 'Ver información',
                                              onPressed: () {
                                                mostrarDialogoInfoTarea(
                                                  ctx: context,
                                                  tareaName:
                                                      data['title'] ??
                                                      'Sin nombre',
                                                  taskDescription:
                                                      data['description'] ??
                                                      'Sin descripción',
                                                  taskEstado: statusUI,
                                                  taskId: taskId,
                                                  // Pasamos la prioridad actual para que el diálogo
                                                  // la muestre pre-seleccionada y permita editarla
                                                  prioridadActual:
                                                      data['priority']
                                                          as String?,
                                                  fechaLimite: fechaLimite,
                                                  diasAntelacion:
                                                      _diasAntelacion,
                                                  onEliminar: eliminarTarea,
                                                  onMostrarSnackbar:
                                                      _mostrarSnackbar,
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ), // Row
                                ), // IntrinsicHeight
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
              // Cierra el ConstrainedBox que ahora envuelve el Column
            ),
          ),
        ),
      ),
    );
  }
}
