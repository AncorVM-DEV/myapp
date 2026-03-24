import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/login.dart';
import 'package:myapp/proyectos.dart';
import 'package:myapp/reset_password.dart'; // Pantalla para establecer la nueva contraseña
import 'package:myapp/main.dart' show supabase;

// ── PANTALLA DE SPLASH / CARGA INICIAL ───────────────────────────────────────
// Esta pantalla sustituye al FutureBuilder que estaba dentro de MyApp.
// Centraliza toda la lógica de arranque: verificar sesión, resolver a qué
// pantalla ir y, lo más importante, manejar los timeouts y errores de red
// de forma amigable para que el usuario nunca se quede con una pantalla en blanco.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // Mensaje que se muestra bajo el spinner; cambia según el estado
  String _mensaje = 'Verificando sesión...';

  // Controla si mostramos el spinner o la pantalla de error con reintento
  bool _hayError = false;

  // Evita que el botón "Reintentar" pueda pulsarse múltiples veces a la vez
  bool _cargando = false;

  // Controlador para la animación de pulso del logo
  late AnimationController _animController;
  late Animation<double> _animEscala;

  // Suscripción al stream de Auth de Supabase.
  // La guardamos aquí para poder cancelarla en dispose() y no dejar
  // un listener huérfano que intente actuar sobre un widget ya desmontado.
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();

    // Animación de pulso suave para el logo mientras carga (0.95 → 1.05 → 0.95...)
    // Le da vida a la pantalla sin distraer demasiado al usuario
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _animEscala = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    // ── LISTENER DE EVENTOS DE AUTENTICACIÓN ──────────────────────────────
    // Registramos el listener ANTES de llamar a _iniciarCarga() para que no
    // haya ninguna ventana de tiempo en la que el evento passwordRecovery
    // pueda dispararse sin que nadie lo esté escuchando.
    //
    // ¿Por qué no basta con comprobar currentSession en _iniciarCarga()?
    // Porque cuando el usuario llega desde el magic link del correo, Supabase
    // procesa el token del deep link y crea la sesión automáticamente. En ese
    // momento currentSession ya es no-null (hay sesión), así que el código
    // antiguo asumía que era un login normal y mandaba a Proyectos. El stream
    // es la única forma de saber que esa sesión es de tipo "recovery".
    _authSub = supabase.auth.onAuthStateChange.listen((AuthState data) {
      if (!mounted) return;

      if (data.event == AuthChangeEvent.passwordRecovery) {
        // Supabase emite passwordRecovery cuando el usuario abre la app a través
        // del enlace del correo de "Recuperar contraseña". En ese momento la sesión
        // temporal ya está activa, pero debemos llevarle a resetear su contraseña,
        // NO a la pantalla principal.
        //
        // Usamos addPostFrameCallback para que la navegación ocurra DESPUÉS de que
        // el frame actual termine de renderizarse. Sin esto, si el evento llega
        // durante el primer build (cold start desde el link), Flutter lanzará el
        // error "Cannot use context to find root of navigator" o "_dependents.isEmpty".
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          // Limpiamos toda la pila: el usuario no debe poder volver al Splash
          // pulsando atrás después de haber llegado por un magic link.
          Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const ResetPasswordPage(),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 350),
            ),
            (route) => false,
          );
        });
      }
    });

    // Arrancamos la verificación de sesión en cuanto el widget se monta
    _iniciarCarga();
  }

  @override
  void dispose() {
    // Liberamos el controlador de animación para no tener memory leaks
    _animController.dispose();
    // Cancelamos la suscripción al stream de Auth para que no lleguen
    // eventos sobre un widget que ya no está en el árbol de widgets
    _authSub?.cancel();
    super.dispose();
  }

  // ── FUNCIÓN PRINCIPAL DE CARGA ────────────────────────────────────────────
  // Aplica un timeout de 15 segundos a la resolución de sesión.
  // Si la conexión a Supabase tarda demasiado (red lenta, sin internet...),
  // en lugar de crashear o congelarse, mostramos feedback y la opción de reintentar.
  Future<void> _iniciarCarga() async {
    // Marcamos que estamos en proceso para deshabilitar el botón de reintento
    if (!mounted) return;
    setState(() {
      _hayError = false;
      _cargando = true;
      _mensaje = 'Verificando sesión...';
    });

    try {
      // Le damos 15 segundos a la resolución de sesión antes de rendirse
      final pantalla = await _resolverPantallaInicial().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          // Si se supera el timeout, lanzamos una excepción controlada
          // en lugar de dejar la pantalla congelada sin ningún feedback
          throw TimeoutException('La conexión tardó demasiado.');
        },
      );

      // ¡Todo bien! Navegamos a la pantalla destino reemplazando el splash
      // para que el usuario no pueda "volver" a la carga con el botón atrás.
      // addPostFrameCallback garantiza que la navegación ocurre después de que
      // el frame actual termine: evita el crash si el Future resuelve muy rápido
      // (por ejemplo, sesión ya en caché) durante el primer build del widget.
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => pantalla,
              // Transición suave de fade para que no haya un corte brusco
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
        });
      }
    } on TimeoutException {
      // Timeout: la app tardó más de 15 segundos
      // Mostramos un mensaje empático y el botón de reintento
      if (mounted) {
        setState(() {
          _hayError = true;
          _cargando = false;
          _mensaje =
              'Parece que la conexión va lenta.\n¿Tienes internet? Pulsa reintentar.';
        });
      }
    } catch (e) {
      // Cualquier otro error inesperado: Supabase caído, sin red, etc.
      // No mostramos el error técnico al usuario; solo un mensaje amable
      if (mounted) {
        setState(() {
          _hayError = true;
          _cargando = false;
          _mensaje =
              'No se pudo conectar al servidor.\nComprueba tu conexión a internet.';
        });
      }
    }
  }

  // ── RESOLUCIÓN DE PANTALLA INICIAL ───────────────────────────────────────
  // Esta es la misma lógica que antes vivía en MyApp._resolverPantallaInicial().
  // La movemos aquí para que el Splash sea el único responsable de decidir
  // a dónde va el usuario al abrir la app.
  Future<Widget> _resolverPantallaInicial() async {
    // Comprobamos si Supabase tiene una sesión guardada en el dispositivo
    final session = supabase.auth.currentSession;

    // Sin sesión activa → mostramos la pantalla de login de siempre
    if (session == null) return const MyHomePage(title: 'ProTask');

    // Con sesión → consultamos el nombre del usuario en la tabla 'profiles'
    // para pasárselo a Proyectos igual que hace el flujo normal de login
    final userId = session.user.id;
    final perfil = await supabase
        .from('profiles')
        .select('username')
        .eq('id', userId)
        .maybeSingle(); // Devuelve null si no hay perfil, en vez de lanzar error

    // Usamos el username si existe; si no, el email como fallback de emergencia
    final nombre =
        (perfil?['username'] as String?) ?? session.user.email ?? 'Usuario';

    // Devolvemos la pantalla de proyectos ya con el nombre cargado
    return Proyectos(nombreUsuario: nombre);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Mismo fondo oscuro de la app para que la transición sea imperceptible
      backgroundColor: const Color(0xFF2D3142),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── LOGO ANIMADO ──────────────────────────────────────────
                // El logo hace un pulso suave mientras espera la respuesta de Supabase
                ScaleTransition(
                  scale: _animEscala,
                  child: Image.asset(
                    'media/proyecto.png',
                    height: 110,
                    width: 110,
                  ),
                ),
                const SizedBox(height: 20),

                // ── NOMBRE DE LA APP ──────────────────────────────────────
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFE8622A), Color(0xFFF0944D)],
                  ).createShader(bounds),
                  child: const Text(
                    'Pro Task',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Gestión de proyectos profesional',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFFAAADBF),
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 56),

                // ── ÁREA DE ESTADO: spinner o error con reintento ─────────
                // Usamos AnimatedSwitcher para que el cambio entre estados
                // tenga una transición suave en vez de un salto brusco
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _hayError
                      ? _VistaError(
                          key: const ValueKey('error'),
                          mensaje: _mensaje,
                          cargando: _cargando,
                          onReintentar: _iniciarCarga,
                        )
                      : _VistaCargando(
                          key: const ValueKey('loading'),
                          mensaje: _mensaje,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── WIDGET: ESTADO DE CARGA ───────────────────────────────────────────────────
// Separamos este trozo visual en un widget privado para mantener el build()
// limpio y legible. Muestra el spinner y el mensaje de estado actual.
class _VistaCargando extends StatelessWidget {
  final String mensaje;

  const _VistaCargando({super.key, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const CircularProgressIndicator(
          color: Color(0xFFE8622A),
          strokeWidth: 3,
        ),
        const SizedBox(height: 20),
        Text(
          mensaje,
          style: const TextStyle(color: Color(0xFFAAADBF), fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── WIDGET: ESTADO DE ERROR ───────────────────────────────────────────────────
// Muestra el icono de sin conexión, el mensaje descriptivo y el botón de reintento.
// Lo mantenemos como widget separado para no contaminar el build() principal.
class _VistaError extends StatelessWidget {
  final String mensaje;
  final bool cargando;
  final VoidCallback onReintentar;

  const _VistaError({
    super.key,
    required this.mensaje,
    required this.cargando,
    required this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Icono de sin conexión con un color apagado para no alarmar demasiado
        const Icon(Icons.wifi_off_rounded, color: Color(0xFFAAADBF), size: 52),
        const SizedBox(height: 16),
        Text(
          mensaje,
          style: const TextStyle(color: Color(0xFFAAADBF), fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        // Botón de reintento que se deshabilita mientras está procesando
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE8622A),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF4A4E66),
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
          icon: cargando
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.refresh_rounded),
          label: Text(
            cargando ? 'Conectando...' : 'Reintentar',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          onPressed: cargando ? null : onReintentar,
        ),
      ],
    );
  }
}
