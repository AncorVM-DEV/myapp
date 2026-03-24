import 'package:flutter/material.dart';
import 'package:myapp/widgets/app_colores.dart';

// ── BARRA DE BÚSQUEDA REUTILIZABLE ───────────────────────────────────────────
// Este widget es un campo de texto estilizado con el diseño oscuro de la app.
// Se usa tanto en Tareas.dart como en proyectos.dart para buscar por nombre.
//
// Cómo funciona:
//   - El padre le pasa un TextEditingController.
//   - Cada vez que el usuario escribe, llamamos al callback onChanged.
//   - El padre filtra su lista local SIN volver a llamar a Supabase
//     (ahorramos peticiones y la respuesta es instantánea).
class BarraBusqueda extends StatelessWidget {
  // El controlador viene de fuera para que el padre pueda leerlo cuando quiera
  final TextEditingController controller;

  // Se llama en cada tecla pulsada para que el padre actualice su filtro
  final ValueChanged<String> onChanged;

  // Texto de ayuda que se ve cuando el campo está vacío
  final String placeholder;

  const BarraBusqueda({
    super.key,
    required this.controller,
    required this.onChanged,
    this.placeholder = 'Buscar...',
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      // Usamos el teclado de búsqueda del sistema para que el móvil muestre
      // el botón de "buscar" en el teclado en lugar del de "intro" normal
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: const TextStyle(color: AppColores.textMuted, fontSize: 14),
        // Icono de lupa a la izquierda
        prefixIcon: const Icon(Icons.search_rounded, color: AppColores.textMuted, size: 20),
        // Si hay texto, mostramos una X para borrarlo de un toque
        suffixIcon: controller.text.isNotEmpty
            ? MouseRegion(
                // En web el cursor cambia a "manita" al pasar por encima
                cursor: SystemMouseCursors.click,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppColores.textMuted,
                  tooltip: 'Limpiar búsqueda',
                  // Garantizamos una zona de toque de al menos 48x48 px (estándar móvil)
                  padding: const EdgeInsets.all(12),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF23253A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColores.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColores.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColores.orangePrimary, width: 2),
        ),
      ),
    );
  }
}
