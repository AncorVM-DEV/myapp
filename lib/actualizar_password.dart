import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/main.dart' show supabase;
import 'package:myapp/login.dart';
import 'package:myapp/widgets/app_colores.dart';

// ── PANTALLA DE ACTUALIZACIÓN DE CONTRASEÑA ────────────────────────
// Esta pantalla aparece ÚNICAMENTE cuando Supabase detecta un evento
// AuthChangeEvent.passwordRecovery, es decir, cuando el usuario llegó
// a la app a través del enlace de recuperación de contraseña que envió
// su correo. Supabase ya lo ha logueado automáticamente con una sesión
// temporal; solo necesitamos que escriba su nueva contraseña y la confirmemos.
class ActualizarPasswordPage extends StatefulWidget {
  const ActualizarPasswordPage({super.key});

  @override
  State<ActualizarPasswordPage> createState() => _ActualizarPasswordPageState();
}

class _ActualizarPasswordPageState extends State<ActualizarPasswordPage> {
  final _nuevaPassController = TextEditingController();
  final _confirmarPassController = TextEditingController();

  // Controla si mostramos el spinner dentro del botón mientras procesa
  bool _guardando = false;

  // Controla la visibilidad de los campos de contraseña (ojo abierto/cerrado)
  bool _verNuevaPass = false;
  bool _verConfirmarPass = false;

  @override
  void dispose() {
    _nuevaPassController.dispose();
    _confirmarPassController.dispose();
    super.dispose();
  }

  // ── VALIDACIÓN Y ENVÍO DE LA NUEVA CONTRASEÑA ────────────────────────────
  // Comprueba el formato, confirma que coinciden y llama a Supabase Auth.
  // Tras el éxito, cerramos la sesión temporal del magic link y mandamos
  // al usuario al login para que entre con sus credenciales habituales.
  Future<void> _guardarNuevaContrasena() async {
    final nuevaPass = _nuevaPassController.text.trim();
    final confirmarPass = _confirmarPassController.text.trim();

    // Verificamos que ningún campo esté vacío
    if (nuevaPass.isEmpty || confirmarPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, rellena ambos campos.')),
      );
      return;
    }

    // La contraseña debe tener al menos 6 caracteres (mínimo de Supabase Auth)
    if (nuevaPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La contraseña debe tener al menos 6 caracteres.'),
        ),
      );
      return;
    }

    // Verificamos que ambos campos coincidan antes de enviar nada
    if (nuevaPass != confirmarPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Las contraseñas no coinciden. Revísalas.'),
        ),
      );
      return;
    }

    // Bloqueamos el botón mientras procesamos para evitar dobles envíos
    setState(() => _guardando = true);

    try {
      // Esta es la llamada: actualizamos la contraseña en Supabase Auth.
      // La sesión temporal del magic link ya está activa, así que Supabase sabe
      // a qué usuario pertenece la actualización sin que tengamos que indicárselo.
      await supabase.auth.updateUser(UserAttributes(password: nuevaPass));

      // Contraseña actualizada con éxito. Cerramos la sesión temporal del magic link.
      // El usuario deberá loguearse de nuevo con su usuario y la contraseña nueva.
      // Esto es una buena práctica de seguridad: no mantenemos la sesión de recuperación.
      await supabase.auth.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ ¡Contraseña actualizada! Inicia sesión con tu nueva contraseña.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
        // Navegamos al login eliminando toda la pila de navegación anterior.
        // Así el usuario no puede pulsar "atrás" y volver a esta pantalla.
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const MyHomePage(title: 'ProTask'),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
          (route) => false, // Limpiamos toda la pila
        );
      }
    } on AuthException catch (e) {
      // Error específico de Supabase Auth: contraseña demasiado débil, sesión expirada...
      setState(() => _guardando = false);
      String mensaje;
      if (e.message.contains('session') || e.message.contains('expired')) {
        mensaje =
            'El enlace de recuperación ha expirado. Solicita uno nuevo desde el login.';
      } else if (e.message.contains('weak') || e.message.contains('password')) {
        mensaje =
            'La contraseña es demasiado débil. Prueba con una más segura.';
      } else {
        mensaje = 'No se pudo actualizar la contraseña. Inténtalo de nuevo.';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensaje)));
    } catch (_) {
      // Error genérico (sin red, timeout...)
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Error de conexión. Comprueba tu red e inténtalo de nuevo.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Usamos WillPopScope para evitar que el usuario salga pulsando "atrás"
      // sin haber establecido su contraseña. Si sale, la sesión de recovery queda
      // activa y podría causar comportamientos inesperados al reabrir la app.
      body: PopScope(
        canPop: false, // Bloqueamos el botón atrás del sistema
        onPopInvoked: (didPop) {
          if (didPop) return;
          // Si intenta salir, le mostramos una advertencia
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: AppColores.bgCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColores.borderColor),
              ),
              title: const Text(
                '¿Salir sin cambiar la contraseña?',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              content: const Text(
                'Si sales ahora, el enlace de recuperación seguirá activo. Puedes volver al login y solicitar uno nuevo si lo necesitas.',
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
                    // Cerramos el diálogo y luego la sesión antes de navegar
                    Navigator.pop(context);
                    await supabase.auth.signOut();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
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
        },
        child: Container(
          // Mismo gradiente de fondo que el login y el registro para consistencia visual
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
                // Evita desbordamiento cuando aparece el teclado
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 32.0,
                ),
                child: ConstrainedBox(
                  // Mismo ancho máximo que el login para consistencia
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ── LOGO ─────────────────────────────────────────────
                      Image.asset('media/proyecto.png', height: 90, width: 90),
                      const SizedBox(height: 16),

                      // ── NOMBRE DE LA APP ──────────────────────────────────
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

                      // ── CARD DEL FORMULARIO ───────────────────────────────
                      Card(
                        color: AppColores.bgCard,
                        elevation: 12.0,
                        shadowColor: Colors.black54,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
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
                              // Icono y título de la sección
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.lock_reset,
                                    color: AppColores.orangePrimary,
                                    size: 28,
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
                                'Elige una contraseña segura de al menos 6 caracteres.',
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
                                obscureText: !_verNuevaPass,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Nueva contraseña',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  // Botón para mostrar/ocultar la contraseña
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _verNuevaPass
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AppColores.textMuted,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                      () => _verNuevaPass = !_verNuevaPass,
                                    ),
                                  ),
                                  helperText: 'Mínimo 6 caracteres',
                                  helperStyle: const TextStyle(
                                    color: AppColores.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                                onSubmitted: (_) => _guardarNuevaContrasena(),
                              ),

                              const SizedBox(height: 16),

                              // ── CAMPO CONFIRMAR CONTRASEÑA ────────────────
                              TextField(
                                controller: _confirmarPassController,
                                obscureText: !_verConfirmarPass,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Confirmar contraseña',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _verConfirmarPass
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AppColores.textMuted,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                      () => _verConfirmarPass =
                                          !_verConfirmarPass,
                                    ),
                                  ),
                                ),
                                onSubmitted: (_) => _guardarNuevaContrasena(),
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
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                onPressed: _guardando
                                    ? null
                                    : _guardarNuevaContrasena,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── NOTA DE SEGURIDAD ─────────────────────────────────
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
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
                                'Después de guardar, cerraremos tu sesión y tendrás que entrar con tu nueva contraseña.',
                                style: TextStyle(
                                  color: AppColores.textMuted.withOpacity(0.8),
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
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
}
