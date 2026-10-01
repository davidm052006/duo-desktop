import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Un `HttpClient` de mentira para las pantallas que llaman a `http.get`
/// directamente, sin transporte inyectable.
///
/// `ClienteDuo` recibe su transporte por constructor y en sus tests basta con
/// `MockClient`. `PantallaGitHub` todavía no: usa `package:http` a pelo, y lo
/// único que queda por debajo es el `HttpClient` de `dart:io`. Con
/// `HttpOverrides` se puede sustituir sin tocar la pantalla.
///
/// Si algún día la pantalla acepta un `http.Client` por constructor, este
/// archivo se puede borrar y los tests pasan a `MockClient`.
class HttpFalso extends HttpOverrides {
  HttpFalso(this.responde);

  /// Qué contestar a cada URL. Lanzar desde aquí simula el servicio caído.
  final Future<RespuestaFalsa> Function(Uri url) responde;

  /// Las URL que se han pedido, en orden: sirve para comprobar que el botón de
  /// actualizar vuelve a preguntar.
  final List<Uri> pedidas = [];

  /// Instala el falso durante un test y deja el anterior al terminar.
  ///
  /// `flutter_test` ya pone un override propio que contesta 400 a todo; hay que
  /// devolverlo en su sitio, no dejarlo en `null`, o el siguiente test saldría
  /// a la red de verdad.
  static HttpFalso instala(
    Future<RespuestaFalsa> Function(Uri url) responde,
    void Function(void Function()) alTerminar,
  ) {
    final previo = HttpOverrides.current;
    final falso = HttpFalso(responde);
    HttpOverrides.global = falso;
    alTerminar(() => HttpOverrides.global = previo);
    return falso;
  }

  /// El atajo más corriente: el mismo cuerpo JSON para todo.
  static HttpFalso conJson(
    Object? cuerpo,
    void Function(void Function()) alTerminar, {
    int codigo = 200,
  }) => instala(
    (_) async => RespuestaFalsa(codigo: codigo, cuerpo: jsonEncode(cuerpo)),
    alTerminar,
  );

  @override
  HttpClient createHttpClient(SecurityContext? context) => _Cliente(this);
}

class RespuestaFalsa {
  const RespuestaFalsa({required this.codigo, required this.cuerpo});

  final int codigo;
  final String cuerpo;
}

class _Cliente implements HttpClient {
  _Cliente(this._falso);

  final HttpFalso _falso;

  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> openUrl(String metodo, Uri url) async {
    _falso.pedidas.add(url);
    return _Peticion(url, () => _falso.responde(url));
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('get', url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocacion) => super.noSuchMethod(invocacion);
}

class _Peticion implements HttpClientRequest {
  _Peticion(this.uri, this._responde);

  final Future<RespuestaFalsa> Function() _responde;

  @override
  final Uri uri;
  @override
  final HttpHeaders headers = _Cabeceras();
  @override
  bool bufferOutput = true;
  @override
  int contentLength = -1;
  @override
  Encoding encoding = utf8;
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  bool persistentConnection = true;

  @override
  String get method => 'GET';

  @override
  void add(List<int> datos) {}

  @override
  Future<void> addStream(Stream<List<int>> flujo) => flujo.drain<void>();

  @override
  Future<HttpClientResponse> close() async {
    final respuesta = await _responde();
    return _Respuesta(respuesta);
  }

  @override
  Future<HttpClientResponse> get done => close();

  @override
  dynamic noSuchMethod(Invocation invocacion) => super.noSuchMethod(invocacion);
}

class _Respuesta extends StreamView<List<int>> implements HttpClientResponse {
  _Respuesta(RespuestaFalsa respuesta)
    : statusCode = respuesta.codigo,
      _bytes = utf8.encode(respuesta.cuerpo),
      super(Stream.value(utf8.encode(respuesta.cuerpo)));

  final List<int> _bytes;

  @override
  final int statusCode;

  @override
  int get contentLength => _bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  HttpHeaders get headers => _Cabeceras();

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => '';

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  dynamic noSuchMethod(Invocation invocacion) => super.noSuchMethod(invocacion);
}

class _Cabeceras implements HttpHeaders {
  @override
  bool chunkedTransferEncoding = false;
  @override
  int contentLength = -1;
  @override
  ContentType? contentType;
  @override
  DateTime? date;
  @override
  DateTime? expires;
  @override
  String? host;
  @override
  DateTime? ifModifiedSince;
  @override
  bool persistentConnection = true;
  @override
  int? port;

  @override
  void forEach(void Function(String nombre, List<String> valores) f) {}

  @override
  void set(String nombre, Object valor, {bool preserveHeaderCase = false}) {}

  @override
  void add(String nombre, Object valor, {bool preserveHeaderCase = false}) {}

  @override
  List<String>? operator [](String nombre) => null;

  @override
  String? value(String nombre) => null;

  @override
  dynamic noSuchMethod(Invocation invocacion) => super.noSuchMethod(invocacion);
}
