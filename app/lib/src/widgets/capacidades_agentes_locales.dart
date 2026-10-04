import 'package:flutter/material.dart';

import '../datos/cliente_duo.dart';
import '../tema/paleta.dart';
import 'tarjeta.dart';

/// Disponibilidad real de este equipo. ChatGPT y Grok se muestran como chats
/// web, porque no son ejecutables que Duo pueda lanzar localmente.
class CapacidadesAgentesLocales extends StatefulWidget {
  const CapacidadesAgentesLocales({super.key, this.cliente});

  final ClienteDuo? cliente;

  @override
  State<CapacidadesAgentesLocales> createState() =>
      _CapacidadesAgentesLocalesState();
}

class _CapacidadesAgentesLocalesState extends State<CapacidadesAgentesLocales> {
  late final ClienteDuo _cliente;
  late Future<List<CapacidadAgenteLocal>> _future;
  late final bool _ownsClient;

  @override
  void initState() {
    super.initState();
    _ownsClient = widget.cliente == null;
    _cliente = widget.cliente ?? ClienteDuo();
    _future = _cliente.capacidadesAgentes();
  }

  @override
  void dispose() {
    if (_ownsClient) _cliente.cierra();
    super.dispose();
  }

  void _reload() => setState(() => _future = _cliente.capacidadesAgentes());

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    return Tarjeta(
      titulo: 'Agentes en este dispositivo',
      icono: Icons.memory_outlined,
      sufijo: IconButton(
        tooltip: 'Actualizar disponibilidad',
        onPressed: _reload,
        icon: const Icon(Icons.refresh, size: 18),
      ),
      hijo: FutureBuilder<List<CapacidadAgenteLocal>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(),
            );
          }
          if (snapshot.hasError) {
            return Text(
              'No se pudo consultar la disponibilidad local. Reintenta cuando el servicio Duo esté activo.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: paleta.aviso),
            );
          }

          final local = {
            for (final capability
                in snapshot.data ?? const <CapacidadAgenteLocal>[])
              capability.provider: capability,
          };
          return Column(
            children: [
              const _FilaAgente(
                nombre: 'ChatGPT Web',
                detalle: 'Chat web CEF',
                web: true,
              ),
              const _FilaAgente(
                nombre: 'Grok Web',
                detalle: 'Chat web CEF',
                web: true,
              ),
              _FilaAgente(nombre: 'Codex Local', capacidad: local['codex']),
              _FilaAgente(
                nombre: 'Claude Code Local',
                capacidad: local['claude'],
              ),
              _FilaAgente(nombre: 'Gemini Local', capacidad: local['gemini']),
            ],
          );
        },
      ),
    );
  }
}

class _FilaAgente extends StatelessWidget {
  const _FilaAgente({
    this.capacidad,
    required this.nombre,
    this.detalle,
    this.web = false,
  });

  final CapacidadAgenteLocal? capacidad;
  final String nombre;
  final String? detalle;
  final bool web;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final disponible = capacidad?.disponible == true;
    final estado = web
        ? detalle!
        : disponible
        ? 'Disponible'
        : 'No instalado';
    final color = web || disponible ? paleta.bien : paleta.tintaTenue;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(nombre)),
          Insignia(estado, tono: color, mono: !web),
        ],
      ),
    );
  }
}
