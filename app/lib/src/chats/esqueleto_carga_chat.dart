import 'package:flutter/material.dart';

import '../tema/paleta.dart';
import 'proveedor_chat.dart';

class EsqueletoCargaChat extends StatefulWidget {
  const EsqueletoCargaChat({super.key, required this.proveedor});

  final ProveedorChat proveedor;

  @override
  State<EsqueletoCargaChat> createState() => _EsqueletoCargaChatState();
}

class _EsqueletoCargaChatState extends State<EsqueletoCargaChat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso;

  @override
  void initState() {
    super.initState();
    _pulso = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final acento = widget.proveedor == ProveedorChat.grok
        ? paleta.acentoAlt
        : paleta.acento;

    return AnimatedBuilder(
      animation: _pulso,
      builder: (context, _) {
        final t = 0.42 + (_pulso.value * 0.28);
        return ColoredBox(
          color: paleta.panel,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Bloque(
                      ancho: 28,
                      alto: 28,
                      radio: 8,
                      color: acento.withValues(alpha: t),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Abriendo ${widget.proveedor.nombre}…',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: paleta.tintaSecundaria,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _Bloque(
                  ancho: 220,
                  alto: 12,
                  color: paleta.rejilla.withValues(alpha: t),
                ),
                const SizedBox(height: 14),
                _Bloque(
                  ancho: double.infinity,
                  alto: 12,
                  color: paleta.rejilla.withValues(alpha: t * 0.9),
                ),
                const SizedBox(height: 10),
                _Bloque(
                  ancho: 280,
                  alto: 12,
                  color: paleta.rejilla.withValues(alpha: t * 0.75),
                ),
                const SizedBox(height: 28),
                Expanded(
                  child: _Bloque(
                    ancho: double.infinity,
                    alto: double.infinity,
                    radio: 10,
                    color: paleta.superficie.withValues(alpha: 0.55 + t * 0.2),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.bottomRight,
                  child: _Bloque(
                    ancho: 72,
                    alto: 36,
                    radio: 18,
                    color: acento.withValues(alpha: 0.18 + t * 0.2),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Bloque extends StatelessWidget {
  const _Bloque({
    required this.ancho,
    required this.alto,
    required this.color,
    this.radio = 6,
  });

  final double ancho;
  final double alto;
  final Color color;
  final double radio;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ancho.isFinite ? ancho : null,
      height: alto.isFinite ? alto : null,
      constraints: alto == double.infinity
          ? const BoxConstraints.expand()
          : null,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radio),
      ),
    );
  }
}
