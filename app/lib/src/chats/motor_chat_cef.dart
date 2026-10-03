import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:webview_cef/webview_cef.dart';

import 'proveedor_chat.dart';

/// Un navegador CEF vivo para un solo proveedor.
///
/// No se destruye al cambiar de ChatGPT/Grok ni al salir de la vista Chats.
/// [disposeMotor] solo existe para apagar Duo; la pantalla no debe llamarlo.
class MotorChatCef extends ChangeNotifier {
  MotorChatCef({required this.proveedor});

  final ProveedorChat proveedor;

  WebViewController? _controller;
  Future<void>? _creacion;
  Timer? _ocultarEsqueleto;
  String? _url;
  String? _error;

  EstadoMotorChat estado = EstadoMotorChat.sinCrear;
  bool primerCargaCompleta = false;

  WebViewController? get controller => _controller;
  String? get error => _error;
  String? get url => _url;
  bool get listo => _controller?.value == true;

  Future<void> crear() {
    return _creacion ??= _crearAhora();
  }

  Future<void> _crearAhora() async {
    estado = EstadoMotorChat.creando;
    _error = null;
    notifyListeners();

    try {
      final controller = WebviewManager().createWebView(
        loading: const SizedBox.expand(),
      );

      controller.setWebviewListener(
        WebviewEventsListener(
          onLoadStart: (_, url) {
            _url = url;
            debugPrint('[CEF/${proveedor.nombre}] START $url');
            estado = EstadoMotorChat.cargando;
            notifyListeners();
          },
          onLoadEnd: (_, url) {
            _url = url;
            debugPrint('[CEF/${proveedor.nombre}] END $url');
            _marcarListoTrasPintado();
          },
          onUrlChanged: (url) {
            _url = url;
            debugPrint('[CEF/${proveedor.nombre}] URL $url');
            notifyListeners();
          },
          onConsoleMessage: (nivel, mensaje, origen, linea) {
            debugPrint(
              '[CEF/${proveedor.nombre} console:$nivel] $mensaje ($origen:$linea)',
            );
          },
        ),
      );

      _controller = controller;
      notifyListeners();
      await controller.initialize(proveedor.url);
      if (!primerCargaCompleta) {
        estado = EstadoMotorChat.cargando;
        notifyListeners();
      }
    } on Object catch (e, st) {
      debugPrint('[CEF/${proveedor.nombre}] init error: $e');
      debugPrintStack(stackTrace: st);
      _error = e.toString();
      estado = EstadoMotorChat.error;
      _creacion = null;
      notifyListeners();
      rethrow;
    }
  }

  /// Grok a menudo pinta el logo antes del SPA. Un breve margen evita
  /// quitar el esqueleto en ese fotograma vacío.
  void _marcarListoTrasPintado() {
    _ocultarEsqueleto?.cancel();
    final espera = proveedor == ProveedorChat.grok
        ? const Duration(milliseconds: 700)
        : const Duration(milliseconds: 180);
    _ocultarEsqueleto = Timer(espera, () {
      primerCargaCompleta = true;
      estado = EstadoMotorChat.listo;
      notifyListeners();
    });
  }

  Future<void> recargar() async {
    final controller = _controller;
    if (controller == null || !controller.value) {
      _creacion = null;
      primerCargaCompleta = false;
      await crear();
      return;
    }

    estado = EstadoMotorChat.cargando;
    notifyListeners();
    try {
      await controller.reload();
    } on Object catch (e) {
      _error = e.toString();
      estado = EstadoMotorChat.error;
      notifyListeners();
      rethrow;
    }
  }

  Widget construirWidget() {
    final controller = _controller;
    if (controller == null) {
      return const SizedBox.expand();
    }

    return ValueListenableBuilder<bool>(
      valueListenable: controller,
      builder: (context, ready, _) {
        if (!ready) {
          return const SizedBox.expand();
        }
        return controller.webviewWidget;
      },
    );
  }

  /// No usar al salir de Chats. Cierra el navegador de este proveedor.
  Future<void> disposeMotor() async {
    _ocultarEsqueleto?.cancel();
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      await controller.dispose();
    }
    super.dispose();
  }
}
