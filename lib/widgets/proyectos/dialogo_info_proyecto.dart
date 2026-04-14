import 'package:flutter/material.dart';
import 'package:myapp/main.dart' show supabase;
import 'package:myapp/widgets/app_colores.dart';
import 'package:myapp/widgets/proyectos/stat_chip.dart';
import 'package:myapp/widgets/proyectos/dialogo_confirmacion_borrado.dart';

// ── CONSULTA PARA LAS ESTADÍSTICAS ────────────────────────────────────────────
Future<Map<String, int>> _obtenerEstadisticas(String projectId) async {
  final snapshot = await supabase
      .from('tasks')
      .select('id, status')
      .eq('project_id', projectId);

  final total = snapshot.length;
  final completadas = snapshot.where((d) => d['status'] == 'done').length;
  final pendientes = total - completadas;

  return {'total': total, 'completadas': completadas, 'pendientes': pendientes};
}

// ── DIÁLOGO DE INFORMACIÓN DEL PROYECTO (con gestión de miembros) ─────────────
// Fase 2 — Objetivo 1: se añade la sección "Miembros" con:
//   • Botón que abre el diálogo de gestión de miembros
//   • Invitar por username exacto
//   • Listado con roles y opciones de cambio/expulsión (solo owner/admin)
//   • El botón de invitar se oculta si el usuario tiene rol de solo lectura

void mostrarDialogoInfoProyecto({
  required BuildContext ctx,
  required String projectName,
  required String projectDescription,
  required String projectEstado,
  required String projectId,
  required Future<void> Function(String nombre, String id) onEliminar,
  required void Function(String mensaje, {bool esError}) onMostrarSnackbar,
}) {
  showDialog(
    context: ctx,
    builder: (BuildContext infoContext) {
      final nombreEditCont = TextEditingController(text: projectName);
      final descEditCont = TextEditingController(text: projectDescription);

      // Variables mutables del closure — misma razón que antes:
      // deben vivir fuera del builder del StatefulBuilder para no resetearse
      // en cada rebuild causado por setStateLocal()
      String estadoEditable = projectEstado;
      bool guardando = false;

      return StatefulBuilder(
        builder: (context, setStateLocal) {
          Future<void> guardarCambios() async {
            final nuevoNombre = nombreEditCont.text.trim();
            final nuevaDesc = descEditCont.text.trim();

            if (nuevoNombre.isEmpty) {
              onMostrarSnackbar(
                'El nombre no puede estar vacío',
                esError: true,
              );
              return;
            }

            setStateLocal(() => guardando = true);

            try {
              await supabase
                  .from('projects')
                  .update({
                    'name': nuevoNombre,
                    'description': nuevaDesc,
                    'estado': estadoEditable,
                  })
                  .eq('id', projectId);

              if (!context.mounted) return;
              Navigator.pop(infoContext);
              onMostrarSnackbar('¡Proyecto actualizado!');
            } catch (e) {
              if (!context.mounted) return;
              setStateLocal(() => guardando = false);
              onMostrarSnackbar('Error al guardar: $e', esError: true);
            }
          }

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            backgroundColor: AppColores.bgCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColores.borderColor),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(infoContext).size.height * 0.85,
                maxWidth: 520,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Cabecera fija ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              AppColores.orangePrimary,
                              AppColores.orangeLight,
                            ],
                          ).createShader(bounds),
                          child: const Icon(
                            Icons.bar_chart_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Información del proyecto',
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

                  // ── Contenido desplazable ──────────────────────────────────
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Nombre ──────────────────────────────────────────
                          _etiquetaCampo('NOMBRE DEL PROYECTO'),
                          const SizedBox(height: 4),
                          _campoEditable(
                            controller: nombreEditCont,
                            hintText: 'Nombre del proyecto',
                          ),
                          const SizedBox(height: 12),

                          // ── Descripción ────────────────────────────────────
                          _etiquetaCampo('DESCRIPCIÓN'),
                          const SizedBox(height: 4),
                          _campoEditable(
                            controller: descEditCont,
                            hintText: 'Descripción del proyecto',
                            maxLines: 3,
                          ),
                          const SizedBox(height: 12),

                          // ── Estado ─────────────────────────────────────────
                          _etiquetaCampo('ESTADO DEL PROYECTO'),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: estadoEditable,
                            dropdownColor: AppColores.bgCard,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF23253A),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
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
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(10),
                                child: imagenSegunEstado(estadoEditable),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Por iniciar',
                                child: Text('Por iniciar'),
                              ),
                              DropdownMenuItem(
                                value: 'En curso',
                                child: Text('En curso'),
                              ),
                              DropdownMenuItem(
                                value: 'Pausado',
                                child: Text('Pausado'),
                              ),
                              DropdownMenuItem(
                                value: 'Finalizado',
                                child: Text('Finalizado'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null)
                                setStateLocal(() => estadoEditable = v);
                            },
                          ),
                          const SizedBox(height: 16),

                          // ── Estadísticas ────────────────────────────────────
                          FutureBuilder<Map<String, int>>(
                            future: _obtenerEstadisticas(projectId),
                            builder: (context, statsSnapshot) {
                              if (statsSnapshot.connectionState ==
                                  ConnectionState.waiting) {
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
                              if (statsSnapshot.hasError) {
                                return const Text(
                                  'No se pudieron cargar las estadísticas.',
                                  style: TextStyle(
                                    color: AppColores.textMuted,
                                    fontSize: 12,
                                  ),
                                );
                              }
                              final stats = statsSnapshot.data!;
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
                                  Row(
                                    children: [
                                      StatChip(
                                        label: 'Totales',
                                        valor: stats['total'].toString(),
                                        icono: Icons.list_alt_rounded,
                                        color: AppColores.orangePrimary,
                                      ),
                                      const SizedBox(width: 8),
                                      StatChip(
                                        label: 'Completadas',
                                        valor: stats['completadas'].toString(),
                                        icono:
                                            Icons.check_circle_outline_rounded,
                                        color: const Color(0xFF48D136),
                                      ),
                                      const SizedBox(width: 8),
                                      StatChip(
                                        label: 'Pendientes',
                                        valor: stats['pendientes'].toString(),
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

                          const SizedBox(height: 8),
                          const Divider(color: AppColores.borderColor),
                          const SizedBox(height: 8),

                          // ── Guardar cambios ────────────────────────────────
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColores.orangePrimary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
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

                          // ── BOTÓN MIEMBROS ─────────────────────────────────
                          // [FASE 2] Nuevo botón que abre el diálogo de gestión
                          // de miembros del proyecto.
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColores.orangeLight,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: const BorderSide(
                                  color: AppColores.orangePrimary,
                                  width: 1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(
                                Icons.people_alt_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Gestionar miembros',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              onPressed: () {
                                // Abrimos el diálogo de miembros desde el contexto del diálogo actual.
                                // Usamos infoContext para que Navigator.pop funcione correctamente.
                                mostrarDialogoMiembros(
                                  ctx: infoContext,
                                  projectId: projectId,
                                  projectName: projectName,
                                  onMostrarSnackbar: onMostrarSnackbar,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),

                          // ── Eliminar proyecto ──────────────────────────────
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFFF6B6B),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
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
                              onPressed: () =>
                                  mostrarConfirmacionBorradoProyecto(
                                    parentContext: infoContext,
                                    projectName: projectName,
                                    projectId: projectId,
                                    onEliminar: onEliminar,
                                    onMostrarSnackbar: onMostrarSnackbar,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),

                  // ── Botón cerrar fijo fuera del scroll ─────────────────────
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

// ════════════════════════════════════════════════════════════════════════════════
// DIÁLOGO DE GESTIÓN DE MIEMBROS
// ════════════════════════════════════════════════════════════════════════════════
// [FASE 2 — Objetivo 1] Muestra la lista de miembros actuales del proyecto
// y permite al owner/admin invitar nuevos miembros por username exacto,
// cambiar roles y expulsar miembros.
//
// SEGURIDAD VISUAL:
//   • Si el usuario actual es 'user' o 'viewer', solo ve la lista.
//   • Si es 'owner' o 'admin', ve además el campo de invitación y los
//     controles de rol/expulsión en cada fila.

void mostrarDialogoMiembros({
  required BuildContext ctx,
  required String projectId,
  required String projectName,
  required void Function(String mensaje, {bool esError}) onMostrarSnackbar,
}) {
  // [FIX] Usamos _DialogoMiembrosContent (StatefulWidget) en lugar de StatefulBuilder.
  // Antes, el TextEditingController y el FocusNode se creaban dentro del builder
  // de showDialog, por lo que Flutter los destruía y reconstruía en cada rebuild
  // provocado por cambios de MediaQuery (ej. aparición del teclado en Android).
  // Con un StatefulWidget, initState() se ejecuta UNA SOLA VEZ y dispose() libera
  // los recursos al cerrar, garantizando que el foco nunca se pierda.
  showDialog(
    context: ctx,
    builder: (context) => _DialogoMiembrosContent(
      projectId: projectId,
      projectName: projectName,
      onMostrarSnackbar: onMostrarSnackbar,
    ),
  );
}

// ── WIDGET INTERNO DEL DIÁLOGO DE MIEMBROS ───────────────────────────────────
// Extraído de mostrarDialogoMiembros para que el TextEditingController y el
// FocusNode vivan en initState() y sobrevivan a los rebuilds de MediaQuery.
class _DialogoMiembrosContent extends StatefulWidget {
  final String projectId;
  final String projectName;
  final void Function(String mensaje, {bool esError}) onMostrarSnackbar;

  const _DialogoMiembrosContent({
    required this.projectId,
    required this.projectName,
    required this.onMostrarSnackbar,
  });

  @override
  State<_DialogoMiembrosContent> createState() =>
      _DialogoMiembrosContentState();
}

class _DialogoMiembrosContentState extends State<_DialogoMiembrosContent> {
  // Controller del campo de búsqueda de username
  late final TextEditingController _usernameCont;
  // FocusNode persistente: creado en initState y destruido en dispose.
  // Al vivir en el State, sobrevive a cualquier rebuild causado por cambios
  // en MediaQuery (como la aparición del teclado virtual en Android).
  late final FocusNode _usernameFocusNode;

  bool _buscando = false;

  // ── Future cacheado de miembros ──────────────────────────────────────────
  // CRÍTICO: guardamos el Future en el State para no recrearlo en cada build().
  // Si pasáramos _obtenerMiembros() directamente al parámetro future: del
  // FutureBuilder, Flutter crearía un nuevo objeto Future en cada rebuild
  // causado por MediaQuery (apertura del teclado), el FutureBuilder volvería
  // a 'waiting', desmontaría el TextField y el teclado se cerraría solo.
  late Future<List<Map<String, dynamic>>> _miembrosFuture;

  // Rol del usuario actual derivado del Future; se actualiza con
  // addPostFrameCallback para no llamar setState dentro del builder.
  // Controla si el TextField de invitación se muestra fuera del FutureBuilder,
  // garantizando que NUNCA se desmonte mientras la lista se recarga.
  bool _puedeGestionar = false;

  @override
  void initState() {
    super.initState();
    _usernameCont = TextEditingController();
    _usernameFocusNode = FocusNode();
    // Iniciamos la carga y registramos el callback para conocer el rol propio
    _miembrosFuture = _obtenerMiembros(widget.projectId);
    _miembrosFuture.then(_actualizarPuedeGestionar);
  }

  @override
  void dispose() {
    _usernameCont.dispose();
    _usernameFocusNode.dispose();
    super.dispose();
  }

  // ── Actualiza _puedeGestionar cuando el Future resuelve ─────────────────
  // Llamado en initState y tras cada recarga. Usa mounted para evitar
  // setState sobre un widget ya desmontado (ej. si el diálogo se cierra
  // mientras la consulta está en vuelo).
  void _actualizarPuedeGestionar(List<Map<String, dynamic>> miembros) {
    if (!mounted) return;
    final rolActual =
        miembros
            .where((m) => m['user_id'] == _currentUserId)
            .map((m) => m['role'] as String)
            .firstOrNull ??
        'user';
    setState(() => _puedeGestionar = rolActual == 'owner' || rolActual == 'admin');
  }

  // ── Recarga la lista de miembros ─────────────────────────────────────────
  // Crea un nuevo Future cacheado. El FutureBuilder muestra el spinner en la
  // lista durante la recarga, pero el TextField (renderizado FUERA del
  // FutureBuilder) permanece montado y con foco en todo momento.
  void _recargarMiembros() {
    final f = _obtenerMiembros(widget.projectId);
    f.then(_actualizarPuedeGestionar);
    setState(() => _miembrosFuture = f);
  }

  // ── Id del usuario actual ────────────────────────────────────────────────
  String get _currentUserId => supabase.auth.currentUser!.id;

  // ── Invitar por username exacto ──────────────────────────────────────────
  // Busca en profiles por username === input. Si existe y no está
  // en el proyecto, lo añade a project_members con rol 'user'.
  Future<void> _invitarMiembro() async {
    final username = _usernameCont.text.trim();
    if (username.isEmpty) {
      widget.onMostrarSnackbar('Escribe un username para buscar', esError: true);
      return;
    }

    setState(() => _buscando = true);

    try {
      // Paso 1: buscar el perfil por username exacto
      final perfiles = await supabase
          .from('profiles')
          .select('id, username, full_name, email')
          .eq('username', username);

      if (perfiles.isEmpty) {
        if (!mounted) return;
        setState(() => _buscando = false);
        widget.onMostrarSnackbar(
          'Usuario "$username" no encontrado',
          esError: true,
        );
        return;
      }

      final perfilInvitado = perfiles.first;
      final invitadoId = perfilInvitado['id'] as String;

      // No se puede invitar a uno mismo
      if (invitadoId == _currentUserId) {
        setState(() => _buscando = false);
        widget.onMostrarSnackbar(
          'No puedes invitarte a ti mismo',
          esError: true,
        );
        return;
      }

      // BUG 3 CORREGIDO: antes se consultaba project_members sin filtrar
      // por 'status', por lo que una invitación en 'pending' bloqueaba
      // cualquier reintento y, peor aún, un status NULL (por el upsert
      // del owner sin campo status) podría causar comportamientos inesperados.
      // Ahora consultamos el status explícitamente y diferenciamos los casos:
      //   • 'accepted' → el usuario ya es miembro activo, no tiene sentido reinvitar.
      //   • 'pending'  → ya tiene una invitación esperando, informamos sin crashear.
      //   • sin fila   → podemos invitar con total seguridad.
      // Paso 2: comprobar si ya existe alguna fila para este user en el proyecto
      final miembrosExistentes = await supabase
          .from('project_members')
          .select('user_id, status')
          .eq('project_id', widget.projectId)
          .eq('user_id', invitadoId);

      if (miembrosExistentes.isNotEmpty) {
        setState(() => _buscando = false);
        // Leemos el status actual para dar el mensaje adecuado
        final statusActual = miembrosExistentes.first['status'] as String?;
        if (statusActual == 'accepted') {
          // Miembro activo: no tiene sentido volver a invitar
          widget.onMostrarSnackbar(
            '${perfilInvitado['username']} ya es miembro activo del proyecto',
            esError: true,
          );
        } else {
          // Invitación pendiente: informamos para evitar confusión
          widget.onMostrarSnackbar(
            '${perfilInvitado['username']} ya tiene una invitación pendiente',
            esError: true,
          );
        }
        return;
      }

      // Paso 3: INSERT explícito con los 4 campos obligatorios.
      // Es imprescindible enviar 'status': 'pending' para que la invitación
      // aparezca en la pestaña "Proyectos Compartidos" del Usuario B.
      // Si no se envía este campo, la fila puede quedar con status=null
      // y la consulta que filtra por status='pending' no la devolvería nunca.
      await supabase.from('project_members').insert({
        'project_id': widget.projectId,
        'user_id': invitadoId,
        'role': 'user',
        'status': 'pending', // ← CRÍTICO: sin este campo la invitación es invisible
      });

      _usernameCont.clear();
      if (!mounted) return;
      setState(() => _buscando = false);
      _recargarMiembros();
      widget.onMostrarSnackbar(
        '✅ ${perfilInvitado["full_name"] ?? perfilInvitado["username"]} añadido al proyecto',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _buscando = false);
      widget.onMostrarSnackbar('Error al invitar: $e', esError: true);
    }
  }

  // ── Cambiar rol de un miembro ────────────────────────────────────────────
  // ── Cambiar rol de un miembro ────────────────────────────────────────────
  Future<void> _cambiarRol(String userId, String nuevoRol) async {
    try {
      await supabase
          .from('project_members')
          .update({'role': nuevoRol})
          .eq('project_id', widget.projectId)
          .eq('user_id', userId);
      _recargarMiembros();
      widget.onMostrarSnackbar('Rol actualizado correctamente');
    } catch (e) {
      widget.onMostrarSnackbar('Error al cambiar rol: $e', esError: true);
    }
  }

  // ── Transferir propiedad ─────────────────────────────────────────────────
  // Solo el owner puede hacerlo. Hace dos operaciones:
  //   1. El destinatario pasa a ser 'owner'
  //   2. El actual owner pasa a ser 'admin'
  // Así nunca hay un proyecto sin propietario.
  Future<void> _transferirPropiedad(String nuevoOwnerId, String nombre) async {
    try {
      // Paso 1: el destinatario se convierte en owner
      await supabase
          .from('project_members')
          .update({'role': 'owner'})
          .eq('project_id', widget.projectId)
          .eq('user_id', nuevoOwnerId);

      // Paso 2: el owner actual pasa a admin
      await supabase
          .from('project_members')
          .update({'role': 'admin'})
          .eq('project_id', widget.projectId)
          .eq('user_id', _currentUserId);

      _recargarMiembros();
      widget.onMostrarSnackbar('✅ Propiedad transferida a $nombre');
    } catch (e) {
      widget.onMostrarSnackbar(
        'Error al transferir propiedad: $e',
        esError: true,
      );
    }
  }

  // ── Expulsar miembro ─────────────────────────────────────────────────────
  Future<void> _expulsarMiembro(String userId, String nombre) async {
    try {
      await supabase
          .from('project_members')
          .delete()
          .eq('project_id', widget.projectId)
          .eq('user_id', userId);
      _recargarMiembros();
      widget.onMostrarSnackbar('$nombre ha sido eliminado del proyecto');
    } catch (e) {
      widget.onMostrarSnackbar('Error al expulsar miembro: $e', esError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // [FIX Bug 1] Patrón AlertDialog a prueba de balas para TextField + listas:
    //   AlertDialog (insetPadding fijo) → content: SizedBox(maxFinite) →
    //   SingleChildScrollView → Column(min) → ListView(shrinkWrap + NeverScroll).
    // AlertDialog gestiona automáticamente el espacio del teclado; SizedBox
    // evita que el diálogo se encoja a lo ancho; la Column hace shrink-wrap;
    // ListView con NeverScrollableScrollPhysics no pelea con el scroll padre.
    return AlertDialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: AppColores.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColores.borderColor),
      ),
      // Manejamos el padding manualmente dentro del content para preservar
      // el diseño original (cabecera con icono + divider + contenido + botón).
      titlePadding: EdgeInsets.zero,
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        // double.maxFinite evita que el AlertDialog encoja el ancho al mínimo
        width: double.maxFinite,
        child: SingleChildScrollView(
          // Padding inferior: garantiza que el teclado nunca tape el TextField
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Cabecera ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Column(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          AppColores.orangePrimary,
                          AppColores.orangeLight,
                        ],
                      ).createShader(bounds),
                      child: const Icon(
                        Icons.people_alt_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Miembros del proyecto',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.projectName,
                      style: const TextStyle(
                        color: AppColores.orangeLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: AppColores.borderColor, height: 1),

              // ── Contenido: lista + campo de invitación ───────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Lista de miembros (FutureBuilder cacheado) ────
                    // _miembrosFuture vive en el State: no se recrea en cada
                    // build() causado por MediaQuery (apertura del teclado).
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _miembrosFuture,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: CircularProgressIndicator(
                                color: AppColores.orangePrimary,
                                strokeWidth: 2.5,
                              ),
                            ),
                          );
                        }

                        if (snap.hasError) {
                          return Text(
                            'Error cargando miembros: ${snap.error}',
                            style: const TextStyle(
                              color: AppColores.textMuted,
                              fontSize: 13,
                            ),
                          );
                        }

                        final miembros = snap.data ?? [];
                        final rolActual =
                            miembros
                                .where((m) => m['user_id'] == _currentUserId)
                                .map((m) => m['role'] as String)
                                .firstOrNull ??
                            'user';
                        final puedeGestionar =
                            rolActual == 'owner' || rolActual == 'admin';

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Contador de miembros
                            Row(
                              children: [
                                const Text(
                                  'MIEMBROS ACTUALES',
                                  style: TextStyle(
                                    color: AppColores.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColores.orangePrimary
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${miembros.length}',
                                    style: const TextStyle(
                                      color: AppColores.orangeLight,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // ── Lista de filas ──────────────────────
                            // ListView con shrinkWrap + NeverScrollableScrollPhysics
                            // para que no pelee con el SingleChildScrollView padre
                            // ni cause huecos gigantes en el diálogo.
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: miembros.length,
                              itemBuilder: (context, i) {
                                final miembro = miembros[i];
                                final uid = miembro['user_id'] as String;
                                final rol = miembro['role'] as String;
                                final perfil =
                                    miembro['perfil']
                                        as Map<String, dynamic>?;
                                final nombre =
                                    perfil?['full_name'] as String? ??
                                    perfil?['username'] as String? ??
                                    'Usuario desconocido';
                                final username =
                                    perfil?['username'] as String? ?? '';
                                final esYo = uid == _currentUserId;
                                final esOwner = rol == 'owner';
                                final estado =
                                    miembro['status'] as String? ?? 'accepted';
                                final esPendiente = estado == 'pending';
                                // Los pendientes no pueden gestionar ni ser gestionados
                                return _FilaMiembro(
                                  nombre: nombre,
                                  username: username,
                                  rol: rol,
                                  esYo: esYo,
                                  esOwner: esOwner,
                                  esPendiente: esPendiente,
                                  puedeGestionar:
                                      puedeGestionar &&
                                      !esYo &&
                                      !esOwner &&
                                      !esPendiente,
                                  puedeTransferir:
                                      rolActual == 'owner' &&
                                      !esYo &&
                                      !esOwner &&
                                      !esPendiente,
                                  onCambiarRol: (nuevoRol) =>
                                      _cambiarRol(uid, nuevoRol),
                                  onExpulsar: () =>
                                      _expulsarMiembro(uid, nombre),
                                  onTransferirPropiedad: () =>
                                      _transferirPropiedad(uid, nombre),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),

                    // ── Campo de invitación (FUERA del FutureBuilder) ──
                    // CRÍTICO: siempre montado gracias a _puedeGestionar (State).
                    // Si estuviera dentro del builder, cada recarga (→ waiting)
                    // lo desmontaría → foco perdido → teclado cerrado.
                    if (_puedeGestionar) ...[
                      const SizedBox(height: 16),
                      const Divider(color: AppColores.borderColor),
                      const SizedBox(height: 12),
                      const Text(
                        'INVITAR MIEMBRO',
                        style: TextStyle(
                          color: AppColores.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _usernameCont,
                              // _usernameFocusNode vive en initState/dispose:
                              // sobrevive a cualquier rebuild de MediaQuery.
                              focusNode: _usernameFocusNode,
                              // Auto-scroll al ganar foco: deja 120px libres
                              // bajo el campo para que el teclado no lo tape.
                              scrollPadding: const EdgeInsets.only(bottom: 120),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _invitarMiembro(),
                              decoration: InputDecoration(
                                hintText: 'Username exacto del usuario',
                                hintStyle: const TextStyle(
                                  color: AppColores.textMuted,
                                  fontSize: 13,
                                ),
                                prefixIcon: const Icon(
                                  Icons.alternate_email_rounded,
                                  color: AppColores.textMuted,
                                  size: 18,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF23253A),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
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
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Botón de invitar con spinner mientras busca
                          SizedBox(
                            height: 44,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColores.orangePrimary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                              ),
                              onPressed: _buscando ? null : _invitarMiembro,
                              child: _buscando
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person_add_rounded,
                                      size: 20,
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'El usuario debe estar registrado en ProTask.',
                        style: TextStyle(
                          color: AppColores.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),

              // ── Botón Cerrar ─────────────────────────────────────────
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── QUERY: obtener miembros con perfil ────────────────────────────────────────
// Devuelve tanto los miembros aceptados como los pendientes, con su perfil.
// El status se pasa al widget _FilaMiembro para mostrarlo visualmente.
Future<List<Map<String, dynamic>>> _obtenerMiembros(String projectId) async {
  // Paso 1: obtenemos los miembros del proyecto (todos los status)
  final memberships = await supabase
      .from('project_members')
      .select('user_id, role, status')
      .eq('project_id', projectId)
      .order('joined_at', ascending: true);

  if (memberships.isEmpty) return [];

  // Paso 2: obtenemos los perfiles de esos usuarios en una sola consulta
  final userIds = memberships.map((m) => m['user_id'] as String).toList();
  final perfiles = await supabase
      .from('profiles')
      .select('id, username, full_name, email')
      .inFilter('id', userIds);

  // Construimos el mapa id → perfil para hacer el join en cliente
  final perfilMap = <String, Map<String, dynamic>>{
    for (final p in perfiles) p['id'] as String: p,
  };

  // Paso 3: unimos los datos
  // Paso 3: unimos incluyendo el status para mostrarlo en la UI
  return memberships.map((m) {
    return {
      'user_id': m['user_id'],
      'role': m['role'],
      'status':
          m['status'] ?? 'accepted', // incluimos el status de la invitación
      'perfil': perfilMap[m['user_id'] as String],
    };
  }).toList();
}

// ── WIDGET: FILA DE MIEMBRO ────────────────────────────────────────────────────
// Widget privado que representa una fila en la lista de miembros.
// Muestra el nombre, username, rol actual y (si puedeGestionar) botones de
// cambio de rol y expulsión.
class _FilaMiembro extends StatelessWidget {
  final String nombre;
  final String username;
  final String rol;
  final bool esYo;
  final bool esOwner;
  final bool puedeGestionar; // owner/admin puede gestionar roles y expulsar
  final bool puedeTransferir; // solo el owner puede transferir la propiedad
  final bool esPendiente; // true si la invitación aún no fue aceptada
  final void Function(String nuevoRol) onCambiarRol;
  final VoidCallback onExpulsar;
  final VoidCallback onTransferirPropiedad;

  const _FilaMiembro({
    required this.nombre,
    required this.username,
    required this.rol,
    required this.esYo,
    required this.esOwner,
    required this.puedeGestionar,
    required this.puedeTransferir,
    required this.esPendiente,
    required this.onCambiarRol,
    required this.onExpulsar,
    required this.onTransferirPropiedad,
  });

  // Devuelve el color del badge según el rol
  Color _colorRol() {
    switch (rol) {
      case 'owner':
        return const Color(0xFFFFD43B);
      case 'admin':
        return AppColores.orangePrimary;
      default:
        return AppColores.borderColor;
    }
  }

  // Devuelve el texto del rol en español
  String _textoRol() {
    switch (rol) {
      case 'owner':
        return 'Propietario';
      case 'admin':
        return 'Admin';
      default:
        return 'Miembro';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: esYo
            ? AppColores.orangePrimary.withOpacity(0.08)
            : const Color(0xFF23253A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: esYo
              ? AppColores.orangePrimary.withOpacity(0.3)
              : AppColores.borderColor,
        ),
      ),
      child: Row(
        children: [
          // Avatar con inicial del nombre
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColores.orangePrimary.withOpacity(0.2),
            child: Text(
              nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AppColores.orangeLight,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Nombre y username
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (esYo) ...[
                      const SizedBox(width: 6),
                      const Text(
                        '(tú)',
                        style: TextStyle(
                          color: AppColores.orangeLight,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
                if (username.isNotEmpty)
                  Text(
                    '@$username',
                    style: const TextStyle(
                      color: AppColores.textMuted,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),

          // Badge de rol o badge "Pendiente" si la invitación no fue aceptada
          esPendiente
              ? Container(
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
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _colorRol().withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _colorRol().withOpacity(0.4)),
                  ),
                  child: Text(
                    _textoRol(),
                    style: TextStyle(
                      color: _colorRol(),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

          // Controles de gestión (solo si puedeGestionar)
          // Mostramos el menú si puede gestionar miembros O si puede transferir propiedad
          if (puedeGestionar || puedeTransferir) ...[
            const SizedBox(width: 4),
            // Menú de opciones del miembro
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                color: AppColores.textMuted,
                size: 18,
              ),
              color: AppColores.bgCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppColores.borderColor),
              ),
              tooltip: 'Opciones',
              onSelected: (valor) {
                if (valor == 'expulsar') {
                  onExpulsar();
                } else if (valor == 'transferir') {
                  onTransferirPropiedad();
                } else {
                  onCambiarRol(valor);
                }
              },
              itemBuilder: (context) => [
                // Cambio de rol a admin (si no lo es ya)
                if (puedeGestionar && rol != 'admin')
                  const PopupMenuItem(
                    value: 'admin',
                    child: Row(
                      children: [
                        Icon(
                          Icons.admin_panel_settings_rounded,
                          color: AppColores.orangePrimary,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Hacer admin',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                // Cambio de rol a miembro (si no lo es ya)
                if (puedeGestionar && rol != 'user')
                  const PopupMenuItem(
                    value: 'user',
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_rounded,
                          color: AppColores.textMuted,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Hacer miembro',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                // Transferir propiedad — solo visible para el owner actual
                if (puedeTransferir) ...[
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'transferir',
                    child: Row(
                      children: [
                        Icon(
                          Icons.workspace_premium_rounded,
                          color: Color(0xFFFFD43B),
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Transferir propiedad',
                          style: TextStyle(
                            color: Color(0xFFFFD43B),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const PopupMenuDivider(),
                // Expulsar del proyecto
                if (puedeGestionar)
                  const PopupMenuItem(
                    value: 'expulsar',
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_remove_rounded,
                          color: Color(0xFFFF6B6B),
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Expulsar',
                          style: TextStyle(
                            color: Color(0xFFFF6B6B),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── HELPERS DE ESTILO ─────────────────────────────────────────────────────────

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
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColores.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColores.orangePrimary, width: 2),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
