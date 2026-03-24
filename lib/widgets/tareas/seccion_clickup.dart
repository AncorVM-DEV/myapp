import 'package:flutter/material.dart';
import 'package:myapp/widgets/app_colores.dart';

// ── HELPER: SECCIÓN ESTILO CLICKUP ───────────────────────────────────────
class SeccionClickUp extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String? badge; // Añadimos el "?" para que sea opcional (puede ser null)
  final Widget hijo;

  const SeccionClickUp({
    super.key,
    required this.icono,
    required this.titulo,
    this.badge, // Le quitamos el "required"
    required this.hijo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF23253A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColores.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: AppColores.orangePrimary, size: 16),
              const SizedBox(width: 6),
              Text(
                titulo,
                style: const TextStyle(
                  color: AppColores.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 8),
              // ── MAGIA AQUÍ ──
              // Solo pintamos el contenedor del badge si no es nulo y tiene texto
              if (badge != null && badge!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColores.orangePrimary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppColores.orangePrimary.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: AppColores.orangeLight,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          hijo,
        ],
      ),
    );
  }
}
