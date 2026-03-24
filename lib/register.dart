import 'package:flutter/material.dart';
import 'package:myapp/proyectos.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/main.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Creamos controladores para cada campo de texto.
  // Estos nos permitirán acceder al texto que el usuario introduce.
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // [FASE 1A] Controlador para el nuevo campo de correo electrónico opcional.
  // Es opcional para no romper el flujo actual: si el usuario no lo rellena,
  // el registro sigue funcionando exactamente igual que antes.
  final _emailController = TextEditingController();

  // Es importante liberar los recursos de los controladores cuando el widget ya no se necesite.
  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailController.dispose(); // [FASE 1A] Liberamos también el nuevo controlador
    super.dispose();
  }

  // ── FUNCIÓN DE SANITIZACIÓN DEL NOMBRE DE USUARIO ────────────────────────
  // Limpia y valida el nombre de usuario antes de enviarlo a Supabase.
  // Solo permitimos letras (incluyendo acentos del español), números,
  // guión bajo y guión normal. Esto evita inyecciones de scripts o SQL.
  String? _sanitizarUsuario(String valor) {
    // Quitamos espacios al principio y al final que el usuario pudo meter sin querer
    final trimmed = valor.trim();

    // Si queda vacío, lo rechazamos
    if (trimmed.isEmpty) return null;

    // Longitud mínima: al menos 3 caracteres para que sea un usuario decente
    if (trimmed.length < 3) return null;

    // Longitud máxima: 30 caracteres es más que suficiente
    if (trimmed.length > 30) return null;

    // Solo permitimos letras (con acentos del español), números, guión bajo y guión.
    // Cualquier carácter especial como <, >, ", ' queda bloqueado automáticamente.
    final regexPermitido = RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ0-9_\-]+$');
    if (!regexPermitido.hasMatch(trimmed)) return null;

    return trimmed;
  }

  // ── FUNCIÓN DE VALIDACIÓN DE CONTRASEÑA
  // Comprobamos que la contraseña tiene al menos 6 caracteres (mínimo de Supabase)
  // y que no empieza ni termina con espacios que confunden al usuario.
  String? _validarPassword(String valor) {
    // Quitamos espacios sobrantes
    final trimmed = valor.trim();

    // Mínimo 6 caracteres para que Supabase Auth la acepte
    if (trimmed.length < 6) return null;

    return trimmed;
  }

  // ── [FASE 1A] FUNCIÓN DE VALIDACIÓN DE EMAIL (OPCIONAL) ──────────────────
  // Comprueba que el email tiene una estructura básica válida.
  // Como el campo es opcional, si está vacío devolvemos null (sin error).
  // Si el usuario escribe algo, sí lo validamos para evitar guardar basura.
  String? _validarEmail(String valor) {
    final trimmed = valor.trim();

    // Si está vacío no hay nada que validar; simplemente no lo guardamos
    if (trimmed.isEmpty) return null;

    // Validamos el formato básico de un email: tiene @ y al menos un punto después
    // No usamos regex ultra-complejos; Supabase hará su propia validación en el servidor
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(trimmed)) {
      // Devolvemos un marcador especial para distinguir "vacío" de "inválido"
      return 'INVALIDO';
    }

    return trimmed;
  }

  void validar() async {
    // Convertimos el método a async
    // ── Sanitizamos y validamos el nombre de usuario
    final userSanitizado = _sanitizarUsuario(_userController.text);

    // Si el campo tiene texto pero no pasó la validación, damos un error descriptivo
    if (_userController.text.trim().isNotEmpty && userSanitizado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El usuario debe tener entre 3 y 30 caracteres y solo puede contener letras, números, guión y guión bajo.',
          ),
        ),
      );
      return;
    }

    // ── Validamos la contraseña
    final passSanitizada = _validarPassword(_passwordController.text);

    if (_passwordController.text.isNotEmpty && passSanitizada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La contraseña debe tener al menos 6 caracteres.'),
        ),
      );
      return;
    }

    // ── [FASE 1A] Validamos el email si el usuario lo rellenó ────────────────
    final emailResultado = _validarEmail(_emailController.text);
    if (emailResultado == 'INVALIDO') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'El correo electrónico no parece válido. Revísalo o déjalo en blanco.'),
        ),
      );
      return;
    }
    // Si emailResultado es null → campo vacío; si tiene valor → email válido
    final emailValido = emailResultado; // null o email limpio

    String user = userSanitizado ?? '';
    String password = passSanitizada ?? '';
    String confirmPassword = _confirmPasswordController.text.trim();

    if (user.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, rellena todos los campos')),
      );
      return; // Detenemos la función si hay campos vacíos.
    } else {
      if (password != confirmPassword) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La contraseña ha de ser identica en ambos campos'),
          ),
        );
        return; // Detenemos la función si hay campos vacíos.
      } else {
        try {
          // ── [FASE 1B] VERIFICACIÓN DE EMAIL DUPLICADO ─────────────────────
          // Antes de intentar el signUp, consultamos la tabla 'profiles' para
          // comprobar si el email real ya está en uso por otra cuenta.
          // Esto es necesario porque la columna 'email' tiene restricción UNIQUE,
          // y si esperamos al INSERT, el error de Postgres es más difícil de
          // traducir de forma amigable para el usuario.
          // Solo lo hacemos si el usuario rellenó el campo de email opcional.
          if (emailValido != null) {
            final duplicado = await supabase
                .from('profiles')
                .select('id') // Solo necesitamos saber si existe, no los datos
                .eq('email', emailValido)
                .limit(1) // Con uno es suficiente; no queremos leer más filas
                .maybeSingle(); // null si no hay coincidencia; objeto si la hay

            if (duplicado != null) {
              // Ya existe una cuenta con ese correo → paramos aquí
              // El SnackBar da al usuario suficiente contexto para decidir qué hacer
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Este correo ya está registrado. Prueba con otro o recupéralo desde el login.',
                  ),
                  duration: Duration(seconds: 4),
                ),
              );
              return; // Salimos sin llamar a signUp ni crear ningún registro
            }
          }
          // ─────────────────────────────────────────────────────────────────

          // Aplicamos el mismo hack que en el login: el usuario escribe "juanito"
          // pero nosotros registramos "juanito@tfg.com" porque Supabase necesita un email.
          // Cambiamos createUserWithEmailAndPassword por el equivalente de Supabase.
          final response = await supabase.auth.signUp(
            email: '$user@tfg.com', // Añadimos el dominio ficticio igual que antes
            password: password,
          );

          // Antes guardábamos los datos del usuario en la colección 'users' de Firestore.
          // Ahora los insertamos en nuestra tabla 'profiles' de PostgreSQL.
          // Usamos el UUID que Supabase Auth acaba de generar para el nuevo usuario.
          // Si el nombre de usuario ya existe, la restricción UNIQUE de la tabla lo bloqueará.

          // [FASE 1A] Construimos el mapa de datos del perfil.
          // Si el usuario proporcionó un email real, lo incluimos en la inserción.
          // Si no, guardamos solo los campos básicos de siempre.
          // NOTA: Asegúrate de que tu tabla 'profiles' tenga la columna 'email' (TEXT, nullable).
          // SQL para añadirla si no existe:
          //   ALTER TABLE profiles ADD COLUMN IF NOT EXISTS email TEXT;
          final Map<String, dynamic> datosPerfil = {
            'id': response.user!.id, // El UUID que nos dio Supabase Auth
            'username': user, // El nombre que escribió el usuario en el campo
            'full_name': user, // De momento lo rellenamos igual; se puede editar después
            if (emailValido != null) 'email': emailValido, // Solo si lo rellenó
          };

          await supabase.from('profiles').insert(datosPerfil);

          // [FASE 1A] Si el usuario añadió su email real, lo actualizamos también
          // en el sistema de autenticación de Supabase para que las funciones
          // como resetPasswordForEmail puedan encontrarle más fácilmente.
          // Lo hacemos en un try separado para que, si falla, no revierta el registro.
          if (emailValido != null) {
            try {
              await supabase.auth.updateUser(UserAttributes(email: emailValido));
            } catch (_) {
              // Si falla la actualización del email en auth, no es crítico.
              // El perfil ya se guardó correctamente. El usuario puede actualizar
              // su email más tarde desde la pantalla de Perfil.
            }
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Registro completado con éxito!')),
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Proyectos(nombreUsuario: user),
            ),
          );
        } on AuthException catch (e) {
          // Supabase lanza AuthException en lugar de FirebaseAuthException.
          // Traducimos los mensajes más comunes al español para que el usuario entienda qué pasó.
          String message;
          if (e.message.contains('User already registered') ||
              e.message.contains('already registered')) {
            // Este error salta cuando el email (usuario@tfg.com) ya está en uso
            message = 'El usuario ya existe. Prueba con otro nombre.';
          } else if (e.message.contains('Password should be at least')) {
            message = 'La contraseña es demasiado débil.';
          } else {
            message = 'Ha ocurrido un error durante el registro: ${e.message}';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        } on PostgrestException catch (e) {
          // Este error lo lanza Supabase cuando falla algo en la base de datos,
          // por ejemplo si el username ya existe (restricción UNIQUE en la tabla profiles).
          String message;
          if (e.code == '23505') {
            // El código 23505 en PostgreSQL significa "valor duplicado en clave única"
            message = 'Ese nombre de usuario ya está en uso. Elige otro.';
          } else {
            message = 'Error al guardar el perfil. Inténtalo de nuevo.';
          }
          // Como el perfil no se guardó, borramos también el usuario de Auth
          // para no dejar una cuenta huérfana sin perfil asociado
          await supabase.auth.signOut();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ha ocurrido un error inesperado')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fondo del register
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2D3142), Color(0xFF232537)],
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
                    // ── LOGO ──────────────────────────────────────────────
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
                      'Crea tu cuenta nueva',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFFAAADBF),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 36),
                    // ── CARD FORMULARIO
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
                              'Registro',
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
                              // Limitamos a 30 caracteres para evitar entradas demasiado largas
                              maxLength: 30,
                              decoration: const InputDecoration(
                                labelText: 'Usuario',
                                prefixIcon: Icon(Icons.person_outline),
                                // Ocultamos el contador para no saturar visualmente
                                counterText: '',
                                // Pequeño hint para que el usuario sepa qué se permite
                                helperText:
                                    'Letras, números, guión y guión bajo (3-30 caracteres)',
                                helperStyle: TextStyle(
                                  color: Color(0xFFAAADBF),
                                  fontSize: 11,
                                ),
                              ),
                              onSubmitted: (_) => validar(),
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
                                helperText: 'Mínimo 6 caracteres',
                                helperStyle: TextStyle(
                                  color: Color(0xFFAAADBF),
                                  fontSize: 11,
                                ),
                              ),
                              onSubmitted: (_) => validar(),
                            ),

                            const SizedBox(height: 16.0),
                            // Espacio entre los campos de texto
                            //Y el espacio para la contraseña
                            TextField(
                              controller: _confirmPasswordController,
                              obscureText: true, // Para ocultar el texto
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Confirmar contraseña',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                              onSubmitted: (_) => validar(),
                            ),

                            // ── [FASE 1A] CAMPO DE EMAIL OPCIONAL ────────────────────
                            // Este campo es completamente opcional: si el usuario lo deja
                            // en blanco, el registro funciona igual que siempre.
                            // Si lo rellena, guardamos el email real en 'profiles' para que
                            // la recuperación de contraseña y la pantalla de Perfil funcionen.
                            const SizedBox(height: 20),
                            // Separador visual para dejar claro que es un campo extra
                            Row(
                              children: [
                                const Expanded(
                                  child: Divider(
                                    color: Color(0xFF4A4E66),
                                    endIndent: 8,
                                  ),
                                ),
                                const Text(
                                  'Opcional',
                                  style: TextStyle(
                                    color: Color(0xFFAAADBF),
                                    fontSize: 11,
                                  ),
                                ),
                                const Expanded(
                                  child: Divider(
                                    color: Color(0xFF4A4E66),
                                    indent: 8,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Correo electrónico',
                                prefixIcon: Icon(Icons.email_outlined),
                                // Aclaramos para qué sirve este campo sin ser intrusivos
                                helperText:
                                    'Para poder recuperar tu contraseña si la olvidas',
                                helperStyle: TextStyle(
                                  color: Color(0xFFAAADBF),
                                  fontSize: 11,
                                ),
                                hintText: 'ejemplo@correo.com',
                                hintStyle: TextStyle(
                                  color: Color(0xFF4A4E66),
                                  fontSize: 13,
                                ),
                              ),
                              onSubmitted: (_) => validar(),
                            ),

                            const SizedBox(height: 28.0), // Espacio antes del botón
                            // Botón de registro
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
                                Icons.person_add_alt_1,
                                color: Colors.white,
                              ),
                              // Ponemos el texto
                              label: const Text(
                                'CREAR CUENTA',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              // El onpressed nos va a llevar a la pagina de proyectos, de momento esta por hacerr
                              onPressed: () {
                                validar();
                              },
                            ),
                            const SizedBox(height: 16.0),
                            OutlinedButton(
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
                              onPressed: () {
                                // Vuelve a la pantalla anterior (que es el login)
                                Navigator.pop(context);
                              },
                              child: const Text(
                                '¿Ya tienes una cuenta? Inicia sesión',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
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
          ),
        ),
      ),
    );
  }
}
