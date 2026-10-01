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
  void initState() {
    super.initState();
    _seleccionada = widget.tareas.isEmpty ? null : widget.tareas.first;
  }

  @override
  void didUpdateWidget(covariant TableroKanban oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_seleccionada != null && !widget.tareas.contains(_seleccionada)) {
      _seleccionada = widget.tareas.isEmpty ? null : widget.tareas.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tareas.isEmpty) return const _SinTareasKanban();

    return LayoutBuilder(
      builder: (context, limites) {
        final muestraInspector = limites.maxWidth >= 920;
        final columnas = [
          for (final definicion in _columnas)
            _ColumnaKanban(
              definicion: definicion,
              tareas: widget.tareas
                  .where((t) => definicion.incluye(t))
                  .toList(),
              seleccionada: _seleccionada,
              alSeleccionar: (tarea) => setState(() => _seleccionada = tarea),
            ),
        ];

        final tablero = muestraInspector
            ? GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: columnas,
              )
            : ListView.separated(
                itemCount: columnas.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, indice) =>
                    SizedBox(height: 230, child: columnas[indice]),
              );

        if (!muestraInspector) return tablero;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: tablero),
            const SizedBox(width: 16),
            SizedBox(width: 304, child: _InspectorTarea(tarea: _seleccionada)),
          ],
        );
      },
    );
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
  // El orden y la relación vienen de docs/diseno/README.md. La API aún no
  // distingue "en curso" de "abierta", así que no se infiere actividad.
  _DefinicionColumna('EN ESPERA', EstadoTarea.abierta, (p) => p.tintaTenue),
  _DefinicionColumna(
    'EN PROGRESO',
    EstadoTarea.esperando,
    (p) => p.series.first,
  ),
  _DefinicionColumna(
    'NECESITA DECISIÓN',
    EstadoTarea.entregada,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: .38),
        border: Border.all(color: paleta.rejilla),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              'INSPECTOR DE TAREA',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 18),
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
            _Dato(etiqueta: 'AGENTE ASIGNADO', valor: tarea!.dueno),
            _Dato(etiqueta: 'RAMA GIT', valor: tarea!.rama),
            _Dato(etiqueta: 'ESTADO', valor: tarea!.estadoCrudo),
            _Dato(etiqueta: 'ABIERTA', valor: _fecha(tarea!.abierta)),
            const SizedBox(height: 24),
            const _AccionFutura(etiqueta: 'REASIGNAR AGENTE', fase: 'Fase 2'),
            const SizedBox(height: 8),
            const _AccionFutura(
              etiqueta: 'FORZAR MERGE A MAIN',
              fase: 'Fase 3',
            ),
          ],
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
