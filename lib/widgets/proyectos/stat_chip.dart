import 'package:flutter/material.dart';
import 'package:myapp/widgets/app_colores.dart';

// ── WIDGET AUXILIAR: CHIP DE ESTADÍSTICA ──────────────────────────────────
// Esto es una pequeña tarjeta que se puede reutilizar para mostrar cada métrica de tareas.
// La sacamos de proyectos.dart a su propio archivo para que sea más fácil de encontrar
// y de reutilizar si en el futuro se necesita en otra pantalla.
class StatChip extends StatelessWidget {
  // Recibimos como parámetros todo lo que el chip necesita para dibujarse
  final String label;
  final String valor;
  final IconData icono;
  final Color color;

  const StatChip({
    super.key,
    required this.label,
    required this.valor,
    required this.icono,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF23253A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColores.borderColor),
        ),
        child: Column(
          children: [
            Icon(icono, color: color, size: 22),
            const SizedBox(height: 4),
            // El FittedBox evita overflow del número si el chip es muy estrecho
            // en pantallas pequeñas escala el texto automáticamente.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                valor,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 2),
            // Aplicamos el FittedBox también al label para evitar overflow en chips estrechos
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColores.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
