import 'package:flutter/foundation.dart';

import 'cef_chats_runtime.dart';
import 'motor_chat_cef.dart';
import 'proveedor_chat.dart';

/// Conserva ChatGPT y Grok mientras Duo siga vivo.
///
/// La pantalla Chats solo muestra/oculta paneles. No destruye motores al
/// cambiar de proveedor ni al ir a otra vista.
class SesionChatsCef extends ChangeNotifier {
  SesionChatsCef._();

  static final SesionChatsCef instancia = SesionChatsCef._();

  ProveedorChat activo = ProveedorChat.chatgpt;
  final Map<ProveedorChat, MotorChatCef> _motores = {};
  Future<void>? _runtime;
  String? errorRuntime;

  MotorChatCef? motorDe(ProveedorChat proveedor) => _motores[proveedor];

  MotorChatCef? get motorActivo => _motores[activo];

  Future<void> _asegurarRuntime() {
    return _runtime ??= () async {
      try {
        await CefChatsRuntime.iniciar();
      } on Object catch (e, st) {
        debugPrint('[CEF] runtime error: $e');
        debugPrintStack(stackTrace: st);
        errorRuntime = e.toString();
        _runtime = null;
        notifyListeners();
        rethrow;
      }
    }();
  }

  Future<void> activar(ProveedorChat proveedor) async {
    if (activo != proveedor) {
      activo = proveedor;
      notifyListeners();
    }
    await asegurar(proveedor);
  }

  Future<void> asegurar(ProveedorChat proveedor) async {
    final existente = _motores[proveedor];
    if (existente != null) {
      return existente.crear();
    }

    await _asegurarRuntime();

    if (_motores.containsKey(proveedor)) {
      return _motores[proveedor]!.crear();
    }

    final motor = MotorChatCef(proveedor: proveedor);
    _motores[proveedor] = motor;
    motor.addListener(notifyListeners);
    notifyListeners();
    await motor.crear();
  }

  Future<void> recargarActivo() async {
    final motor = _motores[activo];
    if (motor == null) {
      await asegurar(activo);
      return;
    }
    await motor.recargar();
  }
}
