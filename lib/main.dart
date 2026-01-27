import 'package:flutter/material.dart';
import 'package:myapp/proyectos.dart';
import 'package:myapp/register.dart';
import 'package:firebase_core/firebase_core.dart'; // Importar Core
import 'package:firebase_auth/firebase_auth.dart'; // Importar Auth
import 'package:myapp/firebase_options.dart'; // Importar las opciones generadas

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Necesario para inicializar plugins antes de arrancar la UI
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 255, 133, 11),
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Fluter Funciona'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  //todo el tema de controladores y metodos se tienen que crear dentro del stado qeu los usara
  // Creamos controladores para cada campo de texto.
  // Estos nos permitirán acceder al texto que el usuario introduce.
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();

  // Es importante liberar los recursos de los controladores cuando el widget ya no se necesite.
  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void validar() {
    String user = _userController.text;
    String password = _passwordController.text;

    if (user.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, rellena todos los campos')),
      );
      return; // Detenemos la función si hay campos vacíos.
    } else {
      //TODO validacion de usuario para cuando tengo la bd
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => Proyectos()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 320,
          height: 400,
          //Card en el que se encuentran los datos del login
          child: Card(
            color: const Color.fromARGB(255, 255, 133, 11),
            elevation: 8.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            //ponemos margenes en todos los bordes
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            //Un margen a todo
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              //Se mete en una columna
              child: Column(
                mainAxisSize: MainAxisSize.min,
                //y se viene una cadena de objetos
                children: <Widget>[
                  //Este es el textfield en el que el usuario introducira el mismo
                  TextField(
                    controller: _userController,
                    decoration: const InputDecoration(
                      labelText: 'Usuario',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),

                  const SizedBox(
                    height: 20.0,
                  ), // Espacio entre los campos de texto
                  //Y el espacio para la contraseña
                  TextField(
                    controller: _passwordController,
                    obscureText:
                        true, // Para ocultar el texto (ideal para contraseñas)
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 30.0), // Espacio antes del botón
                  // Botón de login
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(221, 44, 94, 233),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                    ),
                    icon: const Icon(Icons.login, color: Colors.white),
                    // Ponemos el texto
                    label: const Text(
                      'LOGIN',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    // El onpressed nos va a llevar a la pagina de proyectos, de momento esta por hacer
                    onPressed: () {
                      print('Botón de login presionado!');
                      validar();
                    },
                  ),
                  //Despues de un espacion ponemos un boton de registrarse por si el usuario no tiene una cuenta
                  const SizedBox(height: 35.0),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(221, 44, 94, 233),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 7,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                    ),
                    icon: const Icon(
                      Icons.people_alt_sharp,
                      color: Colors.white,
                    ),

                    label: const Text(
                      '¿No tienes cuenta? Creala',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
        ),
      ),
    );
  }
}
