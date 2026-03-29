import 'package:flutter/material.dart';
import 'package:myapp/widgets/app_colores.dart';

// ── DIÁLOGO DE CONFIRMACIÓN DE ELIMINACIÓN ────────────────────────────────
// Lo extraemos aquí para que proyectos.dart no cargue con ese bloque de código.
// Recibe callbacks en lugar de llamar directamente a métodos del padre,
// así este widget no depende de la pantalla que lo llama.
void mostrarConfirmacionBorradoProyecto({
  // El contexto del diálogo padre (el de info) para poder cerrarlo si el usuario confirma
  required BuildContext parentContext,
  required String projectName,
  required String projectId,
  // Función que ejecuta el borrado real en Supabase; viene del widget padre
  required Future<void> Function(String nombre, String id) onEliminar,
  // Función para mostrar un snackbar desde el contexto raíz de la pantalla
  required void Function(String mensaje, {bool esError}) onMostrarSnackbar,
}) {
  showDialog(
    context: parentContext,
    builder: (BuildContext confirmContext) {
      return AlertDialog(
        backgroundColor: AppColores.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColores.borderColor),
        ),
        // Icono de advertencia para reforzar la gravedad de la acción
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Color(0xFFFF6B6B),
          size: 40,
        ),
        title: const Text(
          '¿Estás seguro?',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Esta acción eliminará el proyecto "$projectName" y todas sus tareas asociadas. Esta operación no se puede deshacer.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColores.textMuted, fontSize: 13),
        ),
        actions: [
          // Cancelar — cierra solo este diálogo y vuelve al de info
          TextButton(
            onPressed: () => Navigator.pop(confirmContext),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColores.textMuted),
            ),
          ),
          // Eliminar definitivo — ejecuta la lógica de borrado
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Eliminar'),
            onPressed: () async {
              // Cerramos el diálogo de confirmación
              Navigator.pop(confirmContext);
              // Cerramos también el diálogo de información (el padre)
              Navigator.pop(parentContext);

              try {
                await onEliminar(projectName, projectId);
                // BUG 1 CORREGIDO: el mensaje decía "Tarea eliminada con exito."
                // pero esta función se usa exclusivamente para eliminar proyectos.
                // Se corrige el texto y se añade tilde en "éxito".
                onMostrarSnackbar('Proyecto eliminado con éxito.');
              } catch (e) {
                onMostrarSnackbar('Error al eliminar: $e', esError: true);
              }
            },
          ),
        ],
      );
    },
  );
}
