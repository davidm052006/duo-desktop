import 'package:flutter/material.dart';

import '../tema/paleta.dart';

/// Marcador honesto para una vista que todavía no existe.
///
/// Prefiere esto a una pantalla vacía o a esconder la entrada del menú: el
/// mockup enseña las secciones futuras con su fase escrita, y así quien abre
/// la app sabe qué falta en vez de encontrarse un hueco.
class EnConstruccion extends StatelessWidget {
  const EnConstruccion({
    super.key,
    required this.titulo,
    required this.fase,
    required this.descripcion,
  });

  final String titulo;
  final int fase;

  /// Qué hará esta vista cuando exista. En una frase.
  final String descripcion;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(titulo, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: paleta.rejilla,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'FASE $fase',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: paleta.tintaSecundaria,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            descripcion,
            style: TextStyle(color: paleta.tintaSecundaria, height: 1.5),
          ),
        ],
      ),
    );
  }
}
