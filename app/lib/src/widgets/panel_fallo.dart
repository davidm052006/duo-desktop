import 'package:flutter/material.dart';

import '../datos/cliente_duo.dart';
import '../tema/paleta.dart';

/// Lo que se ve cuando el servicio no da datos.
///
/// El contrato pide decidir por `error.code` y no por el texto del mensaje, así
/// que el consejo que damos sale del código; el mensaje del servicio se muestra
/// debajo tal cual, sin reinterpretarlo.
class PanelFallo extends StatelessWidget {
  const PanelFallo({super.key, required this.fallo, required this.alReintentar});

  final FalloDuo fallo;
  final VoidCallback alReintentar;

  /// Qué puede hacer David con cada código. Un código que no conozcamos no
  /// recibe un consejo inventado.
  static String? _consejo(String codigo) => switch (codigo) {
    'service_unreachable' =>
      'Arranca las dos piezas juntas con  scripts/dev.fish',
    'unauthorized' =>
      'La app y el servicio no comparten token. scripts/dev.fish genera uno y '
          'se lo pasa a los dos; arrancarlos por separado no funciona.',
    'board_not_found' =>
      'No encuentro la pizarra. Prepara el repo con  duo init  — y si tienes '
          'varios proyectos, indica cuál con DUO_P=<nombre>.',
    'invalid_board' =>
      'La pizarra existe pero su formato no cuadra. Revisa .team/BOARD.md y '
          '.team/ledger.tsv en la rama team/board.',
    'board_read_failed' => 'Fallo al leer la pizarra. El log del servicio tiene el detalle.',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;
    final consejo = _consejo(fallo.codigo);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: paleta.critico, size: 20),
                const SizedBox(width: 8),
                Text(fallo.codigo, style: textos.titleMedium?.copyWith(fontFamily: 'monospace')),
              ],
            ),
            const SizedBox(height: 10),
            Text(fallo.mensaje, style: textos.bodyMedium),
            if (consejo != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: paleta.rejilla),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(consejo, style: textos.bodySmall),
              ),
            ],
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: alReintentar,
              icon: const Icon(Icons.refresh, size: 17),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
