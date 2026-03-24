import 'package:flutter/material.dart';
import 'package:myapp/widgets/app_colores.dart';
import 'package:myapp/widgets/proyectos/dialogo_info_proyecto.dart';
import 'package:myapp/Tareas.dart';
import 'package:myapp/main.dart' show supabase;

// ── TARJETA DE PROYECTO ───────────────────────────────────────────────────
// Extraemos la Card del ListView de proyectos.dart a su propio widget para
// que el archivo principal no crezca con toda la lógica visual de cada tarjeta.
class TarjetaProyecto extends StatelessWidget {
  // Datos del proyecto que vienen del stream de Supabase
  final Map<String, dynamic> data;
  // Nombre del usuario actual para navegar a la pantalla de Tareas
  final String nombreUsuario;
  // Función para eliminar el proyecto; viene de proyectos.dart donde está la lógica
  final Future<void> Function(String nombre, String id) onEliminar;
  // Función para mostrar snackbars desde el contexto raíz de proyectos.dart
  final void Function(String mensaje, {bool esError}) onMostrarSnackbar;

  const TarjetaProyecto({
    super.key,
    required this.data,
    required this.nombreUsuario,
    required this.onEliminar,
    required this.onMostrarSnackbar,
  });

  @override
  Widget build(BuildContext context) {
    // --- MIGRACIÓN A SUPABASE ---
    // Antes teníamos que llamar a proyecto.data() para obtener el mapa.
    // Ahora el stream ya nos devuelve directamente una lista de mapas.
    final projectId = data['id'] as String;

    return Card(
      color: AppColores.bgCard,
      elevation: 4,
      shadowColor: Colors.black45,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: AppColores.borderColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Fila superior: icono del proyecto + textos ────
            // Row con Expanded en el bloque de texto para garantizar
            // que el nombre y la descripción usen todo el ancho
            // disponible y no se compriman los íconos de la derecha.
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Imagen del proyecto con tamaño fijo
                Image.asset("media/proyecto.png", width: 40, height: 40),
                const SizedBox(width: 12),
                // Expanded: el bloque de texto ocupa todo el
                // espacio restante y overflow se maneja con el
                // maxLines + TextOverflow.ellipsis.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['name'] ?? 'Sin nombre',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${data['description'] ?? 'Sin descripción'} • ${data['estado'] ?? 'No definido'}",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColores.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Fila inferior: botones de acción con Wrap ─────
            // El Wrap distribuira los hijos en filas: si todos caben
            // en una sola línea (tablet/desktop), los muestra en
            // fila y si no caben (móvil), baja automáticamente los
            // que no quepan a la siguiente línea, sin overflow.
            Wrap(
              spacing: 4, // espacio horizontal entre botones
              runSpacing: 4, // espacio vertical entre filas de botones
              alignment: WrapAlignment.end,
              children: [
                // Botón de navegación a tareas del proyecto
                ElevatedButton(
                  onPressed: () {
                    // --- MIGRACIÓN A SUPABASE ---
                    // Ahora le pasamos el UUID del proyecto a Tareas
                    // para que la pantalla de Tareas pueda filtrar por él.
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Tareas(
                          projectId: projectId,
                          nombreProyecto: data['name'] ?? 'Sin nombre',
                          nombreUsuario: nombreUsuario,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColores.orangePrimary,
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(8),
                    elevation: 2,
                  ),
                  child: const Icon(Icons.arrow_circle_up),
                ),

                // Icono de estado actual del proyecto
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  child: imagenSegunEstado(data['estado'] ?? 'No definido'),
                ),

                // Menú desplegable para cambiar el estado
                PopupMenuButton<String>(
                  color: AppColores.bgCard,
                  iconColor: AppColores.textMuted,
                  onSelected: (String result) async {
                    // <--- 1. AÑADIR async
                    try {
                      // 2. AÑADIR await
                      await supabase
                          .from('projects')
                          .update({'estado': result})
                          .eq(
                            'id',
                            projectId,
                          ); // Usamos la variable projectId que definiste al principio del build

                      // Opcional: Mostrar feedback visual
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Estado actualizado')),
                        );
                      }
                    } catch (e) {
                      print('Error actualizando proyecto: $e');
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'Por iniciar',
                          child: Text(
                            'Por iniciar',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'En curso',
                          child: Text(
                            'En curso',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'Pausado',
                          child: Text(
                            'Pausado',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'Finalizado',
                          child: Text(
                            'Finalizado',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                ),
                IconButton(
                  icon: const Icon(Icons.info, color: AppColores.textMuted),
                  onPressed: () {
                    mostrarDialogoInfoProyecto(
                      ctx: context,
                      projectName: data['name'] ?? 'Sin nombre',
                      projectDescription:
                          data['description'] ?? 'Sin descripción',
                      projectEstado: data['estado'] ?? 'No definido',
                      projectId: projectId,
                      onEliminar: onEliminar,
                      onMostrarSnackbar: onMostrarSnackbar,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
