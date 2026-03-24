import 'package:flutter/material.dart';
import 'package:myapp/proyectos.dart';
import 'package:myapp/register.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/main.dart' show supabase;

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Todo el tema de controladores y metodos se tienen que crear dentro del estado que los usara
  // Creamos controladores para cada campo de texto.
  // Estos nos permitirán acceder al texto que el usuario introduce.
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();

  // Esto limpia los controladores para ahorrar memoria
  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Esta función limpia el input del usuario antes de enviarlo a Supabase.
  // Recortamos espacios al inicio y al final, y comprobamos que no contenga
  // caracteres especiales que podrían usarse para inyectar scripts maliciosos.
  // Admitimos solo letras, números, guiones y guiones bajos para el usuario.
  String? _sanitizarUsuario(String valor) {
    // Quitamos espacios al principio y al final
    final trimmed = valor.trim();

    // Verificamos que no esté vacío tras el recorte
    if (trimmed.isEmpty) return null;

    // Longitud máxima razonable para un nombre de usuario
    if (trimmed.length > 30) return null;

    // Solo permitimos letras (con acentos), números, guión bajo y guión normal.
    // Esto bloquea cualquier intento de inyectar <script>, SQL, etc.
    // este fue un apunte de nuestro compañero guayre
    final regexPermitido = RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ0-9_\-]+$');
    if (!regexPermitido.hasMatch(trimmed)) return null;

    return trimmed;
  }

  // Para la contraseña solo comprobamos longitud mínima y que no tenga espacios,
  // ya que Supabase auth se encarga del resto de la seguridad en el servidor.
  String? _sanitizarPassword(String valor) {
    // Quitamos espacios (una contraseña no debería tener espacios al inicio/fin)
    final trimmed = valor.trim();

    // Longitud mínima de seguridad
    if (trimmed.length < 6) return null;

    return trimmed;
  }

  void validar() async {
    // Antes de enviar nada a Supabase, pasamos los valores por el sanitizador
    final userSanitizado = _sanitizarUsuario(_userController.text);
    final passSanitizada = _sanitizarPassword(_passwordController.text);

    // Si el usuario escribió algo con caracteres raros, avisamos
    if (_userController.text.trim().isNotEmpty && userSanitizado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El usuario solo puede contener letras, números, guiones y guión bajo (máx. 30 caracteres).',
          ),
        ),
      );
      return;
    }

    if (userSanitizado == null ||
        userSanitizado.isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, rellena todos los campos')),
      );
      return; // Detenemos la función si hay campos vacíos.
    } else {
      try {
        // ── RESOLUCIÓN DE EMAIL PARA EL LOGIN ─────────────────────────────
        // El sistema usa "usuario@tfg.com" como email ficticio en Supabase Auth,
        // pero si el usuario actualizó su correo real desde la pantalla de Perfil,
        // Supabase Auth migró su cuenta a ese email real y ya no reconoce "@tfg.com".
        //
        // Solución definitiva: consultamos profiles ANTES de autenticar para saber
        // qué email tiene registrado ese username. Si tiene email real → lo usamos.
        // Si no tiene (cuenta antigua que nunca actualizó el correo) → usamos el hack.
        // Así ambos tipos de cuenta funcionan siempre, sin importar su historial.
        final perfilPrevio = await supabase
            .from('profiles')
            .select('email')
            .eq('username', userSanitizado)
            .maybeSingle();

        // Si profiles tiene un email real no vacío → lo usamos para autenticar.
        // Si no → construimos el email ficticio de siempre como fallback.
        final emailGuardado = perfilPrevio?['email'] as String?;
        final emailParaAuth =
            (emailGuardado != null && emailGuardado.isNotEmpty)
            ? emailGuardado
            : '$userSanitizado@tfg.com';

        // Aquí está el "hack" del login: el usuario escribe "juanito" pero nosotros
        // le mandamos "juanito@tfg.com" a Supabase, que necesita un email válido.
        // Cambiamos FirebaseAuth.instance.signInWithEmailAndPassword por el equivalente de Supabase.
        final response = await supabase.auth.signInWithPassword(
          email:
              emailParaAuth, // Puede ser el real o el ficticio según el perfil
          password: _passwordController.text.trim(),
        );

        // En lugar de consultar Firestore para verificar si el perfil existe,
        // le preguntamos a nuestra tabla "profiles" de PostgreSQL.
        // Si no hay ninguna fila con ese UUID, es que algo raro pasó al registrarse.
        final userId = response.user!.id;
        final profileData = await supabase
            .from('profiles')
            .select('username')
            .eq('id', userId)
            .maybeSingle(); // Devuelve null si no existe en vez de lanzar error

        if (profileData != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => Proyectos(nombreUsuario: userSanitizado),
            ),
          );
        } else {
          // Si el perfil no existe en la tabla profiles, cerramos la sesión y avisamos
          await supabase.auth.signOut();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se encontraron datos de usuario. Registrate primero.',
              ),
            ),
          );
        }
      } on AuthException catch (e) {
        // Los mensajes de error de Supabase vienen en inglés en e.message,
        // así que los traducimos aquí para que el usuario vea algo legible.
        String message;
        if (e.message.contains('Invalid login credentials') ||
            e.message.contains('invalid_credentials')) {
          message = 'Usuario o contraseña incorrectos.';
        } else if (e.message.contains('Email not confirmed')) {
          message = 'Confirma tu correo antes de entrar.';
        } else {
          message = 'Error de autenticación. Inténtalo de nuevo.';
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error inesperado: $e')));
      }
    }
  }

  // ── [FASE 1A] RECUPERACIÓN DE CONTRASEÑA ─────────────────────────────────
  // Abre un diálogo donde el usuario introduce su correo electrónico REAL
  // (el que guardó en su perfil, no el "usuario@tfg.com" del hack).
  // Supabase envía un magic link a ese email para restablecer la contraseña.
  // IMPORTANTE: esto solo funciona si el usuario guardó su email real al registrarse
  // o lo añadió después desde la pantalla de Perfil.
  void _mostrarDialogoRecuperacion() {
    // Controlador local al diálogo; lo creamos aquí para poder liberarlo
    final emailController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true, // Pueden cerrar tocando fuera si se arrepienten
      builder: (dialogContext) {
        // Usamos StatefulBuilder para poder mostrar un loader dentro del diálogo
        // sin tener que convertir todo el widget en StatefulWidget
        bool enviando = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF3A3D52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF4A4E66)),
              ),
              // Icono y título del diálogo
              title: const Row(
                children: [
                  Icon(Icons.lock_reset, color: Color(0xFFE8622A), size: 26),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Recuperar contraseña',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Explicación breve para que el usuario sepa qué va a pasar
                  const Text(
                    'Introduce tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.',
                    style: TextStyle(
                      color: Color(0xFFAAADBF),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Campo para el email real del usuario
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    autofocus: true, // Abre el teclado automáticamente
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email_outlined),
                      hintText: 'ejemplo@correo.com',
                      hintStyle: TextStyle(color: Color(0xFF4A4E66)),
                    ),
                  ),
                ],
              ),
              actions: [
                // Botón de cancelar, siempre habilitado
                TextButton(
                  onPressed: () {
                    emailController.dispose();
                    Navigator.pop(dialogContext);
                  },
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Color(0xFFAAADBF)),
                  ),
                ),
                // Botón de enviar; se deshabilita mientras procesa para evitar doble envío
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8622A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: enviando
                      ? null
                      : () async {
                          final email = emailController.text.trim();

                          // Validación básica de formato de email antes de llamar a Supabase
                          if (email.isEmpty || !email.contains('@')) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Introduce un correo electrónico válido.',
                                ),
                              ),
                            );
                            return;
                          }

                          // Activamos el estado de "enviando" para mostrar el loader
                          setDialogState(() => enviando = true);

                          try {
                            // Llamamos a Supabase para enviar el email de recuperación
                            // Supabase se encarga de generar el magic link y enviarlo
                            await supabase.auth.resetPasswordForEmail(email);

                            // Cerramos el diálogo y mostramos confirmación
                            if (dialogContext.mounted) {
                              emailController.dispose();
                              Navigator.pop(dialogContext);
                            }

                            // Mensaje de éxito fuera del diálogo para que se vea bien
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '✅ Si ese correo está registrado, recibirás el enlace en breve.',
                                  ),
                                  duration: Duration(seconds: 5),
                                ),
                              );
                            }
                          } catch (e) {
                            // Si falla algo, desactivamos el loader y avisamos
                            setDialogState(() => enviando = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No se pudo enviar el correo. Inténtalo de nuevo.',
                                ),
                              ),
                            );
                          }
                        },
                  child: enviando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Enviar enlace',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
                // En tablet/web el formulario no se estira demasiado; en móvil ocupa el ancho disponible
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // logo
                    Image.asset('media/proyecto.png', height: 90, width: 90),
                    const SizedBox(height: 16),
                    // nombre de nuestra app
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
                      'Gestión de proyectos profesional',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFFAAADBF),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // card del login
                    Card(
                      color: const Color(0xFF3A3D52),
                      elevation: 12.0,
                      shadowColor: Colors.black54,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.0),
                        side: const BorderSide(
                          color: Color(0xFF4A4E66),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(28.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            // Título de sección dentro de la card
                            const Text(
                              'Iniciar sesión',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),

                            //Este es el textfield en el que el usuario introducira el mismo
                            TextField(
                              controller: _userController,
                              style: const TextStyle(color: Colors.white),
                              // Limitamos a 30 caracteres directamente en el campo
                              maxLength: 30,
                              decoration: const InputDecoration(
                                labelText: 'Usuario',
                                prefixIcon: Icon(Icons.person_outline),
                                // Ocultamos el contador de caracteres para no saturar visualmente
                                counterText: '',
                              ),
                              onSubmitted: (_) =>
                                  validar(), //Llama a validar al pulsar enter
                            ),

                            const SizedBox(height: 16.0),
                            // Espacio entre los campos de texto
                            //Y el espacio para la contraseña
                            TextField(
                              controller: _passwordController,
                              obscureText: true, // Para ocultar el texto
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                              onSubmitted: (_) =>
                                  validar(), //Llama a validar al pulsar enter
                            ),

                            // ── [FASE 1A] ENLACE DE CONTRASEÑA OLVIDADA ──────────────
                            // TextButton alineado a la derecha para que no rompa el flujo
                            // visual del formulario. Abre el diálogo de recuperación.
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                    horizontal: 0,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: _mostrarDialogoRecuperacion,
                                child: const Text(
                                  '¿Olvidaste tu contraseña?',
                                  style: TextStyle(
                                    color: Color(0xFFE8622A),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(
                              height: 16.0,
                            ), // Espacio antes del botón
                            // Botón de login
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE8622A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                elevation: 4,
                              ),
                              icon: const Icon(
                                Icons.login,
                                color: Colors.white,
                              ),
                              // Ponemos el texto
                              label: const Text(
                                'LOGIN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              // El onpressed nos va a llevar a la pagina de proyectos, de momento esta por hacer
                              onPressed: () {
                                print('Botón de login presionado!');
                                validar();
                              },
                            ),
                            //Despues de un espacio ponemos un boton de registrarse por si el usuario no tiene una cuenta
                            const SizedBox(height: 16.0),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFE8622A),
                                side: const BorderSide(
                                  color: Color(0xFFE8622A),
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                              ),
                              icon: const Icon(Icons.people_alt_sharp),
                              label: const Text(
                                '¿No tienes cuenta? Créala',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              //Llevamos al usuario a la pagina correspondiente
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const RegisterPage(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
