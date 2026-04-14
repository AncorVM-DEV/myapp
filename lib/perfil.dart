import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/main.dart' show supabase;
import 'package:myapp/utils/sanitizer.dart'; // Sanitización de inputs antes de enviar a Supabase
import 'package:myapp/widgets/app_colores.dart';

// ── [FASE 1A] PANTALLA DE PERFIL ─────────────────────────────────────────────
// Pantalla nueva que permite al usuario ver y actualizar su información personal.
// De momento expone dos campos: el username (solo lectura, para que sepa quién es)
// y el correo electrónico real (editable, útil para recuperar contraseña).
//
// Acceso desde el Drawer de proyectos.dart añadiendo este ListTile justo debajo
// del de "Compartido contigo":
//
//   ListTile(
//     leading: const Icon(Icons.person_rounded, color: AppColores.orangePrimary),
//     title: const Text('Mi perfil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
//     onTap: () {
//       Navigator.pop(context); // Cerramos el drawer antes de navegar
//       Navigator.push(context, MaterialPageRoute(
//         builder: (_) => PerfilPage(nombreUsuario: widget.nombreUsuario),
//       ));
//     },
//   ),
//
// Recuerda añadir también el import al principio de proyectos.dart:
//   import 'package:myapp/perfil.dart';
class PerfilPage extends StatefulWidget {
  // Recibimos el nombre de usuario desde Proyectos para mostrarlo de entrada
  // sin necesidad de hacer una consulta extra a la BD nada más abrir la pantalla
  final String nombreUsuario;

  const PerfilPage({super.key, required this.nombreUsuario});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  // Controlador para el campo de email; lo rellenaremos con el valor actual de BD
  final _emailController = TextEditingController();

  // Estado de carga al entrar a la pantalla
  bool _cargandoPerfil = true;

  // Estado del botón de guardar: true mientras procesa para evitar doble pulsación
  bool _guardando = false;

  // Guardamos el email original para saber si el usuario ha hecho cambios reales
  String _emailOriginal = '';

  @override
  void initState() {
    super.initState();
    // Cargamos los datos del perfil nada más montar el widget
    _cargarPerfil();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // ── CARGA DEL PERFIL DESDE SUPABASE ──────────────────────────────────────
  // Consultamos la tabla 'profiles' para obtener el email guardado (si existe).
  // Si el usuario nunca ha añadido email, el campo llegará como null → campo vacío.
  Future<void> _cargarPerfil() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return; // No debería ocurrir si el usuario está logueado

      final datos = await supabase
          .from('profiles')
          .select('email') // Solo necesitamos el email; el username ya lo tenemos
          .eq('id', userId)
          .maybeSingle();

      // Rellenamos el campo con el email guardado, o lo dejamos vacío
      final emailGuardado = (datos?['email'] as String?) ?? '';
      if (mounted) {
        setState(() {
          _emailController.text = emailGuardado;
          _emailOriginal = emailGuardado; // Guardamos para detectar cambios
          _cargandoPerfil = false;
        });
      }
    } catch (_) {
      // Si la consulta falla (sin red, error de permisos...) mostramos la pantalla
      // igualmente pero con el campo vacío. El usuario puede intentar guardar después.
      if (mounted) {
        setState(() => _cargandoPerfil = false);
      }
    }
  }

  // ── VALIDACIÓN BÁSICA DE EMAIL ────────────────────────────────────────────
  // Comprobamos el formato antes de hacer ninguna llamada a Supabase.
  // Devolvemos true si es válido o está vacío (borrar email también es válido).
  bool _emailEsValido(String valor) {
    if (valor.trim().isEmpty) return true; // Vacío → OK, borramos el email
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(valor.trim());
  }

  // ── GUARDAR CAMBIOS EN EL PERFIL ─────────────────────────────────────────
  // Actualiza tanto la tabla 'profiles' (para nuestros datos) como el sistema
  // de auth de Supabase (para que las funciones de Auth como resetPassword funcionen).
  // Ambas operaciones van por separado para que si una falla, la otra no se revierta.
  Future<void> _guardarCambios() async {
    final nuevoEmail = _emailController.text.trim();

    // Si no ha cambiado nada, no hacemos ninguna llamada innecesaria
    if (nuevoEmail == _emailOriginal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No has realizado ningún cambio.'),
        ),
      );
      return;
    }

    // Validamos el formato del email antes de mandar nada
    if (!_emailEsValido(nuevoEmail)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'El correo electrónico no tiene un formato válido. Revísalo.'),
        ),
      );
      return;
    }

    // Bloqueamos el botón mientras procesamos
    setState(() => _guardando = true);

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _guardando = false);
      return;
    }

    bool exitoProfiles = false;
    bool exitoAuth = false;

    // ── Paso 1: Actualizamos la tabla 'profiles' ──────────────────────────
    // Aquí guardamos el email en nuestra propia tabla de datos de usuario.
    // NOTA: Asegúrate de que tu tabla 'profiles' tenga la columna 'email' (TEXT, nullable).
    // SQL para añadirla si no existe: ALTER TABLE profiles ADD COLUMN IF NOT EXISTS email TEXT;
    try {
      // Sanitizamos el input antes de enviarlo a Supabase
      final emailLimpio = Sanitizer.cleanNullable(nuevoEmail);
      await supabase
          .from('profiles')
          .update({'email': emailLimpio})
          .eq('id', userId);
      exitoProfiles = true;
    } on PostgrestException {
      // Error de base de datos: columna no existe, permisos, etc.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No se pudo actualizar el perfil. Contacta con el administrador.'),
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error de red al guardar. Inténtalo de nuevo.'),
        ),
      );
    }

    // ── Paso 2: Actualizamos el email en Supabase Auth ────────────────────
    // Esto es necesario para que las funciones de Auth (como el envío de email
    // de recuperación de contraseña) encuentren la dirección actualizada.
    // Solo lo hacemos si el nuevo email no está vacío (no tiene sentido poner
    // email vacío en Auth porque auth necesita alguna dirección).
    if (exitoProfiles && nuevoEmail.isNotEmpty) {
      try {
        await supabase.auth.updateUser(UserAttributes(email: nuevoEmail));
        exitoAuth = true;
      } on AuthException catch (e) {
        // Supabase puede rechazar el email si ya está en uso por otra cuenta
        if (e.message.contains('already registered') ||
            e.message.contains('already been registered')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '⚠️ Ese correo ya está en uso por otra cuenta. Se guardó en tu perfil, pero no se actualizó en el sistema de autenticación.'),
              duration: Duration(seconds: 5),
            ),
          );
        } else {
          // Otro error de auth: el dato se guardó en profiles pero no en auth
          // Informamos sin alarmar; el dato más importante (en profiles) ya está guardado
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '⚠️ El correo se guardó en tu perfil, pero no se pudo actualizar en el sistema de login.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } catch (_) {
        // Error de red durante la actualización de auth → no es crítico
      }
    }

    // ── Feedback final al usuario ─────────────────────────────────────────
    if (exitoProfiles) {
      // Actualizamos el estado interno para que el botón sepa el nuevo "original"
      setState(() {
        _emailOriginal = nuevoEmail;
        _guardando = false;
      });

      // Mensaje de éxito diferente si también se actualizó Auth o no
      final mensaje = exitoAuth || nuevoEmail.isEmpty
          ? '✅ Perfil actualizado correctamente.'
          : '✅ Email guardado en tu perfil.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje)),
      );
    } else {
      setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.bgDark,
      // AppBar con el mismo estilo que el resto de la app
      appBar: AppBar(
        backgroundColor: AppColores.bgCard,
        foregroundColor: Colors.white,
        title: const Text(
          'Mi Perfil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColores.borderColor),
        ),
      ),
      body: _cargandoPerfil
          // Mientras cargamos los datos del perfil mostramos el spinner
          ? const Center(
              child: CircularProgressIndicator(color: AppColores.orangePrimary),
            )
          : SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 32.0,
                  ),
                  child: ConstrainedBox(
                    // Misma restricción de ancho máximo que el login y el registro
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── CABECERA DEL PERFIL ───────────────────────────
                        // Avatar generado con las iniciales del username para que
                        // tenga identidad visual sin necesidad de foto real
                        Center(
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  AppColores.orangePrimary,
                                  AppColores.orangeLight,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: AppColores.borderColor,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                // Tomamos la primera letra del username y la ponemos en mayúscula
                                widget.nombreUsuario.isNotEmpty
                                    ? widget.nombreUsuario[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Nombre de usuario bajo el avatar
                        Center(
                          child: Text(
                            widget.nombreUsuario,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Center(
                          child: Text(
                            'Miembro de ProTask',
                            style: TextStyle(
                              color: AppColores.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),

                        const SizedBox(height: 36),

                        // ── CARD DE DATOS ─────────────────────────────────
                        Card(
                          color: AppColores.bgCard,
                          elevation: 8,
                          shadowColor: Colors.black45,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(
                              color: AppColores.borderColor,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Título de la sección
                                const Text(
                                  'Información de cuenta',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // ── CAMPO USERNAME (solo lectura) ─────────
                                // Mostramos el username pero no permitimos editarlo
                                // porque cambiarlo requeriría actualizar también el
                                // "hack" del email en Auth (usuario@tfg.com), lo cual
                                // queda fuera del alcance de esta fase.
                                TextField(
                                  controller: TextEditingController(
                                      text: widget.nombreUsuario),
                                  readOnly: true, // No se puede editar
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Nombre de usuario',
                                    prefixIcon: const Icon(
                                      Icons.person_outline,
                                    ),
                                    // Icono de candado para que quede claro que es de solo lectura
                                    suffixIcon: const Icon(
                                      Icons.lock_outline,
                                      color: AppColores.textMuted,
                                      size: 18,
                                    ),
                                    // Fondo ligeramente distinto para marcar visualmente que es de solo lectura
                                    fillColor: const Color(0xFF1E2033),
                                    filled: true,
                                    helperText:
                                        'El nombre de usuario no se puede cambiar',
                                    helperStyle: const TextStyle(
                                      color: AppColores.textMuted,
                                      fontSize: 11,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: AppColores.borderColor),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: AppColores.borderColor),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: AppColores.borderColor),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // ── CAMPO EMAIL (editable) ────────────────
                                // Este es el campo estrella de la pantalla: permite
                                // añadir o actualizar el correo real del usuario.
                                // Al guardar se actualiza tanto 'profiles' como Supabase Auth.
                                TextField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    labelText: 'Correo electrónico',
                                    prefixIcon: Icon(Icons.email_outlined),
                                    hintText: 'ejemplo@correo.com',
                                    hintStyle: TextStyle(
                                        color: AppColores.borderColor),
                                    helperText:
                                        'Necesario para recuperar tu contraseña',
                                    helperStyle: TextStyle(
                                      color: AppColores.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 28),

                                // ── BOTÓN GUARDAR ─────────────────────────
                                SizedBox(
                                  width: double.infinity, // Ocupa todo el ancho
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          AppColores.orangePrimary,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor:
                                          AppColores.borderColor,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
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
                                        : const Icon(Icons.save_rounded),
                                    label: Text(
                                      _guardando
                                          ? 'Guardando...'
                                          : 'Guardar cambios',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    // Deshabilitamos el botón mientras procesa
                                    onPressed:
                                        _guardando ? null : _guardarCambios,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── NOTA INFORMATIVA ──────────────────────────────
                        // Aclaramos al usuario por qué pedimos su email real,
                        // dado que el sistema usa un "truco" con @tfg.com internamente
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColores.bgCard.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: AppColores.borderColor),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppColores.textMuted,
                                size: 18,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Tu correo electrónico se usa únicamente para que puedas recuperar tu contraseña si la olvidas. No lo compartiremos con nadie.',
                                  style: TextStyle(
                                    color: AppColores.textMuted,
                                    fontSize: 12,
                                    height: 1.5,
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
    );
  }
}
