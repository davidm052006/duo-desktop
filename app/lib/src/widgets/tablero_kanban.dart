import 'package:flutter/material.dart';

import '../modelos/tablero.dart';
import '../tema/paleta.dart';

/// Vista de Fase 2 del tablero: organiza la misma fuente de verdad de la tabla
/// de Fase 1 en columnas y permite inspeccionar una tarea, sin editarla.
class TableroKanban extends StatefulWidget {
  const TableroKanban({super.key, required this.tareas});

  final List<Tarea> tareas;

  @override
  State<TableroKanban> createState() => _TableroKanbanState();
}

class _TableroKanbanState extends State<TableroKanban> {
  Tarea? _seleccionada;

  @override
  Widget build(BuildContext context) {
    if (widget.tareas.isEmpty) return const _SinTareasKanban();

    return LayoutBuilder(
      builder: (context, limites) {
        final columnas = [
          for (final definicion in _columnas)
            _ColumnaKanban(
              definicion: definicion,
              tareas: widget.tareas
                  .where((t) => definicion.incluye(t))
                  .toList(),
              seleccionada: _seleccionada,
              alSeleccionar: (tarea) => _abreInspector(tarea),
            ),
        ];

        // Las tarjetas conservan una anchura de lectura; cuando el espacio no
        // alcanza se desplaza el tablero, nunca se aplastan las columnas ni se
        // coloca el inspector encima de una de ellas.
        final anchoTablero = limites.maxWidth > 1192
            ? limites.maxWidth
            : 1192.0;
        return Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: anchoTablero,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < columnas.length; i++) ...[
                    Expanded(child: columnas[i]),
                    if (i != columnas.length - 1) const SizedBox(width: 16),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _abreInspector(Tarea tarea) async {
    setState(() => _seleccionada = tarea);
    await showDialog<void>(
      context: context,
      builder: (_) => _InspectorTarea(tarea: tarea),
    );
    if (mounted) setState(() => _seleccionada = null);
  }
}

class _DefinicionColumna {
  const _DefinicionColumna(this.titulo, this.estado, this.color);

  final String titulo;
  final EstadoTarea estado;
  final Color Function(PaletaDatos) color;

  // Un estado nuevo no desaparece del tablero: queda en espera hasta que el
  // contrato declare su columna propia, conservando su literal en la tarjeta.
  bool incluye(Tarea tarea) =>
      tarea.estado == estado ||
      (estado == EstadoTarea.abierta &&
          tarea.estado == EstadoTarea.desconocido);
}

final _columnas = [
  // El orden y la relación vienen de docs/diseño/README.md. La API aún no
  // distingue "en curso" de "abierta", así que no se infiere actividad.
  _DefinicionColumna('EN ESPERA', EstadoTarea.entregada, (p) => p.tintaTenue),
  _DefinicionColumna('EN PROGRESO', EstadoTarea.abierta, (p) => p.series.first),
  _DefinicionColumna(
    'NECESITA DECISIÓN',
    EstadoTarea.esperando,
    (p) => p.aviso,
  ),
  _DefinicionColumna('FINALIZADAS', EstadoTarea.integrada, (p) => p.bien),
];

class _ColumnaKanban extends StatelessWidget {
  const _ColumnaKanban({
    required this.definicion,
    required this.tareas,
    required this.seleccionada,
    required this.alSeleccionar,
  });

  final _DefinicionColumna definicion;
  final List<Tarea> tareas;
  final Tarea? seleccionada;
  final ValueChanged<Tarea> alSeleccionar;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final color = definicion.color(paleta);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: .38),
        border: Border.all(color: paleta.rejilla),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 10, 9),
            child: Row(
              children: [
                Container(width: 8, height: 8, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    definicion.titulo,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                _Contador(cantidad: tareas.length),
              ],
            ),
          ),
          Divider(height: 1, color: paleta.rejilla),
          Expanded(
            child: tareas.isEmpty
                ? Center(
                    child: Text(
                      'Sin tareas',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: tareas.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, indice) => _TarjetaTarea(
                      tarea: tareas[indice],
                      seleccionada: tareas[indice] == seleccionada,
                      alPulsar: () => alSeleccionar(tareas[indice]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Contador extends StatelessWidget {
  const _Contador({required this.cantidad});
  final int cantidad;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    color: context.paleta.rejilla,
    child: Text('$cantidad', style: Theme.of(context).textTheme.labelSmall),
  );
}

class _TarjetaTarea extends StatelessWidget {
  const _TarjetaTarea({
    required this.tarea,
    required this.seleccionada,
    required this.alPulsar,
  });

  final Tarea tarea;
  final bool seleccionada;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final colorAgente = paleta.serieDe(tarea.dueno);
    return Material(
      color: seleccionada
          ? colorAgente.withValues(alpha: .15)
          : Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: alPulsar,
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: colorAgente, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    tarea.id,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: colorAgente),
                  ),
                  const Spacer(),
                  Text(
                    tarea.dueno,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                tarea.titulo,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tarea.rama,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tarea.estadoCrudo,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InspectorTarea extends StatelessWidget {
  const _InspectorTarea({required this.tarea});
  final Tarea? tarea;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    if (tarea == null) return const SizedBox.shrink();
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: paleta.acentoAlt.withValues(alpha: .8)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'INSPECTOR DE TAREA',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar inspector',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 14),
              Text(
                tarea!.id,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: paleta.serieDe(tarea!.dueno),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                tarea!.titulo,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              _Dato(etiqueta: 'ESTADO ACTUAL', valor: tarea!.estadoCrudo),
              _Dato(etiqueta: 'AGENTE ASIGNADO', valor: tarea!.dueno),
              _Dato(etiqueta: 'RAMA GIT', valor: tarea!.rama),
              _Dato(etiqueta: 'ABIERTA', valor: _fecha(tarea!.abierta)),
              const SizedBox(height: 8),
              Text(
                'ACCIONES DE FASE (SOLO LECTURA)',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 8),
              const _AccionFutura(etiqueta: 'REASIGNAR AGENTE', fase: 'Fase 2'),
              const SizedBox(height: 8),
              const _AccionFutura(
                etiqueta: 'CERRAR O EDITAR TAREA',
                fase: 'Fase 2',
              ),
              const SizedBox(height: 8),
              const _AccionFutura(
                etiqueta: 'RESPONDER PREGUNTA',
                fase: 'Fase 3',
              ),
              const SizedBox(height: 8),
              const _AccionFutura(
                etiqueta: 'INSPECCIÓN DE DIFFS',
                fase: 'Fase 4',
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fecha(DateTime fecha) =>
      '${fecha.year.toString().padLeft(4, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
}

class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, required this.valor});
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        Text(
          valor,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
        ),
      ],
    ),
  );
}

class _AccionFutura extends StatelessWidget {
  const _AccionFutura({required this.etiqueta, required this.fase});
  final String etiqueta;
  final String fase;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: null,
    child: Row(
      children: [
        Expanded(child: Text(etiqueta)),
        Text(fase),
      ],
    ),
  );
}

class _SinTareasKanban extends StatelessWidget {
  const _SinTareasKanban();

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      'No hay tareas abiertas.',
      style: Theme.of(context).textTheme.bodyMedium,
    ),
  );
}
