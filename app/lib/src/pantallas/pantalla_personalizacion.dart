import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tema/paleta.dart';
import '../widgets/tarjeta.dart';

class PantallaPersonalizacion extends StatefulWidget {
  const PantallaPersonalizacion({super.key});

  @override
  State<PantallaPersonalizacion> createState() => _PantallaPersonalizacionState();
}

class _PantallaPersonalizacionState extends State<PantallaPersonalizacion> {
  static const _temaKey = 'personalizacion.tema';
  static const _acentoKey = 'personalizacion.acento';
  static const _textoKey = 'personalizacion.escala_texto';
  static const _fondoKey = 'personalizacion.fondo';

  bool _cargando = true;
  String? _fallo;
  String _tema = 'oscuro';
  String _acento = 'rosa';
  double _escalaTexto = 1.0;
  String _fondo = 'ninguno';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    // Si el almacén de preferencias no responde (plugin sin registrar en el
    // escritorio, permisos del perfil), la pantalla NO puede quedarse
    // cargando para siempre: se abre con los valores por defecto.
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('Personalización: no pude leer las preferencias ($e)');
    }
    if (!mounted) return;
    if (prefs == null) {
      setState(() {
        _cargando = false;
        _fallo = 'No pude leer tus preferencias guardadas. '
            'Puedes cambiarlas, pero no se recordarán al reiniciar.';
      });
      return;
    }
    final guardadas = prefs;
    setState(() {
      _tema = guardadas.getString(_temaKey) ?? 'oscuro';
      _acento = guardadas.getString(_acentoKey) ?? 'rosa';
      _escalaTexto =
          (guardadas.getDouble(_textoKey) ?? 1.0).clamp(0.85, 1.30).toDouble();
      _fondo = guardadas.getString(_fondoKey) ?? 'ninguno';
      _cargando = false;
    });
  }

  Future<void> _guardarTema(String valor) async {
    setState(() => _tema = valor);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_temaKey, valor);
  }

  Future<void> _guardarAcento(String valor) async {
    setState(() => _acento = valor);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_acentoKey, valor);
  }

  Future<void> _guardarTexto(double valor) async {
    setState(() => _escalaTexto = valor);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_textoKey, valor);
  }

  Future<void> _guardarFondo(String valor) async {
    setState(() => _fondo = valor);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fondoKey, valor);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, caja) {
        final dosColumnas = caja.maxWidth >= 980;
        // Si las preferencias no se pudieron leer, decirlo arriba en vez de
        // fingir que todo va bien: lo que cambie aquí no sobrevivirá.
        final aviso = _fallo == null
            ? null
            : Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.paleta.panel,
                  border: Border(
                    left: BorderSide(color: context.paleta.aviso, width: 3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_outlined,
                        size: 16, color: context.paleta.aviso),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_fallo!)),
                  ],
                ),
              );
        final apariencia = _Apariencia(
          tema: _tema,
          acento: _acento,
          escalaTexto: _escalaTexto,
          alCambiarTema: _guardarTema,
          alCambiarAcento: _guardarAcento,
          alCambiarTexto: _guardarTexto,
        );
        final fondo = _Fondo(
          fondo: _fondo,
          alCambiar: _guardarFondo,
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 36),
          children: [
            const _Cabecera(),
            const SizedBox(height: 24),
            ?aviso,
            if (dosColumnas)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: apariencia),
                    const SizedBox(width: 18),
                    Expanded(child: fondo),
                  ],
                ),
              )
            else ...[
              apariencia,
              const SizedBox(height: 18),
              fondo,
            ],
            const SizedBox(height: 18),
            _VistaPrevia(
              tema: _tema,
              acento: _acento,
              escalaTexto: _escalaTexto,
              fondo: _fondo,
            ),
          ],
        );
      },
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera();

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Personalización',
              style: textos.headlineSmall?.copyWith(fontSize: 26),
            ),
            const SizedBox(width: 12),
            Insignia('preferencias locales', tono: paleta.acento),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Tema, acento, tipografía y fondo del espacio de trabajo.',
          style: textos.bodySmall?.copyWith(color: paleta.tintaSecundaria),
        ),
      ],
    );
  }
}

class _Apariencia extends StatelessWidget {
  const _Apariencia({
    required this.tema,
    required this.acento,
    required this.escalaTexto,
    required this.alCambiarTema,
    required this.alCambiarAcento,
    required this.alCambiarTexto,
  });

  final String tema;
  final String acento;
  final double escalaTexto;
  final ValueChanged<String> alCambiarTema;
  final ValueChanged<String> alCambiarAcento;
  final ValueChanged<double> alCambiarTexto;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;

    return Tarjeta(
      titulo: 'Apariencia',
      icono: Icons.palette_outlined,
      sufijo: Insignia(tema, tono: paleta.acentoAlt),
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TEMA', style: textos.labelSmall),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'oscuro',
                icon: Icon(Icons.dark_mode_outlined, size: 16),
                label: Text('Oscuro'),
              ),
              ButtonSegment(
                value: 'claro',
                icon: Icon(Icons.light_mode_outlined, size: 16),
                label: Text('Claro'),
              ),
            ],
            selected: {tema},
            onSelectionChanged: (v) => alCambiarTema(v.first),
          ),
          const SizedBox(height: 24),
          Text('ACENTO', style: textos.labelSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Acento(nombre: 'rosa', color: const Color(0xFFFF8FC4), activo: acento == 'rosa', alPulsar: () => alCambiarAcento('rosa')),
              _Acento(nombre: 'morado', color: const Color(0xFFB388FF), activo: acento == 'morado', alPulsar: () => alCambiarAcento('morado')),
              _Acento(nombre: 'cian', color: const Color(0xFF5CD7F2), activo: acento == 'cian', alPulsar: () => alCambiarAcento('cian')),
              _Acento(nombre: 'azul', color: const Color(0xFF70C8FF), activo: acento == 'azul', alPulsar: () => alCambiarAcento('azul')),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Text('TAMAÑO DE TIPOGRAFÍA', style: textos.labelSmall)),
              Mono(
                '${(escalaTexto * 100).round()}%',
                color: paleta.acentoAlt,
                peso: FontWeight.w600,
              ),
            ],
          ),
          Slider(
            min: 0.85,
            max: 1.30,
            divisions: 9,
            value: escalaTexto,
            label: '${(escalaTexto * 100).round()}%',
            onChanged: alCambiarTexto,
          ),
          Text(
            'Las preferencias quedan guardadas localmente para que el controlador global de apariencia pueda aplicarlas al arrancar.',
            style: textos.bodySmall?.copyWith(color: paleta.tintaTenue),
          ),
        ],
      ),
    );
  }
}

class _Acento extends StatelessWidget {
  const _Acento({
    required this.nombre,
    required this.color,
    required this.activo,
    required this.alPulsar,
  });

  final String nombre;
  final Color color;
  final bool activo;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    return InkWell(
      onTap: alPulsar,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 104,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: activo ? color.withValues(alpha: 0.12) : paleta.superficie,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: activo ? color : paleta.rejilla, width: activo ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(nombre, style: Theme.of(context).textTheme.bodySmall)),
          ],
        ),
      ),
    );
  }
}

class _Fondo extends StatelessWidget {
  const _Fondo({required this.fondo, required this.alCambiar});

  final String fondo;
  final ValueChanged<String> alCambiar;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;
    return Tarjeta(
      titulo: 'Fondo',
      icono: Icons.wallpaper_outlined,
      sufijo: Insignia(fondo, tono: paleta.acento),
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TIPO DE FONDO', style: textos.labelSmall),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: fondo,
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            items: const [
              DropdownMenuItem(value: 'ninguno', child: Text('Sin fondo')),
              DropdownMenuItem(value: 'degradado', child: Text('Degradado')),
              DropdownMenuItem(value: 'imagen', child: Text('Imagen')),
              DropdownMenuItem(value: 'video', child: Text('Vídeo')),
            ],
            onChanged: (v) {
              if (v != null) alCambiar(v);
            },
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: paleta.acento.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: paleta.acento.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome_outlined, size: 17, color: paleta.acento),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Imagen y vídeo quedan definidos como preferencias de UI. La selección de archivos y el render animado pueden conectarse después sin cambiar esta pantalla.',
                    style: textos.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VistaPrevia extends StatelessWidget {
  const _VistaPrevia({
    required this.tema,
    required this.acento,
    required this.escalaTexto,
    required this.fondo,
  });

  final String tema;
  final String acento;
  final double escalaTexto;
  final String fondo;

  Color get colorAcento => switch (acento) {
        'morado' => const Color(0xFFB388FF),
        'cian' => const Color(0xFF5CD7F2),
        'azul' => const Color(0xFF70C8FF),
        _ => const Color(0xFFFF8FC4),
      };

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final oscuro = tema == 'oscuro';
    return Tarjeta(
      titulo: 'Vista previa',
      icono: Icons.visibility_outlined,
      sufijo: Insignia('guardado', tono: paleta.bien),
      hijo: Container(
        constraints: const BoxConstraints(minHeight: 150),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: oscuro ? const Color(0xFF141316) : const Color(0xFFF8F5FA),
          gradient: fondo == 'degradado'
              ? LinearGradient(
                  colors: [
                    colorAcento.withValues(alpha: 0.25),
                    const Color(0xFF5CD7F2).withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: paleta.rejilla),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 68,
              decoration: BoxDecoration(color: colorAcento, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TU WORKSPACE', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorAcento)),
                  const SizedBox(height: 8),
                  Text(
                    'duo-desktop',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontSize: 22 * escalaTexto,
                          color: oscuro ? Colors.white : Colors.black87,
                        ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Vista previa del tema, acento y escala elegidos.',
                    style: TextStyle(
                      fontSize: 13 * escalaTexto,
                      color: oscuro ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
