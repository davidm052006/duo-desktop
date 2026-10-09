import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../actualizaciones/estado_actualizacion.dart';
import '../estado/estado_proyecto_activo.dart';
import '../estado/estado_tablero.dart';
import '../tema/paleta.dart';
import '../widgets/fondo_cyber_animado.dart';
import '../widgets/tarjeta.dart';
import 'fondo_video_config.dart';
import 'fondo_video_reproductor.dart';
import 'pantalla_agentes.dart';
import 'pantalla_chats.dart';
import 'pantalla_configuracion.dart';
import 'pantalla_github.dart';
import 'pantalla_historial.dart';
import 'pantalla_inicio.dart';
import 'pantalla_personalizacion.dart';
import 'pantalla_proyectos.dart';
import 'pantalla_preguntas.dart';
import 'pantalla_tablero.dart';
import 'pantalla_tareas.dart';
import 'pantalla_terminal.dart';
import 'pantalla_visualizaciones.dart';

class Destino {
  const Destino(this.nombre, this.icono, {this.fase});

  final String nombre;
  final IconData icono;
  final int? fase;

  bool get listo => fase == null;
}

const destinosTrabajo = [
  Destino('Inicio', Icons.home_outlined),
  Destino('Proyectos', Icons.account_tree_outlined),
  Destino('Tablero', Icons.view_week_outlined),
  Destino('Tareas', Icons.check_circle_outline),
  Destino('Agentes', Icons.hub_outlined),
  Destino('Chats', Icons.chat_bubble_outline),
  Destino('Preguntas', Icons.help_outline),
  Destino('Terminal', Icons.code),
  Destino('GitHub', Icons.commit_outlined),
  Destino('Historial', Icons.history),
  Destino('Visualizaciones', Icons.show_chart),
];

const destinosPreferencias = [
  Destino('Personalización', Icons.palette_outlined),
  Destino('Configuración', Icons.settings_outlined),
];

const destinos = [...destinosTrabajo, ...destinosPreferencias];

class MarcoApp extends StatefulWidget {
  const MarcoApp({super.key});

  @override
  State<MarcoApp> createState() => _MarcoAppState();
}

class _MarcoAppState extends State<MarcoApp> with WidgetsBindingObserver {
  int _activo = 0;
  Timer? _temporizadorFondo;
  String _modoFondo = 'ninguno';
  String? _videoSeleccionado;
  String? _estadoFondoVideo;
  List<File> _videos = const [];
  final Set<String> _videosFallidos = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FondoVideoConfig.cambios.addListener(_cargarFondo);
    _cargarFondo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FondoVideoConfig.cambios.removeListener(_cargarFondo);
    _temporizadorFondo?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cargarFondo();
    }
  }

  Future<void> _cargarFondo() async {
    _temporizadorFondo?.cancel();

    try {
      final prefs = await SharedPreferences.getInstance();
      final modo = prefs.getString(FondoVideoConfig.fondoKey) ?? 'ninguno';

      if (!FondoVideoConfig.esModoVideo(modo)) {
        if (!mounted) return;
        setState(() {
          _modoFondo = modo;
          _videoSeleccionado = null;
          _estadoFondoVideo = null;
          _videos = const [];
          _videosFallidos.clear();
        });
        return;
      }

      final carpeta = prefs.getString(FondoVideoConfig.carpetaKey) ?? '';
      final intervalo = FondoVideoConfig.normalizarIntervalo(
        prefs.getInt(FondoVideoConfig.intervaloKey),
      );

      if (carpeta.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _modoFondo = modo;
          _videoSeleccionado = null;
          _estadoFondoVideo = 'Elige una carpeta de vídeos en Personalización.';
          _videos = const [];
          _videosFallidos.clear();
        });
        return;
      }

      final videos = await FondoVideoConfig.videosEn(carpeta);
      if (!mounted) return;

      _videosFallidos.clear();
      setState(() {
        _modoFondo = modo;
        _videos = videos;
      });
      _seleccionarSiguiente();

      if (videos.isNotEmpty) {
        _temporizadorFondo = Timer.periodic(
          Duration(minutes: intervalo),
          (_) => _seleccionarSiguiente(),
        );
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _modoFondo = 'video';
        _videoSeleccionado = null;
        _estadoFondoVideo = 'No se pudo preparar el fondo de vídeo: $e';
        _videos = const [];
        _videosFallidos.clear();
      });
    }
  }

  void _seleccionarSiguiente() {
    if (!FondoVideoConfig.esModoVideo(_modoFondo)) return;

    final elegido = FondoVideoConfig.aleatorio(
      _videos,
      excluirRuta: _videos.length > 1 ? _videoSeleccionado : null,
      excluirRutas: _videosFallidos,
    );

    if (!mounted) return;
    setState(() {
      _videoSeleccionado = elegido?.path;
      _estadoFondoVideo = elegido == null
          ? (_videos.isEmpty
              ? 'La carpeta no contiene vídeos compatibles.'
              : 'No quedan vídeos reproducibles en esta carpeta.')
          : null;
    });
  }

  void _videoFallo(String mensaje) {
    final actual = _videoSeleccionado;
    if (actual == null) return;

    _videosFallidos.add(actual);
    _seleccionarSiguiente();

    if (_videoSeleccionado == null && mounted) {
      setState(() {
        _estadoFondoVideo = 'No quedan vídeos reproducibles. Último error: $mensaje';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _FondoBase(modo: _modoFondo),
          if (FondoVideoConfig.esModoVideo(_modoFondo) &&
              _videoSeleccionado != null)
            FondoVideoReproductor(
              key: ValueKey(_videoSeleccionado),
              ruta: _videoSeleccionado!,
              alFallar: _videoFallo,
            ),
          const FondoCyberAnimado(),
          Column(
            children: [
              _BarraMarca(
                mostrarEstadoVideo: FondoVideoConfig.esModoVideo(_modoFondo),
                videoSeleccionado: _videoSeleccionado,
                estadoFondoVideo: _estadoFondoVideo,
              ),
              Divider(height: 1, color: paleta.rejilla),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _BarraLateral(
                      activo: _activo,
                      alElegir: (i) => setState(() => _activo = i),
                    ),
                    VerticalDivider(width: 1, color: paleta.rejilla),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final estado = context.watch<EstadoTablero>();
                          final proyectoCloud =
                              context.watch<EstadoProyectoActivo?>()?.proyecto;
                          final nombre = destinos[_activo].nombre;
                          final libreDeBoard = nombre == 'Proyectos' ||
                              nombre == 'Chats' ||
                              nombre == 'Personalización' ||
                              nombre == 'Configuración' ||
                              (nombre == 'Tablero' && proyectoCloud != null);

                          if (estado.sinProyectoLocal && !libreDeBoard) {
                            return _ProyectoLocalPendiente(
                              irAProyectos: () => setState(
                                () => _activo = destinos.indexWhere(
                                  (d) => d.nombre == 'Proyectos',
                                ),
                              ),
                            );
                          }

                          return switch (nombre) {
                            'Proyectos' => const PantallaProyectos(),
                            'Tablero' => const PantallaTablero(),
                            'Tareas' => const PantallaTareas(),
                            'Agentes' => const PantallaAgentes(),
                            'Chats' => const PantallaChats(),
                            'Preguntas' => const PantallaPreguntas(),
                            'Terminal' => const PantallaTerminal(),
                            'GitHub' => const PantallaGitHub(),
                            'Historial' => const PantallaHistorial(),
                            'Visualizaciones' => const PantallaVisualizaciones(),
                            'Personalización' => const PantallaPersonalizacion(),
                            'Configuración' => const PantallaConfiguracion(),
                            _ => const PantallaInicio(),
                          };
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FondoBase extends StatelessWidget {
  const _FondoBase({required this.modo});

  final String modo;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    if (modo == 'degradado') {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              paleta.acento.withValues(alpha: .16),
              paleta.acentoAlt.withValues(alpha: .10),
              paleta.superficie,
            ],
          ),
        ),
      );
    }

    return ColoredBox(color: paleta.superficie);
  }
}

class _BarraMarca extends StatelessWidget {
  const _BarraMarca({
    required this.mostrarEstadoVideo,
    this.videoSeleccionado,
    this.estadoFondoVideo,
  });

  final bool mostrarEstadoVideo;
  final String? videoSeleccionado;
  final String? estadoFondoVideo;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final estado = context.watch<EstadoTablero>();
    final proyectoCloud = context.watch<EstadoProyectoActivo>().proyecto;
    final repo = proyectoCloud?.repositorio ?? estado.tablero?.proyecto?.repo ?? '';

    return ValueListenableBuilder<double>(
      valueListenable: FondoVideoConfig.opacidadPaneles,
      builder: (context, opacidad, _) => Container(
        height: 56,
        color: paleta.panel,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            Icon(Icons.blur_on, size: 20, color: paleta.acento),
            const SizedBox(width: 10),
            Text(
              'DUO-DESKTOP',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(letterSpacing: 1.2),
            ),
            if (repo.isNotEmpty) ...[
              const SizedBox(width: 18),
              Flexible(
                child: Insignia(
                  repo,
                  tono: paleta.tintaSecundaria,
                  mono: true,
                ),
              ),
            ],
            const Spacer(),
            const _CentroNotificaciones(),
            const SizedBox(width: 12),
            if (mostrarEstadoVideo &&
                (videoSeleccionado != null || estadoFondoVideo != null)) ...[
              Tooltip(
                message: estadoFondoVideo ??
                    'Vídeo de fondo: $videoSeleccionado',
                child: Icon(
                  estadoFondoVideo == null
                      ? Icons.video_library_outlined
                      : Icons.video_file_outlined,
                  size: 16,
                  color: estadoFondoVideo == null
                      ? paleta.acentoAlt
                      : paleta.aviso,
                ),
              ),
              const SizedBox(width: 12),
            ],
            _Conexion(
              conectado: estado.servicioLocalResponde,
              proyectoPendiente: estado.sinProyectoLocal,
            ),
            const SizedBox(width: 12),
            const Row(
              children: [
                Icon(Icons.terminal, size: 15),
                SizedBox(width: 6),
                Text('Terminal'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CentroNotificaciones extends StatelessWidget {
  const _CentroNotificaciones();

  @override
  Widget build(BuildContext context) {
    // Algunas vistas se reutilizan en previsualizaciones sin el proveedor
    // global; en ese caso se muestra la campana desactivada.
    final actualizaciones = context.watch<EstadoActualizacion?>();
    final paleta = context.paleta;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notificaciones',
          icon: const Icon(Icons.notifications_none, size: 20),
          onPressed: actualizaciones == null
              ? null
              : () {
            actualizaciones.marcaLeida();
            showDialog<void>(
              context: context,
              builder: (_) => const _DialogoNotificaciones(),
            );
          },
        ),
        if (actualizaciones?.hayActualizacion == true && !actualizaciones!.leida)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: paleta.acento,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class _DialogoNotificaciones extends StatelessWidget {
  const _DialogoNotificaciones();

  @override
  Widget build(BuildContext context) {
    final actualizaciones = context.watch<EstadoActualizacion>();
    final paleta = context.paleta;
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.notifications_outlined),
          SizedBox(width: 10),
          Text('Notificaciones'),
        ],
      ),
      content: SizedBox(
        width: 390,
        child: actualizaciones.hayActualizacion
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Actualización ${actualizaciones.versionNueva} disponible',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    actualizaciones.obligatoria
                        ? 'Esta actualización es obligatoria.'
                        : 'Está lista para instalarse. Duo se reiniciará automáticamente.',
                  ),
                  if (actualizaciones.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      actualizaciones.error!,
                      style: TextStyle(color: paleta.aviso),
                    ),
                  ],
                ],
              )
            : Text(
                actualizaciones.comprobando
                    ? 'Buscando actualizaciones…'
                    : actualizaciones.error == null
                    ? 'No tienes notificaciones nuevas.'
                    : 'No se pudo comprobar actualizaciones. Puedes seguir trabajando y Duo volverá a intentarlo.',
              ),
      ),
      actions: [
        TextButton(
          onPressed: actualizaciones.comprobando
              ? null
              : actualizaciones.comprueba,
          child: const Text('Comprobar ahora'),
        ),
        if (actualizaciones.hayActualizacion)
          FilledButton.icon(
            onPressed: actualizaciones.instalando
                ? null
                : actualizaciones.instalar,
            icon: actualizaciones.instalando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.system_update_alt),
            label: Text(
              actualizaciones.instalando ? 'Preparando…' : 'Actualizar ahora',
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _Conexion extends StatelessWidget {
  const _Conexion({
    required this.conectado,
    required this.proyectoPendiente,
  });

  final bool conectado;
  final bool proyectoPendiente;

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
          !conectado
              ? 'Servicio local sin responder'
              : proyectoPendiente
                  ? 'Servicio conectado · configura un proyecto'
                  : 'Servicio local conectado',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ProyectoLocalPendiente extends StatelessWidget {
  const _ProyectoLocalPendiente({required this.irAProyectos});

  final VoidCallback irAProyectos;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Tarjeta(
            titulo: 'Duo está listo',
            icono: Icons.rocket_launch_outlined,
            sufijo: Insignia('configuración inicial', tono: paleta.acentoAlt),
            hijo: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Todavía no has vinculado un proyecto local en este dispositivo.',
                  style: textos.titleMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'El servicio local está funcionando. Abre Proyectos, selecciona '
                  'tu proyecto y configura el repositorio local para habilitar '
                  'Tablero, Tareas, Agentes, GitHub e Historial.',
                  style: textos.bodyMedium?.copyWith(
                    color: paleta.tintaSecundaria,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: irAProyectos,
                  icon: const Icon(Icons.account_tree_outlined),
                  label: const Text('Ir a Proyectos'),
                ),
              ],
            ),
          ),
        ),
      ),
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
        : estado.tablero!.tareas
            .where((t) => t.estadoCrudo == 'esperando')
            .length;

    return ValueListenableBuilder<double>(
      valueListenable: FondoVideoConfig.opacidadPaneles,
      builder: (context, opacidad, _) => Container(
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
                aviso:
                    destinosTrabajo[i].nombre == 'Preguntas' && esperando > 0
                        ? '$esperando'
                        : null,
                alPulsar:
                    destinosTrabajo[i].listo ? () => alElegir(i) : null,
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
        child: Text(
          texto.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall,
        ),
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
              if (aviso == null && destino.fase != null)
                MarcaFase(destino.fase!),
            ],
          ),
        ),
      ),
    );
  }
}
