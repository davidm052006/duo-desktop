import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class FondoVideoReproductor extends StatefulWidget {
  const FondoVideoReproductor({
    super.key,
    required this.ruta,
    required this.alFallar,
  });

  final String ruta;
  final ValueChanged<String> alFallar;

  @override
  State<FondoVideoReproductor> createState() => _FondoVideoReproductorState();
}

class _FondoVideoReproductorState extends State<FondoVideoReproductor> {
  late final Player _player;
  late final VideoController _controller;
  StreamSubscription<String>? _errores;
  String? _rutaEnFallo;

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: const PlayerConfiguration(
        muted: true,
        title: 'duo-desktop background',
      ),
    );
    _controller = VideoController(_player);
    _errores = _player.stream.error.listen(_manejarError);
    _abrir(widget.ruta);
  }

  @override
  void didUpdateWidget(covariant FondoVideoReproductor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ruta != oldWidget.ruta) {
      _rutaEnFallo = null;
      _abrir(widget.ruta);
    }
  }

  Future<void> _abrir(String ruta) async {
    try {
      await _player.setVolume(0);
      await _player.setPlaylistMode(PlaylistMode.single);
      await _player.open(Media(ruta), play: true);
    } on Object catch (e) {
      _notificarFallo('No se pudo abrir el vídeo: $e');
    }
  }

  void _manejarError(String mensaje) {
    _notificarFallo(mensaje);
  }

  void _notificarFallo(String mensaje) {
    if (_rutaEnFallo == widget.ruta) return;
    _rutaEnFallo = widget.ruta;
    widget.alFallar(mensaje);
  }

  @override
  void dispose() {
    _errores?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: IgnorePointer(
          child: Video(
            controller: _controller,
            fit: BoxFit.cover,
            controls: NoVideoControls,
            wakelock: false,
            pauseUponEnteringBackgroundMode: true,
            resumeUponEnteringForegroundMode: true,
          ),
        ),
      );
}
