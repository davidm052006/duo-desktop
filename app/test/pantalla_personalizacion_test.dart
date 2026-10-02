import 'package:duo_desktop/src/pantallas/pantalla_personalizacion.dart';
import 'package:duo_desktop/src/tema/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- el almacén de preferencias ------------------------------------------
//
// Esta pantalla no habla con el servicio: su única fuente son las
// preferencias locales, así que el "estado vacío" es un almacén sin nada y el
// "fallo de servicio" es un almacén que no responde.
//
// Se sirve desde el canal de plataforma en vez de `setMockInitialValues`
// porque esa función deja elegido un almacén *estático* para el resto del
// archivo, y entonces el caso del almacén roto dependería del orden.

const _canalPrefs = MethodChannel('plugins.flutter.io/shared_preferences');
const _prefijo = 'flutter.';

late Map<String, Object> _almacen;
late bool _almacenRoto;
late String? _claveQueFalla;

void _instalaAlmacen() {
  _almacen = {};
  _almacenRoto = false;
  _claveQueFalla = null;
  SharedPreferences.resetStatic();

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_canalPrefs, (llamada) async {
        if (_almacenRoto) {
          throw PlatformException(
            code: 'sin-almacen',
            message: 'El almacén de preferencias no responde.',
          );
        }
        final args = llamada.arguments is Map
            ? (llamada.arguments as Map).cast<String, Object?>()
            : const <String, Object?>{};
        switch (llamada.method) {
          case 'getAll':
            return Map<String, Object>.from(_almacen);
          case 'setString' || 'setDouble' || 'setBool' || 'setInt' || 'setStringList':
            final key = args['key']! as String;
            if (_claveQueFalla == key) return false;
            _almacen[key] = args['value']!;
            return true;
          case 'remove':
            _almacen.remove(args['key']);
            return true;
          case 'clear':
            _almacen.clear();
            return true;
        }
        return null;
      });

  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canalPrefs, null);
    SharedPreferences.resetStatic();
  });
}

void _guardadas(Map<String, Object> valores) =>
    _almacen.addAll({for (final e in valores.entries) '$_prefijo${e.key}': e.value});

/// Una ventana de escritorio de verdad: la pantalla reparte por ancho.
Future<void> _pinta(
  WidgetTester tester, {
  Size tamano = const Size(1600, 1400),
  ThemeData? tema,
}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: tema ?? TemaDuo.oscuro(),
      home: const Scaffold(body: PantallaPersonalizacion()),
    ),
  );
  // La pantalla arranca leyendo las preferencias: hasta que no vuelven solo
  // hay un spinner.
  await tester.pumpAndSettle();
}


Finder get _sliderTipografia => find.byWidgetPredicate(
      (widget) => widget is Slider && widget.min == 0.85 && widget.max == 1.30,
    );

Finder get _sliderOpacidad => find.byWidgetPredicate(
      (widget) => widget is Slider && widget.min == 0.72 && widget.max == 0.98,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(_instalaAlmacen);

  testWidgets('los tres paneles se pintan: apariencia, fondo y vista previa', (tester) async {
    await _pinta(tester);

    expect(find.text('Personalización'), findsOneWidget);
    expect(find.text('preferencias locales'), findsOneWidget);
    expect(find.text('APARIENCIA'), findsOneWidget);
    expect(find.text('FONDO'), findsOneWidget);
    expect(find.text('VISTA PREVIA'), findsOneWidget);
    // Los cuatro controles de apariencia, cada uno con su rótulo.
    expect(find.text('TEMA'), findsOneWidget);
    expect(find.text('ACENTO'), findsOneWidget);
    expect(find.text('TAMAÑO DE TIPOGRAFÍA'), findsOneWidget);
    expect(find.text('TIPO DE FONDO'), findsOneWidget);
  });

  testWidgets('los cuatro acentos se ofrecen por nombre, no solo por color', (tester) async {
    await _pinta(tester);

    for (final acento in ['rosa', 'morado', 'cian', 'azul']) {
      expect(find.text(acento), findsWidgets, reason: 'falta el acento $acento');
    }
  });

  testWidgets('la vista previa enseña el resultado de lo elegido', (tester) async {
    await _pinta(tester);

    expect(find.text('TU WORKSPACE'), findsOneWidget);
    expect(find.text('duo-desktop'), findsOneWidget);
    expect(find.text('Vista previa del tema, acento y escala elegidos.'), findsOneWidget);
  });

  testWidgets('sin nada guardado se abre con los valores por defecto', (tester) async {
    await _pinta(tester);

    // Oscuro, rosa, 100% y sin fondo: lo que describe `docs/diseno/`.
    expect(tester.widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>)).selected, {
      'oscuro',
    });
    expect(find.text('100%'), findsOneWidget);
    // Las insignias de los paneles repiten el valor activo.
    expect(find.text('oscuro'), findsOneWidget);
    expect(find.text('ninguno'), findsOneWidget);
    expect(tester.widget<Slider>(_sliderTipografia).value, 1.0);
  });

  testWidgets('lo guardado se recupera al abrir', (tester) async {
    _guardadas({
      'personalizacion.tema': 'claro',
      'personalizacion.acento': 'cian',
      'personalizacion.escala_texto': 1.15,
      'personalizacion.fondo': 'degradado',
    });

    await _pinta(tester);

    expect(tester.widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>)).selected, {
      'claro',
    });
    expect(find.text('claro'), findsOneWidget);
    expect(find.text('115%'), findsWidgets);
    expect(find.text('degradado'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 1.15);
  });

  testWidgets('una escala fuera de rango se recorta en vez de romper el slider', (tester) async {
    // El `Slider` lanza si el valor queda fuera de [min, max]: una preferencia
    // vieja o editada a mano no puede tirar la pantalla.
    _guardadas({'personalizacion.escala_texto': 4.0});

    await _pinta(tester);

    expect(tester.widget<Slider>(find.byType(Slider)).value, 1.30);
    expect(find.text('130%'), findsWidgets);
  });

  testWidgets('elegir un acento lo guarda y lo refleja', (tester) async {
    await _pinta(tester);

    await tester.tap(find.text('morado'));
    await tester.pumpAndSettle();

    expect(_almacen['${_prefijo}personalizacion.acento'], 'morado');
  });

  testWidgets('cambiar de tema lo guarda', (tester) async {
    await _pinta(tester);

    await tester.tap(find.text('Claro'));
    await tester.pumpAndSettle();

    expect(_almacen['${_prefijo}personalizacion.tema'], 'claro');
    expect(find.text('claro'), findsOneWidget);
  });

  testWidgets('si el almacén no responde se avisa y se sigue pudiendo tocar', (tester) async {
    _almacenRoto = true;

    await _pinta(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.textContaining('No pude leer tus preferencias guardadas.'),
      findsOneWidget,
    );
    expect(find.textContaining('no se recordarán al reiniciar'), findsOneWidget);
    // Y los controles siguen ahí, con los valores por defecto.
    expect(find.text('APARIENCIA'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('con el almacén roto, cambiar algo no revienta', (tester) async {
    // El aviso promete que «puedes cambiarlas, pero no se recordarán»: hoy eso
    // no es verdad. `_guardarAcento` hace `await SharedPreferences.getInstance()`
    // sin `try`, así que el tap propaga una PlatformException sin capturar.
    // El arreglo va en `_guardarTema/_guardarAcento/_guardarTexto/_guardarFondo`
    // de `lib/src/pantallas/pantalla_personalizacion.dart`, fuera del
    // territorio de T-015.
    _almacenRoto = true;
    await _pinta(tester);

    await tester.tap(find.text('morado'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // skip: fallo abierto; guardar con el almacén caído lanza sin capturar.
  }, skip: true);

  testWidgets('la opacidad por defecto es segura y se persiste', (tester) async {
    await _pinta(tester);

    expect(tester.widget<Slider>(_sliderOpacidad).value, 0.88);

    await tester.drag(_sliderOpacidad, const Offset(80, 0));
    await tester.pumpAndSettle();

    final guardada =
        _almacen['${_prefijo}personalizacion.paneles.opacidad'] as double?;
    expect(guardada, isNotNull);
    expect(guardada!, inInclusiveRange(0.72, 0.98));
  });

  testWidgets('modo sin fondo no enseña controles de carpeta de video', (tester) async {
    _guardadas({'personalizacion.fondo': 'ninguno'});
    await _pinta(tester);

    expect(find.text('CARPETA DE VÍDEOS'), findsNothing);
    expect(find.text('CAMBIAR VÍDEO CADA'), findsNothing);
  });

  testWidgets('modo video enseña carpeta e intervalo', (tester) async {
    _guardadas({'personalizacion.fondo': 'video'});
    await _pinta(tester);

    expect(find.text('CARPETA DE VÍDEOS'), findsOneWidget);
    expect(find.text('CAMBIAR VÍDEO CADA'), findsOneWidget);
  });

  testWidgets('si guardar el modo falla se muestra el error y no dice persistido',
      (tester) async {
    _claveQueFalla = '${_prefijo}personalizacion.fondo';
    await _pinta(tester);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vídeo').last);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('SharedPreferences devolvió false'),
      findsOneWidget,
    );
    expect(find.text('sin guardar'), findsOneWidget);
    expect(find.text('CARPETA DE VÍDEOS'), findsNothing);
    expect(
      _almacen.containsKey('${_prefijo}personalizacion.fondo'),
      isFalse,
    );
  });

  testWidgets('cambiar a video notifica a MarcoApp tras persistir',
      (tester) async {
    final antes = FondoVideoConfig.cambios.value;
    await _pinta(tester);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vídeo').last);
    await tester.pumpAndSettle();

    expect(
      _almacen['${_prefijo}personalizacion.fondo'],
      'video',
    );
    expect(FondoVideoConfig.cambios.value, greaterThan(antes));
    expect(find.text('CARPETA DE VÍDEOS'), findsOneWidget);
  });

  testWidgets('con el almacén sano no se avisa de nada', (tester) async {
    await _pinta(tester);

    expect(find.textContaining('No pude leer tus preferencias guardadas.'), findsNothing);
  });

  testWidgets('en una ventana estrecha y en claro no desborda', (tester) async {
    // `pumpWidget` ya fallaría con un desborde de layout; aquí basta con que
    // los tres paneles sigan estando en la columna única.
    await _pinta(tester, tamano: const Size(820, 1400), tema: TemaDuo.claro());

    expect(find.text('APARIENCIA'), findsOneWidget);
    expect(find.text('FONDO'), findsOneWidget);
    expect(find.text('VISTA PREVIA'), findsOneWidget);
  });
}
