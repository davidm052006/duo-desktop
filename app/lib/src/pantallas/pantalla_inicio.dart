import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../estado/estado_tablero.dart';
import '../modelos/resumen.dart';
import '../modelos/tablero.dart';
import '../tema/paleta.dart';
import '../widgets/panel_fallo.dart';
import '../widgets/tarjeta.dart';

/// Inicio: el centro de control.
///
/// Es la vista que contesta de un vistazo "¿quién está haciendo qué y qué me
/// toca a mí?". Todo lo que enseña sale de `GET /board`; lo que todavía no
/// tiene fuente aparece dicho con su fase, nunca relleno con datos de adorno.
class PantallaInicio extends StatelessWidget {
  const PantallaInicio({super.key});

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

  /// Por debajo de esto las dos columnas de la zona media se pisan y el panel
  /// de carga se queda sin sitio para las barras.
  static const _anchoDosColumnas = 1040.0;

  /// El margen del `ListView`, a los dos lados. Las tarjetas se reparten el
  /// ancho que queda, no el de la ventana.
  static const _margen = 28.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, caja) {
        final util = caja.maxWidth - _margen * 2;
        final anchas = util >= _anchoDosColumnas;

        final agentes = _PanelAgentes(resumen: resumen);
        final carga = _PanelCarga(resumen: resumen);

        return ListView(
          padding: const EdgeInsets.fromLTRB(_margen, 24, _margen, 36),
          children: [
            _Cabecera(tablero: tablero, estado: estado),
            const SizedBox(height: 24),
            _FilaResumen(resumen: resumen, estado: estado, ancho: util),
            const SizedBox(height: 18),
            if (anchas)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: agentes),
                    const SizedBox(width: 18),
                    Expanded(flex: 2, child: carga),
                  ],
                ),
              )
            else ...[
              agentes,
              const SizedBox(height: 18),
              carga,
            ],
            const SizedBox(height: 18),
            _PanelMovimientos(tablero: tablero),
          ],
        );
      },
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.tablero, required this.estado});

  final Tablero tablero;
  final EstadoTablero estado;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;
    final proyecto = tablero.proyecto;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Centro de control', style: textos.headlineSmall?.copyWith(fontSize: 26)),
                  const SizedBox(width: 12),
                  Insignia('repo local', tono: paleta.acentoAlt),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.folder_outlined, size: 14, color: paleta.tintaTenue),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Mono(
                      proyecto == null || proyecto.repo.isEmpty
                          ? 'proyecto sin ruta declarada'
                          : proyecto.repo,
                      color: paleta.tintaSecundaria,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    estado.obsoleto
                        ? 'datos de la última lectura buena'
                        : 'leído ${_hora(estado.ultimaLectura)}',
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
        const SizedBox(width: 10),
        // Crear tareas es escritura: el servicio todavía es de solo lectura.
        Tooltip(
          message: 'Abrir tareas desde la app llega en la Fase 2. Hoy: duo "lo que quieras"',
          child: FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Nueva tarea · Fase 2'),
          ),
        ),
      ],
    );
  }

  static String _hora(DateTime? d) {
    if (d == null) return 'nunca';
    String dd(int n) => n.toString().padLeft(2, '0');
    return '${dd(d.hour)}:${dd(d.minute)}:${dd(d.second)}';
  }
}

/// Las cuatro tarjetas de arriba. Se reparten el ancho disponible y bajan a dos
/// filas cuando la ventana se estrecha.
class _FilaResumen extends StatelessWidget {
  const _FilaResumen({required this.resumen, required this.estado, required this.ancho});

  final ResumenInicio resumen;
  final EstadoTablero estado;
  final double ancho;

  @override
  Widget build(BuildContext context) {
    const hueco = 18.0;
    final columnas = ancho >= 1180 ? 4 : (ancho >= 620 ? 2 : 1);

    final tarjetas = <Widget>[
      _TarjetaAgentes(resumen: resumen),
      _TarjetaTareas(resumen: resumen),
      _TarjetaPreguntas(resumen: resumen),
      _TarjetaLectura(estado: estado),
    ];

    // Fila a fila, en vez de `Wrap`: así las tarjetas que comparten fila
    // comparten también altura y la rejilla no queda dentada.
    return Column(
      children: [
        for (var i = 0; i < tarjetas.length; i += columnas)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : hueco),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < columnas; j++) ...[
                    if (j > 0) const SizedBox(width: hueco),
                    Expanded(
                      child: i + j < tarjetas.length
                          ? tarjetas[i + j]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TarjetaAgentes extends StatelessWidget {
  const _TarjetaAgentes({required this.resumen});

  final ResumenInicio resumen;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;

    return Tarjeta(
      titulo: 'Agentes',
      icono: Icons.hub_outlined,
      sufijo: Text(
        '${resumen.activos} con tarea',
        style: Theme.of(context).textTheme.labelSmall,
      ),
      pie: Row(
        children: [
          Expanded(
            child: Text(
              'Estado deducido del tablero',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          // Saber si el proceso del agente sigue vivo exige hablar con el CLI.
          const MarcaFase(2),
        ],
      ),
      hijo: Column(
        children: [
          for (final a in resumen.agentes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Mono(
                      '${a.nombre} (${a.alias})',
                      color: paleta.tintaSecundaria,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _PuntoEstado(estado: a.estado),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TarjetaTareas extends StatelessWidget {
  const _TarjetaTareas({required this.resumen});

  final ResumenInicio resumen;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Tarjeta(
      titulo: 'Tareas',
      icono: Icons.check_circle_outline,
      sufijo: Text('${resumen.totalTareas} total', style: textos.titleMedium),
      pie: Row(
        children: [
          Expanded(
            child: Text('Estados reales de duo', style: textos.labelSmall),
          ),
          Text(
            resumen.pendientesDeDecision.isEmpty
                ? 'sin bloqueos'
                : '${resumen.pendientesDeDecision.length} bloqueada(s)',
            style: textos.bodySmall?.copyWith(
              color: resumen.pendientesDeDecision.isEmpty
                  ? context.paleta.bien
                  : context.paleta.acento,
            ),
          ),
        ],
      ),
      hijo: Column(
        children: [
          for (var i = 0; i < ColumnaTablero.values.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  for (final c in ColumnaTablero.values.skip(i).take(2))
                    Expanded(child: _Celda(columna: c, valor: resumen.porColumna[c] ?? 0)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Celda extends StatelessWidget {
  const _Celda({required this.columna, required this.valor});

  final ColumnaTablero columna;
  final int valor;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(columna.etiqueta.toUpperCase(), style: textos.labelSmall),
        const SizedBox(height: 2),
        Text('$valor', style: textos.headlineSmall),
        // El estado literal de `BOARD.md`: la columna es nuestra lectura, el
        // estado es el dato.
        Mono(columna.estado.name, color: context.paleta.tintaTenue),
      ],
    );
  }
}

class _TarjetaPreguntas extends StatelessWidget {
  const _TarjetaPreguntas({required this.resumen});

  final ResumenInicio resumen;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;
    final pendientes = resumen.pendientesDeDecision;

    return Tarjeta(
      titulo: 'Preguntas',
      icono: Icons.help_outline,
      sufijo: pendientes.isEmpty
          ? Insignia('al día', tono: paleta.bien)
          : Insignia('${pendientes.length} pendiente(s)', tono: paleta.acento),
      pie: Row(
        children: [
          Expanded(
            child: Text('Responder desde la app', style: textos.labelSmall),
          ),
          const MarcaFase(3),
        ],
      ),
      hijo: pendientes.isEmpty
          ? Text(
              'Ningún agente está esperando una decisión tuya.',
              style: textos.bodySmall,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('ORIGEN', style: textos.labelSmall),
                    const SizedBox(width: 8),
                    Mono(pendientes.first.dueno, color: paleta.acento, peso: FontWeight.w600),
                    const Spacer(),
                    Mono(pendientes.first.id, color: paleta.tintaTenue),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  pendientes.first.titulo,
                  style: textos.bodySmall,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Decirlo evita el malentendido de creer que esto es la
                // pregunta: es la tarea que la hizo.
                Text(
                  'El texto de la pregunta vive en la sesión del agente; '
                  'la app lo leerá cuando exista GET /questions.',
                  style: textos.bodySmall?.copyWith(color: paleta.tintaTenue),
                ),
              ],
            ),
    );
  }
}

/// De dónde vienen los datos y cuándo se leyeron. Ocupa el sitio que en el
/// diseño tiene la actividad en vivo, que todavía no tiene fuente.
class _TarjetaLectura extends StatelessWidget {
  const _TarjetaLectura({required this.estado});

  final EstadoTablero estado;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;

    return Tarjeta(
      titulo: 'Actividad',
      icono: Icons.history,
      sufijo: Text('en disco', style: textos.labelSmall),
      pie: Row(
        children: [
          Expanded(
            child: Text('Eventos en vivo por WebSocket', style: textos.labelSmall),
          ),
          const MarcaFase(2),
        ],
      ),
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Dato(
            etiqueta: 'Origen',
            valor: estado.tablero?.proyecto?.pizarra.isNotEmpty == true
                ? '${estado.tablero!.proyecto!.pizarra}/.team'
                : '.team/BOARD.md',
          ),
          const SizedBox(height: 8),
          _Dato(etiqueta: 'Refresco', valor: 'sondeo cada ${estado.intervalo.inSeconds}s'),
          const SizedBox(height: 8),
          _Dato(
            etiqueta: 'Última',
            valor: estado.obsoleto ? 'falló: ${estado.fallo!.codigo}' : 'correcta',
            tono: estado.obsoleto ? paleta.aviso : paleta.bien,
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, required this.valor, this.tono});

  final String etiqueta;
  final String valor;
  final Color? tono;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 68,
        child: Text(etiqueta.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
      ),
      Expanded(child: Mono(valor, color: tono ?? context.paleta.tintaSecundaria)),
    ],
  );
}

/// Una ficha por agente: qué tiene asignado y qué puede hacer David con él.
class _PanelAgentes extends StatelessWidget {
  const _PanelAgentes({required this.resumen});

  final ResumenInicio resumen;

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      titulo: 'Estado de los agentes',
      icono: Icons.tune,
      sufijo: Text(
        '${resumen.agentes.length} en el ledger',
        style: Theme.of(context).textTheme.labelSmall,
      ),
      hijo: Column(
        children: [
          for (final a in resumen.agentes)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _FichaAgente(agente: a),
            ),
        ],
      ),
    );
  }
}

class _FichaAgente extends StatelessWidget {
  const _FichaAgente({required this.agente});

  final ResumenAgente agente;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;
    final tarea = agente.tarea;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: paleta.rejilla),
        borderRadius: BorderRadius.circular(8),
        // El color del agente entra por el canto: identifica sin teñir texto.
        gradient: LinearGradient(
          colors: [paleta.serieDe(agente.alias).withValues(alpha: 0.07), Colors.transparent],
          stops: const [0, 0.35],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: paleta.serieDe(agente.alias),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 9),
              Text(agente.nombre, style: textos.titleMedium),
              const SizedBox(width: 8),
              Insignia('alias: ${agente.alias}', tono: paleta.tintaSecundaria, mono: true),
              const Spacer(),
              _PuntoEstado(estado: agente.estado),
            ],
          ),
          const SizedBox(height: 12),
          Text('TAREA ASIGNADA', style: textos.labelSmall),
          const SizedBox(height: 4),
          if (tarea == null)
            Text(
              'Ninguna tarea activa',
              style: textos.bodyMedium?.copyWith(
                color: paleta.tintaTenue,
                fontStyle: FontStyle.italic,
              ),
            )
          else ...[
            Text(tarea.titulo, style: textos.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                Mono(tarea.id, color: paleta.tintaSecundaria, peso: FontWeight.w600),
                const SizedBox(width: 10),
                Flexible(child: Mono(tarea.rama, color: paleta.tintaTenue)),
              ],
            ),
            if (agente.activas > 1) ...[
              const SizedBox(height: 4),
              Text(
                'y ${agente.activas - 1} tarea(s) más sin cerrar',
                style: textos.bodySmall?.copyWith(color: paleta.tintaTenue),
              ),
            ],
          ],
          const SizedBox(height: 12),
          _Acciones(estado: agente.estado),
        ],
      ),
    );
  }
}

/// Lo que se podrá hacer con el agente, según en qué esté.
///
/// Van apagadas y con su fase escrita: el diseño pide enseñar a dónde va la app
/// en vez de esconder lo que falta, y un botón que no hace nada sin avisar es
/// peor que un botón apagado que lo dice.
class _Acciones extends StatelessWidget {
  const _Acciones({required this.estado});

  final EstadoAgente estado;

  static const _porEstado = {
    EstadoAgente.trabajando: [
      ('Ver terminal', Icons.terminal, 5),
      ('Pausar', Icons.pause, 2),
    ],
    EstadoAgente.esperandoDecision: [
      ('Ver pregunta', Icons.help_outline, 3),
      ('Reanudar', Icons.play_arrow, 3),
    ],
    EstadoAgente.entregado: [
      ('Ver cambios', Icons.difference_outlined, 4),
      ('Integrar', Icons.merge, 2),
    ],
    EstadoAgente.disponible: [
      ('Asignar tarea', Icons.assignment_outlined, 2),
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (final (nombre, icono, fase) in _porEstado[estado]!) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: '$nombre llega en la Fase $fase.',
            child: OutlinedButton.icon(
              onPressed: null,
              icon: Icon(icono, size: 15),
              label: Text('$nombre · Fase $fase'),
            ),
          ),
        ],
      ],
    );
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

/// Reparto del trabajo vivo. Cuenta tareas y lo dice: no estima tokens, ni
/// tiempo, ni "esfuerzo" — igual que el ledger (`docs/diseno/README.md`).
class _PanelCarga extends StatelessWidget {
  const _PanelCarga({required this.resumen});

  final ResumenInicio resumen;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;

    return Tarjeta(
      titulo: 'Carga de trabajo',
      icono: Icons.bar_chart,
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distribución por cantidad de tareas sin cerrar '
            '(total: ${resumen.activas}).',
            style: textos.bodySmall,
          ),
          const SizedBox(height: 18),
          if (resumen.activas == 0)
            Text('Nadie tiene trabajo abierto.', style: textos.bodySmall)
          else
            for (final a in resumen.agentes)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _BarraCarga(agente: a),
              ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 14, color: paleta.tintaTenue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Basado estrictamente en el número de tareas del tablero, '
                  'sin estimación de recursos ni de tokens.',
                  style: textos.bodySmall?.copyWith(color: paleta.tintaTenue),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarraCarga extends StatelessWidget {
  const _BarraCarga({required this.agente});

  final ResumenAgente agente;

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
            Expanded(
              child: Mono('${agente.alias} (${agente.nombre})', color: paleta.tintaSecundaria),
            ),
            const SizedBox(width: 8),
            Text(
              '${agente.activas} tarea(s) · $pct%',
              style: textos.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: 8,
            color: paleta.rejilla,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: agente.carga.clamp(0.0, 1.0),
              child: ColoredBox(
                color: paleta.serieDe(agente.alias),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Lo último que pasó en el tablero, por fecha de apertura.
///
/// No es la actividad del sistema de archivos del diseño: eso necesita el
/// vigilante y el WebSocket de la Fase 2. Esto es lo que sí se puede afirmar
/// hoy sin inventar nada.
class _PanelMovimientos extends StatelessWidget {
  const _PanelMovimientos({required this.tablero});

  final Tablero tablero;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;

    final recientes = [...tablero.tareas]
      ..sort((a, b) => b.abierta.compareTo(a.abierta));

    return Tarjeta(
      titulo: 'Actividad del tablero',
      icono: Icons.folder_open,
      sufijo: Text('leído de .team', style: textos.labelSmall),
      pie: Row(
        children: [
          Icon(Icons.wifi_tethering, size: 15, color: paleta.tintaTenue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Los eventos en vivo (ediciones de archivos, salida de los agentes) '
              'llegan por WebSocket en la Fase 2. Esta vista se refresca por sondeo.',
              style: textos.bodySmall?.copyWith(color: paleta.tintaTenue),
            ),
          ),
          const MarcaFase(2),
        ],
      ),
      hijo: recientes.isEmpty
          ? Text('El tablero está vacío.', style: textos.bodySmall)
          : Column(
              children: [
                for (final t in recientes.take(5))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          color: paleta.serieDe(t.dueno),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(width: 56, child: Mono(t.dueno, peso: FontWeight.w600)),
                        SizedBox(width: 56, child: Mono(t.id, color: paleta.tintaSecundaria)),
                        Expanded(
                          child: Text(
                            t.titulo,
                            style: textos.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Insignia(t.estadoCrudo, tono: paleta.tintaSecundaria),
                        const SizedBox(width: 12),
                        Mono(_fecha(t.abierta), color: paleta.tintaTenue),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  static String _fecha(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
