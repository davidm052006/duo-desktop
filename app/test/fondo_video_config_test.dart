import 'dart:io';
import 'dart:math';

import 'package:duo_desktop/src/pantallas/fondo_video_config.dart';
import 'package:duo_desktop/src/tema/paleta.dart';
import 'package:duo_desktop/src/tema/tema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seleccion aleatoria excluye el video actual y los fallidos', () {
    final videos = [
      File('/tmp/a.mp4'),
      File('/tmp/b.mp4'),
      File('/tmp/c.mp4'),
    ];

    final elegido = FondoVideoConfig.aleatorio(
      videos,
      random: Random(0),
      excluirRuta: '/tmp/a.mp4',
      excluirRutas: {'/tmp/b.mp4'},
    );

    expect(elegido?.path, '/tmp/c.mp4');
  });

  test('intervalo solo acepta las opciones soportadas', () {
    expect(FondoVideoConfig.normalizarIntervalo(5), 5);
    expect(FondoVideoConfig.normalizarIntervalo(30), 30);
    expect(FondoVideoConfig.normalizarIntervalo(120), 120);
    expect(FondoVideoConfig.normalizarIntervalo(null), 30);
    expect(FondoVideoConfig.normalizarIntervalo(7), 30);
    expect(FondoVideoConfig.normalizarIntervalo(999), 30);
  });

  test('sin fondo y degradado nunca activan video', () {
    expect(FondoVideoConfig.esModoVideo('ninguno'), isFalse);
    expect(FondoVideoConfig.esModoVideo('degradado'), isFalse);
    expect(FondoVideoConfig.esModoVideo('imagen'), isFalse);
    expect(FondoVideoConfig.esModoVideo(null), isFalse);
    expect(FondoVideoConfig.esModoVideo('video'), isTrue);
  });

  test('opacidad se mantiene en rango seguro', () {
    expect(FondoVideoConfig.normalizarOpacidad(null), 0.88);
    expect(FondoVideoConfig.normalizarOpacidad(0.5), 0.72);
    expect(FondoVideoConfig.normalizarOpacidad(0.85), 0.85);
    expect(FondoVideoConfig.normalizarOpacidad(1.0), 0.98);
  });

  test('el tema aplica opacidad solo al color de panel', () {
    final tema = TemaDuo.oscuro(opacidadPaneles: 0.72);
    final paleta = tema.extension<PaletaDatos>()!;

    expect(paleta.panel.a, closeTo(0.72, 0.01));
    expect(paleta.tintaPrincipal.a, 1.0);
    expect(paleta.tintaSecundaria.a, 1.0);
  });

  test('enumera solo extensiones de video admitidas', () async {
    final directorio = await Directory.systemTemp.createTemp('duo-video-test-');
    addTearDown(() => directorio.delete(recursive: true));

    await File('${directorio.path}/uno.mp4').writeAsBytes([0]);
    await File('${directorio.path}/dos.WEBM').writeAsBytes([0]);
    await File('${directorio.path}/nota.txt').writeAsBytes([0]);

    final videos = await FondoVideoConfig.videosEn(directorio.path);

    expect(
      videos.map((e) => e.path.split(Platform.pathSeparator).last),
      ['dos.WEBM', 'uno.mp4'],
    );
  });
}
