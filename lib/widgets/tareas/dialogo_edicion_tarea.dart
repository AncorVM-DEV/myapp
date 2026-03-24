import 'package:flutter/material.dart';
import 'package:myapp/widgets/app_colores.dart';
import 'package:myapp/main.dart' show supabase;

// ── DIÁLOGO DE EDICIÓN DE NOMBRE, DESCRIPCIÓN Y FECHA LÍMITE ─────────────
// Permite al usuario cambiar el nombre, la descripción y la fecha límite de
// la tarea. Los cambios se guardan en Supabase en tiempo real.
// Ahora recibe también la fechaActual para pre-rellenar el selector de fecha.
void mostrarDialogoEdicionTarea({
  // El contexto del diálogo padre (el de info) para poder cerrarlo tras guardar
  required BuildContext parentCtx,
  required String taskId,
  required String nombreActual,
  required String descripcionActual,
  DateTime? fechaActual, // Puede ser null si la tarea no tenía fecha antes
  // Función para mostrar un snackbar desde el contexto raíz de la pantalla
  required void Function(String mensaje) onMostrarSnackbar,
}) {
  // Pre-rellenamos los controladores con los valores actuales para que el
  // usuario no tenga que escribir todo desde cero.
  final editNombreCont = TextEditingController(text: nombreActual);
  final editDescCont = TextEditingController(text: descripcionActual);

  showDialog(
    context: parentCtx,
    builder: (BuildContext editCtx) {
      // Guardamos la fecha seleccionada dentro del diálogo con StatefulBuilder
      // para que el selector de fecha se actualice visualmente al elegir una.
      DateTime? fechaEdicion = fechaActual;

      return StatefulBuilder(
        builder: (context, setStateEdit) {
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
                  'Editar tarea',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Campo para cambiar el nombre de la tarea
                    TextField(
                      controller: editNombreCont,
                      style: const TextStyle(color: Colors.white),
                      maxLength: 80,
                      decoration: InputDecoration(
                        labelText: 'Nombre de la tarea',
                        labelStyle: const TextStyle(color: AppColores.textMuted),
                        counterStyle: const TextStyle(color: AppColores.textMuted),
                        filled: true,
                        fillColor: const Color(0xFF23253A),
                        prefixIcon: const Icon(
                          Icons.task_alt_rounded,
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
                    // Campo para cambiar la descripción con soporte multilinea
                    TextField(
                      controller: editDescCont,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      maxLength: 300,
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
                    const SizedBox(height: 12),

                    // ── SELECTOR DE FECHA LÍMITE (EDICIÓN) ───────────────
                    // El usuario puede cambiar o añadir una fecha límite desde aquí.
                    // Si ya tenía una, la mostramos pre-seleccionada para que solo
                    // tenga que ajustar lo que quiere cambiar.
                    InkWell(
                      onTap: () async {
                        // Abrimos el selector de fecha nativo de Flutter.
                        // El locale 'es' viene del MaterialApp, así que el
                        // calendario ya saldrá en español automáticamente.
                        final DateTime? fechaPicked = await showDatePicker(
                          context: context,
                          // Si ya había fecha la usamos como punto de partida; si no, hoy + 7
                          initialDate:
                              fechaEdicion ??
                              DateTime.now().add(const Duration(days: 7)),
                          // No se puede elegir una fecha anterior a hoy
                          firstDate: DateTime.now(),
                          // Como máximo un año desde hoy
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                          builder: (context, child) {
                            // Aplicamos nuestro tema oscuro al selector de fecha
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: AppColores.orangePrimary,
                                  surface: AppColores.bgCard,
                                  onSurface: Colors.white,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );

                        // Si el usuario eligió una fecha (no canceló) la guardamos
                        if (fechaPicked != null) {
                          setStateEdit(() {
                            fechaEdicion = fechaPicked;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF23253A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: fechaEdicion != null
                                ? AppColores.orangePrimary
                                : AppColores.borderColor,
                            width: fechaEdicion != null ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              color: fechaEdicion != null
                                  ? AppColores.orangePrimary
                                  : AppColores.textMuted,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                fechaEdicion != null
                                    ? 'Fecha límite: ${fechaEdicion!.day}/${fechaEdicion!.month}/${fechaEdicion!.year}'
                                    : 'Sin fecha límite (toca para añadir)',
                                style: TextStyle(
                                  color: fechaEdicion != null
                                      ? Colors.white
                                      : AppColores.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            // Si hay fecha mostramos un botón para quitarla
                            if (fechaEdicion != null)
                              GestureDetector(
                                onTap: () {
                                  setStateEdit(() {
                                    fechaEdicion = null;
                                  });
                                },
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: AppColores.textMuted,
                                  size: 18,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // Liberamos los controladores temporales antes de salir
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
                  final nuevoNombre = editNombreCont.text.trim();
                  final nuevaDesc = editDescCont.text.trim();

                  if (nuevoNombre.isEmpty || nuevaDesc.isEmpty) {
                    onMostrarSnackbar(
                      'El nombre y la descripción no pueden estar vacíos.',
                    );
                    return;
                  }

                  // --- MIGRACIÓN A SUPABASE ---
                  // Actualizamos los campos editables en la tabla 'tasks'.
                  // El nombre ahora es 'title' y la fecha se guarda como ISO 8601.
                  // Si el usuario quitó la fecha, enviamos null para que se borre en la BD.
                  await supabase.from('tasks').update({
                    'title': nuevoNombre,
                    'description': nuevaDesc,
                    // Convertimos la fecha a ISO 8601 o mandamos null si se eliminó
                    'due_date': fechaEdicion?.toIso8601String(),
                  }).eq('id', taskId);

                  // Liberamos los controladores temporales
                  editNombreCont.dispose();
                  editDescCont.dispose();

                  // Cerramos el diálogo de edición y el de información para
                  // que el usuario vea los cambios reflejados en la lista.
                  Navigator.pop(editCtx);
                  Navigator.pop(parentCtx);

                  onMostrarSnackbar('Tarea actualizada correctamente.');
                },
              ),
            ],
          );
        },
      );
    },
  );
}
