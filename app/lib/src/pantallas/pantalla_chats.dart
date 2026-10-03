import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../chats/panel_proveedores_cef.dart';
import '../chats/proveedor_chat.dart';
import '../chats/sesion_chats_cef.dart';
import '../tema/paleta.dart';

/// Chats embebidos. Los navegadores CEF viven en [SesionChatsCef] mientras
/// Duo siga abierto: cambiar de proveedor u otra vista no recarga ni cierra
/// la sesión.
class PantallaChats extends StatefulWidget {
  const PantallaChats({super.key});

  @override
  State<PantallaChats> createState() => _PantallaChatsState();
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
  final SesionChatsCef _sesion = SesionChatsCef.instancia;

  @override
  void initState() {
    super.initState();
    _sesion.addListener(_alCambiarSesion);
    _sesion.activar(_sesion.activo);
  }

  @override
  void dispose() {
    _sesion.removeListener(_alCambiarSesion);
    super.dispose();
  }

  void _alCambiarSesion() {
    if (mounted) setState(() {});
  }

  ProveedorChat get _proveedor => _sesion.activo;

  _EstadoChatWeb get _estado {
    if (_sesion.errorRuntime != null) {
      return _EstadoChatWeb.webViewNoDisponible;
    }
    final motor = _sesion.motorActivo;
    if (motor == null) return _EstadoChatWeb.inicializando;
    switch (motor.estado) {
      case EstadoMotorChat.sinCrear:
      case EstadoMotorChat.creando:
        return _EstadoChatWeb.inicializando;
      case EstadoMotorChat.cargando:
        return _EstadoChatWeb.cargando;
      case EstadoMotorChat.listo:
        return _EstadoChatWeb.listo;
      case EstadoMotorChat.error:
        return _EstadoChatWeb.errorNavegacion;
    }
  }

  String? get _mensajeEstado {
    if (_sesion.errorRuntime != null) return _sesion.errorRuntime;
    final motor = _sesion.motorActivo;
    if (motor?.error != null) return motor!.error;
    return switch (_estado) {
      _EstadoChatWeb.inicializando => 'Preparando ${_proveedor.host}…',
      _EstadoChatWeb.cargando => 'Cargando ${_proveedor.host}…',
      _EstadoChatWeb.listo => 'Página lista',
      _ => null,
    };
  }

  Future<void> _cambiarProveedor(ProveedorChat nuevo) async {
    if (nuevo == _proveedor) return;
    await _sesion.activar(nuevo);
  }

  Future<void> _recargar() async {
    try {
      await _sesion.recargarActivo();
    } on Object catch (_) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _abrirEnNavegador() async {
    final uri = Uri.parse(_proveedor.url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir ${_proveedor.url}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;
    final estado = _estado;
    final mensaje = _mensajeEstado;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Chats', style: textos.headlineSmall?.copyWith(fontSize: 26)),
          const SizedBox(height: 6),
          Text(
            'ChatGPT y Grok se quedan abiertos al cambiar de pestaña o de vista.',
            style: textos.bodySmall?.copyWith(color: paleta.tintaSecundaria),
          ),
          const SizedBox(height: 18),
          _BarraChats(
            proveedor: _proveedor,
            alCambiar: _cambiarProveedor,
            alRecargar: _recargar,
            alAbrirNavegador: _abrirEnNavegador,
            recargarHabilitado: true,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: paleta.panel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: paleta.rejilla),
              ),
              clipBehavior: Clip.none,
              child: PanelProveedoresCef(
                sesion: _sesion,
                capaError: estado == _EstadoChatWeb.webViewNoDisponible
                    ? _CapaError(
                        titulo: 'El WebView no está disponible',
                        detalle: mensaje ??
                            'Duo no pudo iniciar el motor web. Reintenta en esta vista.',
                        alReintentar: _recargar,
                      )
                    : estado == _EstadoChatWeb.errorNavegacion
                        ? _CapaError(
                            titulo: 'No se pudo cargar la página',
                            detalle: mensaje ??
                                'El motor web informó un error de carga.',
                            alReintentar: _recargar,
                          )
                        : estado == _EstadoChatWeb.procesoTerminado
                            ? _CapaError(
                                titulo: 'El contenido web dejó de responder',
                                detalle: mensaje ??
                                    'El proceso del WebView terminó inesperadamente.',
                                alReintentar: _recargar,
                              )
                            : null,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _EstadoChatWebBarra(
            estado: estado,
            mensaje: mensaje,
            host: _proveedor.host,
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
    required this.alAbrirNavegador,
    required this.recargarHabilitado,
  });

  final ProveedorChat proveedor;
  final ValueChanged<ProveedorChat> alCambiar;
  final VoidCallback alRecargar;
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
          tooltip: 'Recargar página activa',
          onPressed: recargarHabilitado ? alRecargar : null,
          icon: Icon(Icons.refresh, size: 20, color: paleta.tintaSecundaria),
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

  final ProveedorChat seleccionado;
  final ValueChanged<ProveedorChat> alCambiar;

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
          for (final p in ProveedorChat.values)
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

class _CapaError extends StatelessWidget {
  const _CapaError({
    required this.titulo,
    required this.detalle,
    required this.alReintentar,
  });

  final String titulo;
  final String detalle;
  final VoidCallback alReintentar;

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
                OutlinedButton(
                  onPressed: alReintentar,
                  child: const Text('Reintentar'),
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
  });

  final _EstadoChatWeb estado;
  final String? mensaje;
  final String host;

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

    return Row(
      children: [
        Icon(icono, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textos.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
