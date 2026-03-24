import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // FileOptions, FileOptionsResponse
import 'package:myapp/main.dart' show supabase;
import 'package:myapp/widgets/app_colores.dart';

// ── [FASE 1B] SECCIÓN DE ARCHIVOS ADJUNTOS ───────────────────────────────────
// Widget que gestiona la subida, listado y visualización de adjuntos de una tarea.
//
// FLUJO COMPLETO:
//   1. Al montar el widget carga los adjuntos existentes desde la tabla
//      'attachments' filtrados por task_id.
//   2. Al pulsar "Adjuntar archivo" se abre el selector nativo del sistema
//      (file_picker) que permite elegir uno o varios archivos de cualquier tipo.
//   3. Cada archivo seleccionado se sube al bucket 'archivos_tareas' de
//      Supabase Storage con la ruta: {taskId}/{timestamp}_{filename}
//   4. Se obtiene la URL pública con getPublicUrl() y se inserta un registro
//      en la tabla 'attachments' con todos los campos requeridos.
//   5. La lista local se actualiza al instante (sin esperar reload).
//
// VISUALIZACIÓN:
//   - Imágenes → miniatura cuadrada que al tocar abre un visor de pantalla completa.
//   - Documentos → icono representativo del tipo de archivo + nombre + botón de abrir
//     que lanza la URL con url_launcher.
//
// PAQUETES NECESARIOS (añadir a pubspec.yaml):
//   file_picker: ^8.1.2
//   url_launcher: ^6.3.0
//
// CONFIGURACIÓN EXTRA EN ANDROID (android/app/src/main/AndroidManifest.xml):
//   <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
//   <!-- Dentro de <application>: -->
//   <queries>
//     <intent>
//       <action android:name="android.intent.action.VIEW" />
//       <data android:scheme="https" />
//     </intent>
//   </queries>
class SeccionAdjuntos extends StatefulWidget {
  final String taskId;

  const SeccionAdjuntos({super.key, required this.taskId});

  @override
  State<SeccionAdjuntos> createState() => _SeccionAdjuntosState();
}

class _SeccionAdjuntosState extends State<SeccionAdjuntos> {
  // Lista local de adjuntos: se rellena al inicio y se actualiza en tiempo real
  List<Map<String, dynamic>> _adjuntos = [];

  // true mientras se cargan los adjuntos por primera vez
  bool _cargandoInicial = true;

  // Controla el estado de la subida:
  //   null → no hay subida en curso
  //   String → nombre del archivo que se está subiendo
  String? _nombreSubiendo;

  // Índice del adjunto que se está subiendo (para el indicador de progreso inline)
  // Usamos una lista porque pueden subirse varios en secuencia
  final Set<String> _subiendo = {};

  @override
  void initState() {
    super.initState();
    _cargarAdjuntos();
  }

  // ── CARGA INICIAL DE ADJUNTOS ─────────────────────────────────────────────
  // Hacemos una consulta única (no stream) porque los adjuntos no cambian
  // en tiempo real por otros usuarios con la frecuencia de las subtareas.
  // Siempre podemos añadir un StreamSubscription aquí en el futuro si se necesita.
  Future<void> _cargarAdjuntos() async {
    try {
      final datos = await supabase
          .from('attachments')
          .select()
          .eq('task_id', widget.taskId)
          .order('created_at', ascending: true);

      if (!mounted) return;
      setState(() {
        _adjuntos = List<Map<String, dynamic>>.from(datos);
        _cargandoInicial = false;
      });
    } catch (e) {
      debugPrint('Error al cargar adjuntos: $e');
      if (mounted) setState(() => _cargandoInicial = false);
    }
  }

  // ── SELECCIÓN Y SUBIDA DE ARCHIVOS ────────────────────────────────────────
  // Abre el selector de archivos nativo y sube cada archivo seleccionado.
  // Permite selección múltiple: si el usuario elige 3 archivos, se suben
  // de uno en uno mostrando feedback de progreso para cada uno.
  Future<void> _adjuntarArchivos() async {
    // Abrimos el selector con allowMultiple:true y withData:true
    // withData:true es imprescindible en Flutter Web porque en web no hay
    // acceso al sistema de archivos por ruta, solo a los bytes en memoria.
    final resultado = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
      withData: true,
    );

    if (resultado == null || resultado.files.isEmpty) return;

    // Subimos los archivos de uno en uno para no saturar el ancho de banda
    for (final archivo in resultado.files) {
      await _subirArchivo(archivo);
    }
  }

  // ── LÓGICA DE SUBIDA DE UN ARCHIVO ───────────────────────────────────────
  Future<void> _subirArchivo(PlatformFile archivo) async {
    final bytes = archivo.bytes;
    final nombre = archivo.name;
    final extension = (archivo.extension ?? '').toLowerCase();

    // En web los bytes vienen en archivo.bytes; en móvil/escritorio pueden
    // venir en archivo.bytes si withData:true (que es lo que pedimos).
    // Si por alguna razón bytes es null avisamos y seguimos con el siguiente.
    if (bytes == null || bytes.isEmpty) {
      _mostrarError('No se pudieron leer los bytes de "$nombre".');
      return;
    }

    // Marcamos este archivo como "en subida" para mostrar el loader inline
    setState(() {
      _nombreSubiendo = nombre;
      _subiendo.add(nombre);
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('No hay sesión de usuario activa.');

      // Ruta en el bucket: taskId/timestamp_filename
      // El timestamp evita colisiones si el mismo archivo se sube dos veces
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = '${widget.taskId}/${timestamp}_$nombre';

      // 1. Subimos el archivo al bucket 'archivos_tareas'
      await supabase.storage
          .from('archivos_tareas')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: _mimeType(extension),
              upsert: false, // false: falla si ya existe (no sobreescribe)
            ),
          );

      // 2. Obtenemos la URL pública del archivo recién subido
      final publicUrl = supabase.storage
          .from('archivos_tareas')
          .getPublicUrl(storagePath);

      // 3. Insertamos el registro en la tabla 'attachments' con todos los campos
      final insertado = await supabase
          .from('attachments')
          .insert({
            'task_id': widget.taskId,
            'user_id': userId,
            'file_name': nombre,
            'file_url': publicUrl,
            'file_extension': extension, // columna nueva añadida en Fase 1B
          })
          .select() // Recuperamos el registro creado con su id y timestamps
          .single();

      // 4. Actualizamos la lista local al instante (sin reload)
      if (!mounted) return;
      setState(() {
        _adjuntos.add(Map<String, dynamic>.from(insertado));
        _subiendo.remove(nombre);
        _nombreSubiendo = _subiendo.isNotEmpty ? _subiendo.first : null;
      });
    } catch (e) {
      debugPrint('Error al subir "$nombre": $e');
      if (!mounted) return;
      setState(() {
        _subiendo.remove(nombre);
        _nombreSubiendo = _subiendo.isNotEmpty ? _subiendo.first : null;
      });
      _mostrarError(
        'Error al subir "$nombre". Comprueba tu conexión e inténtalo de nuevo.',
      );
    }
  }

  // ── ELIMINAR ADJUNTO ──────────────────────────────────────────────────────
  // Elimina el registro de la BD (el archivo en Storage lo borra la política
  // de la BD o se puede añadir limpieza manual aquí si se necesita).
  Future<void> _eliminarAdjunto(Map<String, dynamic> adjunto) async {
    final adjuntoId = adjunto['id'] as String;

    // Eliminación visual inmediata para respuesta instantánea
    setState(() => _adjuntos.removeWhere((a) => a['id'] == adjuntoId));

    try {
      await supabase.from('attachments').delete().eq('id', adjuntoId);
    } catch (e) {
      debugPrint('Error al eliminar adjunto: $e');
      // Si falla, recargamos para restaurar el estado real
      _cargarAdjuntos();
    }
  }

  // ── ABRIR ARCHIVO CON URL LAUNCHER ───────────────────────────────────────
  Future<void> _abrirUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _mostrarError(
        'No se pudo abrir el archivo. Cópialo y ábrelo manualmente.',
      );
    }
  }

  // ── VISOR DE IMAGEN A PANTALLA COMPLETA ───────────────────────────────────
  // Abre un diálogo negro con la imagen en su tamaño real.
  // El usuario puede cerrarlo tocando fuera o pulsando el botón de cerrar.
  void _mostrarImagenCompleta(String url, String nombre) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            // Imagen con zoom interactivo mediante InteractiveViewer
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, prog) {
                    if (prog == null) return child;
                    return const SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColores.orangePrimary,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColores.bgCard,
                    padding: const EdgeInsets.all(24),
                    child: const Text(
                      'No se pudo cargar la imagen',
                      style: TextStyle(color: AppColores.textMuted),
                    ),
                  ),
                ),
              ),
            ),
            // Botón de cerrar en la esquina superior derecha
            Padding(
              padding: const EdgeInsets.all(8),
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SNACKBAR DE ERROR ─────────────────────────────────────────────────────
  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: const Color(0xFFFF4757),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Estado de carga inicial ──────────────────────────────────────
        if (_cargandoInicial)
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
        // ── Lista de adjuntos ────────────────────────────────────────────
        else if (_adjuntos.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2030),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColores.borderColor.withOpacity(0.5),
              ),
            ),
            child: const Text(
              'Todavía no hay archivos adjuntos',
              style: TextStyle(color: AppColores.textMuted, fontSize: 12),
            ),
          )
        else
          Column(
            children: _adjuntos.map((adjunto) {
              final ext = (adjunto['file_extension'] as String? ?? '')
                  .toLowerCase();
              final nombre = adjunto['file_name'] as String? ?? 'archivo';
              final url = adjunto['file_url'] as String? ?? '';
              final esImagen = _esImagen(ext);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: esImagen
                    ? _TarjetaImagen(
                        nombre: nombre,
                        url: url,
                        onTap: () => _mostrarImagenCompleta(url, nombre),
                        onEliminar: () => _eliminarAdjunto(adjunto),
                      )
                    : _TarjetaDocumento(
                        nombre: nombre,
                        extension: ext,
                        onTap: () => _abrirUrl(url),
                        onEliminar: () => _eliminarAdjunto(adjunto),
                      ),
              );
            }).toList(),
          ),

        const SizedBox(height: 8),

        // ── Indicador de subida activa ───────────────────────────────────
        if (_nombreSubiendo != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColores.orangePrimary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColores.orangePrimary.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: AppColores.orangePrimary,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Subiendo "${_nombreSubiendo}"...',
                      style: const TextStyle(
                        color: AppColores.orangeLight,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Botón de adjuntar archivo ────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            // Deshabilitamos mientras hay una subida activa para evitar solapamientos
            onPressed: _nombreSubiendo != null ? null : _adjuntarArchivos,
            icon: const Icon(Icons.cloud_upload_outlined, size: 18),
            label: const Text('Adjuntar archivo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColores.orangeLight,
              disabledForegroundColor: AppColores.textMuted,
              side: BorderSide(
                color: _nombreSubiendo != null
                    ? AppColores.borderColor.withOpacity(0.5)
                    : AppColores.orangePrimary.withOpacity(0.5),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── TARJETA DE IMAGEN ─────────────────────────────────────────────────────────
// Muestra una miniatura cuadrada del archivo de imagen.
// Al tocarse abre el visor de pantalla completa.
class _TarjetaImagen extends StatelessWidget {
  final String nombre;
  final String url;
  final VoidCallback onTap;
  final VoidCallback onEliminar;

  const _TarjetaImagen({
    required this.nombre,
    required this.url,
    required this.onTap,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E2030),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColores.borderColor),
          ),
          child: Row(
            children: [
              // Miniatura cuadrada
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(7),
                  bottomLeft: Radius.circular(7),
                ),
                child: Image.network(
                  url,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, prog) {
                    if (prog == null) return child;
                    return Container(
                      width: 60,
                      height: 60,
                      color: AppColores.bgCard,
                      child: const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: AppColores.orangePrimary,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    width: 60,
                    height: 60,
                    color: AppColores.bgCard,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: AppColores.textMuted,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Nombre del archivo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Toca para ver',
                      style: TextStyle(
                        color: AppColores.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Botón de eliminar
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onEliminar,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: AppColores.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── TARJETA DE DOCUMENTO ──────────────────────────────────────────────────────
// Muestra un icono representativo del tipo de documento, el nombre y un botón
// para abrirlo con la app nativa del sistema mediante url_launcher.
class _TarjetaDocumento extends StatelessWidget {
  final String nombre;
  final String extension;
  final VoidCallback onTap;
  final VoidCallback onEliminar;

  const _TarjetaDocumento({
    required this.nombre,
    required this.extension,
    required this.onTap,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final icono = _iconoDocumento(extension);
    final color = _colorDocumento(extension);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2030),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColores.borderColor),
          ),
          child: Row(
            children: [
              // Icono del tipo de documento con fondo coloreado
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Icon(icono, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              // Nombre y tipo de archivo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      extension.toUpperCase().isNotEmpty
                          ? '${extension.toUpperCase()} · Toca para abrir'
                          : 'Toca para abrir',
                      style: const TextStyle(
                        color: AppColores.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Icono de abrir externo
              const Icon(
                Icons.open_in_new_rounded,
                size: 14,
                color: AppColores.textMuted,
              ),
              const SizedBox(width: 4),
              // Botón de eliminar
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onEliminar,
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: AppColores.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── HELPERS DE TIPO DE ARCHIVO ────────────────────────────────────────────────

// Extensiones que consideramos imágenes para mostrar miniatura
const _extensionesImagen = {
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
  'bmp',
  'svg',
  'tiff',
  'tif',
  'heic',
};

bool _esImagen(String ext) => _extensionesImagen.contains(ext);

// Devuelve el icono más representativo para cada extensión de documento
IconData _iconoDocumento(String ext) {
  switch (ext) {
    case 'pdf':
      return Icons.picture_as_pdf_rounded;
    case 'doc':
    case 'docx':
      return Icons.description_rounded;
    case 'xls':
    case 'xlsx':
    case 'csv':
      return Icons.table_chart_rounded;
    case 'ppt':
    case 'pptx':
      return Icons.slideshow_rounded;
    case 'zip':
    case 'rar':
    case '7z':
    case 'tar':
    case 'gz':
      return Icons.folder_zip_rounded;
    case 'mp4':
    case 'mov':
    case 'avi':
    case 'mkv':
      return Icons.videocam_rounded;
    case 'mp3':
    case 'wav':
    case 'aac':
    case 'ogg':
      return Icons.audio_file_rounded;
    case 'txt':
    case 'md':
      return Icons.text_snippet_rounded;
    case 'json':
    case 'xml':
    case 'dart':
    case 'js':
    case 'ts':
    case 'py':
    case 'html':
    case 'css':
      return Icons.code_rounded;
    default:
      return Icons.insert_drive_file_rounded;
  }
}

// Color de acento del icono según el tipo de archivo
Color _colorDocumento(String ext) {
  switch (ext) {
    case 'pdf':
      return const Color(0xFFFF4757); // Rojo PDF
    case 'doc':
    case 'docx':
      return const Color(0xFF2B82D9); // Azul Word
    case 'xls':
    case 'xlsx':
    case 'csv':
      return const Color(0xFF1FA463); // Verde Excel
    case 'ppt':
    case 'pptx':
      return const Color(
        0xFFE8622A,
      ); // Naranja PowerPoint (igual que AppColores)
    case 'zip':
    case 'rar':
    case '7z':
    case 'tar':
    case 'gz':
      return const Color(0xFFFFD43B); // Amarillo para comprimidos
    case 'mp4':
    case 'mov':
    case 'avi':
    case 'mkv':
      return const Color(0xFF9B59B6); // Morado para vídeo
    case 'mp3':
    case 'wav':
    case 'aac':
      return const Color(0xFF4FC3F7); // Azul claro para audio
    default:
      return AppColores.textMuted; // Gris neutro para el resto
  }
}

// Devuelve el MIME type a partir de la extensión para que Supabase Storage
// almacene el Content-Type correcto en el objeto. Cubre los tipos más comunes.
String _mimeType(String ext) {
  switch (ext) {
    // Imágenes
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'svg':
      return 'image/svg+xml';
    case 'bmp':
      return 'image/bmp';
    // Documentos
    case 'pdf':
      return 'application/pdf';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'xls':
      return 'application/vnd.ms-excel';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'ppt':
      return 'application/vnd.ms-powerpoint';
    case 'pptx':
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    case 'txt':
      return 'text/plain';
    case 'csv':
      return 'text/csv';
    case 'json':
      return 'application/json';
    case 'xml':
      return 'application/xml';
    case 'zip':
      return 'application/zip';
    case 'rar':
      return 'application/x-rar-compressed';
    // Vídeo / Audio
    case 'mp4':
      return 'video/mp4';
    case 'mp3':
      return 'audio/mpeg';
    case 'wav':
      return 'audio/wav';
    default:
      return 'application/octet-stream'; // Tipo genérico para todo lo demás
  }
}
