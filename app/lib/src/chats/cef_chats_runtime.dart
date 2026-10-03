import 'package:path_provider/path_provider.dart';
import 'package:webview_cef/webview_cef.dart';

class CefChatsRuntime {
  CefChatsRuntime._();
  static Future<String>? _inicio;

  static Future<String> iniciar() => _inicio ??= _iniciar();

  static Future<String> _iniciar() async {
    final soporte = await getApplicationSupportDirectory();
    final rootCachePath = '${soporte.path}/cef-chats';
    await WebviewManager().initialize();
    return rootCachePath;
  }
}
