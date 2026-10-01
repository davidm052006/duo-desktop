import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../estado/estado_tablero.dart';
import '../tema/paleta.dart';
import '../widgets/tarjeta.dart';
import 'pantalla_agentes.dart';
import 'pantalla_configuracion.dart';
import 'pantalla_github.dart';
import 'pantalla_historial.dart';
import 'pantalla_inicio.dart';
import 'pantalla_personalizacion.dart';
import 'pantalla_preguntas.dart';
import 'pantalla_tablero.dart';
import 'pantalla_tareas.dart';
import 'pantalla_terminal.dart';
import 'pantalla_visualizaciones.dart';

/// Un sitio al que ir desde la barra lateral.
///
/// Los destinos que todavía no existen aparecen con su fase escrita en vez de
/// esconderse, pero no se pueden pulsar: una pantalla en blanco sería peor que
/// una entrada apagada.
class Destino {
  const Destino(this.nombre, this.icono, {this.fase});

  final String nombre;
  final IconData icono;

  /// `null` cuando el destino ya existe.
  final int? fase;

  bool get listo => fase == null;
}

const destinosTrabajo = [
  Destino('Inicio', Icons.home_outlined),
  Destino('Tablero', Icons.view_week_outlined),
  Destino('Tareas', Icons.check_circle_outline),
  Destino('Agentes', Icons.hub_outlined),
  Destino('Preguntas', Icons.help_outline),
  Destino('Terminal', Icons.code, fase: 5),
  Destino('GitHub', Icons.commit_outlined, fase: 4),
  Destino('Historial', Icons.history),
  Destino('Visualizaciones', Icons.show_chart, fase: 6),
];

const destinosPreferencias = [
  Destino('Personalización', Icons.palette_outlined),
  Destino('Configuración', Icons.settings_outlined),
];

const destinos = [...destinosTrabajo, ...destinosPreferencias];

/// El armazón de la app: barra de marca arriba, navegación a la izquierda y la
/// pantalla activa ocupando el resto.
class MarcoApp extends StatefulWidget {
  const MarcoApp({super.key});

  @override
  State<MarcoApp> createState() => _MarcoAppState();
}

class _MarcoAppState extends State<MarcoApp> {
  int _activo = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const _BarraMarca(),
          Divider(height: 1, color: context.paleta.rejilla),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BarraLateral(
                  activo: _activo,
                  alElegir: (i) => setState(() => _activo = i),
                ),
                VerticalDivider(width: 1, color: context.paleta.rejilla),
                Expanded(
                  // Cada sección vive en su propio archivo: así varios agentes
                  // pueden trabajar a la vez sin pisarse en este switch.
                  child: switch (destinos[_activo].nombre) {
                    'Tablero' => const PantallaTablero(),
                    'Tareas' => const PantallaTareas(),
                    'Agentes' => const PantallaAgentes(),
                    'Preguntas' => const PantallaPreguntas(),
                    'Terminal' => const PantallaTerminal(),
                    'GitHub' => const PantallaGitHub(),
                    'Historial' => const PantallaHistorial(),
                    'Visualizaciones' => const PantallaVisualizaciones(),
                    'Personalización' => const PantallaPersonalizacion(),
                    'Configuración' => const PantallaConfiguracion(),
                    _ => const PantallaInicio(),
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarraMarca extends StatelessWidget {
  const _BarraMarca();

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final estado = context.watch<EstadoTablero>();
    final repo = estado.tablero?.proyecto?.repo ?? '';

    return Container(
      height: 56,
      color: paleta.panel,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Icon(Icons.blur_on, size: 20, color: paleta.acento),
          const SizedBox(width: 10),
          Text(
            'DUO-DESKTOP',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(letterSpacing: 1.2),
          ),
          if (repo.isNotEmpty) ...[
            const SizedBox(width: 18),
            Flexible(child: Insignia(repo, tono: paleta.tintaSecundaria, mono: true)),
          ],
          const Spacer(),
          _Conexion(conectado: estado.tablero != null && !estado.obsoleto),
          const SizedBox(width: 12),
          const Row(
            children: [
              Icon(Icons.terminal, size: 15),
              SizedBox(width: 6),
              Text('Terminal'),
              SizedBox(width: 8),
              MarcaFase(5),
            ],
          ),
        ],
      ),
    );
  }
}

class _Conexion extends StatelessWidget {
  const _Conexion({required this.conectado});

  final bool conectado;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final color = conectado ? paleta.acentoAlt : paleta.aviso;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          conectado ? 'Servicio local conectado' : 'Servicio local sin responder',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _BarraLateral extends StatelessWidget {
  const _BarraLateral({required this.activo, required this.alElegir});

  final int activo;
  final ValueChanged<int> alElegir;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final estado = context.watch<EstadoTablero>();
    final esperando = estado.tablero == null
        ? 0
        : estado.tablero!.tareas.where((t) => t.estadoCrudo == 'esperando').length;

    return Container(
      // Lo justo para que "Visualizaciones" quepa entera junto a su fase.
      width: 236,
      color: paleta.panel,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          const _Rotulo('Workspace'),
          for (var i = 0; i < destinosTrabajo.length; i++)
            _Entrada(
              destino: destinosTrabajo[i],
              activa: i == activo,
              // El contador de preguntas sale de las tareas paradas: es lo
              // único que el servicio sabe hoy sobre decisiones pendientes.
              aviso: destinosTrabajo[i].nombre == 'Preguntas' && esperando > 0
                  ? '$esperando'
                  : null,
              alPulsar: destinosTrabajo[i].listo ? () => alElegir(i) : null,
            ),
          const SizedBox(height: 18),
          const _Rotulo('Preferencias'),
          for (var i = 0; i < destinosPreferencias.length; i++)
            _Entrada(
              destino: destinosPreferencias[i],
              activa: activo == destinosTrabajo.length + i,
              alPulsar: destinosPreferencias[i].listo
                  ? () => alElegir(destinosTrabajo.length + i)
                  : null,
            ),
        ],
      ),
    );
  }
}

class _Rotulo extends StatelessWidget {
  const _Rotulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
    child: Text(texto.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
  );
}

class _Entrada extends StatelessWidget {
  const _Entrada({
    required this.destino,
    required this.activa,
    required this.alPulsar,
    this.aviso,
  });

  final Destino destino;
  final bool activa;
  final VoidCallback? alPulsar;
  final String? aviso;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;

    // Un destino que aún no existe se lee más apagado que el resto, y el lector
    // de pantalla lo anuncia como deshabilitado.
    final tinta = activa
        ? paleta.acento
        : destino.listo
            ? paleta.tintaPrincipal
            : paleta.tintaTenue;

    return Semantics(
      selected: activa,
      enabled: destino.listo,
      button: true,
      child: InkWell(
        onTap: alPulsar,
        child: Container(
          decoration: BoxDecoration(
            color: activa ? paleta.acento.withValues(alpha: 0.10) : null,
            border: Border(
              left: BorderSide(
                color: activa ? paleta.acento : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(15.5, 10, 14, 10),
          child: Row(
            children: [
              Icon(destino.icono, size: 17, color: tinta),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  destino.nombre,
                  style: textos.bodyMedium?.copyWith(
                    color: tinta,
                    fontWeight: activa ? FontWeight.w600 : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (aviso != null) Insignia(aviso!, tono: paleta.acento),
              if (aviso == null && destino.fase != null) MarcaFase(destino.fase!),
            ],
          ),
        ),
      ),
    );
  }
}
