// ── PANTALLA: PROYECTOS COMPARTIDOS + SISTEMA DE INVITACIONES ─────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:myapp/main.dart' show supabase;
import 'package:myapp/proyectos.dart';
import 'package:myapp/services/email_service.dart';
import 'package:myapp/widgets/app_colores.dart';
import 'package:myapp/widgets/app_drawer.dart';
import 'package:myapp/widgets/proyectos/tarjeta_proyecto.dart';
import 'package:myapp/widgets/proyectos/centro_notificaciones_global.dart';
import 'package:myapp/widgets/tareas/barra_busqueda.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────
class ProyectosCompartidos extends StatefulWidget {
  final String nombreUsuario;
  const ProyectosCompartidos({super.key, required this.nombreUsuario});

  @override
  State<ProyectosCompartidos> createState() => _ProyectosCompartidosState();
}

class _ProyectosCompartidosState extends State<ProyectosCompartidos> {
  // ── Notificaciones ────────────────────────────────────────────────────────
  int _diasAntelacion = 7;
  final Set<String> _notificacionesLeidas = {};
  final Map<String, String> _proyectosCache = {};

  // ── Búsqueda (aplica solo a proyectos aceptados) ──────────────────────────
  final TextEditingController _busquedaCont = TextEditingController();
  String _textoBusqueda = '';

  // ── Datos de las dos secciones ────────────────────────────────────────────
  List<Map<String, dynamic>> _invitaciones = []; // status = 'pending'
  List<Map<String, dynamic>> _proyectos =
      []; // status = 'accepted' + 2+ miembros

  // ── Estado de carga por sección ───────────────────────────────────────────
  bool _cargandoInvitaciones = true;
  bool _cargandoProyectos = true;
  String? _errorMensaje;

  // ── Infraestructura de actualización ─────────────────────────────────────
  RealtimeChannel? _canal;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _arrancar();
  }

  // ── ARRANQUE ──────────────────────────────────────────────────────────────
  void _arrancar() {
    final userId = supabase.auth.currentUser!.id;

    _cargarInvitaciones(userId);
    _cargarProyectosAceptados(userId);

    // Canal Realtime SIN filtro server-side (los filtered channels requieren
    // Realtime RLS activado; sin eso el callback nunca dispara).
    _canal = supabase
        .channel('compartidos_v2_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'project_members',
          callback: (payload) {
            final uidNuevo = payload.newRecord['user_id'] as String?;
            final uidViejo = payload.oldRecord['user_id'] as String?;
            if (mounted && (uidNuevo == userId || uidViejo == userId)) {
              _cargarInvitaciones(userId);
              _cargarProyectosAceptados(userId);
            }
          },
        )
        .subscribe();

    // Polling cada 30 s como red de seguridad si Realtime no está disponible
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _cargarInvitaciones(userId);
        _cargarProyectosAceptados(userId);
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INVITACIONES PENDIENTES
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _cargarInvitaciones(String userId) async {
    if (!mounted) return;
    if (_invitaciones.isEmpty) setState(() => _cargandoInvitaciones = true);

    try {
      // Filas donde el usuario tiene status='pending'
      final filasPendientes = await supabase
          .from('project_members')
          .select('project_id')
          .eq('user_id', userId)
          .eq('status', 'pending');

      if (filasPendientes.isEmpty) {
        if (mounted)
          setState(() {
            _invitaciones = [];
            _cargandoInvitaciones = false;
            _errorMensaje = null;
          });
        return;
      }

      final idsPendientes = filasPendientes
          .map((f) => f['project_id'] as String)
          .toList();

      // Datos completos de esos proyectos
      final proyectosPendientes = await supabase
          .from('projects')
          .select('id, name, description, created_by, estado')
          .inFilter('id', idsPendientes);

      // Nombre del creador
      final resultado = <Map<String, dynamic>>[];
      for (final p in proyectosPendientes) {
        String ownerNombre = 'Alguien';
        final ownerId = p['created_by'] as String?;
        if (ownerId != null) {
          try {
            final perfil = await supabase
                .from('profiles')
                .select('full_name, username')
                .eq('id', ownerId)
                .maybeSingle();
            if (perfil != null) {
              final nombre = (perfil['full_name'] as String?)?.trim() ?? '';
              final user = (perfil['username'] as String?) ?? '';
              ownerNombre = nombre.isNotEmpty
                  ? nombre
                  : (user.isNotEmpty ? user : 'Alguien');
            }
          } catch (_) {}
        }
        resultado.add({...p, 'owner_nombre': ownerNombre});
      }

      if (mounted)
        setState(() {
          _invitaciones = resultado;
          _cargandoInvitaciones = false;
          _errorMensaje = null;
        });
    } catch (e) {
      debugPrint('_cargarInvitaciones error: $e');
      if (mounted)
        setState(() {
          _cargandoInvitaciones = false;
          _errorMensaje = 'Error al cargar invitaciones: $e';
        });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PROYECTOS ACEPTADOS
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _cargarProyectosAceptados(String userId) async {
    if (!mounted) return;
    if (_proyectos.isEmpty) setState(() => _cargandoProyectos = true);

    try {
      final filasAceptadas = await supabase
          .from('project_members')
          .select('project_id')
          .eq('user_id', userId)
          .eq('status', 'accepted');

      if (filasAceptadas.isEmpty) {
        if (mounted)
          setState(() {
            _proyectos = [];
            _cargandoProyectos = false;
          });
        return;
      }

      final idsAceptados = filasAceptadas
          .map((f) => f['project_id'] as String)
          .toList();

      // Solo proyectos con 2+ miembros aceptados son "compartidos"
      final todosMiembros = await supabase
          .from('project_members')
          .select('project_id')
          .inFilter('project_id', idsAceptados)
          .eq('status', 'accepted');

      final conteo = <String, int>{};
      for (final f in todosMiembros) {
        final pid = f['project_id'] as String;
        conteo[pid] = (conteo[pid] ?? 0) + 1;
      }

      final idsCompartidos = conteo.entries
          .where((e) => e.value >= 2)
          .map((e) => e.key)
          .toList();

      if (idsCompartidos.isEmpty) {
        if (mounted)
          setState(() {
            _proyectos = [];
            _cargandoProyectos = false;
          });
        return;
      }

      final datosProyectos = await supabase
          .from('projects')
          .select()
          .inFilter('id', idsCompartidos)
          .order('created_at', ascending: false);

      for (final p in datosProyectos) {
        if (p['id'] != null && p['name'] != null) {
          _proyectosCache[p['id'] as String] = p['name'] as String;
        }
      }

      if (mounted)
        setState(() {
          _proyectos = List<Map<String, dynamic>>.from(datosProyectos);
          _cargandoProyectos = false;
        });
    } catch (e) {
      debugPrint('_cargarProyectosAceptados error: $e');
      if (mounted) setState(() => _cargandoProyectos = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACEPTAR INVITACIÓN — usa RPC SECURITY DEFINER para bypassear RLS
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _aceptarInvitacion(Map<String, dynamic> proyecto) async {
    final userId = supabase.auth.currentUser!.id;
    final projectId = proyecto['id'] as String;
    final projectName = proyecto['name'] as String;

    // 1 Respuesta visual inmediata (patrón optimista)
    setState(() => _invitaciones.removeWhere((i) => i['id'] == projectId));

    try {
      // 2 Llamamos a la RPC — función SQL con SECURITY DEFINER
      //    Definición en Supabase SQL Editor:
      //      CREATE OR REPLACE FUNCTION public.aceptar_invitacion(p_project_id UUID)
      //      RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
      //    La función actualiza status='accepted' solo si la fila es del usuario actual
      final respuesta = await supabase.rpc(
        'aceptar_invitacion',
        params: {'p_project_id': projectId},
      );

      // La función devuelve {"ok": true} o {"ok": false, "error": "..."}
      final ok = respuesta['ok'] as bool? ?? false;
      if (!ok) {
        throw Exception(
          respuesta['error'] ?? 'Error al procesar en el servidor',
        );
      }

      if (mounted) {
        _mostrarSnackbar('✅ Te has unido a "$projectName"');
        // ③ Recargamos la sección de proyectos aceptados
        _cargarProyectosAceptados(userId);
      }

      // ④ Email al owner (best-effort, no bloquea nada)
      _notificarOwnerPorEmail(proyecto, userId);
    } catch (e) {
      // ⑤ Revertimos la UI si la RPC falló
      if (mounted) {
        setState(() => _invitaciones.add(proyecto));
        _mostrarSnackbar('Error al aceptar: $e', esError: true);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RECHAZAR INVITACIÓN — RPC SECURITY DEFINER
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _rechazarInvitacion(Map<String, dynamic> proyecto) async {
    final projectId = proyecto['id'] as String;
    final projectName = proyecto['name'] as String;

    // 1 Respuesta visual inmediata
    setState(() => _invitaciones.removeWhere((i) => i['id'] == projectId));

    try {
      // 2 Llamamos a la RPC — hace DELETE solo si la fila es pending y del usuario
      //    CREATE OR REPLACE FUNCTION public.rechazar_invitacion(p_project_id UUID)
      final respuesta = await supabase.rpc(
        'rechazar_invitacion',
        params: {'p_project_id': projectId},
      );

      final ok = respuesta['ok'] as bool? ?? false;
      if (!ok) {
        throw Exception(
          respuesta['error'] ?? 'Error al procesar en el servidor',
        );
      }

      if (mounted) _mostrarSnackbar('Invitación a "$projectName" rechazada');
    } catch (e) {
      // 3 Revertimos si la RPC falló
      if (mounted) {
        setState(() => _invitaciones.add(proyecto));
        _mostrarSnackbar('Error al rechazar: $e', esError: true);
      }
    }
  }

  // ── Email al owner (best-effort, aislado del flujo principal) ────────────
  Future<void> _notificarOwnerPorEmail(
    Map<String, dynamic> proyecto,
    String userId,
  ) async {
    try {
      final miPerfil = await supabase
          .from('profiles')
          .select('full_name, username')
          .eq('id', userId)
          .single();
      final ownerId = proyecto['created_by'] as String?;
      if (ownerId == null) return;
      final ownerPerfil = await supabase
          .from('profiles')
          .select('email, full_name')
          .eq('id', ownerId)
          .single();
      final ownerEmail = ownerPerfil['email'] as String?;
      if (ownerEmail == null) return;
      final miNombre =
          (miPerfil['full_name'] as String?)?.trim().isNotEmpty == true
          ? miPerfil['full_name'] as String
          : (miPerfil['username'] as String? ?? 'Un usuario');
      await EmailService.notificarInvitacion(
        emailDestinatario: ownerEmail,
        nombreDestinatario: ownerPerfil['full_name'] as String? ?? 'Owner',
        nombreProyecto: proyecto['name'] as String,
        nombreInvitador: '$miNombre aceptó tu invitación al proyecto',
      );
    } catch (e) {
      debugPrint('Email al owner falló (ignorado): $e');
    }
  }

  // ── Eliminar proyecto de la sección de aceptados ─────────────────────────
  Future<void> eliminarProyecto(String nombre, String id) async {
    await supabase.from('projects').delete().eq('id', id);
    if (mounted) setState(() => _proyectos.removeWhere((p) => p['id'] == id));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _mostrarSnackbar(String msg, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: esError ? Colors.red[700] : null,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  List<Map<String, dynamic>> _filtrarProyectos(
    List<Map<String, dynamic>> lista,
  ) {
    if (_textoBusqueda.isEmpty) return lista;
    final q = _textoBusqueda.toLowerCase();
    return lista
        .where((p) => (p['name'] as String? ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    if (_canal != null) supabase.removeChannel(_canal!);
    _busquedaCont.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final userId = supabase.auth.currentUser!.id;

    return Scaffold(
      backgroundColor: AppColores.bgDark,
      drawer: AppDrawer(
        nombreUsuario: widget.nombreUsuario,
        pantallaActual: PantallaProyectos.compartidos,
        misProyectosBuilder: () =>
            Proyectos(nombreUsuario: widget.nombreUsuario),
        compartidosBuilder: () =>
            ProyectosCompartidos(nombreUsuario: widget.nombreUsuario),
      ),

      // ── AppBar ─────────────────────────────────────────────────────────────
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
          children: [
            const Icon(
              Icons.people_alt_rounded,
              color: AppColores.orangePrimary,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Compartido conmigo',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ),
            if (_invitaciones.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_invitaciones.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        iconTheme: const IconThemeData(color: AppColores.orangePrimary),
        actions: [
          // Botón de recarga manual
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: AppColores.textMuted,
            tooltip: 'Actualizar',
            onPressed: () {
              setState(() {
                _cargandoInvitaciones = true;
                _cargandoProyectos = true;
                _errorMensaje = null;
              });
              _cargarInvitaciones(userId);
              _cargarProyectosAceptados(userId);
            },
          ),
          // Campana de notificaciones globales
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: supabase
                .from('tasks')
                .stream(primaryKey: ['id'])
                .eq('assigned_to', userId),
            builder: (ctx, snap) {
              int c = 0;
              if (snap.hasData) {
                final lim = DateTime.now().add(Duration(days: _diasAntelacion));
                c = snap.data!.where((d) {
                  if (d['due_date'] == null || d['status'] == 'done')
                    return false;
                  if (_notificacionesLeidas.contains(d['id'] as String))
                    return false;
                  return DateTime.parse(d['due_date'] as String).isBefore(lim);
                }).length;
              }
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_rounded),
                    color: AppColores.orangePrimary,
                    onPressed: () => mostrarCentroNotificacionesGlobal(
                      ctx: context,
                      diasAntelacion: _diasAntelacion,
                      notificacionesLeidas: _notificacionesLeidas,
                      proyectosCache: _proyectosCache,
                      onCambiarDias: (d) => setState(() => _diasAntelacion = d),
                      onActualizarEstado: () => setState(() {}),
                    ),
                  ),
                  if (c > 0)
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
                            c > 9 ? '9+' : '$c',
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

      // ── Body ───────────────────────────────────────────────────────────────
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
                  // Barra de búsqueda (filtra solo proyectos aceptados)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: BarraBusqueda(
                      controller: _busquedaCont,
                      placeholder: 'Buscar en proyectos compartidos...',
                      onChanged: (t) => setState(() => _textoBusqueda = t),
                    ),
                  ),

                  // Banner de error (visible si hay fallo en la carga)
                  if (_errorMensaje != null)
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red[900]!.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.red[400]!.withOpacity(0.6),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Colors.redAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMensaje!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _errorMensaje = null),
                            child: const Icon(
                              Icons.close,
                              color: Colors.redAccent,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Contenido desplazable con las dos secciones
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(
                        top: 12,
                        left: 12,
                        right: 12,
                        bottom: 16 + MediaQuery.of(context).padding.bottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ══════════════════════════════════════════════════
                          // INVITACIONES PENDIENTES
                          // ══════════════════════════════════════════════════
                          _SeccionInvitaciones(
                            cargando: _cargandoInvitaciones,
                            invitaciones: _invitaciones,
                            onAceptar: _aceptarInvitacion,
                            onRechazar: _rechazarInvitacion,
                          ),

                          const SizedBox(height: 20),

                          // ══════════════════════════════════════════════════
                          // PROYECTOS COMPARTIDOS ACEPTADOS
                          // ══════════════════════════════════════════════════
                          _SeccionProyectosAceptados(
                            cargando: _cargandoProyectos,
                            proyectos: _filtrarProyectos(_proyectos),
                            hayProyectosSinFiltro: _proyectos.isNotEmpty,
                            nombreUsuario: widget.nombreUsuario,
                            onEliminar: eliminarProyecto,
                            onMostrarSnackbar: _mostrarSnackbar,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET:  INVITACIONES PENDIENTES
// ─────────────────────────────────────────────────────────────────────────────
class _SeccionInvitaciones extends StatelessWidget {
  final bool cargando;
  final List<Map<String, dynamic>> invitaciones;
  final Future<void> Function(Map<String, dynamic>) onAceptar;
  final Future<void> Function(Map<String, dynamic>) onRechazar;

  const _SeccionInvitaciones({
    required this.cargando,
    required this.invitaciones,
    required this.onAceptar,
    required this.onRechazar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Encabezado
        Row(
          children: [
            const Icon(
              Icons.mark_email_unread_rounded,
              color: Color(0xFFFF6B6B),
              size: 16,
            ),
            const SizedBox(width: 8),
            const Text(
              'INVITACIONES PENDIENTES',
              style: TextStyle(
                color: Color(0xFFFF6B6B),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            if (invitaciones.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFF6B6B).withOpacity(0.5),
                  ),
                ),
                child: Text(
                  '${invitaciones.length}',
                  style: const TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),

        if (cargando)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: Color(0xFFFF6B6B),
                  strokeWidth: 2.5,
                ),
              ),
            ),
          )
        else if (invitaciones.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColores.bgCard.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColores.borderColor.withOpacity(0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.inbox_rounded,
                  color: AppColores.borderColor,
                  size: 22,
                ),
                SizedBox(width: 10),
                Text(
                  'Sin invitaciones pendientes',
                  style: TextStyle(color: AppColores.textMuted, fontSize: 14),
                ),
              ],
            ),
          )
        else
          Column(
            mainAxisSize: MainAxisSize.min,
            children: invitaciones
                .map(
                  (inv) => _TarjetaInvitacion(
                    key: ValueKey(inv['id']),
                    proyecto: inv,
                    onAceptar: () => onAceptar(inv),
                    onRechazar: () => onRechazar(inv),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET:  PROYECTOS COMPARTIDOS ACEPTADOS
// ─────────────────────────────────────────────────────────────────────────────
class _SeccionProyectosAceptados extends StatelessWidget {
  final bool cargando;
  final List<Map<String, dynamic>> proyectos;
  final bool hayProyectosSinFiltro;
  final String nombreUsuario;
  final Future<void> Function(String, String) onEliminar;
  final void Function(String, {bool esError}) onMostrarSnackbar;

  const _SeccionProyectosAceptados({
    required this.cargando,
    required this.proyectos,
    required this.hayProyectosSinFiltro,
    required this.nombreUsuario,
    required this.onEliminar,
    required this.onMostrarSnackbar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: const [
            Icon(
              Icons.people_alt_rounded,
              color: AppColores.orangePrimary,
              size: 16,
            ),
            SizedBox(width: 8),
            Text(
              'MIS PROYECTOS COMPARTIDOS',
              style: TextStyle(
                color: AppColores.orangePrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (cargando)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: AppColores.orangePrimary,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          )
        else if (proyectos.isEmpty && hayProyectosSinFiltro)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    color: AppColores.borderColor,
                    size: 48,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Sin resultados para tu búsqueda.',
                    style: TextStyle(color: AppColores.textMuted, fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else if (proyectos.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColores.bgCard.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColores.borderColor.withOpacity(0.5),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.folder_shared_outlined,
                  color: AppColores.borderColor,
                  size: 40,
                ),
                SizedBox(height: 10),
                Text(
                  'Aún no tienes proyectos compartidos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColores.textMuted, fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  'Acepta una invitación para empezar a colaborar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColores.borderColor, fontSize: 12),
                ),
              ],
            ),
          )
        else
          Column(
            mainAxisSize: MainAxisSize.min,
            children: proyectos
                .map(
                  (data) => TarjetaProyecto(
                    key: ValueKey(data['id']),
                    data: data,
                    nombreUsuario: nombreUsuario,
                    onEliminar: onEliminar,
                    onMostrarSnackbar: onMostrarSnackbar,
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: TARJETA DE INVITACIÓN PENDIENTE
// Estado propio solo para el spinner de cada botón.
// ─────────────────────────────────────────────────────────────────────────────
class _TarjetaInvitacion extends StatefulWidget {
  final Map<String, dynamic> proyecto;
  final Future<void> Function() onAceptar;
  final Future<void> Function() onRechazar;

  const _TarjetaInvitacion({
    super.key,
    required this.proyecto,
    required this.onAceptar,
    required this.onRechazar,
  });

  @override
  State<_TarjetaInvitacion> createState() => _TarjetaInvitacionState();
}

class _TarjetaInvitacionState extends State<_TarjetaInvitacion> {
  bool _aceptando = false;
  bool _rechazando = false;

  @override
  Widget build(BuildContext context) {
    final nombre = widget.proyecto['name'] as String? ?? 'Proyecto sin nombre';
    final descripcion = widget.proyecto['description'] as String? ?? '';
    final ownerNombre = widget.proyecto['owner_nombre'] as String? ?? 'Alguien';
    final estado = widget.proyecto['estado'] as String? ?? '';
    final procesando = _aceptando || _rechazando;

    return Card(
      color: AppColores.bgCard,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFFF6B6B), width: 1.2),
      ),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Fila superior: icono + datos + badge PENDIENTE ──────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFFF6B6B).withOpacity(0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.folder_shared_rounded,
                    color: Color(0xFFFF6B6B),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Te invitaron a:',
                        style: TextStyle(
                          color: AppColores.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.person_outline_rounded,
                            color: AppColores.textMuted,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Invitado por $ownerNombre',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColores.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Badge PENDIENTE
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFF6B6B).withOpacity(0.5),
                    ),
                  ),
                  child: const Text(
                    'PENDIENTE',
                    style: TextStyle(
                      color: Color(0xFFFF6B6B),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),

            // ── Descripción ─────────────────────────────────────────────
            if (descripcion.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                descripcion,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColores.textMuted,
                  fontSize: 13,
                ),
              ),
            ],

            // ── Estado del proyecto ──────────────────────────────────────
            if (estado.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.flag_rounded,
                    color: AppColores.textMuted,
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    estado,
                    style: const TextStyle(
                      color: AppColores.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),
            const Divider(color: AppColores.borderColor, height: 1),
            const SizedBox(height: 14),

            // ── Botones Aceptar / Rechazar ───────────────────────────────
            Row(
              children: [
                // Aceptar
                Flexible(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3EC934),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(
                          0xFF3EC934,
                        ).withOpacity(0.4),
                        disabledForegroundColor: Colors.white54,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: procesando ? 0 : 2,
                      ),
                      icon: _aceptando
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 18,
                            ),
                      label: Text(
                        _aceptando ? 'Aceptando...' : 'Aceptar',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      onPressed: procesando
                          ? null
                          : () async {
                              setState(() => _aceptando = true);
                              await widget.onAceptar();
                              if (mounted) setState(() => _aceptando = false);
                            },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Rechazar
                Flexible(
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF6B6B),
                        disabledForegroundColor: const Color(
                          0xFFFF6B6B,
                        ).withOpacity(0.35),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: procesando
                              ? const Color(0xFFFF6B6B).withOpacity(0.3)
                              : const Color(0xFFFF6B6B),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: _rechazando
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                color: Color(0xFFFF6B6B),
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.cancel_outlined, size: 18),
                      label: Text(
                        _rechazando ? 'Rechazando...' : 'Rechazar',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      onPressed: procesando
                          ? null
                          : () async {
                              setState(() => _rechazando = true);
                              await widget.onRechazar();
                              if (mounted) setState(() => _rechazando = false);
                            },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
