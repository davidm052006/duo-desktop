import 'tablero.dart';

sealed class EventoDuo {
  const EventoDuo();

  factory EventoDuo.desdeJson(Map<String, dynamic> json) {
    final tipo = json['type'] as String?;
    return switch (tipo) {
      'board_snapshot' || 'board_changed' => EventoTablero(
          tipo: tipo!,
          tablero: Tablero.desdeJson(
            (json['board'] as Map).cast<String, dynamic>(),
          ),
        ),
      'agent_output' => EventoSalidaAgente(
          tareaId: json['taskId'] as String,
          agente: json['agent'] as String?,
          texto: json['text'] as String,
        ),
      _ => throw FormatException('Tipo de evento desconocido: $tipo'),
    };
  }
}

final class EventoTablero extends EventoDuo {
  const EventoTablero({required this.tipo, required this.tablero});

  final String tipo;
  final Tablero tablero;
}

final class EventoSalidaAgente extends EventoDuo {
  const EventoSalidaAgente({
    required this.tareaId,
    required this.agente,
    required this.texto,
  });

  final String tareaId;
  final String? agente;
  final String texto;
}

class SalidaAgente {
  const SalidaAgente({
    required this.tareaId,
    required this.agente,
    required this.texto,
    required this.recibida,
  });

  final String tareaId;
  final String? agente;
  final String texto;
  final DateTime recibida;
}
