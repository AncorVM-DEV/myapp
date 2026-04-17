import 'package:flutter/material.dart';
import 'package:myapp/widgets/app_colores.dart';
import 'package:myapp/main.dart' show supabase;

// ── DIÁLOGO DE EDICIÓN DE NOMBRE Y DESCRIPCIÓN ───────────────────────────
// Abrimos un nuevo diálogo donde el usuario puede cambiar el nombre y la
// descripción del proyecto. Cuando guarda, actualizamos Supabase en tiempo real.
void mostrarDialogoEdicionProyecto({
  // El contexto del diálogo padre (el de info) para poder cerrarlo tras guardar
  required BuildContext parentCtx,
  required String projectId,
  required String nombreActual,
  required String descripcionActual,
  // Función para mostrar un snackbar desde el contexto raíz de la pantalla
  required void Function(String mensaje) onMostrarSnackbar,
}) {
  // Controladores pre-rellenados con los valores actuales para que el usuario
  // no tenga que escribir todo desde cero, solo modificar lo que quiere cambiar.
  final editNombreCont = TextEditingController(text: nombreActual);
  final editDescCont = TextEditingController(text: descripcionActual);

  showDialog(
    context: parentCtx,
    builder: (BuildContext editCtx) {
      return AlertDialog(
        backgroundColor: AppColores.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColores.borderColor),
        ),
        title: Row(
          children: const [
            Icon(Icons.edit_rounded, color: AppColores.orangePrimary, size: 22),
            SizedBox(width: 8),
            Text(
              'Editar proyecto',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          // Limitamos el ancho máximo del contenido del diálogo en pantallas grandes
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Campo para editar el nombre
              TextField(
                controller: editNombreCont,
                style: const TextStyle(color: Colors.white),
                maxLength: 60,
                decoration: InputDecoration(
                  labelText: 'Nombre del proyecto',
                  labelStyle: const TextStyle(color: AppColores.textMuted),
                  counterStyle: const TextStyle(color: AppColores.textMuted),
                  filled: true,
                  fillColor: const Color(0xFF23253A),
                  prefixIcon: const Icon(
                    Icons.folder_outlined,
                    color: AppColores.orangePrimary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColores.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColores.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColores.orangePrimary,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Campo para editar la descripción con soporte para múltiples líneas
              TextField(
                controller: editDescCont,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: 'Descripción',
                  labelStyle: const TextStyle(color: AppColores.textMuted),
                  counterStyle: const TextStyle(color: AppColores.textMuted),
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: const Color(0xFF23253A),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 44),
                    child: Icon(
                      Icons.notes_rounded,
                      color: AppColores.orangePrimary,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColores.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColores.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColores.orangePrimary,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Liberamos los controladores temporales antes de cerrar
              editNombreCont.dispose();
              editDescCont.dispose();
              Navigator.pop(editCtx);
            },
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColores.textMuted),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColores.orangePrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('Guardar'),
            onPressed: () async {
              // Comprobamos que los campos no estén vacíos antes de guardar
              final nuevoNombre = editNombreCont.text.trim();
              final nuevaDesc = editDescCont.text.trim();

              if (nuevoNombre.isEmpty || nuevaDesc.isEmpty) {
                onMostrarSnackbar(
                  'El nombre y la descripción no pueden estar vacíos.',
                );
                return;
              }

              // --- MIGRACIÓN A SUPABASE ---
              // Actualizamos el nombre y la descripción del proyecto en PostgreSQL.
              // Antes también había que hacer un batch update en Firestore para sincronizar
              // el campo 'padre' en todas las tareas. Con Supabase eso ya NO hace falta:
              // las tareas apuntan al proyecto por su UUID, que nunca cambia aunque
              // el nombre sí lo haga.
              await supabase
                  .from('projects')
                  .update({'name': nuevoNombre, 'description': nuevaDesc})
                  .eq('id', projectId);

              // Liberamos los controladores temporales
              editNombreCont.dispose();
              editDescCont.dispose();

              // Cerramos el diálogo de edición y el de información juntos para
              // que el usuario vea los cambios reflejados inmediatamente en la lista.
              Navigator.pop(editCtx);
              Navigator.pop(parentCtx);

              onMostrarSnackbar('Proyecto actualizado correctamente.');
            },
          ),
        ],
      );
    },
  );
}
