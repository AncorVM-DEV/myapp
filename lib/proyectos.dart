import 'package:myapp/utils/sanitizer.dart'; // Sanitización de inputs antes de enviar a Supabase
// ── PANTALLA: TUS PROYECTOS (INDIVIDUALES) ────────────────────────────────────
// Muestra ÚNICAMENTE los proyectos donde el usuario actual es el ÚNICO miembro.
// Los proyectos cooperativos (2+ miembros) se muestran en ProyectosCompartidos.
//
// Lógica de consulta (Fase 2 - Objetivo 2):
//   1. Escuchamos en tiempo real la tabla project_members filtrada por userId.
//   2. Cuando llegan cambios, ejecutamos _cargarProyectosSolo() de forma asíncrona.
//   3. Esa función cuenta los miembros de cada proyecto y filtra los que tienen 1.
//   4. El resultado se guarda en _proyectos y setState() actualiza la UI.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:myapp/Tareas.dart';
import 'package:myapp/login.dart';
import 'package:myapp/main.dart' show supabase;
import 'package:myapp/proyectos_compartidos.dart';
import 'package:myapp/widgets/app_colores.dart';
import 'package:myapp/widgets/app_drawer.dart';
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
  // Controladores del formulario de creación de proyecto
  final nombreCont = TextEditingController();
  final descripcionCont = TextEditingController();
  String? valorSeleccionado = 'Por iniciar';

  // ── NOTIFICACIONES GLOBALES ────────────────────────────────────────────────
  // Días de antelación configurados por el usuario para las alertas de tareas.
  // El valor por defecto es 7 días; el usuario puede cambiarlo desde el centro
  // de notificaciones. Valores permitidos: 1, 3, 7 o 15.
  int _diasAntelacion = 7;

  // IDs de las tareas que el usuario ya descartó del centro de notificaciones
  // (se reinician al cerrar la app porque es una solución ligera en memoria)
  final Set<String> _notificacionesLeidas = {};

  // Caché de UUID → nombre de proyecto para las notificaciones sin consulta extra
  final Map<String, String> _proyectosCache = {};

  // ── BÚSQUEDA ───────────────────────────────────────────────────────────────
  // El controller vive en el State para que sobreviva a los repintados de la UI
  // y el TextField no pierda el foco mientras el usuario escribe.
  final TextEditingController _busquedaCont = TextEditingController();
  String _textoBusqueda = '';

  // ── ESTADO DE LA LISTA ─────────────────────────────────────────────────────
  // Lista de proyectos individuales (donde el usuario es el único miembro).
  // Se actualiza mediante _cargarProyectosSolo() al recibir cambios en tiempo real.
  List<Map<String, dynamic>> _proyectos = [];
  bool _cargando = true; // Muestra el spinner la primera vez

  // RealtimeChannel para detectar cambios en project_members en tiempo real.
  // Sustituye a StreamSubscription porque onPostgresChanges detecta INSERT
  // de filas nuevas, algo que .stream() no hace correctamente.
  RealtimeChannel? _canalMemberships;

  // [FIX] Canal secundario que escucha INSERT y UPDATE directamente en la tabla
  // 'projects'. Sin él, editar el nombre, descripción o estado de un proyecto
  // no se reflejaba en la lista porque _canalMemberships solo escucha
  // cambios en 'project_members', no en 'projects'.
  RealtimeChannel? _canalProyectos;

  @override
  void initState() {
    super.initState();
    _iniciarStream();
  }

  // ── CANAL EN TIEMPO REAL ───────────────────────────────────────────────────
  // Usamos onPostgresChanges en lugar de .stream() para detectar
  // correctamente todos los eventos: INSERT (nuevo proyecto), UPDATE
  // (cambio de rol, status) y DELETE (expulsión o abandono).
  void _iniciarStream() {
    final userId = supabase.auth.currentUser!.id;

    // Carga inicial inmediata al abrir la pantalla
    _cargarProyectosSolo(userId);

    _canalMemberships = supabase
        .channel('proyectos_solo_${userId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'project_members',
          // [FIX] Se elimina el filtro server-side: los filtered channels requieren
          // Realtime RLS activado; sin esa configuración el callback nunca dispara.
          // Ahora filtramos en el cliente dentro del callback, igual que hace
          // proyectos_compartidos.dart, para no disparar recargas innecesarias.
          callback: (payload) {
            final uidNuevo = payload.newRecord['user_id'] as String?;
            final uidViejo = payload.oldRecord['user_id'] as String?;
            if (mounted && (uidNuevo == userId || uidViejo == userId)) {
              _cargarProyectosSolo(userId);
            }
          },
        )
        .subscribe();

    // [FIX] Canal adicional para la tabla 'projects': detecta CREATE (INSERT) y
    // EDIT/CAMBIO DE ESTADO (UPDATE). Sin filtro server-side por el mismo motivo
    // que _canalMemberships. _cargarProyectosSolo filtra por membresía del usuario.
    _canalProyectos = supabase
        .channel('proyectos_cambios_${userId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'projects',
          callback: (_) {
            if (mounted) _cargarProyectosSolo(userId);
          },
        )
        .subscribe();
  }

  // ── CARGA Y FILTRADO DE PROYECTOS INDIVIDUALES ────────────────────────────
  // Consulta en dos pasos para determinar qué proyectos son "solo" del usuario:
  //   Paso 1: Obtenemos todos los project_id donde el usuario es miembro.
  //   Paso 2: Contamos cuántos miembros tiene CADA uno de esos proyectos.
  //   Paso 3: Nos quedamos solo con los que tienen exactamente 1 miembro (el propio usuario).
  //   Paso 4: Obtenemos los datos completos de esos proyectos de la tabla projects.
  Future<void> _cargarProyectosSolo(String userId) async {
    try {
      // Paso 1: project_ids donde el usuario tiene membresía ACEPTADA
      // Ignoramos las invitaciones pendientes (status='pending') porque aún
      // no forman parte activa del proyecto.
      final misMemberships = await supabase
          .from('project_members')
          .select('project_id')
          .eq('user_id', userId)
          .eq('status', 'accepted');

      if (misMemberships.isEmpty) {
        if (mounted)
          setState(() {
            _proyectos = [];
            _cargando = false;
          });
        return;
      }

      final misProjectIds = misMemberships
          .map((m) => m['project_id'] as String)
          .toList();

      // Paso 2: todos los miembros ACEPTADOS de esos proyectos (para contar)
      // Solo contamos aceptados: un pendiente no hace que el proyecto sea "compartido"
      final todosMiembros = await supabase
          .from('project_members')
          .select('project_id')
          .inFilter('project_id', misProjectIds)
          .eq('status', 'accepted');

      // Paso 3: contamos miembros por proyecto y filtramos los que tienen exactamente 1
      final conteoMap = <String, int>{};
      for (final fila in todosMiembros) {
        final pid = fila['project_id'] as String;
        conteoMap[pid] = (conteoMap[pid] ?? 0) + 1;
      }

      final soloIds = conteoMap.entries
          .where((e) => e.value == 1) // Solo yo soy miembro
          .map((e) => e.key)
          .toList();

      if (soloIds.isEmpty) {
        if (mounted)
          setState(() {
            _proyectos = [];
            _cargando = false;
          });
        return;
      }

      // Paso 4: datos completos de los proyectos individuales, ordenados por fecha de creación
      final proyectos = await supabase
          .from('projects')
          .select()
          .inFilter('id', soloIds)
          .order('created_at', ascending: false);

      // Actualizamos la caché de nombres para el centro de notificaciones
      for (final p in proyectos) {
        if (p['id'] != null && p['name'] != null) {
          _proyectosCache[p['id'] as String] = p['name'] as String;
        }
      }

      if (mounted) {
        setState(() {
          _proyectos = List<Map<String, dynamic>>.from(proyectos);
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
      print('🔴 PROYECTOS: error al cargar proyectos individuales → $e');
    }
  }

  @override
  void dispose() {
    // Eliminamos el canal de Supabase al salir para liberar recursos
    if (_canalMemberships != null) supabase.removeChannel(_canalMemberships!);
    // [FIX] Liberamos también el canal secundario de la tabla 'projects'
    if (_canalProyectos != null) supabase.removeChannel(_canalProyectos!);
    nombreCont.dispose();
    descripcionCont.dispose();
    _busquedaCont.dispose();
    super.dispose();
  }

  // ── FILTRADO EN CLIENTE ────────────────────────────────────────────────────
  // Comparamos el texto de búsqueda contra el nombre del proyecto.
  // No lanzamos consultas extra a Supabase: filtramos la lista en memoria.
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

  // ── CREAR PROYECTO ─────────────────────────────────────────────────────────
  // Devuelve true en éxito (para que el diálogo se cierre) y false en error
  // (para que el botón reactive el spinner y el usuario pueda reintentar).
  Future<bool> _subir(
    void Function(void Function()) setStateDialog,
    bool Function() montado,
  ) async {
    final nombreP = nombreCont.text.trim();
    final descripcionP = descripcionCont.text.trim();

    if (nombreP.isEmpty || descripcionP.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, rellena todos los campos')),
      );
      return false;
    }

    try {
      final userId = supabase.auth.currentUser!.id;

      // Insertamos el proyecto y obtenemos el UUID generado por PostgreSQL
      final proyectoCreado = await supabase
          .from('projects')
          .insert({
            // Sanitizamos el input antes de enviarlo a Supabase
            'name': Sanitizer.clean(nombreP),
            'description': Sanitizer.clean(descripcionP),
            'created_by': userId,
            'estado': valorSeleccionado,
          })
          .select()
          .single();

      // Registramos al creador como miembro con rol 'owner'.
      // Usamos upsert con ignoreDuplicates por si el Trigger de la BBDD ya lo insertó.
      await supabase.from('project_members').upsert({
        'project_id': proyectoCreado['id'],
        'user_id': userId,
        'role': 'owner',
      }, ignoreDuplicates: true);

      // Limpiamos los campos para la próxima vez que se abra el diálogo
      nombreCont.clear();
      descripcionCont.clear();

      if (!montado()) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Proyecto creado con éxito!')),
      );

      // [FIX] Forzamos recarga inmediata de la lista sin esperar al canal Realtime,
      // garantizando que el nuevo proyecto aparezca al instante en cualquier entorno.
      _cargarProyectosSolo(userId);

      // El stream de project_members detectará el nuevo registro y recargará la lista
      return true;
    } catch (e) {
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

  // ── ELIMINAR PROYECTO ──────────────────────────────────────────────────────
  // PostgreSQL eliminará en cascada tareas, subtareas, comentarios y adjuntos
  // gracias a las constraints ON DELETE CASCADE definidas en el esquema.
  Future<void> eliminarProyecto(String projectName, String projectId) async {
    await supabase.from('projects').delete().eq('id', projectId);

    // BUG 2 CORREGIDO: antes solo se hacía el .delete() en Supabase pero la UI
    // no reaccionaba hasta el próximo reload del canal en tiempo real.
    // Ahora removemos el proyecto de la lista local inmediatamente con setState,
    // así la tarjeta desaparece al instante sin esperar al siguiente evento.
    if (mounted) {
      setState(() {
        _proyectos.removeWhere((p) => p['id'] == projectId);
      });
    }
  }

  // Callback para que las tarjetas hijas muestren SnackBars sin acceder al contexto directamente
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
    final userId = supabase.auth.currentUser!.id;

    return Scaffold(
      backgroundColor: AppColores.bgDark,

      // ── FAB: CREAR PROYECTO ────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        heroTag:
            'fab_crear_proyecto', // Tag único para evitar conflicto con otros FABs
        backgroundColor: AppColores.orangePrimary,
        foregroundColor: Colors.white,
        elevation: 6,
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext dialogContext) {
              bool guardando = false;

              // StatefulBuilder nos permite controlar el estado del botón del diálogo
              // sin necesidad de convertir el diálogo en un StatefulWidget propio.
              return StatefulBuilder(
                builder: (context, setStateDialog) {
                  return AlertDialog(
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
                    content: SingleChildScrollView(
                      // SingleChildScrollView evita overflow cuando se abre el teclado en móvil
                      child: Column(
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
                              labelText: 'Estado del proyecto',
                              labelStyle: const TextStyle(
                                color: AppColores.textMuted,
                              ),
                            ),
                            items:
                                <String>['Por iniciar', 'En curso', 'Pausado']
                                    .map(
                                      (v) => DropdownMenuItem(
                                        value: v,
                                        child: Text(v),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) =>
                                setState(() => valorSeleccionado = v),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
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
                        onPressed: guardando
                            ? null
                            : () async {
                                setStateDialog(() => guardando = true);
                                final exito = await _subir(
                                  setStateDialog,
                                  () => mounted,
                                );
                                if (exito && mounted) {
                                  Navigator.pop(context);
                                } else if (mounted) {
                                  setStateDialog(() => guardando = false);
                                }
                              },
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

      // ── DRAWER COMPARTIDO ──────────────────────────────────────────────────
      // Usamos el AppDrawer reutilizable. Inyectamos los builders de navegación
      // aquí para evitar que el widget del drawer tenga imports circulares.
      drawer: AppDrawer(
        nombreUsuario: widget.nombreUsuario,
        pantallaActual:
            PantallaProyectos.misProyectos, // Resalta "Tus proyectos"
        misProyectosBuilder: () =>
            Proyectos(nombreUsuario: widget.nombreUsuario),
        compartidosBuilder: () =>
            ProyectosCompartidos(nombreUsuario: widget.nombreUsuario),
      ),

      // ── APPBAR ─────────────────────────────────────────────────────────────
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
            Icon(Icons.home_rounded, color: AppColores.orangePrimary, size: 20),
            SizedBox(width: 8),
            Text(
              'Tus proyectos',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: AppColores.orangePrimary),

        // ── CAMPANA DE NOTIFICACIONES GLOBAL ──────────────────────────────
        // Cuenta en tiempo real las tareas próximas a su fecha límite.
        // Filtramos las finalizadas (status == 'done') y las ya descartadas.
        actions: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: supabase
                .from('tasks')
                .stream(primaryKey: ['id'])
                .eq('created_by', userId),
            builder: (context, snapshot) {
              int contadorAlertas = 0;
              if (snapshot.hasData) {
                final ahora = DateTime.now();
                final limiteAlerta = ahora.add(Duration(days: _diasAntelacion));
                contadorAlertas = snapshot.data!.where((data) {
                  if (data['due_date'] == null) return false;
                  if (data['status'] == 'done') return false;
                  if (_notificacionesLeidas.contains(data['id'] as String))
                    return false;
                  final fecha = DateTime.parse(data['due_date'] as String);
                  return fecha.isBefore(limiteAlerta) ||
                      fecha.isAtSameMomentAs(limiteAlerta);
                }).length;
              }

              return Stack(
                children: [
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
                        onCambiarDias: (nuevosDias) =>
                            setState(() => _diasAntelacion = nuevosDias),
                        onActualizarEstado: () => setState(() {}),
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
          const SizedBox(width: 4),
        ],
      ),

      // ── BODY ───────────────────────────────────────────────────────────────
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF232537), AppColores.bgDark],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                children: [
                  // ── BARRA DE BÚSQUEDA ──────────────────────────────────────
                  // Fuera del builder de la lista para que no pierda el foco
                  // cuando llegan datos nuevos de Supabase.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: BarraBusqueda(
                      controller: _busquedaCont,
                      placeholder: 'Buscar proyecto por nombre...',
                      onChanged: (texto) =>
                          setState(() => _textoBusqueda = texto),
                    ),
                  ),

                  Expanded(child: _buildContenido()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── CONTENIDO DE LA LISTA ──────────────────────────────────────────────────
  // Separamos el contenido en su propio método para mantener build() legible.
  Widget _buildContenido() {
    // Estado de carga inicial (spinner)
    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(color: AppColores.orangePrimary),
      );
    }

    // Sin proyectos individuales
    if (_proyectos.isEmpty) {
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
              'No tienes proyectos individuales aún.',
              style: TextStyle(color: AppColores.textMuted, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Pulsa + para crear tu primer proyecto.',
              style: TextStyle(color: AppColores.borderColor, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Aplicamos el filtro de búsqueda en memoria
    final filtrados = _filtrarProyectos(_proyectos);

    if (filtrados.isEmpty) {
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
              style: TextStyle(color: AppColores.textMuted, fontSize: 15),
            ),
          ],
        ),
      );
    }

    // ── PADDING INFERIOR DINÁMICO ────────────────────────────────────────────
    // Sumamos la altura de la barra de navegación del sistema para que la última
    // tarjeta no quede oculta detrás de los botones del OS. En Web es 0.
    return ListView.builder(
      padding: EdgeInsets.only(
        top: 8,
        left: 12,
        right: 12,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      itemCount: filtrados.length,
      itemBuilder: (context, index) {
        final data = filtrados[index];
        return TarjetaProyecto(
          data: data,
          nombreUsuario: widget.nombreUsuario,
          onEliminar: eliminarProyecto,
          onMostrarSnackbar: _mostrarSnackbar,
        );
      },
    );
  }
}
