import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:myapp/Tareas.dart';
import 'package:myapp/login.dart';
import 'package:myapp/main.dart' show supabase;
import 'package:myapp/widgets/app_colores.dart';
import 'package:myapp/widgets/proyectos/tarjeta_proyecto.dart';
import 'package:myapp/widgets/proyectos/centro_notificaciones_global.dart';
import 'package:myapp/widgets/tareas/barra_busqueda.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/perfil.dart';

class Proyectos extends StatefulWidget {
  final String nombreUsuario;
  const Proyectos({super.key, required this.nombreUsuario});

  @override
  State<Proyectos> createState() => _ProyectosState();
}

class _ProyectosState extends State<Proyectos> {
  // Los controladores van dentro del State, nota mental por ningun error que llevo varias horas de busqueda en particular
  final nombreCont = TextEditingController();
  final descripcionCont = TextEditingController();
  String? valorSeleccionado = "Por iniciar";

  // ── Días de antelación para las notificaciones globales ───────────────────
  // Por defecto avisamos con 7 días, pero el usuario puede ajustarlo desde
  // el centro de notificaciones. Solo permite valores: 1, 3, 7 o 15 días.
  int _diasAntelacion = 7;

  // ── IDs de notificaciones leídas (descartadas) en esta sesión ────────────
  // Guardamos los IDs de las tareas que el usuario ha descartado
  // del centro de notificaciones. Al cerrar la app se reinicia (solución ligera).
  final Set<String> _notificacionesLeidas = {};

  // Guardamos un mapa de UUID de proyecto → nombre del proyecto para poder
  // mostrar el nombre en las notificaciones sin hacer una consulta extra por cada tarea.
  // Este mapa se rellena cuando llegan los datos de la lista de proyectos.
  final Map<String, String> _proyectosCache = {};

  // ── BÚSQUEDA ──────────────────────────────────────────────────────────────
  // Mismo patrón que en Tareas.dart: el controller vive en el State para que
  // sobreviva a los repintados del StreamBuilder y no pierda el foco al escribir.
  final TextEditingController _busquedaCont = TextEditingController();
  String _textoBusqueda = '';

  // Últimos datos recibidos del stream (para que el filtro funcione en memoria)
  List<Map<String, dynamic>> _ultimosDatos = [];

  @override
  void dispose() {
    //Liberamos todos los contraldores
    nombreCont.dispose();
    descripcionCont.dispose();
    _busquedaCont.dispose();
    super.dispose();
  }

  // ── FILTRADO EN CLIENTE ────────────────────────────────────────────────────
  // Comparamos el texto de búsqueda contra el nombre del proyecto.
  // No hacemos ninguna petición extra a Supabase: filtramos la lista en memoria.
  List<Map<String, dynamic>> _filtrarProyectos(
    List<Map<String, dynamic>> todos,
  ) {
    if (_textoBusqueda.isEmpty) return todos;
    final query = _textoBusqueda.toLowerCase();
    return todos.where((p) {
      final nombre = (p['name'] as String? ?? '').toLowerCase();
      return nombre.contains(query);
    }).toList();
  }

  //Funcion de subir los proyectos
  Future<bool> subir(
    void Function(void Function()) setStateDialog,
    bool Function() montado,
  ) async {
    String nombreP = nombreCont.text;
    String descripcionP = descripcionCont.text;

    if (nombreP.isEmpty || descripcionP.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, rellena todos los campos')),
      );
      // Campos vacíos: le decimos al botón que resetee el spinner
      return false;
    }

    try {
      //Formateamos los datos para supabase
      final userId = supabase.auth.currentUser!.id;

      // Insertamos el proyecto y pedimos que nos devuelva la fila completa
      // para poder obtener el UUID que PostgreSQL generó automáticamente.
      final proyectoCreado = await supabase
          .from('projects')
          .insert({
            'name': nombreP,
            'description': descripcionP,
            'created_by': userId,
            'estado': valorSeleccionado,
          })
          .select()
          .single();

      // Una vez creado el proyecto, registramos al creador como miembro con
      // rol 'owner' en la tabla project_members. Así podemos controlar
      // quién pertenece a qué proyecto y con qué permisos.

      //usamos .upsert() con ignoreDuplicates: true.
      // - Si el Trigger ya insertó la fila → Supabase la ignora sin error.
      // - Si el Trigger no existe (otro entorno) → la inserta normalmente.
      // De las dos formas el resultado es correcto y nunca hay crash.
      await supabase.from('project_members').upsert({
        'project_id': proyectoCreado['id'],
        'user_id': userId,
        'role': 'owner',
      }, ignoreDuplicates: true);

      // ── LIMPIEZA DE CAMPOS ────────────────────────────────────────────────
      // Limpiamos los campos de texto para que al abrir el diálogo de nuevo
      // estén vacíos. Antes no se hacía y el usuario veía los datos anteriores.
      nombreCont.clear();
      descripcionCont.clear();

      // Comprobamos que el widget sigue en pantalla antes de tocar el contexto
      if (!montado()) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Proyecto creado con éxito!')),
      );

      // ÉXITO: avisamos al botón para que él cierre el diálogo
      // El StreamBuilder se encargará de refrescar la lista automáticamente.
      return true;
    } catch (e) {
      // Si Supabase lanza algún error (red, permisos, constraint...) lo
      // mostramos en un SnackBar y devolvemos false para que el botón
      // reactive el spinner y el usuario pueda volver a intentarlo.
      if (montado()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar el proyecto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  // LOGICA DE BORRADO
  Future<void> eliminarProyecto(String projectName, String projectId) async {
    //borramos el proyecto y PostgreSQL se encarga del resto gracias
    // a "ON DELETE CASCADE": tareas, subtareas, comentarios y adjuntos desaparecen solos.
    await supabase.from('projects').delete().eq('id', projectId);
  }

  // Función auxiliar para mostrar un snackbar desde el contexto raíz de esta pantalla.
  // La pasamos como callback a los widgets hijos (tarjetas y diálogos) para que puedan
  // mostrar mensajes sin necesidad de tener acceso directo al contexto del Scaffold.
  void _mostrarSnackbar(String mensaje, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: esError ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sacamos el UUID del usuario una sola vez aquí para usarlo en los streams de esta pantalla.
    final userId = supabase.auth.currentUser!.id;

    return Scaffold(
      backgroundColor: AppColores.bgDark,

      // ── FLOATING ACTION BUTTON ─────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        // Tag único para que Flutter no confunda este FAB con los de Tareas.dart
        // si ambas rutas están en el stack de navegación al mismo tiempo.
        heroTag: 'fab_crear_proyecto',
        backgroundColor: AppColores.orangePrimary,
        foregroundColor: Colors.white,
        elevation: 6,
        onPressed: () {
          showDialog(
            context: context,
            // usamos StatefulBuilder en el diálogo
            // Antes el diálogo era un AlertDialog simple sin estado propio.
            // Ahora usamos StatefulBuilder para que el botón "Guardar" pueda
            // mostrar un loader mientras espera a que termine la operación en Supabase.
            // Esto evita que el usuario pulse dos veces y cree proyectos duplicados.
            builder: (BuildContext dialogContext) {
              // Variable local al diálogo para controlar el estado del botón
              bool guardando = false;

              return StatefulBuilder(
                builder: (context, setStateDialog) {
                  return AlertDialog(
                    //Y aqui creamos el formulario de creacion de los proyectos
                    backgroundColor: AppColores.bgCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColores.borderColor),
                    ),
                    title: const Text(
                      'Crear un proyecto',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nombreCont,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Nombre del proyecto',
                            labelStyle: const TextStyle(
                              color: AppColores.textMuted,
                            ),
                            filled: true,
                            fillColor: const Color(0xFF23253A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColores.borderColor,
                              ),
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
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: descripcionCont,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Descripción del proyecto',
                            labelStyle: const TextStyle(
                              color: AppColores.textMuted,
                            ),
                            filled: true,
                            fillColor: const Color(0xFF23253A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColores.borderColor,
                              ),
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
                          ),
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          dropdownColor: AppColores.bgCard,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColores.borderColor,
                              ),
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
                            filled: true,
                            fillColor: const Color(0xFF23253A),
                            labelText: "Estado del proyecto",
                            labelStyle: const TextStyle(
                              color: AppColores.textMuted,
                            ),
                          ),
                          items: <String>['Por iniciar', 'En curso', 'Pausado']
                              .map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              })
                              .toList(),
                          onChanged: (String? nuevoValor) {
                            setState(() {
                              valorSeleccionado = nuevoValor;
                            });
                          },
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        // Si está guardando bloqueamos el botón Cancelar también
                        // para que el usuario no cierre el diálogo a medias
                        onPressed: guardando
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(color: AppColores.textMuted),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColores.orangePrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        //  BOTÓN CON LOADER
                        // Si ya estamos guardando (guardando == true) pasamos null
                        // como onPressed para deshabilitar el botón y evitar doble clic
                        // Esto es igual en tareas.dart
                        onPressed: guardando
                            ? null
                            : () async {
                                // Activamos el spinner en el botón
                                setStateDialog(() => guardando = true);

                                // Llamamos a subir(): ahora devuelve bool
                                // true  → la inserción fue exitosa
                                // false → campos vacíos o error de Supabase
                                final exito = await subir(
                                  setStateDialog,
                                  () => mounted,
                                );

                                // 'context' aquí es el del StatefulBuilder, que sí
                                // apunta al diálogo (no al Scaffold padre). Eso
                                // garantiza que Navigator.pop cierre el diálogo
                                // y no otra ruta del stack de navegación.
                                if (exito && mounted) {
                                  Navigator.pop(context);
                                } else if (mounted) {
                                  // Hubo error o campos vacíos: apagamos el spinner
                                  // para que el usuario pueda corregir y reintentar.
                                  setStateDialog(() => guardando = false);
                                }
                              },
                        // El botón muestra un spinner o el texto "Guardar" según el estado
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

      // ── DRAWER
      drawer: Drawer(
        backgroundColor: AppColores.bgCard,
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF232537), AppColores.bgCard],
                ),
                border: Border(
                  bottom: BorderSide(color: AppColores.borderColor, width: 1),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset("media/proyecto.png", height: 64, width: 64),
                  const SizedBox(height: 12),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        AppColores.orangePrimary,
                        AppColores.orangeLight,
                      ],
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
                    widget.nombreUsuario,
                    style: const TextStyle(
                      color: AppColores.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── [FASE 1B] MI PERFIL — ahora es el primer ítem del menú ──────
            // Lo subimos a la primera posición porque es la acción más personal
            // y frecuente: el usuario quiere ver o actualizar su info antes que
            // navegar por secciones. Requiere el import de perfil.dart:
            //   import 'package:myapp/perfil.dart';
            ListTile(
              leading: const Icon(
                Icons.person_rounded,
                color: AppColores.orangePrimary,
              ),
              title: const Text(
                'Mi perfil',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context); // Cerramos el drawer antes de navegar
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PerfilPage(nombreUsuario: widget.nombreUsuario),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            ListTile(
              leading: const Icon(
                Icons.home_rounded,
                color: AppColores.orangePrimary,
              ),
              title: const Text(
                'Tus proyectos',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 4),
            ListTile(
              leading: const Icon(
                Icons.people_alt_rounded,
                color: AppColores.orangePrimary,
              ),
              title: const Text(
                'Compartido contigo',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () => Navigator.pop(context),
            ),
            // Empuja el botón de cerrar sesión hacia abajo
            const Spacer(),

            //SafeArea(top: false) añade automáticamente el padding correcto
            //para la barra de navegación del sistema en cualquier dispositivo,
            //sin importar si es alta, baja o tiene gestos en lugar de botones.
            SafeArea(
              top:
                  false, // Solo nos interesa el margen inferior, no el superior
              child: Column(
                children: [
                  const Divider(
                    color: AppColores.borderColor,
                    indent: 16,
                    endIndent: 16,
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Color(0xFFFF6B6B)),
                    title: const Text(
                      'Cerrar sesión',
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
                      // Cambiamos FirebaseAuth.instance.signOut() por el equivalente de Supabase.
                      await supabase.auth.signOut();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const MyHomePage(title: 'Página de inicio'),
                        ),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColores.orangePrimary,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.folder_rounded,
              color: AppColores.orangePrimary,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              "Tus proyectos",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: AppColores.orangePrimary),

        // ── CAMPANA DE NOTIFICACIONES GLOBAL ─────────────────────────────
        // Un StreamBuilder cuenta en tiempo real cuántas tareas de TODOS
        // los proyectos del usuario están dentro del rango de alerta.
        // Ahora filtramos las finalizadas y las ya descartadas por el usuario.
        actions: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: supabase
                .from('tasks')
                .stream(primaryKey: ['id'])
                .eq('created_by', userId),
            builder: (context, snapshot) {
              // Calculamos cuántas tareas tienen alerta activa
              int contadorAlertas = 0;
              if (snapshot.hasData) {
                final ahora = DateTime.now();
                final limiteAlerta = ahora.add(Duration(days: _diasAntelacion));
                contadorAlertas = snapshot.data!.where((data) {
                  // Retrocompatibilidad: si no tiene 'due_date' lo saltamos
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
                  // Botón de la campana con hitbox corregida
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: IconButton(
                      icon: const Icon(Icons.notifications_rounded),
                      color: AppColores.orangePrimary,
                      tooltip: 'Notificaciones globales',
                      padding: const EdgeInsets.all(12),
                      onPressed: () => mostrarCentroNotificacionesGlobal(
                        ctx: context,
                        diasAntelacion: _diasAntelacion,
                        notificacionesLeidas: _notificacionesLeidas,
                        proyectosCache: _proyectosCache,
                        onCambiarDias: (nuevosDias) {
                          setState(() => _diasAntelacion = nuevosDias);
                        },
                        onActualizarEstado: () {
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                  // Badge rojo, solo visible si hay tareas en alerta
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
          const SizedBox(width: 4),
        ],
      ),

      // ── BODY ──────────────────────────────────────────────────────────────
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF232537), AppColores.bgDark],
          ),
        ),
        // ── SAFE AREA EN EL BODY
        // Evita que la lista quede tapada por la barra de navegación del
        // sistema (botones inicio/atrás en Android, home indicator en iPhone).
        // top: false porque el AppBar ya gestiona el margen superior.
        // En Web el padding será cero, no afecta a esa plataforma.
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                children: [
                  // ── BARRA DE BÚSQUEDA: FUERA DEL STREAMBUILDER ────────────
                  // Mismo patrón que en Tareas.dart.
                  // Al estar fuera del StreamBuilder, el TextField nunca se
                  // destruye cuando llegan datos nuevos de Supabase, así que el
                  // usuario puede escribir sin perder el foco en ningún momento.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: BarraBusqueda(
                      controller: _busquedaCont,
                      placeholder: 'Buscar proyecto por nombre...',
                      onChanged: (texto) {
                        // setState solo actualiza _textoBusqueda.
                        // El controller no se toca, así que el TextField mantiene el foco.
                        setState(() => _textoBusqueda = texto);
                      },
                    ),
                  ),

                  Expanded(
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: supabase
                          .from('projects')
                          .stream(primaryKey: ['id'])
                          .eq('created_by', userId),
                      builder: (context, snapshot) {
                        if (snapshot.hasError)
                          return Center(
                            child: Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(
                                color: AppColores.textMuted,
                              ),
                            ),
                          );

                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            _ultimosDatos.isEmpty)
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppColores.orangePrimary,
                            ),
                          );

                        // Guardamos los datos más recientes del stream
                        if (snapshot.hasData) {
                          _ultimosDatos = snapshot.data!;
                          // Actualizamos la caché de nombres de proyectos para que las
                          // notificaciones puedan mostrar el nombre en lugar del UUID.
                          for (final p in _ultimosDatos) {
                            if (p['id'] != null && p['name'] != null) {
                              _proyectosCache[p['id'] as String] =
                                  p['name'] as String;
                            }
                          }
                        }

                        if (_ultimosDatos.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.folder_open_rounded,
                                  color: AppColores.borderColor,
                                  size: 72,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No tienes proyectos creados aún.',
                                  style: TextStyle(
                                    color: AppColores.textMuted,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Pulsa + para crear tu primer proyecto.',
                                  style: TextStyle(
                                    color: AppColores.borderColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // Aplicamos el filtro de búsqueda en memoria
                        final proyectosFiltrados = _filtrarProyectos(
                          _ultimosDatos,
                        );

                        // Si el filtro dejó la lista vacía mostramos un estado vacío descriptivo
                        if (proyectosFiltrados.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.search_off_rounded,
                                  color: AppColores.borderColor,
                                  size: 56,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Sin resultados para tu búsqueda.',
                                  style: TextStyle(
                                    color: AppColores.textMuted,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // ── PADDING INFERIOR DINÁMICO ─────────────────────────
                        // Sumamos al padding inferior la altura de la barra de
                        // navegación del sistema (MediaQuery) para que la última
                        // tarjeta nunca quede oculta detrás de los botones del OS.
                        // En Web y escritorio este valor es 0, así que no cambia nada.
                        return ListView.builder(
                          padding: EdgeInsets.only(
                            top: 8,
                            left: 12,
                            right: 12,
                            bottom: 8 + MediaQuery.of(context).padding.bottom,
                          ),
                          itemCount: proyectosFiltrados.length,
                          itemBuilder: (context, index) {
                            final data = proyectosFiltrados[index];

                            // Usamos el widget TarjetaProyecto que extraímos a su propio archivo
                            return TarjetaProyecto(
                              data: data,
                              nombreUsuario: widget.nombreUsuario,
                              onEliminar: eliminarProyecto,
                              onMostrarSnackbar: _mostrarSnackbar,
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
