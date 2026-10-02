import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_provider_linux/path_provider_linux.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias y utilidades del fondo de vídeo.
///
/// Vive temporalmente en pantallas porque T-023 restringe el territorio a
/// app/lib/src/pantallas. No reproduce vídeo por sí mismo.
class FalloPreferencias implements Exception {
  const FalloPreferencias(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

abstract final class FondoVideoConfig {
  static final cambios = ValueNotifier<int>(0);
  static final opacidadPaneles = ValueNotifier<double>(0.88);
  static const fondoKey = 'personalizacion.fondo';
  static const carpetaKey = 'personalizacion.video.carpeta';
  static const intervaloKey = 'personalizacion.video.intervalo_minutos';
  static const opacidadPanelesKey = 'personalizacion.paneles.opacidad';
  static const _bootstrapKey = 'duo.persistencia.inicializada';

  static String? rutaArchivoPreferencias;
  static String? falloInicializacion;

  static const extensiones = <String>{
    '.mp4',
    '.m4v',
    '.mov',
    '.webm',
    '.mkv',
  };

  static bool esModoVideo(String? fondo) => fondo == 'video';

  static int normalizarIntervalo(int? valor) =>
      const [5, 15, 30, 60, 120].contains(valor) ? valor! : 30;

  static double normalizarOpacidad(double? valor) =>
      (valor ?? 0.88).clamp(0.72, 0.98).toDouble();


  static Future<void> inicializarPersistencia() async {
    if (!Platform.isLinux) return;

    try {
      final soporte = await PathProviderLinux().getApplicationSupportPath();
      if (soporte == null || soporte.trim().isEmpty) {
        throw const FalloPreferencias(
          'path_provider_linux no devolvió un directorio de soporte.',
        );
      }

      final directorio = Directory(soporte);
      await directorio.create(recursive: true);
      final archivo = File(
        '${directorio.path}${Platform.pathSeparator}shared_preferences.json',
      );
      rutaArchivoPreferencias = archivo.path;

      final prefs = await SharedPreferences.getInstance();
      final escrito = await prefs.setBool(_bootstrapKey, true);
      _exigir(
        escrito,
        'crear el archivo de preferencias',
      );

      await prefs.reload();
      if (prefs.getBool(_bootstrapKey) != true) {
        throw FalloPreferencias(
          'SharedPreferences escribió pero no pudo releer '
          '${archivo.path}.',
        );
      }

      if (!await archivo.exists()) {
        throw FalloPreferencias(
          'SharedPreferences no creó el archivo esperado: '
          '${archivo.path}.',
        );
      }
    } on FalloPreferencias {
      rethrow;
    } on Object catch (e) {
      throw FalloPreferencias(
        'No se pudo inicializar SharedPreferences en Linux: $e',
      );
    }
  }

  static Future<SharedPreferences> _preferencias() async {
    try {
      return await SharedPreferences.getInstance();
    } on Object catch (e) {
      throw FalloPreferencias(
        'No se pudo abrir SharedPreferences'
        '${rutaArchivoPreferencias == null ? '' : ' ($rutaArchivoPreferencias)'}: $e',
      );
    }
  }

  static void _exigir(bool ok, String accion) {
    if (ok) return;
    throw FalloPreferencias(
      'SharedPreferences devolvió false al $accion'
      '${rutaArchivoPreferencias == null ? '' : ' en $rutaArchivoPreferencias'}.',
    );
  }

  static Future<void> guardarModoFondo(String valor) async {
    final prefs = await _preferencias();
    _exigir(
      await prefs.setString(fondoKey, valor),
      'guardar el modo de fondo',
    );
    cambios.value++;
  }

  static Future<void> guardarVideo({
    required String carpeta,
    required int intervaloMinutos,
  }) async {
    final prefs = await _preferencias();
    _exigir(
      await prefs.setString(carpetaKey, carpeta),
      'guardar la carpeta de vídeos',
    );
    _exigir(
      await prefs.setInt(
        intervaloKey,
        normalizarIntervalo(intervaloMinutos),
      ),
      'guardar el intervalo de vídeo',
    );
    cambios.value++;
  }

  static Future<void> cargarPreferenciasVisuales() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      opacidadPaneles.value = normalizarOpacidad(
        prefs.getDouble(opacidadPanelesKey),
      );
    } on Object catch (e) {
      debugPrint('FondoVideoConfig: no pude cargar preferencias visuales ($e)');
      opacidadPaneles.value = 0.88;
    }
  }

  static Future<List<File>> videosEn(String ruta) async {
    if (ruta.trim().isEmpty) return const [];

    final directorio = Directory(ruta);
    if (!await directorio.exists()) {
      throw const FileSystemException('La carpeta seleccionada no existe.');
    }

    final videos = <File>[];
    await for (final entidad in directorio.list(followLinks: false)) {
      if (entidad is! File) continue;
      final nombre = entidad.path.toLowerCase();
      if (extensiones.any(nombre.endsWith)) videos.add(entidad);
    }

    videos.sort((a, b) => a.path.compareTo(b.path));
    return videos;
  }

  static File? aleatorio(
    List<File> videos, {
    Random? random,
    String? excluirRuta,
    Set<String> excluirRutas = const <String>{},
  }) {
    final candidatos = videos
        .where(
          (video) =>
              video.path != excluirRuta && !excluirRutas.contains(video.path),
        )
        .toList(growable: false);
    if (candidatos.isEmpty) return null;
    final r = random ?? Random.secure();
    return candidatos[r.nextInt(candidatos.length)];
  }

  static Future<String?> elegirCarpeta(
    BuildContext context, {
    String? inicial,
  }) async {
    final inicio = inicial == null || inicial.trim().isEmpty
        ? Directory.current
        : Directory(inicial);

    return showDialog<String>(
      context: context,
      builder: (_) => _SelectorCarpeta(inicial: inicio),
    );
  }

  static Future<void> guardarOpacidad(double valor) async {
    final opacidad = normalizarOpacidad(valor);
    final prefs = await _preferencias();
    _exigir(
      await prefs.setDouble(opacidadPanelesKey, opacidad),
      'guardar la opacidad de paneles',
    );
    opacidadPaneles.value = opacidad;
  }

  static Future<void> guardar({
    required String carpeta,
    required int intervaloMinutos,
    required double opacidadPaneles,
  }) async {
    await guardarVideo(
      carpeta: carpeta,
      intervaloMinutos: intervaloMinutos,
    );
    await guardarOpacidad(opacidadPaneles);
  }
}

class _SelectorCarpeta extends StatefulWidget {
  const _SelectorCarpeta({required this.inicial});

  final Directory inicial;

  @override
  State<_SelectorCarpeta> createState() => _SelectorCarpetaState();
}

class _SelectorCarpetaState extends State<_SelectorCarpeta> {
  late Directory _actual;
  List<Directory> _subdirectorios = const [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _actual = widget.inicial;
    _leer();
  }

  Future<void> _leer() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final existe = await _actual.exists();
      if (!existe) {
        _actual = Directory.current;
      }

      final carpetas = <Directory>[];
      await for (final entidad in _actual.list(followLinks: false)) {
        if (entidad is Directory) carpetas.add(entidad);
      }
      carpetas.sort((a, b) => a.path.compareTo(b.path));

      if (!mounted) return;
      setState(() {
        _subdirectorios = carpetas;
        _cargando = false;
      });
    } on FileSystemException catch (e) {
      if (!mounted) return;
      setState(() {
        _subdirectorios = const [];
        _cargando = false;
        _error = e.osError?.message ?? e.message;
      });
    }
  }

  Future<void> _abrir(Directory directorio) async {
    _actual = directorio;
    await _leer();
  }

  Directory? get _padre {
    final padre = _actual.parent;
    if (padre.path == _actual.path) return null;
    return padre;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Elegir carpeta de vídeos'),
      content: SizedBox(
        width: 620,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(
              _actual.path,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _padre == null ? null : () => _abrir(_padre!),
                  icon: const Icon(Icons.arrow_upward, size: 16),
                  label: const Text('Subir'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _leer,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Actualizar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'No se puede leer esta carpeta: $_error',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _subdirectorios.isEmpty
                      ? const Center(child: Text('No hay subcarpetas visibles.'))
                      : ListView.builder(
                          itemCount: _subdirectorios.length,
                          itemBuilder: (_, i) {
                            final d = _subdirectorios[i];
                            final partes = d.path
                                .split(Platform.pathSeparator)
                                .where((e) => e.isNotEmpty)
                                .toList(growable: false);
                            final nombre = partes.isEmpty ? d.path : partes.last;
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.folder_outlined),
                              title: Text(nombre),
                              subtitle: Text(
                                d.path,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _abrir(d),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _error == null
              ? () => Navigator.of(context).pop(_actual.path)
              : null,
          child: const Text('Usar esta carpeta'),
        ),
      ],
    );
  }
}
