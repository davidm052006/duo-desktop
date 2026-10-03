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
        IndexedStack(
          index: sesion.activo.index,
          sizing: StackFit.expand,
          children: [
            for (final proveedor in ProveedorChat.values)
              _PanelUnProveedor(
                proveedor: proveedor,
                motor: sesion.motorDe(proveedor),
                visible: sesion.activo == proveedor,
              ),
          ],
        ),
        if (capaError != null) capaError!,
      ],
    );
  }
}

class _PanelUnProveedor extends StatelessWidget {
  const _PanelUnProveedor({
    required this.proveedor,
    required this.motor,
    required this.visible,
  });

  final ProveedorChat proveedor;
  final MotorChatCef? motor;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final actual = motor;
    final mostrarEsqueleto = actual == null ||
        !actual.primerCargaCompleta ||
        actual.estado == EstadoMotorChat.creando ||
        actual.estado == EstadoMotorChat.sinCrear;

    return TickerMode(
      enabled: visible,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (actual != null) actual.construirWidget(),
          if (mostrarEsqueleto) EsqueletoCargaChat(proveedor: proveedor),
        ],
      ),
    );
  }
}
