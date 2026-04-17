// ============================================================
// IMPLEMENTACIÓN NATIVA (Android, iOS, Windows, macOS, Linux)
// Este archivo se compila en todas las plataformas EXCEPTO Web.
// Usa dart:io y los paquetes nativos ya existentes en el proyecto
// para guardar el archivo según el tipo de dispositivo.
// ============================================================

import 'dart:io'; // API de sistema de archivos de Dart (NO disponible en web)
import 'dart:typed_data'; // Necesario para trabajar con bytes (Uint8List)

import 'package:flutter/foundation.dart'; // Para debugPrint y kIsWeb (aunque aquí nunca es web)
// ── REEMPLAZADO: image_gallery_saver → gal ───────────────────────────────────
// image_gallery_saver 2.0.3 usaba la API "Registrar" del embedding V1 de Flutter,
// que fue eliminada en versiones recientes del SDK y causaba el error
// "Unresolved reference 'Registrar'" al compilar.
// gal es su reemplazo moderno: usa el embedding V2, está activamente mantenido
// y gestiona los permisos de galería internamente en Android 10+ (API 29+),
// por lo que ya no necesitamos pedirlos manualmente en esos dispositivos.
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart'; // Obtiene la carpeta de Descargas en Windows/macOS/Linux

// Función universal que guarda el archivo en la ubicación correcta
// según si estamos en un móvil (galería) o en un escritorio (carpeta Descargas).
Future<void> descargarArchivo(Uint8List bytes, String nombreArchivo) async {
  // ── MÓVIL: Android e iOS ─────────────────────────────────────────────────
  if (Platform.isAndroid || Platform.isIOS) {
    // gal comprueba y solicita los permisos de galería él solo antes de guardar.
    // Si el usuario los deniega, lanza una excepción GalException que capturamos.
    try {
      // Guardamos los bytes directamente como imagen en la galería del dispositivo.
      // El parámetro 'album' es el nombre del álbum donde aparecerá en la galería.
      // CORRECCIÓN: la API de gal usa 'album:' en lugar de 'name:' para este parámetro.
      await Gal.putImageBytes(
        bytes,
        album: nombreArchivo.replaceAll('.png', ''),
      );
      debugPrint('Imagen guardada en la galería: $nombreArchivo');
    } catch (e) {
      // Si el usuario denegó el permiso o hubo cualquier otro problema, lo
      // registramos en consola sin crashear la app (mismo comportamiento que antes).
      debugPrint('Error al guardar en la galería: $e');
    }
    return; // Terminamos aquí para móvil, el resto del código es solo para escritorio
  }

  // ── ESCRITORIO: Windows, macOS y Linux ───────────────────────────────────
  // En escritorio no hay galería de fotos, así que buscamos la carpeta "Descargas"
  final directorioDescargas = await getDownloadsDirectory();

  if (directorioDescargas == null) {
    // Fallback: si no encontramos "Descargas", usamos la carpeta de documentos
    final directorioDocumentos = await getApplicationDocumentsDirectory();
    final archivo = File('${directorioDocumentos.path}/$nombreArchivo');
    await archivo.writeAsBytes(bytes);
    debugPrint('Archivo guardado en Documentos: ${archivo.path}');
    return;
  }

  // Construimos la ruta completa del archivo y lo escribimos en disco
  final archivo = File('${directorioDescargas.path}/$nombreArchivo');
  await archivo.writeAsBytes(bytes);
  debugPrint('Archivo guardado en Descargas: ${archivo.path}');
}
