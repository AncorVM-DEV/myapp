/// Utilidades de sanitización de inputs centralizadas.
/// Aplica siempre ANTES de cualquier INSERT o UPDATE a Supabase para
/// prevenir inyecciones XSS, etiquetas HTML embebidas y datos basura.
///
/// Uso:
///   import 'package:myapp/utils/sanitizer.dart';
///   final nombre = Sanitizer.clean(controller.text);
class Sanitizer {
  Sanitizer._(); // Clase utilitaria: solo métodos estáticos, no instanciar

  /// Limpieza general para campos de texto libre (nombres, descripciones,
  /// comentarios, títulos). Elimina etiquetas HTML/script, patrones de
  /// inyección JS y colapsa espacios múltiples en uno solo.
  static String clean(String? input) {
    if (input == null) return '';
    String s = input.trim();
    // Eliminamos cualquier etiqueta HTML: <script>, <img onerror=...>, etc.
    s = s.replaceAll(RegExp(r'<[^>]*>'), '');
    // Bloqueamos intentos de inyección JavaScript en atributos o urls
    s = s.replaceAll(RegExp(r'javascript:', caseSensitive: false), '');
    // Eliminamos manejadores de eventos inline: onerror=, onclick=, etc.
    s = s.replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '');
    // Colapsamos secuencias de espacios/tabs/saltos en un espacio único
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  /// Limpieza estricta para usernames: permite solo letras (con acentos),
  /// dígitos, guión bajo y guión. Bloquea cualquier carácter especial.
  static String cleanUsername(String? input) {
    if (input == null) return '';
    return input
        .trim()
        .replaceAll(RegExp(r'[^\w\-áéíóúÁÉÍÓÚñÑüÜ]'), '');
  }

  /// Versión nullable de clean(): devuelve null si el resultado queda vacío.
  /// Usar en campos opcionales que admiten NULL en la base de datos
  /// (p.ej. descripción de tarea, fecha, campos opcionales de perfil).
  static String? cleanNullable(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    return clean(input);
  }
}
