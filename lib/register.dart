import 'package:flutter/material.dart';
import 'package:myapp/proyectos.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importar Auth
import 'package:cloud_firestore/cloud_firestore.dart'; // Importar Firestore

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Creamos controladores para cada campo de texto.
  // Estos nos permitirán acceder al texto que el usuario introduce.
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Es importante liberar los recursos de los controladores cuando el widget ya no se necesite.
  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void validar() async { // Convertimos el método a async
    String user = _userController.text;
    String password = _passwordController.text;
    String confirmPassword = _confirmPasswordController.text;

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
          // Creamos el usuario en Firebase Authentication con un email ficticio
          UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: '$user@tfg.com', // Añadimos un dominio ficticio
            password: password,
          );

          // Creamos el documento en la colección 'users' de Firestore
          await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
            'uid': userCredential.user!.uid,
            'username': user,
            'createdAt': Timestamp.now(),
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Registro completado con éxito!')),
          );
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Proyectos()),
          );
        } on FirebaseAuthException catch (e) {
          if (e.code == 'weak-password') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('La contraseña es demasiado débil')),
            );
          } else if (e.code == 'email-already-in-use') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('El usuario ya existe')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ha ocurrido un error durante el registro')),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ha ocurrido un error inesperado')),
          );
        }
      }
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 320,
          height: 350,
          //Card en el que se encuentran los datos del login
          child: Card(
            color: Color.fromARGB(255, 255, 133, 11),
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

                  const SizedBox(height: 20.0),
                  // Espacio entre los campos de texto
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

                  const SizedBox(height: 20.0),
                  // Espacio entre los campos de texto
                  //Y el espacio para la contraseña
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText:
                        true, // Para ocultar el texto (ideal para contraseñas)
                    decoration: const InputDecoration(
                      labelText: 'Confirmar contraseña',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),

                  const SizedBox(height: 30.0), // Espacio antes del botón
                  // Botón de registro
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
                      'Registro',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    // El onpressed nos va a llevar a la pagina de proyectos, de momento esta por hacer
                    onPressed: () {
                      validar();
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
