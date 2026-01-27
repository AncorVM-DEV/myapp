import 'package:flutter/material.dart';

class Proyectos extends StatelessWidget {
  const Proyectos({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: Icon(Icons.add),
      ),

      drawer: Drawer(
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              Container(
                width: 250,
                height: 250,
                //Esto es un placeholder, hay que cambiarlo
                margin: EdgeInsets.all(15),
                child: Image.asset("media/proyecto.png"),
              ),
              const Text(
                "Proyectos",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
              ),
              Padding(padding: EdgeInsetsGeometry.all(10)),

              ListTile(
                leading: Icon(Icons.home),
                title: Text('Tus proyectos'),
                onTap: () {
                  //TODO, aqui va la carga de los proyectos al pulsar, pero todavia no tenemos la bd
                  Navigator.pop(context); // Cierra el drawer
                },
              ),
              Padding(padding: EdgeInsetsGeometry.all(15)),
              ListTile(
                leading: Icon(Icons.people_alt_rounded),
                title: Text('Compartido contigo'),
                onTap: () {
                  // TODO, aqui va el de los proyectos compartidos pero todavia no tenemos la bd
                  Navigator.pop(context); // Cierra el drawer
                },
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Tus proyectos"),
        backgroundColor: Colors.orange,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(32.0),
          child: Container(
            color: const Color.fromARGB(255, 139, 223, 167),
            height: 32.0,
          ),
        ),
      ),
      body: Center(
        child: Column(children: [Text("Bienvenido a tus proyectos")]),
      ),
    );
  }
}
