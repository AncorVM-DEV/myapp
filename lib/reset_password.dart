import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/main.dart' show supabase;
import 'package:myapp/login.dart';
import 'package:myapp/proyectos.dart';
import 'package:myapp/widgets/app_colores.dart';

// ── PANTALLA DE RESETEO DE CONTRASEÑA ────────────────────────────────────────
// Esta pantalla aparece ÚNICAMENTE cuando el usuario abrió la app a través
// del magic link que Supabase envía al pulsar "¿Olvidaste tu contraseña?".
// Supabase ya ha iniciado una sesión temporal para él; solo necesitamos que
// escriba su nueva contraseña y la confirmemos antes de guardarla.
//
// Tras guardar con éxito: cerramos la sesión temporal y redirigimos al login.
// Esto es buena práctica de seguridad: la sesión de recovery no debe persistir.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _nuevaPassController = TextEditingController();
  final _confirmarPassController = TextEditingController();

  // Controla el spinner dentro del botón mientras procesa la petición
  bool _guardando = false;

  // Controla si los campos muestran el texto en claro o enmascarado
  bool _verNueva = false;
  bool _verConfirmar = false;

  @override
  void dispose() {
    _nuevaPassController.dispose();
    _confirmarPassController.dispose();
    super.dispose();
  }

  // ── GUARDAR LA NUEVA CONTRASEÑA ───────────────────────────────────────────
  Future<void> _guardar() async {
    final nueva = _nuevaPassController.text.trim();
    final confirmar = _confirmarPassController.text.trim();

    // Validaciones locales antes de hacer ninguna llamada a la red
    if (nueva.isEmpty || confirmar.isEmpty) {
      _snack('Por favor, rellena ambos campos.');
      return;
    }
    if (nueva.length < 6) {
      _snack('La contraseña debe tener al menos 6 caracteres.');
      return;
    }
    if (nueva != confirmar) {
      _snack('Las contraseñas no coinciden. Revísalas.');
      return;
    }

    // ── COMPROBACIÓN DE SESIÓN ACTIVA ─────────────────────────────────────
    // Antes de llamar a Supabase verificamos que la sesión de recovery sigue
    // viva. Si el usuario tardó mucho en rellenar el formulario, o si cerró
    // y volvió a abrir la app, el token puede haber expirado ya.
    // Sin esta comprobación, updateUser lanza un error críptico que no
    // ayuda nada al usuario.
    final session = supabase.auth.currentSession;
    if (session == null) {
      _snack(
        'Tu sesión ha expirado. Vuelve al login, pulsa "¿Olvidaste tu contraseña?" y solicita un nuevo enlace.',
        duracion: 6,
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      // Actualizamos la contraseña en Supabase Auth.
      // La sesión temporal del magic link ya está activa, así que Supabase
      // sabe a qué usuario aplicar el cambio sin que se lo indiquemos.
      await supabase.auth.updateUser(UserAttributes(password: nueva));

      // ── NO cerramos la sesión aquí ────────────────────────────────────
      // El flujo anterior hacía signOut() y mandaba al login, pero eso
      // rompía el acceso si el email en Auth había cambiado de
      // "usuario@tfg.com" al correo real (algo que ocurre cuando se actualiza
      // el email desde la pantalla de Perfil): el login intentaba autenticar
      // con "usuario@tfg.com" pero esa dirección ya no existía en Auth.
      //
      // Solución: aprovechar que la sesión sigue activa tras updateUser,
      // consultar el username en profiles y navegar directamente a Proyectos.
      final userId = supabase.auth.currentUser?.id;
      String nombreUsuario = 'Usuario';

      if (userId != null) {
        // Buscamos el username en profiles igual que hace el splash al restaurar sesión
        final perfil = await supabase
            .from('profiles')
            .select('username')
            .eq('id', userId)
            .maybeSingle();
        nombreUsuario = (perfil?['username'] as String?) ?? nombreUsuario;
      }

      if (!mounted) return;

      _snack('✅ ¡Contraseña actualizada! Bienvenido de nuevo.', duracion: 3);

      // Navegamos a Proyectos limpiando toda la pila: el usuario no debe
      // poder volver a esta pantalla pulsando el botón atrás.
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => Proyectos(nombreUsuario: nombreUsuario),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
        (route) => false,
      );
    } on AuthException catch (e) {
      setState(() => _guardando = false);

      // ── TRADUCCIÓN DE ERRORES DE SUPABASE ──────────────────────────────
      // Cubrimos los casos más comunes en orden de probabilidad.
      // El último else muestra el mensaje original de Supabase para que, si
      // aparece algo inesperado, el usuario pueda reportarlo con precisión
      // en lugar de recibir un mensaje genérico que no dice nada.
      final msg = e.message.toLowerCase();
      if (msg.contains('expired') || msg.contains('session')) {
        _snack(
          'El enlace ha expirado. Solicita uno nuevo desde el login.',
          duracion: 5,
        );
      } else if (msg.contains('same password') ||
          msg.contains('different from') ||
          msg.contains('already been used')) {
        // Supabase rechaza si la nueva contraseña es igual a la anterior
        _snack(
          'La nueva contraseña debe ser diferente a la que tenías antes.',
          duracion: 4,
        );
      } else if (msg.contains('weak') || msg.contains('strength')) {
        _snack(
          'La contraseña es demasiado débil. Prueba con una combinación de letras y números.',
          duracion: 4,
        );
      } else {
        // Mostramos el error real de Supabase; es más útil que "inténtalo de nuevo"
        // porque permite identificar exactamente qué está fallando
        _snack('Supabase: ${e.message}', duracion: 7);
      }
    } catch (e) {
      setState(() => _guardando = false);
      // Igual aquí: mostramos el error real para poder diagnosticar
      _snack('Error inesperado: $e', duracion: 7);
    }
  }

  // Atajo para mostrar SnackBars sin repetir tanto código
  void _snack(String texto, {int duracion = 3}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        duration: Duration(seconds: duracion),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // PopScope bloquea el botón atrás del sistema para que el usuario
      // no salga accidentalmente dejando la sesión de recovery activa.
      body: PopScope(
        canPop: false,
        onPopInvoked: (_) => _mostrarDialogoSalir(),
        child: Container(
          // Mismo gradiente que el login para que la pantalla sea consistente
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF232537), Color(0xFF2D3142)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 32.0,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── LOGO ─────────────────────────────────────────────
                      Image.asset('media/proyecto.png', height: 90, width: 90),
                      const SizedBox(height: 16),

                      // ── NOMBRE APP ────────────────────────────────────────
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFE8622A), Color(0xFFF0944D)],
                        ).createShader(bounds),
                        child: const Text(
                          'Pro Task',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Establece tu nueva contraseña',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColores.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 36),

                      // ── CARD ──────────────────────────────────────────────
                      Card(
                        color: AppColores.bgCard,
                        elevation: 12,
                        shadowColor: Colors.black54,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(
                            color: AppColores.borderColor,
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(28.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Título e icono de la sección
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.lock_reset,
                                    color: AppColores.orangePrimary,
                                    size: 26,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Nueva contraseña',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Elige una contraseña segura (mínimo 6 caracteres).',
                                style: TextStyle(
                                  color: AppColores.textMuted,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),

                              // ── CAMPO NUEVA CONTRASEÑA ────────────────────
                              TextField(
                                controller: _nuevaPassController,
                                obscureText: !_verNueva,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Nueva contraseña',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _verNueva
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AppColores.textMuted,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        setState(() => _verNueva = !_verNueva),
                                  ),
                                  helperText: 'Mínimo 6 caracteres',
                                  helperStyle: const TextStyle(
                                    color: AppColores.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                                onSubmitted: (_) => _guardar(),
                              ),
                              const SizedBox(height: 16),

                              // ── CAMPO CONFIRMAR ───────────────────────────
                              TextField(
                                controller: _confirmarPassController,
                                obscureText: !_verConfirmar,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Confirmar contraseña',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _verConfirmar
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AppColores.textMuted,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                      () => _verConfirmar = !_verConfirmar,
                                    ),
                                  ),
                                ),
                                onSubmitted: (_) => _guardar(),
                              ),
                              const SizedBox(height: 28),

                              // ── BOTÓN GUARDAR ─────────────────────────────
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColores.orangePrimary,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      AppColores.borderColor,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 4,
                                ),
                                icon: _guardando
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.check_circle_outline),
                                label: Text(
                                  _guardando
                                      ? 'Guardando...'
                                      : 'GUARDAR CONTRASEÑA',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                onPressed: _guardando ? null : _guardar,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── NOTA DE SEGURIDAD ─────────────────────────────────
                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppColores.textMuted,
                            size: 15,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Al guardar, cerraremos tu sesión y deberás entrar con tu nueva contraseña.',
                              style: TextStyle(
                                color: AppColores.textMuted.withOpacity(0.8),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Diálogo de confirmación cuando el usuario intenta salir sin guardar.
  // Antes de redirigir al login hacemos signOut() para limpiar la sesión temporal.
  void _mostrarDialogoSalir() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColores.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColores.borderColor),
        ),
        title: const Text(
          '¿Salir sin guardar?',
          style: TextStyle(color: Colors.white, fontSize: 17),
        ),
        content: const Text(
          'Si sales ahora, el enlace de recuperación seguirá activo pero tendrás que solicitarlo de nuevo para cambiar la contraseña.',
          style: TextStyle(color: AppColores.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColores.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColores.orangePrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context); // Cerramos el diálogo primero
              await supabase.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const MyHomePage(title: 'ProTask'),
                  ),
                  (route) => false,
                );
              }
            },
            child: const Text(
              'Salir igualmente',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
