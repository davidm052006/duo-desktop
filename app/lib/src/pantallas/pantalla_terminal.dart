import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../estado/estado_tablero.dart';
import '../modelos/evento_duo.dart';
import '../tema/paleta.dart';
import '../widgets/tarjeta.dart';

/// Salida real de los agentes recibida por /events.
///
/// Esto cierra la necesidad de observabilidad de la Fase 2. Sigue sin ser un
/// PTY interactivo: escribir comandos dentro de la app pertenece a la Fase 5.
class PantallaTerminal extends StatelessWidget {
  const PantallaTerminal({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoTablero>();
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 36),
      children: [
        Row(
          children: [
            Text(
              'Salida en vivo',
              style: textos.headlineSmall?.copyWith(fontSize: 26),
            ),
            const SizedBox(width: 12),
            Insignia(
              estado.eventosConectados ? 'EN VIVO' : 'RECONECTANDO',
              tono: estado.eventosConectados ? paleta.bien : paleta.aviso,
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: estado.salidas.isEmpty ? null : estado.limpiaSalidas,
              icon: const Icon(Icons.delete_sweep_outlined, size: 16),
              label: const Text('Limpiar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          estado.eventosConectados
              ? 'Eventos reales del servicio local. La pizarra y la salida de agentes llegan por WebSocket.'
              : 'El canal WebSocket no está disponible ahora. Duo conserva la última pizarra válida y usa sondeo mientras reconecta.',
          style: textos.bodySmall?.copyWith(color: paleta.tintaSecundaria),
        ),
        if (estado.falloEventos != null && !estado.eventosConectados) ...[
          const SizedBox(height: 8),
          Mono(
            '${estado.falloEventos!.codigo}: ${estado.falloEventos!.mensaje}',
            color: paleta.aviso,
          ),
        ],
        const SizedBox(height: 24),
        Tarjeta(
          titulo: 'Salida de agentes',
          icono: Icons.wifi_tethering,
          sufijo: Insignia(
            '${estado.salidas.length} bloque(s)',
            tono: paleta.tintaSecundaria,
            mono: true,
          ),
          pie: Row(
            children: [
              Icon(Icons.info_outline, size: 15, color: paleta.tintaTenue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Esta vista es streaming de salida (Fase 2). La terminal PTY interactiva sigue reservada para la Fase 5.',
                  style: textos.bodySmall?.copyWith(color: paleta.tintaTenue),
                ),
              ),
            ],
          ),
          hijo: Container(
            height: 500,
            decoration: BoxDecoration(
              color: const Color(0xFF0E0E10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: paleta.rejilla),
            ),
            child: estado.salidas.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        estado.eventosConectados
                            ? 'Aún no ha llegado salida de agentes. Crea una tarea y aparecerá aquí cuando duo escriba su sesión.'
                            : 'Esperando reconexión con /events…',
                        textAlign: TextAlign.center,
                        style: textos.bodySmall?.copyWith(
                          color: paleta.tintaTenue,
                        ),
                      ),
                    ),
                  )
                : Scrollbar(
                    child: ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: estado.salidas.length,
                      itemBuilder: (context, i) {
                        final salida =
                            estado.salidas[estado.salidas.length - 1 - i];
                        return _Linea(salida: salida);
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea({required this.salida});

  final SalidaAgente salida;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final agente = salida.agente ?? 'agente';
    final color = paleta.serieDe(agente);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '[$agente]',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Mono(
                  salida.tareaId,
                  color: paleta.tintaTenue,
                ),
              ],
            ),
          ),
          Expanded(
            child: SelectableText(
              salida.texto,
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
