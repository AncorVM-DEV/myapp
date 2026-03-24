// ============================================================
// IMPLEMENTACIÓN WEB de la descarga de archivos.
// Este archivo SOLO se compila cuando la plataforma es Web.
// Usa dart:html que es la API nativa del navegador para crear
// un enlace temporal y forzar la descarga del archivo PNG.
// ============================================================

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html; // Librería exclusiva de web: maneja el DOM del navegador
import 'dart:typed_data'; // Necesario para trabajar con bytes (Uint8List)

// Función que descarga el archivo en el navegador web.
// Recibe los bytes de la imagen y el nombre con el que se guardará.
Future<void> descargarArchivo(Uint8List bytes, String nombreArchivo) async {
  // Convertimos los bytes en un "Blob" (objeto binario que entiende el navegador)
  final blob = html.Blob([bytes]);

  // Creamos una URL temporal en memoria que apunta a ese Blob
  final url = html.Url.createObjectUrlFromBlob(blob);

  // Creamos un enlace <a> invisible con el atributo "download" para forzar la descarga
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', nombreArchivo) // Nombre del archivo al guardar
    ..click(); // Simulamos un clic para disparar la descarga

  // Eliminamos la URL temporal de memoria para no generar fugas de memoria
  html.Url.revokeObjectUrl(url);

  // Eliminamos el enlace del DOM (aunque en este caso nunca se añadió al body,
  // es buena práctica limpiarlo para que el GC pueda liberarlo)
  anchor.remove();
}
