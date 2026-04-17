// ── DRAWER COMPARTIDO DE LA APP ───────────────────────────────────────────────
// Drawer reutilizable.
//
// Importante con los imports: para no acabar con imports circulares, la navegación
// se inyecta desde fuera con callbacks (misProyectosBuilder y
// compartidosBuilder). Así el drawer no necesita importar Proyectos ni
// ProyectosCompartidos, solo pinta el menú y ya.
//
// Ejemplo de cómo se usa:
//   drawer: AppDrawer(
//     nombreUsuario: widget.nombreUsuario,
//     pantallaActual: PantallaProyectos.misProyectos,
//     misProyectosBuilder: () => Proyectos(nombreUsuario: widget.nombreUsuario),
//     compartidosBuilder: () => ProyectosCompartidos(nombreUsuario: widget.nombreUsuario),
//   ),

import 'package:flutter/material.dart';
import 'package:myapp/main.dart' show supabase;
import 'package:myapp/login.dart';
import 'package:myapp/widgets/app_colores.dart';
import 'package:myapp/perfil.dart';

// Enum para saber en qué pantalla está el usuario y resaltar el ítem activo
enum PantallaProyectos { misProyectos, compartidos }

class AppDrawer extends StatelessWidget {
  final String nombreUsuario;

  // Indica qué pantalla está activa (para resaltar el ítem correspondiente)
  final PantallaProyectos pantallaActual;

  // Builder de la pantalla "Tus proyectos" — se inyecta desde fuera
  final Widget Function() misProyectosBuilder;

  // Builder de la pantalla "Proyectos compartidos" — se inyecta desde fuera
  final Widget Function() compartidosBuilder;

  const AppDrawer({
    super.key,
    required this.nombreUsuario,
    required this.pantallaActual,
    required this.misProyectosBuilder,
    required this.compartidosBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColores.bgCard,
      child: Column(
        children: [
          // ── CABECERA ──────────────────────────────────────────────────────
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF232537), AppColores.bgCard],
              ),
              border: Border(
                bottom: BorderSide(color: AppColores.borderColor, width: 1),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('media/proyecto.png', height: 64, width: 64),
                const SizedBox(height: 12),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [AppColores.orangePrimary, AppColores.orangeLight],
                  ).createShader(bounds),
                  child: const Text(
                    'Pro Task',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  nombreUsuario,
                  style: const TextStyle(
                    color: AppColores.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── MI PERFIL ─────────────────────────────────────────────────────
          // El perfil es el primer ítem, siempre sin resaltar (no es
          // una pantalla de proyectos)
          _DrawerItem(
            icono: Icons.person_rounded,
            titulo: 'Mi perfil',
            activo: false,
            onTap: () {
              Navigator.pop(context); // Cierra el drawer antes de navegar
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PerfilPage(nombreUsuario: nombreUsuario),
                ),
              );
            },
          ),

          const SizedBox(height: 4),

          // ── TUS PROYECTOS (individuales) ───────────────────────────────────
          // Proyectos donde el usuario es el ÚNICO miembro.
          // Se resalta cuando pantallaActual == misProyectos.
          _DrawerItem(
            icono: Icons.home_rounded,
            titulo: 'Tus proyectos',
            activo: pantallaActual == PantallaProyectos.misProyectos,
            onTap: () {
              Navigator.pop(context); // Cierra el drawer

              // Evitamos navegar si ya estamos en esta pantalla
              if (pantallaActual == PantallaProyectos.misProyectos) return;

              // pushAndRemoveUntil en lugar de pushReplacement: evita el error
              // "Navigator has no active routes to replace" cuando Proyectos es
              // la pantalla raíz del stack (no hay nada previo que reemplazar).
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => misProyectosBuilder()),
                (route) => false,
              );
            },
          ),

          const SizedBox(height: 4),

          // ── PROYECTOS COMPARTIDOS (cooperativos) ───────────────────────────
          // Proyectos donde el usuario es miembro Y hay 2 o más miembros.
          // Antes se llamaba "Compartido contigo" → renombrado a "Proyectos compartidos"
          // Se resalta cuando pantallaActual == compartidos.
          _DrawerItem(
            icono: Icons.people_alt_rounded,
            titulo: 'Proyectos compartidos',
            activo: pantallaActual == PantallaProyectos.compartidos,
            onTap: () {
              Navigator.pop(context); // Cierra el drawer

              // Evitamos navegar si ya estamos en esta pantalla
              if (pantallaActual == PantallaProyectos.compartidos) return;

              // Misma razón que arriba: pushAndRemoveUntil limpia el stack
              // y pone la pantalla de compartidos como raíz.
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => compartidosBuilder()),
                (route) => false,
              );
            },
          ),

          // Empuja el botón de cerrar sesión hacia el fondo de la pantalla
          const Spacer(),

          // ── CERRAR SESIÓN ──────────────────────────────────────────────────
          // SafeArea(top: false) añade el padding correcto para la barra de
          // navegación del sistema en cualquier dispositivo sin afectar al margen superior.
          SafeArea(
            top: false,
            child: Column(
              children: [
                const Divider(
                  color: AppColores.borderColor,
                  indent: 16,
                  endIndent: 16,
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Color(0xFFFF6B6B)),
                  title: const Text(
                    'Cerrar sesión',
                    style: TextStyle(
                      color: Color(0xFFFF6B6B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  onTap: () async {
                    // Cerramos la sesión en Supabase (elimina el token guardado)
                    await supabase.auth.signOut();

                    // Limpiamos todo el stack de navegación y volvemos al Login
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MyHomePage(title: 'Página de inicio'),
                      ),
                      (Route<dynamic> route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── ÍTEM DEL DRAWER ───────────────────────────────────────────────────────────
// Widget privado para los ítems del menú lateral.
// Si 'activo' es true, aplica un fondo naranja sutil y pone el texto en negrita
// para indicar que es la pantalla que el usuario está viendo ahora mismo.
class _DrawerItem extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final bool activo;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icono,
    required this.titulo,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Margen horizontal para que el borde redondeado no toque los bordes del drawer
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListTile(
        leading: Icon(icono, color: AppColores.orangePrimary),
        title: Text(
          titulo,
          style: TextStyle(
            // Texto blanco y negrita cuando el ítem está activo
            color: activo ? Colors.white : const Color(0xFFCCCEDE),
            fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        // Fondo naranja muy tenue para resaltar el ítem activo
        tileColor: activo
            ? AppColores.orangePrimary.withOpacity(0.13)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          // Borde naranja fino solo en el ítem activo
          side: activo
              ? const BorderSide(color: AppColores.orangePrimary, width: 0.6)
              : BorderSide.none,
        ),
        onTap: onTap,
      ),
    );
  }
}
