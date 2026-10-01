import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../estado/estado_tablero.dart';
import '../tema/paleta.dart';
import '../widgets/tarjeta.dart';

class PantallaConfiguracion extends StatefulWidget {
  const PantallaConfiguracion({super.key});

  @override
  State<PantallaConfiguracion> createState() => _PantallaConfiguracionState();
}

class _PantallaConfiguracionState extends State<PantallaConfiguracion> {
  static const _rutaDuoKey = 'config.ruta_duo';
  static const _rutaConfigKey = 'config.ruta_config_duo';

  final _rutaDuo = TextEditingController();
  final _rutaConfig = TextEditingController();
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _rutaDuo.dispose();
    _rutaConfig.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    // Nunca dejar la pantalla colgada esperando al almacén de preferencias:
    // con los valores por defecto se puede trabajar igual.
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('Configuración: no pude leer las preferencias ($e)');
    }
    if (!mounted) return;
    _rutaDuo.text = prefs?.getString(_rutaDuoKey) ?? '~/.local/bin/duo';
    _rutaConfig.text = prefs?.getString(_rutaConfigKey) ?? '~/.config/duo';
    setState(() => _cargando = false);
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rutaDuoKey, _rutaDuo.text.trim());
    await prefs.setString(_rutaConfigKey, _rutaConfig.text.trim());
    if (!mounted) return;
    setState(() => _guardando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuración local guardada.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(
        child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final estado = context.watch<EstadoTablero>();
    return LayoutBuilder(
      builder: (context, caja) {
        final dosColumnas = caja.maxWidth >= 980;
        final proyecto = _ProyectoActivo(estado: estado);
        final servicio = _ServicioLocal(estado: estado);

        return ListView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 36),
          children: [
            const _Cabecera(),
            const SizedBox(height: 24),
            if (dosColumnas)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: proyecto),
                    const SizedBox(width: 18),
                    Expanded(child: servicio),
                  ],
                ),
              )
            else ...[
              proyecto,
              const SizedBox(height: 18),
              servicio,
            ],
            const SizedBox(height: 18),
            _RutasDuo(
              rutaDuo: _rutaDuo,
              rutaConfig: _rutaConfig,
              guardando: _guardando,
              alGuardar: _guardar,
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
            Text('Configuración', style: textos.headlineSmall?.copyWith(fontSize: 26)),
            const SizedBox(width: 12),
            Insignia('entorno local', tono: paleta.acentoAlt),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Proyecto activo, rutas de duo y estado del servicio local.',
          style: textos.bodySmall?.copyWith(color: paleta.tintaSecundaria),
        ),
      ],
    );
  }
}

class _ProyectoActivo extends StatelessWidget {
  const _ProyectoActivo({required this.estado});

  final EstadoTablero estado;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final proyecto = estado.tablero?.proyecto;
    return Tarjeta(
      titulo: 'Proyecto activo',
      icono: Icons.folder_open_outlined,
      sufijo: Insignia(
        proyecto == null ? 'sin datos' : 'activo',
        tono: proyecto == null ? paleta.aviso : paleta.bien,
      ),
      hijo: proyecto == null
          ? Text(
              'El servicio todavía no informó un proyecto activo.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          : Column(
              children: [
                _Dato(etiqueta: 'Nombre', valor: proyecto.nombre),
                const SizedBox(height: 14),
                _Dato(etiqueta: 'Repo', valor: proyecto.repo.isEmpty ? 'no declarado' : proyecto.repo),
                const SizedBox(height: 14),
                _Dato(
                  etiqueta: 'Pizarra',
                  valor: proyecto.pizarra.isEmpty ? 'no declarada' : '${proyecto.pizarra}/.team',
                ),
              ],
            ),
      pie: Text(
        'El proyecto lo decide duo. Esta vista solo muestra el estado real recibido por GET /board.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: paleta.tintaTenue),
      ),
    );
  }
}

class _ServicioLocal extends StatelessWidget {
  const _ServicioLocal({required this.estado});

  final EstadoTablero estado;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final config = ConfigDuo.desdeEntorno;
    final conectado = estado.tablero != null && !estado.obsoleto;
    final tono = conectado ? paleta.bien : paleta.aviso;

    return Tarjeta(
      titulo: 'Servicio local',
      icono: Icons.dns_outlined,
      sufijo: Insignia(conectado ? 'conectado' : 'sin respuesta', tono: tono),
      hijo: Column(
        children: [
          const _Dato(etiqueta: 'Host', valor: '127.0.0.1'),
          const SizedBox(height: 14),
          _Dato(etiqueta: 'Puerto', valor: '${config.puerto}'),
          const SizedBox(height: 14),
          _Dato(etiqueta: 'URL', valor: 'http://127.0.0.1:${config.puerto}'),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tono.withValues(alpha: 0.08),
              border: Border.all(color: tono.withValues(alpha: 0.30)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: tono, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    conectado
                        ? 'El servicio local está respondiendo.'
                        : estado.fallo?.mensaje ?? 'Esperando respuesta del servicio local.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      pie: Text(
        'El puerto viene de SERVICE_PORT al arrancar la app; esta pantalla no reconfigura el proceso.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: paleta.tintaTenue),
      ),
    );
  }
}

class _RutasDuo extends StatelessWidget {
  const _RutasDuo({
    required this.rutaDuo,
    required this.rutaConfig,
    required this.guardando,
    required this.alGuardar,
  });

  final TextEditingController rutaDuo;
  final TextEditingController rutaConfig;
  final bool guardando;
  final VoidCallback alGuardar;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    return Tarjeta(
      titulo: 'Rutas de duo',
      icono: Icons.alt_route_outlined,
      sufijo: Insignia('local', tono: paleta.acento),
      hijo: LayoutBuilder(
        builder: (context, caja) {
          final horizontal = caja.maxWidth >= 850;
          final campos = [
            _CampoRuta(
              etiqueta: 'EJECUTABLE DUO',
              controlador: rutaDuo,
              pista: '~/.local/bin/duo',
            ),
            _CampoRuta(
              etiqueta: 'CONFIGURACIÓN DUO',
              controlador: rutaConfig,
              pista: '~/.config/duo',
            ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (horizontal)
                Row(
                  children: [
                    Expanded(child: campos[0]),
                    const SizedBox(width: 18),
                    Expanded(child: campos[1]),
                  ],
                )
              else ...[
                campos[0],
                const SizedBox(height: 18),
                campos[1],
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Estas rutas se guardan con shared_preferences; no cambian el backend en ejecución.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: paleta.tintaTenue),
                    ),
                  ),
                  const SizedBox(width: 18),
                  FilledButton.icon(
                    onPressed: guardando ? null : alGuardar,
                    icon: guardando
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined, size: 16),
                    label: Text(guardando ? 'Guardando…' : 'Guardar'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CampoRuta extends StatelessWidget {
  const _CampoRuta({
    required this.etiqueta,
    required this.controlador,
    required this.pista,
  });

  final String etiqueta;
  final TextEditingController controlador;
  final String pista;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          TextField(
            controller: controlador,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.folder_outlined, size: 18),
              hintText: pista,
            ),
          ),
        ],
      );
}

class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 82, child: Text(etiqueta.toUpperCase(), style: Theme.of(context).textTheme.labelSmall)),
        const SizedBox(width: 8),
        Expanded(child: Mono(valor, color: paleta.tintaSecundaria)),
      ],
    );
  }
}
