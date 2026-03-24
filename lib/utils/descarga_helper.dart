// ============================================================
// PUNTO DE ENTRADA UNIVERSAL para la descarga de archivos.
//
// Este archivo usa "importaciones condicionales" de Dart:
// Flutter decide en tiempo de compilación qué archivo cargar:
//   • Si la plataforma tiene dart:html (es decir, es Web)  → carga descarga_web.dart
//   • En cualquier otra plataforma (Android/iOS/Windows…) → carga descarga_io.dart
//
// Gracias a esto, tablaTarea.dart solo importa ESTE archivo
// y funciona en todas las plataformas sin ningún condicional extra.
// ============================================================

// La sintaxis "if (dart.library.html)" es la forma oficial de Flutter
// para hacer importaciones que cambian según la plataforma de compilación.
export 'descarga_io.dart' if (dart.library.html) 'descarga_web.dart';
