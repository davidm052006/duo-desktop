import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_all/webview_all.dart';

import '../tema/paleta.dart';

/// Experimento aislado (rama experiment/chats-webview).
/// Un solo WebView activo a la vez: ChatGPT o Grok.
class PantallaChats extends StatefulWidget {
  const PantallaChats({super.key});

  /// Interruptor temporal para aislar el problema de pintura del WebView en
  /// Linux. Debe quedar en `false` cuando termine el experimento.
  static const bool kDiagnosticoWebView = false;

  @override
  State<PantallaChats> createState() => _PantallaChatsState();
}

enum _ProveedorChat {
  chatgpt(nombre: 'ChatGPT', url: 'https://chatgpt.com', host: 'chatgpt.com'),
  grok(nombre: 'Grok', url: 'https://grok.com', host: 'grok.com');

  const _ProveedorChat({
    required this.nombre,
    required this.url,
    required this.host,
  });

  final String nombre;
  final String url;
  final String host;
}

enum _EstadoChatWeb {
  inicializando,
  cargando,
  listo,
  errorNavegacion,
  webViewNoDisponible,
  procesoTerminado,
  requiereNavegadorExterno,
}

class _PantallaChatsState extends State<PantallaChats> {
  _ProveedorChat _proveedor = _ProveedorChat.chatgpt;
  _EstadoChatWeb _estado = _EstadoChatWeb.inicializando;
  String? _mensajeEstado;
  WebViewController? _controller;
  bool _webViewDisponible = true;

  String get _urlActual => PantallaChats.kDiagnosticoWebView
      ? 'https://example.com'
      : _proveedor.url;

  String get _hostActual =>
      PantallaChats.kDiagnosticoWebView ? 'example.com' : _proveedor.host;

  @override
  void initState() {
    super.initState();
    _inicializarWebView();
  }

  @override
  void dispose() {
    // El controlador se libera con el widget.
    super.dispose();
  }

  Future<void> _inicializarWebView() async {
    setState(() {
      _estado = _EstadoChatWeb.inicializando;
      _mensajeEstado = null;
    });

    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) {
              if (!mounted) return;
              setState(() {
                _estado = _EstadoChatWeb.cargando;
                _mensajeEstado = 'Cargando $_hostActual…';
              });
            },
            onPageFinished: (url) {
              if (!mounted) return;
              setState(() {
                _estado = _EstadoChatWeb.listo;
                _mensajeEstado = 'Página lista';
              });
            },
            onWebResourceError: (error) {
              if (!mounted) return;
              setState(() {
                _estado = _EstadoChatWeb.errorNavegacion;
                _mensajeEstado = error.description.isNotEmpty
                    ? error.description
                    : 'Error de red o de carga';
              });
            },
            onNavigationRequest: (request) {
              // Por ahora permitimos navegación interna.
              // Enlaces externos complejos se pueden derivar al navegador más adelante.
              return NavigationDecision.navigate;
            },
          ),
        );

      await controller.loadRequest(Uri.parse(_urlActual));

      if (!mounted) return;
      setState(() {
        _controller = controller;
        _webViewDisponible = true;
        _estado = _EstadoChatWeb.cargando;
        _mensajeEstado = 'Cargando $_hostActual…';
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _webViewDisponible = false;
        _controller = null;
        _estado = _EstadoChatWeb.webViewNoDisponible;
        _mensajeEstado = e.toString();
      });
    }
  }

  Future<void> _cambiarProveedor(_ProveedorChat nuevo) async {
    if (nuevo == _proveedor) return;

    setState(() {
      _proveedor = nuevo;
      _estado = _EstadoChatWeb.cargando;
      _mensajeEstado = 'Cargando $_hostActual…';
    });

    final controller = _controller;
    if (controller == null) {
      await _inicializarWebView();
      return;
    }

    try {
      await controller.loadRequest(Uri.parse(_urlActual));
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _estado = _EstadoChatWeb.errorNavegacion;
        _mensajeEstado = e.toString();
      });
    }
  }

  Future<void> _recargar() async {
    final controller = _controller;
    if (controller == null) {
      await _inicializarWebView();
      return;
    }

    setState(() {
      _estado = _EstadoChatWeb.cargando;
      _mensajeEstado = 'Cargando $_hostActual…';
    });

    try {
      await controller.reload();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _estado = _EstadoChatWeb.errorNavegacion;
        _mensajeEstado = e.toString();
      });
    }
  }

  Future<void> _abrirEnNavegador() async {
    final uri = Uri.parse(_urlActual);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo abrir $_urlActual')));
    }
  }

  Future<void> _cargarHtmlPrueba() async {
    final controller = _controller;
    if (controller == null) return;

    try {
      await controller.loadHtmlString('''<!DOCTYPE html>
<html><body style="margin:0;background:#ffffff;color:#000;font:24px sans-serif;padding:40px;">
  <h1>WebView OK</h1>
  <p>Si lees esto, el motor pinta dentro de Flutter.</p>
</body></html>''');
      if (!mounted) return;
      setState(() {
        _estado = _EstadoChatWeb.listo;
        _mensajeEstado = 'HTML local cargado';
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _estado = _EstadoChatWeb.errorNavegacion;
        _mensajeEstado = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Chats', style: textos.headlineSmall?.copyWith(fontSize: 26)),
          const SizedBox(height: 6),
          Text(
            'ChatGPT y Grok sin salir de Duo. Experimento aislado — no forma parte de main.',
            style: textos.bodySmall?.copyWith(color: paleta.tintaSecundaria),
          ),
          const SizedBox(height: 18),
          _BarraChats(
            proveedor: _proveedor,
            alCambiar: _cambiarProveedor,
            alRecargar: _recargar,
            alCargarHtmlPrueba: _cargarHtmlPrueba,
            alAbrirNavegador: _abrirEnNavegador,
            recargarHabilitado: _controller != null || !_webViewDisponible,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _MarcoWebChat(
              controller: _controller,
              estado: _estado,
              mensaje: _mensajeEstado,
              webViewDisponible: _webViewDisponible,
              alReintentar: _recargar,
              alAbrirNavegador: _abrirEnNavegador,
              diagnostico: PantallaChats.kDiagnosticoWebView,
            ),
          ),
          const SizedBox(height: 10),
          _EstadoChatWebBarra(
            estado: _estado,
            mensaje: _mensajeEstado,
            host: _hostActual,
            diagnostico: PantallaChats.kDiagnosticoWebView,
          ),
        ],
      ),
    );
  }
}

class _BarraChats extends StatelessWidget {
  const _BarraChats({
    required this.proveedor,
    required this.alCambiar,
    required this.alRecargar,
    required this.alCargarHtmlPrueba,
    required this.alAbrirNavegador,
    required this.recargarHabilitado,
  });

  final _ProveedorChat proveedor;
  final ValueChanged<_ProveedorChat> alCambiar;
  final VoidCallback alRecargar;
  final VoidCallback alCargarHtmlPrueba;
  final VoidCallback alAbrirNavegador;
  final bool recargarHabilitado;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;

    return Row(
      children: [
        _SelectorProveedor(seleccionado: proveedor, alCambiar: alCambiar),
        const Spacer(),
        IconButton(
          tooltip: 'Recargar página',
          onPressed: recargarHabilitado ? alRecargar : null,
          icon: Icon(Icons.refresh, size: 20, color: paleta.tintaSecundaria),
        ),
        if (PantallaChats.kDiagnosticoWebView)
          IconButton(
            tooltip: 'Cargar HTML de prueba',
            onPressed: recargarHabilitado ? alCargarHtmlPrueba : null,
            icon: Icon(Icons.code, size: 20, color: paleta.tintaSecundaria),
          ),
        const SizedBox(width: 4),
        TextButton.icon(
          onPressed: alAbrirNavegador,
          icon: Icon(Icons.open_in_new, size: 16, color: paleta.acento),
          label: Text(
            'Abrir en navegador',
            style: TextStyle(color: paleta.acento),
          ),
        ),
      ],
    );
  }
}

class _SelectorProveedor extends StatelessWidget {
  const _SelectorProveedor({
    required this.seleccionado,
    required this.alCambiar,
  });

  final _ProveedorChat seleccionado;
  final ValueChanged<_ProveedorChat> alCambiar;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;

    return Container(
      decoration: BoxDecoration(
        color: paleta.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: paleta.rejilla),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in _ProveedorChat.values)
            _ChipProveedor(
              nombre: p.nombre,
              activo: p == seleccionado,
              alPulsar: () => alCambiar(p),
            ),
        ],
      ),
    );
  }
}

class _ChipProveedor extends StatelessWidget {
  const _ChipProveedor({
    required this.nombre,
    required this.activo,
    required this.alPulsar,
  });

  final String nombre;
  final bool activo;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;

    return Material(
      color: activo
          ? paleta.acento.withValues(alpha: 0.14)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: alPulsar,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            nombre,
            style: textos.bodyMedium?.copyWith(
              color: activo ? paleta.acento : paleta.tintaSecundaria,
              fontWeight: activo ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _MarcoWebChat extends StatelessWidget {
  const _MarcoWebChat({
    required this.controller,
    required this.estado,
    required this.mensaje,
    required this.webViewDisponible,
    required this.alReintentar,
    required this.alAbrirNavegador,
    required this.diagnostico,
  });

  final WebViewController? controller;
  final _EstadoChatWeb estado;
  final String? mensaje;
  final bool webViewDisponible;
  final VoidCallback alReintentar;
  final VoidCallback alAbrirNavegador;
  final bool diagnostico;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;

    final webView = controller != null && webViewDisponible
        ? diagnostico
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    debugPrint('[Chats/WebView] constraints: $constraints');
                    debugPrint('[Chats/WebView] estado: $estado');
                    return WebViewWidget(controller: controller!);
                  },
                )
              : WebViewWidget(controller: controller!)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: diagnostico ? Colors.white : paleta.panel,
        borderRadius: diagnostico ? null : BorderRadius.circular(10),
        border: diagnostico ? null : Border.all(color: paleta.rejilla),
      ),
      clipBehavior: diagnostico ? Clip.none : Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ?webView,
          if (estado == _EstadoChatWeb.inicializando ||
              (estado == _EstadoChatWeb.cargando && controller == null))
            _CapaCarga(texto: mensaje ?? 'Preparando WebView…'),
          if (estado == _EstadoChatWeb.webViewNoDisponible)
            _CapaError(
              titulo: 'El WebView no está disponible',
              detalle:
                  mensaje ??
                  'Duo no pudo iniciar el motor web de Linux. '
                      'Puedes seguir usando este servicio en tu navegador.',
              alReintentar: alReintentar,
              alAbrirNavegador: alAbrirNavegador,
            ),
          if (estado == _EstadoChatWeb.errorNavegacion)
            _CapaError(
              titulo: 'No se pudo cargar la página',
              detalle:
                  mensaje ?? 'El WebView informó un error de red o de carga.',
              alReintentar: alReintentar,
              alAbrirNavegador: alAbrirNavegador,
            ),
          if (estado == _EstadoChatWeb.procesoTerminado)
            _CapaError(
              titulo: 'El contenido web dejó de responder',
              detalle:
                  mensaje ?? 'El proceso del WebView terminó inesperadamente.',
              alReintentar: alReintentar,
              alAbrirNavegador: alAbrirNavegador,
            ),
        ],
      ),
    );
  }
}

class _CapaCarga extends StatelessWidget {
  const _CapaCarga({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;

    return ColoredBox(
      color: paleta.panel.withValues(alpha: 0.92),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: paleta.acentoAlt,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              texto,
              style: textos.bodyMedium?.copyWith(color: paleta.tintaSecundaria),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapaError extends StatelessWidget {
  const _CapaError({
    required this.titulo,
    required this.detalle,
    required this.alReintentar,
    required this.alAbrirNavegador,
  });

  final String titulo;
  final String detalle;
  final VoidCallback alReintentar;
  final VoidCallback alAbrirNavegador;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;

    return ColoredBox(
      color: paleta.panel,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 36, color: paleta.grave),
                const SizedBox(height: 14),
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: textos.titleMedium?.copyWith(
                    color: paleta.tintaPrincipal,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  detalle,
                  textAlign: TextAlign.center,
                  style: textos.bodySmall?.copyWith(
                    color: paleta.tintaSecundaria,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: alReintentar,
                      child: const Text('Reintentar'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: alAbrirNavegador,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Abrir en navegador'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EstadoChatWebBarra extends StatelessWidget {
  const _EstadoChatWebBarra({
    required this.estado,
    required this.mensaje,
    required this.host,
    required this.diagnostico,
  });

  final _EstadoChatWeb estado;
  final String? mensaje;
  final String host;
  final bool diagnostico;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;

    final (Color color, String texto, IconData icono) = switch (estado) {
      _EstadoChatWeb.inicializando => (
        paleta.acentoAlt,
        mensaje ?? 'Preparando WebView…',
        Icons.hourglass_top,
      ),
      _EstadoChatWeb.cargando => (
        paleta.acentoAlt,
        mensaje ?? 'Cargando $host…',
        Icons.circle,
      ),
      _EstadoChatWeb.listo => (
        paleta.bien,
        mensaje ?? 'Página lista',
        Icons.check_circle_outline,
      ),
      _EstadoChatWeb.errorNavegacion => (
        paleta.grave,
        mensaje ?? 'No se pudo cargar la página',
        Icons.error_outline,
      ),
      _EstadoChatWeb.webViewNoDisponible => (
        paleta.critico,
        mensaje ?? 'WebView no disponible',
        Icons.warning_amber_rounded,
      ),
      _EstadoChatWeb.procesoTerminado => (
        paleta.grave,
        mensaje ?? 'El proceso web terminó',
        Icons.report_gmailerrorred_outlined,
      ),
      _EstadoChatWeb.requiereNavegadorExterno => (
        paleta.aviso,
        mensaje ?? 'Se necesita el navegador del sistema',
        Icons.open_in_new,
      ),
    };

    final textoEstado = diagnostico ? '$texto · diagnóstico' : texto;
    return Row(
      children: [
        Icon(icono, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            textoEstado,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textos.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
