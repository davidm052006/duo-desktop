import 'package:flutter/material.dart';

import 'esqueleto_carga_chat.dart';
import 'motor_chat_cef.dart';
import 'proveedor_chat.dart';
import 'sesion_chats_cef.dart';

/// Mantiene ambos WebView en el árbol: cambiar de proveedor solo oculta.
class PanelProveedoresCef extends StatelessWidget {
  const PanelProveedoresCef({
    super.key,
    required this.sesion,
    required this.capaError,
  });

  final SesionChatsCef sesion;
  final Widget? capaError;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final proveedor in ProveedorChat.values)
          IgnorePointer(
            ignoring: sesion.activo != proveedor,
            child: Opacity(
              opacity: sesion.activo == proveedor ? 1 : 0,
              child: _PanelUnProveedor(
                proveedor: proveedor,
                motor: sesion.motorDe(proveedor),
                visible: sesion.activo == proveedor,
              ),
            ),
          ),
        ?capaError,
      ],
    );
  }
}

class _PanelUnProveedor extends StatefulWidget {
  const _PanelUnProveedor({
    required this.proveedor,
    required this.motor,
    required this.visible,
  });

  final ProveedorChat proveedor;
  final MotorChatCef? motor;
  final bool visible;

  @override
  State<_PanelUnProveedor> createState() => _PanelUnProveedorState();
}

class _PanelUnProveedorState extends State<_PanelUnProveedor> {
  @override
  void initState() {
    super.initState();
    _actualizarEntrada();
  }

  @override
  void didUpdateWidget(covariant _PanelUnProveedor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible ||
        oldWidget.motor != widget.motor) {
      _actualizarEntrada();
    }
  }

  void _actualizarEntrada() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.visible) {
        widget.motor?.activarEntrada();
      } else {
        widget.motor?.desactivarEntrada();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final actual = widget.motor;
    final mostrarEsqueleto =
        actual == null ||
        !actual.primerCargaCompleta ||
        actual.estado == EstadoMotorChat.creando ||
        actual.estado == EstadoMotorChat.sinCrear;

    return FocusScope(
      canRequestFocus: widget.visible,
      descendantsAreFocusable: widget.visible,
      child: TickerMode(
        enabled: widget.visible,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (actual != null) actual.construirWidget(),
            if (mostrarEsqueleto)
              EsqueletoCargaChat(proveedor: widget.proveedor),
          ],
        ),
      ),
    );
  }
}
