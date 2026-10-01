import 'package:flutter/material.dart';

import '../modelos/tablero.dart';
import '../tema/paleta.dart';

/// Carga acumulada por agente: una barra por agente, comparables entre sí.
///
/// Es la versión en pantalla de lo que `duo status` dibuja con bloques en la
/// terminal. Cada fila lleva su nombre y su cifra escritos al lado, así que el
/// color es un refuerzo de la identidad, nunca la única pista.
class CargaAgentes extends StatelessWidget {
  const CargaAgentes({super.key, required this.agentes, required this.maximo});

  final List<CargaAgente> agentes;
  final int maximo;

  @override
  Widget build(BuildContext context) {
    if (agentes.isEmpty) {
      return Text('Sin agentes en el ledger.', style: Theme.of(context).textTheme.bodySmall);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final agente in agentes)
          Padding(
            // El hueco vertical hace de separador entre barras: dos rellenos
            // nunca se tocan.
            padding: const EdgeInsets.only(bottom: 14),
            child: _BarraAgente(agente: agente, maximo: maximo),
          ),
      ],
    );
  }
}

class _BarraAgente extends StatelessWidget {
  const _BarraAgente({required this.agente, required this.maximo});

  final CargaAgente agente;
  final int maximo;

  static const _alturaBarra = 10.0;
  static const _anchoEtiqueta = 64.0;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;
    final color = paleta.serieDe(agente.agente);

    // Con todo a cero no hay escala posible; se dibuja la pista vacía.
    final fraccion = maximo <= 0 ? 0.0 : agente.puntos / maximo;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: _anchoEtiqueta,
          child: Text(
            agente.agente,
            style: textos.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: _alturaBarra,
              color: paleta.rejilla,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fraccion.clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    // El extremo que nace de la línea base queda recto; solo se
                    // redondea la punta, que es el dato.
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(4),
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Etiqueta directa: la cifra se lee sin pasar el ratón y sin leyenda.
        // Las cifras van en tinta de texto, no del color de la serie.
        // Las cifras se quedan en una línea: si la columna se queda corta, mejor
        // recortar que partir la fila en dos y descuadrar las barras.
        SizedBox(
          width: 132,
          child: Text(
            '${agente.puntos} pts · ${agente.tareas} '
            '${agente.tareas == 1 ? "tarea" : "tareas"}',
            style: textos.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(
          width: 96,
          child: Text(
            agente.ultima == null ? 'sin actividad' : _fecha(agente.ultima!),
            style: textos.bodySmall?.copyWith(color: paleta.tintaTenue),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  static String _fecha(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
