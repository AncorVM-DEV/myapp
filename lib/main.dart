import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // Para el calendario en español
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/notification_service.dart'; // Servicio de notificaciones push
import 'package:myapp/splash.dart'; // [FASE 1A] Pantalla de carga con timeout y animación

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Necesario para inicializar plugins antes de arrancar la UI

  // Cambiamos Firebase.initializeApp() por Supabase.initialize().
  // Aquí es donde le decimos a la app dónde está nuestro proyecto en Supabase.
  await Supabase.initialize(
    url: 'https://rmnurofyjnoonqdzwwdy.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJtbnVyb2Z5am5vb25xZHp3d2R5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzMDEwMDAsImV4cCI6MjA4Nzg3NzAwMH0.FuCEuXUadRLuhzkAy0ZwiLDJ48SANdJO1ci4rNYk2WY', // La clave pública "anon" de tu proyecto
  );

  // Arrancamos el servicio de notificaciones locales (en web no hace nada)
  await NotificationService.init();

  runApp(const MyApp());
}

// Creamos un acceso rápido y global al cliente de Supabase para poder usarlo
// desde cualquier parte de la app sin tener que escribir Supabase.instance.client cada vez.
final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // [FASE 1A] La lógica de _resolverPantallaInicial() se ha movido a SplashScreen.
  // Ahora MyApp solo se ocupa de configurar el tema y los delegates de localización.
  // Esto sigue el principio de responsabilidad única: MyApp = configuración global;
  // SplashScreen = decisión de navegación inicial.

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ProTask',

      // ── LOCALIZACIÓN EN ESPAÑOL ──────────────────────────────────────────
      // Estos delegates le dicen a Flutter que use los textos en español
      // para todos los widgets nativos: DatePicker, TimePicker, AlertDialog, etc.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate, // Textos en Material (botones, meses...)
        GlobalWidgetsLocalizations.delegate,  // Dirección del texto (LTR/RTL)
        GlobalCupertinoLocalizations.delegate, // Textos en estilo iOS
      ],
      // Le decimos a la app que soporte el español de España
      supportedLocales: const [
        Locale('es', 'ES'), // Español de España (semana empieza en Lunes)
      ],
      // Forzamos el locale a español para que el DatePicker salga siempre en español
      locale: const Locale('es', 'ES'),

      // Declaramos la paleta de colores que usaremos en toda la app
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

      // [FASE 1A] Apuntamos al SplashScreen como pantalla de inicio.
      // El SplashScreen se encarga de mostrar la animación de carga, verificar
      // si hay sesión activa y navegar al destino correcto (Login o Proyectos).
      // Ya no necesitamos el FutureBuilder aquí porque esa responsabilidad
      // ahora vive íntegramente en splash.dart.
      home: const SplashScreen(),
    );
  }
}
