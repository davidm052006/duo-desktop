import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../estado/estado_tablero.dart';
import '../modelos/tablero.dart';
import '../tema/paleta.dart';
import '../widgets/panel_fallo.dart';
import '../widgets/tarjeta.dart';

/// Línea de tiempo que el servicio puede sostener hoy: aperturas de tareas.
///
/// El endpoint no expone eventos ni la fecha de los cambios de estado. Por eso
/// una tarjeta en esta vista significa "tarea abierta este día", no una
/// reconstrucción ficticia de lo que hizo el agente después.
class PantallaHistorial extends StatelessWidget {
  const PantallaHistorial({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoTablero>();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 24,
        title: const Text('Historial'),
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
    final porFecha = <DateTime, List<Tarea>>{};
    for (final tarea in tablero.tareas) {
      final fecha = DateTime(
        tarea.abierta.year,
        tarea.abierta.month,
        tarea.abierta.day,
      );
      porFecha.putIfAbsent(fecha, () => []).add(tarea);
    }
    final fechas = porFecha.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
      children: [
        const _AvisoFuente(),
        const SizedBox(height: 18),
        if (fechas.isEmpty)
          const _Vacio()
        else
          for (final fecha in fechas) ...[
            _GrupoFecha(fecha: fecha, tareas: porFecha[fecha]!),
            const SizedBox(height: 20),
          ],
      ],
    );
  }
}

class _AvisoFuente extends StatelessWidget {
  const _AvisoFuente();

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: paleta.acentoAlt.withValues(alpha: .08),
        border: Border.all(color: paleta.rejilla),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: paleta.acentoAlt),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'La línea de tiempo usa la fecha de apertura de las tareas en /board. '
              'El servicio todavía no entrega eventos ni cambios de estado.',
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
    titulo: 'Sin actividad registrada',
    icono: Icons.history_toggle_off,
    hijo: Text(
      'No hay tareas registradas en /board.',
      style: Theme.of(context).textTheme.bodyMedium,
    ),
    pie: Text(
      'Los eventos detallados llegarán cuando el servicio los exponga.',
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: context.paleta.tintaTenue),
    ),
  );
}

class _GrupoFecha extends StatelessWidget {
  const _GrupoFecha({required this.fecha, required this.tareas});

  final DateTime fecha;
  final List<Tarea> tareas;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 15,
            color: context.paleta.tintaTenue,
          ),
          const SizedBox(width: 8),
          Text(_fechaIso(fecha), style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(width: 10),
          Text(
            '${tareas.length} tarea${tareas.length == 1 ? '' : 's'} abierta${tareas.length == 1 ? '' : 's'}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.paleta.tintaTenue),
          ),
        ],
      ),
      const SizedBox(height: 10),
      for (var indice = 0; indice < tareas.length; indice++)
        _Evento(tarea: tareas[indice], esUltimo: indice == tareas.length - 1),
    ],
  );

  static String _fechaIso(DateTime fecha) {
    String dosDigitos(int numero) => numero.toString().padLeft(2, '0');
    return '${fecha.year}-${dosDigitos(fecha.month)}-${dosDigitos(fecha.day)}';
  }
}

class _Evento extends StatelessWidget {
  const _Evento({required this.tarea, required this.esUltimo});

  final Tarea tarea;
  final bool esUltimo;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 17),
                  decoration: BoxDecoration(
                    color: paleta.serieDe(tarea.dueno),
                    shape: BoxShape.circle,
                  ),
                ),
                if (!esUltimo)
                  Expanded(child: Container(width: 1, color: paleta.rejilla)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: esUltimo ? 0 : 12),
              child: Tarjeta(
                titulo: tarea.id,
                icono: Icons.task_alt,
                sufijo: Insignia(
                  tarea.estadoCrudo,
                  tono: paleta.tintaSecundaria,
                  mono: true,
                ),
                hijo: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tarea.titulo,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 15,
                          color: paleta.tintaTenue,
                        ),
                        const SizedBox(width: 6),
                        Mono(tarea.dueno, color: paleta.tintaSecundaria),
                        const SizedBox(width: 10),
                        Text(
                          'abrió esta tarea',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: paleta.tintaTenue),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
