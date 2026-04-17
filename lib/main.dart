import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Carga credenciales desde .env
import 'package:flutter_localizations/flutter_localizations.dart'; // Para el calendario en español
import 'package:supabase_flutter/supabase_flutter.dart';
// ── NotificationService eliminado ─────────────────────────────────────
// Las alertas ahora se envían por correo electrónico a través de una Edge Function
// de Supabase. Ver: lib/services/email_service.dart
import 'package:myapp/splash.dart'; // Pantalla de carga con timeout y animación

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Necesario para inicializar plugins antes de arrancar la UI

  // Cargamos las variables de entorno desde .env antes de inicializar Supabase
  await dotenv.load(fileName: '.env');

  // Inicializamos Supabase con la URL y la clave pública del proyecto
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  runApp(const MyApp());
}

// Acceso global al cliente de Supabase para usarlo desde cualquier parte de la app
final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ProTask',

      // ── LOCALIZACIÓN EN ESPAÑOL ─────────────────────────────────────────
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'ES')],
      locale: const Locale('es', 'ES'),

      // Paleta de colores global de la app
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFE8622A),
          secondary: const Color(0xFFF0944D),
          surface: const Color(0xFF3A3D52),
          onPrimary: Colors.white,
          onSurface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF2D3142),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF23253A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF4A4E66)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF4A4E66)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE8622A), width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFFAAADBF)),
          prefixIconColor: const Color(0xFFE8622A),
        ),
      ),

      // El SplashScreen decide a qué pantalla navegar según la sesión
      home: const SplashScreen(),
    );
  }
}
