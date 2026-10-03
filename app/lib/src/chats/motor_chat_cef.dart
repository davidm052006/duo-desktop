import 'package:flutter/material.dart';
import 'package:webview_cef/webview_cef.dart';

import 'cef_chats_runtime.dart';

/// Motor Chromium aislado para el experimento de Chats.
///
/// No está conectado aún a PantallaChats: así podemos comprobar primero el
/// arranque, procesos y políticas de CEF sin alterar la vista existente.
class MotorChatCef extends StatefulWidget {
  const MotorChatCef({
    super.key,
    required this.initialUrl,
    this.onReady,
    this.onUrlChanged,
    this.onConsoleMessage,
  });

  final String initialUrl;
  final VoidCallback? onReady;
  final ValueChanged<String>? onUrlChanged;
  final ValueChanged<String>? onConsoleMessage;

  @override
  State<MotorChatCef> createState() => _MotorChatCefState();
}

class _MotorChatCefState extends State<MotorChatCef> {
  WebViewController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    try {
      await CefChatsRuntime.iniciar();
      final controller = WebviewManager().createWebView(
        loading: const Center(child: CircularProgressIndicator()),
      );
      controller.setWebviewListener(
        WebviewEventsListener(
          onUrlChanged: widget.onUrlChanged,
          onConsoleMessage: (nivel, mensaje, fuente, linea) {
            widget.onConsoleMessage?.call(
              '[$nivel] $mensaje ($fuente:$linea)',
            );
          },
        ),
      );
      await controller.initialize(widget.initialUrl);

      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      widget.onReady?.call();
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller != null) return controller.webviewWidget;
    if (_error != null) {
      return Center(child: Text('CEF no pudo iniciar: $_error'));
    }
    return const Center(child: CircularProgressIndicator());
  }

  @override
  void dispose() {
    // WebviewManager es global y se conserva para futuros paneles. Solo se
    // libera esta instancia; cerrar el manager terminaría otros WebViews.
    _controller?.dispose();
    super.dispose();
  }
}
