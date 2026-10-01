import 'package:flutter/material.dart';

import '../modelos/tablero.dart';
import '../tema/paleta.dart';

/// Las tareas del tablero, en el mismo orden que `.team/BOARD.md`.
///
/// El orden no se toca a propósito (contrato §8): si la app reordenara, las
/// filas se moverían solas cada vez que `duo` escribe en la pizarra.
class TablaTareas extends StatelessWidget {
  const TablaTareas({super.key, required this.tareas});

  final List<Tarea> tareas;

  @override
  Widget build(BuildContext context) {
    if (tareas.isEmpty) {
      return _SinTareas();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < tareas.length; i++) ...[
          if (i > 0) Divider(height: 1, color: context.paleta.rejilla),
          _FilaTarea(tarea: tareas[i]),
        ],
      ],
    );
  }
}

class _SinTareas extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, color: paleta.tintaTenue, size: 28),
          const SizedBox(height: 10),
          Text('No hay tareas abiertas.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            'Abre una con  duo "lo que quieras"',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}

class _FilaTarea extends StatelessWidget {
  const _FilaTarea({required this.tarea});

  final Tarea tarea;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;
    final color = paleta.serieDe(tarea.dueno);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Text(
              tarea.id,
              style: textos.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tarea.titulo, style: textos.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  tarea.rama,
                  style: textos.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: paleta.tintaTenue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(width: 92, child: _Dueno(agente: tarea.dueno, color: color)),
          const SizedBox(width: 12),
          SizedBox(width: 128, child: _ChipEstado(tarea: tarea)),
        ],
      ),
    );
  }
}

/// Punto del color del agente más su nombre escrito: la identidad se lee
/// también sin distinguir colores.
class _Dueno extends StatelessWidget {
  const _Dueno({required this.agente, required this.color});

  final String agente;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(
          agente,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
        ),
      ],
    );
  }
}

/// El estado, con icono y palabra. Los colores de estado están reservados: no
/// se usan nunca para identificar a un agente, y nunca van solos.
class _ChipEstado extends StatelessWidget {
  const _ChipEstado({required this.tarea});

  final Tarea tarea;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;

    final (color, icono) = switch (tarea.estado) {
      EstadoTarea.abierta => (paleta.series.first, Icons.play_circle_outline),
      EstadoTarea.esperando => (paleta.aviso, Icons.pause_circle_outline),
      EstadoTarea.entregada => (paleta.bien, Icons.check_circle_outline),
      EstadoTarea.integrada => (paleta.tintaSecundaria, Icons.merge_outlined),
      EstadoTarea.desconocido => (paleta.tintaTenue, Icons.help_outline),
    };

    return Row(
      children: [
        Icon(icono, size: 15, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            tarea.estadoCrudo,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
