import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:webview_cef/webview_cef.dart';

class CefChatsRuntime {
  CefChatsRuntime._();

  static Future<String>? _inicio;

  static Future<String> iniciar() => _inicio ??= _iniciar();

  static Future<String> _iniciar() async {
    // El launcher proporciona una raíz estable fuera de versions/<version>.
    // Así los perfiles CEF sobreviven una actualización de la aplicación.
    final raizDuo = Platform.environment['DUO_DATA_DIR'];
    final soporte = raizDuo == null || raizDuo.trim().isEmpty
        ? await getApplicationSupportDirectory()
        : Directory(raizDuo);
    final perfil = Directory(
      '${soporte.path}/cef/chat-profile',
    ).absolute;

    await perfil.create(recursive: true);

    await WebviewManager().initialize(
      rootCachePath: perfil.path,
    );

    return perfil.path;
  }
}
