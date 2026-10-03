import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:webview_cef/webview_cef.dart';

class CefChatsRuntime {
  CefChatsRuntime._();

  static Future<String>? _inicio;

  static Future<String> iniciar() => _inicio ??= _iniciar();

  static Future<String> _iniciar() async {
    final soporte = await getApplicationSupportDirectory();
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
