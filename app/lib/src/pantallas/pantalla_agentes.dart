import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../estado/estado_tablero.dart';
import '../modelos/resumen.dart';
import '../modelos/tablero.dart';
import '../tema/paleta.dart';
import '../widgets/panel_fallo.dart';
import '../widgets/capacidades_agentes_locales.dart';
import '../widgets/tarjeta.dart';

/// Agentes: una ficha por agente con su carga, su última actividad y las tareas
/// que tiene abiertas.
///
/// Es la vista larga del panel «Estado de los agentes» de Inicio. Las dos
/// fuentes son `board.tasks` (lo que tiene entre manos ahora) y `ledger.agents`
/// (lo que lleva acumulado). Si el proceso del CLI está vivo o no, el servicio
/// todavía no lo sabe, y la ficha lo dice en vez de suponerlo.
class PantallaAgentes extends StatelessWidget {
  const PantallaAgentes({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoTablero>();

    return switch (estado.fase) {
      Fase.inicial || Fase.cargando => const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      Fase.fallo => Padding(
        padding: const EdgeInsets.all(24),
        child: PanelFallo(fallo: estado.fallo!, alReintentar: estado.refresca),
      ),
      Fase.listo => _Contenido(
        tablero: estado.tablero!,
        resumen: ResumenInicio.desde(estado.tablero!),
        estado: estado,
      ),
    };
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.tablero,
    required this.resumen,
    required this.estado,
  });

  final Tablero tablero;
  final ResumenInicio resumen;
  final EstadoTablero estado;

  /// Por debajo de esto una ficha a media anchura deja las tareas abiertas en
  /// una columna de texto demasiado estrecha para leerse.
  static const _anchoDosColumnas = 1040.0;
  static const _margen = 28.0;
  static const _hueco = 18.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, caja) {
        final columnas = caja.maxWidth - _margen * 2 >= _anchoDosColumnas
            ? 2
            : 1;
        final fichas = [
          for (final a in resumen.agentes)
            _Ficha(
              agente: a,
              // Un dueño que todavía no tiene fila en el ledger existe igual:
              // su ficha sale sin acumulado, no se esconde.
              ledger: _ledgerDe(a.alias),
              abiertas: tablero
                  .tareasDe(a.alias)
                  .where((t) => t.estado != EstadoTarea.integrada)
                  .toList(growable: false),
            ),
        ];

        return ListView(
          padding: const EdgeInsets.fromLTRB(_margen, 24, _margen, 36),
          children: [
            _Cabecera(resumen: resumen, estado: estado),
            const SizedBox(height: 22),
            const CapacidadesAgentesLocales(),
            const SizedBox(height: 18),
            if (fichas.isEmpty)
              _SinAgentes()
            else
              for (var i = 0; i < fichas.length; i += columnas)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : _hueco),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var j = 0; j < columnas; j++) ...[
                          if (j > 0) const SizedBox(width: _hueco),
                          Expanded(
                            child: i + j < fichas.length
                                ? fichas[i + j]
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }

  CargaAgente? _ledgerDe(String alias) {
    for (final a in tablero.agentes) {
      if (a.agente == alias) return a;
    }
    return null;
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.resumen, required this.estado});

  final ResumenInicio resumen;
  final EstadoTablero estado;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Agentes',
                    style: textos.headlineSmall?.copyWith(fontSize: 26),
                  ),
                  const SizedBox(width: 12),
                  Insignia(
                    '${resumen.activos} con tarea',
                    tono: paleta.acentoAlt,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.hub_outlined, size: 14, color: paleta.tintaTenue),
                  const SizedBox(width: 6),
                  Text(
                    '${resumen.agentes.length} en el ledger · '
                    '${resumen.activas} tarea(s) sin cerrar repartidas',
                    style: textos.bodySmall?.copyWith(
                      color: paleta.tintaSecundaria,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    estado.obsoleto
                        ? 'datos de la última lectura buena'
                        : 'estado deducido del tablero',
                    style: textos.bodySmall?.copyWith(
                      color: estado.obsoleto ? paleta.aviso : paleta.tintaTenue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          onPressed: estado.refresca,
          icon: const Icon(Icons.sync, size: 16),
          label: const Text('Sincronizar'),
        ),
      ],
    );
  }
}

class _SinAgentes extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Tarjeta(
    titulo: 'Agentes',
    icono: Icons.hub_outlined,
    hijo: Text(
      'El ledger está vacío y ninguna tarea tiene dueño.',
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

/// La ficha de un agente: quién es, cuánto lleva encima, cuándo se le contó
/// algo por última vez y qué tiene abierto ahora mismo.
class _Ficha extends StatelessWidget {
  const _Ficha({
    required this.agente,
    required this.ledger,
    required this.abiertas,
  });

  final ResumenAgente agente;

  /// `null` si el agente tiene tareas pero aún no figura en `ledger.agents`.
  final CargaAgente? ledger;
  final List<Tarea> abiertas;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;
    final color = paleta.serieDe(agente.alias);

    return Tarjeta(
      // El rótulo del panel es el alias, que es como se nombra al agente en el
      // tablero y en la línea de órdenes; el nombre humano va dentro, grande.
      titulo: agente.alias,
      icono: Icons.person_outline,
      sufijo: _PuntoEstado(estado: agente.estado),
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 9),
              Flexible(child: Text(agente.nombre, style: textos.titleMedium)),
              const SizedBox(width: 8),
              Insignia(
                'alias: ${agente.alias}',
                tono: paleta.tintaSecundaria,
                mono: true,
              ),
              const Spacer(),
              if (ledger == null)
                Insignia('fuera del ledger', tono: paleta.aviso),
            ],
          ),
          const SizedBox(height: 16),
          _Carga(agente: agente, ledger: ledger, color: color),
          const SizedBox(height: 16),
          _UltimaActividad(ledger: ledger),
          const SizedBox(height: 16),
          _TareasAbiertas(abiertas: abiertas),
        ],
      ),
    );
  }
}

/// Cuánto del trabajo vivo lleva este agente, y lo que el ledger le tiene
/// contado. Son dos cifras distintas y se dicen por separado: la barra es
/// reparto de *ahora*, el acumulado es histórico.
class _Carga extends StatelessWidget {
  const _Carga({
    required this.agente,
    required this.ledger,
    required this.color,
  });

  final ResumenAgente agente;
  final CargaAgente? ledger;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;
    final pct = (agente.carga * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('CARGA', style: textos.labelSmall)),
            Text(
              '${agente.activas} tarea(s) sin cerrar · $pct% del total',
              style: textos.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: 8,
            color: paleta.rejilla,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: agente.carga.clamp(0.0, 1.0),
              child: ColoredBox(color: color, child: const SizedBox.expand()),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          ledger == null
              ? 'Sin acumulado: no figura en ledger.agents.'
              : 'Acumulado en el ledger: ${ledger!.puntos} pts · '
                    '${ledger!.tareas} tarea(s) contabilizada(s).',
          style: textos.bodySmall?.copyWith(color: paleta.tintaTenue),
        ),
      ],
    );
  }
}

/// La última actividad que consta. Es la fecha `last` del ledger, no la de un
/// vigilante de archivos: se nombra tal cual para no venderla como tiempo real.
class _UltimaActividad extends StatelessWidget {
  const _UltimaActividad({required this.ledger});

  final CargaAgente? ledger;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;
    final ultima = ledger?.ultima;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text('ÚLTIMA ACTIVIDAD', style: textos.labelSmall),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    ultima == null
                        ? Icons.remove
                        : Icons.event_available_outlined,
                    size: 14,
                    color: ultima == null ? paleta.tintaTenue : paleta.bien,
                  ),
                  const SizedBox(width: 7),
                  Mono(
                    ultima == null
                        ? 'sin actividad registrada'
                        : _fecha(ultima),
                    color: ultima == null
                        ? paleta.tintaTenue
                        : paleta.tintaSecundaria,
                    peso: FontWeight.w600,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Fecha del campo last del ledger: la última tarea que se le '
                'contabilizó, no su último evento en disco.',
                style: textos.bodySmall?.copyWith(color: paleta.tintaTenue),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _fecha(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Todo lo suyo que no está integrado, no sólo la tarea que mejor lo resume.
class _TareasAbiertas extends StatelessWidget {
  const _TareasAbiertas({required this.abiertas});

  final List<Tarea> abiertas;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('TAREAS ABIERTAS', style: textos.labelSmall)),
            Text('${abiertas.length}', style: textos.bodySmall),
          ],
        ),
        const SizedBox(height: 8),
        if (abiertas.isEmpty)
          Text(
            'Ninguna tarea activa',
            style: textos.bodyMedium?.copyWith(
              color: paleta.tintaTenue,
              fontStyle: FontStyle.italic,
            ),
          )
        else
          for (final t in abiertas)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 58,
                        child: Mono(t.id, peso: FontWeight.w600),
                      ),
                      Expanded(
                        child: Text(
                          t.titulo,
                          style: textos.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Insignia(t.estadoCrudo, tono: _tono(context, t.estado)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Padding(
                    padding: const EdgeInsets.only(left: 58),
                    child: Mono(t.rama, color: paleta.tintaTenue),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  /// Los colores de estado están reservados y nunca van solos: la insignia
  /// lleva siempre el estado escrito al lado del tono.
  static Color _tono(BuildContext context, EstadoTarea estado) {
    final paleta = context.paleta;
    return switch (estado) {
      EstadoTarea.abierta => paleta.series.first,
      EstadoTarea.esperando => paleta.aviso,
      EstadoTarea.entregada => paleta.bien,
      EstadoTarea.integrada => paleta.tintaSecundaria,
      EstadoTarea.desconocido => paleta.tintaTenue,
    };
  }
}

/// Estado del agente: cuadrado de color *y* palabra. Nunca el color solo.
class _PuntoEstado extends StatelessWidget {
  const _PuntoEstado({required this.estado});

  final EstadoAgente estado;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final color = switch (estado) {
      EstadoAgente.trabajando => paleta.acentoAlt,
      EstadoAgente.esperandoDecision => paleta.acento,
      EstadoAgente.entregado => paleta.bien,
      EstadoAgente.disponible => paleta.tintaTenue,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 7),
        Text(
          estado.etiqueta,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
