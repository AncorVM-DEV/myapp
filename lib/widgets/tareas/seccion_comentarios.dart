import 'package:flutter/material.dart';
import 'package:myapp/main.dart' show supabase;
import 'package:myapp/widgets/app_colores.dart';

// ── SECCIÓN DE COMENTARIOS CONECTADA A SUPABASE ───────────────────────────────
// Este widget sustituye la maqueta de comentarios en dialogo_info_tarea.dart.
// Lista los comentarios de la tabla 'comments' en tiempo real y permite
// escribir y guardar uno nuevo. Respeta el diseño oscuro de la app.
class SeccionComentarios extends StatefulWidget {
  // El ID de la tarea padre para filtrar sus comentarios en Supabase
  final String taskId;

  const SeccionComentarios({super.key, required this.taskId});

  @override
  State<SeccionComentarios> createState() => _SeccionComentariosState();
}

class _SeccionComentariosState extends State<SeccionComentarios> {
  // Controlador del campo donde el usuario escribe su comentario
  final _comentarioCont = TextEditingController();

  // Para deshabilitar el botón enviar mientras se procesa la petición
  bool _enviando = false;

  @override
  void dispose() {
    _comentarioCont.dispose();
    super.dispose();
  }

  // Envía el comentario nuevo a Supabase
  Future<void> _enviarComentario() async {
    final texto = _comentarioCont.text.trim();
    if (texto.isEmpty) return;

    setState(() => _enviando = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await supabase.from('comments').insert({
        'task_id': widget.taskId,
        'user_id': userId,
        'content': texto,
      });

      // Limpiamos el campo tras enviar con éxito
      _comentarioCont.clear();
    } catch (e) {
      debugPrint('Error al enviar comentario: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      // Stream en tiempo real de los comentarios de esta tarea
      stream: supabase
          .from('comments')
          .stream(primaryKey: ['id'])
          .eq('task_id', widget.taskId),
      builder: (context, snapshot) {
        final comentarios = snapshot.data ?? [];

        // Ordenamos por fecha de creación (más antiguo primero, como un chat normal)
        final comentariosOrdenados = List<Map<String, dynamic>>.from(comentarios)
          ..sort((a, b) {
            final fechaA = DateTime.tryParse(a['created_at'] as String? ?? '');
            final fechaB = DateTime.tryParse(b['created_at'] as String? ?? '');
            if (fechaA == null || fechaB == null) return 0;
            return fechaA.compareTo(fechaB);
          });

        final userId = supabase.auth.currentUser?.id;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Estado de carga ────────────────────────────────────────────
            if (snapshot.connectionState == ConnectionState.waiting &&
                comentarios.isEmpty)
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

            // ── Sin comentarios ────────────────────────────────────────────
            else if (comentariosOrdenados.isEmpty)
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2030),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColores.borderColor.withOpacity(0.5),
                  ),
                ),
                child: const Center(
                  child: Text(
                    'Sin comentarios aún',
                    style: TextStyle(color: AppColores.textMuted, fontSize: 12),
                  ),
                ),
              )

            // ── Lista de comentarios ───────────────────────────────────────
            else
              // Limitamos la altura del área de chat a 200px y le ponemos scroll
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: comentariosOrdenados.length,
                  itemBuilder: (context, index) {
                    final comentario = comentariosOrdenados[index];
                    final esMio = comentario['user_id'] == userId;
                    final contenido = comentario['content'] as String? ?? '';
                    final fechaStr = comentario['created_at'] as String?;
                    final fecha = fechaStr != null ? DateTime.tryParse(fechaStr) : null;

                    return _BurbujaMensaje(
                      contenido: contenido,
                      esMio: esMio,
                      fecha: fecha,
                    );
                  },
                ),
              ),

            const SizedBox(height: 8),

            // ── Input de nuevo comentario ──────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _comentarioCont,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    maxLines: 3,
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: 'Escribe un comentario...',
                      hintStyle: const TextStyle(
                        color: AppColores.textMuted,
                        fontSize: 12,
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
                // Botón de envío con área táctil de 48x48 garantizada
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _enviando ? null : _enviarComentario,
                    child: Container(
                      // Mínimo 48x48 para el área de toque
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _enviando
                            ? AppColores.borderColor
                            : AppColores.orangePrimary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _enviando
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ── BURBUJA DE MENSAJE ────────────────────────────────────────────────────────
// Cada comentario se muestra como una burbuja de chat.
// Los comentarios del usuario actual aparecen a la derecha en naranja;
// los de otros usuarios, a la izquierda en gris oscuro.
class _BurbujaMensaje extends StatelessWidget {
  final String contenido;
  final bool esMio;
  final DateTime? fecha;

  const _BurbujaMensaje({
    required this.contenido,
    required this.esMio,
    this.fecha,
  });

  @override
  Widget build(BuildContext context) {
    // Formateamos la hora si tenemos fecha disponible
    final horaTexto = fecha != null
        ? '${fecha!.hour.toString().padLeft(2, '0')}:${fecha!.minute.toString().padLeft(2, '0')}'
        : '';

    return Align(
      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          // Mis mensajes en naranja suave; los ajenos en gris
          color: esMio
              ? AppColores.orangePrimary.withOpacity(0.2)
              : const Color(0xFF1E2030),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(esMio ? 12 : 2),
            bottomRight: Radius.circular(esMio ? 2 : 12),
          ),
          border: Border.all(
            color: esMio
                ? AppColores.orangePrimary.withOpacity(0.4)
                : AppColores.borderColor.withOpacity(0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              esMio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              contenido,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            if (horaTexto.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                horaTexto,
                style: const TextStyle(
                  color: AppColores.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
