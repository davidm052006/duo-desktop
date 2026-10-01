import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../estado/estado_tablero.dart';
import '../modelos/tablero.dart';
import '../tema/paleta.dart';
import '../widgets/panel_fallo.dart';
import '../widgets/tarjeta.dart';

/// Preguntas pendientes detectadas a partir de las tareas detenidas.
///
/// `GET /board` solo identifica la tarea en estado `esperando`; todavía no
/// entrega el contenido de la pregunta. La pantalla no convierte el título de
/// la tarea en una pregunta ficticia y deja esa ausencia escrita en cada caso.
class PantallaPreguntas extends StatelessWidget {
  const PantallaPreguntas({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoTablero>();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 24,
        title: const Text('Preguntas'),
        actions: [
          IconButton(
            tooltip: 'Actualizar tablero',
            onPressed: estado.refresca,
            icon: const Icon(Icons.refresh, size: 19),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: switch (estado.fase) {
        Fase.inicial || Fase.cargando => const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        Fase.fallo => Padding(
          padding: const EdgeInsets.all(24),
          child: PanelFallo(
            fallo: estado.fallo!,
            alReintentar: estado.refresca,
          ),
        ),
        Fase.listo => _Contenido(tablero: estado.tablero!),
      },
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.tablero});

  final Tablero tablero;

  @override
  Widget build(BuildContext context) {
    final pendientes = tablero.tareas
        .where((tarea) => tarea.estado == EstadoTarea.esperando)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
      children: [
        _AvisoFuente(),
        const SizedBox(height: 18),
        Text(
          pendientes.isEmpty
              ? 'SIN PREGUNTAS PENDIENTES'
              : '${pendientes.length} PREGUNTA${pendientes.length == 1 ? '' : 'S'} PENDIENTE${pendientes.length == 1 ? '' : 'S'}',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 10),
        if (pendientes.isEmpty)
          const _Vacio()
        else
          for (final tarea in pendientes) ...[
            _Pregunta(tarea: tarea),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _AvisoFuente extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: paleta.acento.withValues(alpha: .08),
        border: Border.all(color: paleta.rejilla),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: paleta.acento),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'El servicio local solo entrega las tareas detenidas en /board. '
              'El texto de cada pregunta llegará cuando exista la API de preguntas.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio();

  @override
  Widget build(BuildContext context) => Tarjeta(
    titulo: 'Todo al día',
    icono: Icons.check_circle_outline,
    hijo: Text(
      'Ningún agente está esperando una respuesta.',
      style: Theme.of(context).textTheme.bodyMedium,
    ),
    pie: Text(
      'Se muestran las tareas con estado esperando de /board.',
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: context.paleta.tintaTenue),
    ),
  );
}

class _Pregunta extends StatelessWidget {
  const _Pregunta({required this.tarea});

  final Tarea tarea;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;

    return Tarjeta(
      titulo: tarea.id,
      icono: Icons.help_outline,
      sufijo: Insignia(tarea.estadoCrudo, tono: paleta.acento, mono: true),
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tarea.titulo, style: textos.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.person_outline, size: 15, color: paleta.tintaTenue),
              const SizedBox(width: 6),
              Mono(tarea.dueno, color: paleta.tintaSecundaria),
              const SizedBox(width: 16),
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: paleta.tintaTenue,
              ),
              const SizedBox(width: 6),
              Mono(_fecha(tarea.abierta), color: paleta.tintaSecundaria),
            ],
          ),
          const SizedBox(height: 14),
          Text('PREGUNTA', style: textos.labelSmall),
          const SizedBox(height: 5),
          Text(
            'El texto de la pregunta no viene en /board.',
            style: textos.bodySmall?.copyWith(color: paleta.tintaTenue),
          ),
        ],
      ),
      pie: Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: () => _muestraComando(context),
          icon: const Icon(Icons.terminal, size: 16),
          label: const Text('Responder'),
        ),
      ),
    );
  }

  static String _fecha(DateTime fecha) {
    String dosDigitos(int numero) => numero.toString().padLeft(2, '0');
    return '${fecha.year}-${dosDigitos(fecha.month)}-${dosDigitos(fecha.day)}';
  }

  static Future<void> _muestraComando(BuildContext context) => showDialog<void>(
    context: context,
    builder: (contextoDialogo) => AlertDialog(
      title: const Text('Responder desde Duo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'La app todavía no envía respuestas al agente. Ejecuta este comando:',
          ),
          const SizedBox(height: 14),
          SelectableText(
            'duo ask',
            style: Theme.of(
              contextoDialogo,
            ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(contextoDialogo),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}
