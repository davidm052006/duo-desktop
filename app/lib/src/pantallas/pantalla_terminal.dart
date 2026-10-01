import 'package:flutter/material.dart';

import '../tema/paleta.dart';
import '../widgets/tarjeta.dart';

class PantallaTerminal extends StatelessWidget {
  const PantallaTerminal({super.key});

  static const _lineas = <_LineaTerminal>[
    _LineaTerminal('chat', 'Leyendo el brief de la tarea…'),
    _LineaTerminal('codex', r'$ dotnet test --no-restore'),
    _LineaTerminal('codex', 'Passed! 26 tests completados.'),
    _LineaTerminal('cc', 'Revisando cambios multiarchivo y estado del worktree…'),
    _LineaTerminal('chat', 'Entregable preparado para revisión cruzada.'),
  ];

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 36),
      children: [
        Row(
          children: [
            Text(
              'Terminal',
              style: textos.headlineSmall?.copyWith(fontSize: 26),
            ),
            const SizedBox(width: 12),
            Insignia('DEMO', tono: paleta.aviso),
            const SizedBox(width: 8),
            const MarcaFase(5),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Vista previa de la salida de agentes. Las líneas siguientes son datos de ejemplo, no una sesión real.',
          style: textos.bodySmall?.copyWith(color: paleta.tintaSecundaria),
        ),
        const SizedBox(height: 24),
        Tarjeta(
          titulo: 'Salida de agentes',
          icono: Icons.terminal,
          sufijo: Insignia('ejemplo', tono: paleta.aviso),
          pie: Row(
            children: [
              Icon(Icons.info_outline, size: 15, color: paleta.tintaTenue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'La ejecución real, PTY y streaming en vivo llegan en la Fase 5.',
                  style: textos.bodySmall?.copyWith(color: paleta.tintaTenue),
                ),
              ),
            ],
          ),
          hijo: Container(
            height: 430,
            decoration: BoxDecoration(
              color: const Color(0xFF0E0E10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: paleta.rejilla),
            ),
            child: Scrollbar(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _lineas.length,
                itemBuilder: (context, i) => _Linea(linea: _lineas[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LineaTerminal {
  const _LineaTerminal(this.agente, this.texto);

  final String agente;
  final String texto;
}

class _Linea extends StatelessWidget {
  const _Linea({required this.linea});

  final _LineaTerminal linea;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final color = paleta.serieDe(linea.agente);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(
              '[${linea.agente}]',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              linea.texto,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                height: 1.45,
                color: Color(0xFFE8E8EA),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
