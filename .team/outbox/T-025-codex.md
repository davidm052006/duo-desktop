# T-025 — entregable de `codex`

**Rama:** `codex/t-025-prueba-e2e-breve-confirmar-los-eventos-b`  
**Cerrado:** 2026-10-03 14:36

## Cambios contra la base

```
 service/tests/LiveEventStreamTests.cs | 123 ++++++++++++++++++++++++++++++++++
 1 file changed, 123 insertions(+)
```

## Lo que reportó el agente

+        Environment.SetEnvironmentVariable("DUO_CONF", Path.Combine(_root, "conf"));
+        Environment.SetEnvironmentVariable("DUO_P", "e2e");
+    }
+
+    private sealed class RecordingWebSocket(Action<JsonElement> onSnapshot) : WebSocket
+    {
+        private WebSocketState _state = WebSocketState.Open;
+
+        public List<JsonElement> Messages { get; } = [];
+        public Action<JsonElement>? OnMessage { get; set; }
+        public override WebSocketCloseStatus? CloseStatus => null;
+        public override string? CloseStatusDescription => null;
+        public override WebSocketState State => _state;
+        public override string SubProtocol => "";
+
+        public override void Abort() => _state = WebSocketState.Aborted;
+
+        public override Task CloseAsync(WebSocketCloseStatus closeStatus, string? statusDescription,
+            CancellationToken cancellationToken)
+        {
+            _state = WebSocketState.Closed;
+            return Task.CompletedTask;
+        }
+
+        public override Task CloseOutputAsync(WebSocketCloseStatus closeStatus, string? statusDescription,
+            CancellationToken cancellationToken) => CloseAsync(closeStatus, statusDescription, cancellationToken);
+
+        public override void Dispose() => _state = WebSocketState.Closed;
+
+        public override Task<WebSocketReceiveResult> ReceiveAsync(ArraySegment<byte> buffer,
+            CancellationToken cancellationToken) => throw new NotSupportedException();
+
+        public override Task SendAsync(ArraySegment<byte> buffer, WebSocketMessageType messageType,
+            bool endOfMessage, CancellationToken cancellationToken)
+        {
+            using var document = JsonDocument.Parse(buffer.AsMemory());
+            var payload = document.RootElement.Clone();
+            Messages.Add(payload);
+            if (payload.GetProperty("type").GetString() == "board_snapshot") onSnapshot(payload);
+            OnMessage?.Invoke(payload);
+            return Task.CompletedTask;
+        }
+    }
+}

tokens used
43,905
Alcance mínimo: añadí solo la prueba de eventos en `service/tests/LiveEventStreamTests.cs`.

- Cubre el flujo completo del emisor: `board_snapshot` inicial, cambio de `BOARD.md` → `board_changed` con `T-026`, y escritura de sesión → `agent_output` de `T-025/codex`.
- Compila correctamente con `dotnet build service/tests/DuoDesktop.Service.Tests.csproj --no-restore`.
- La ejecución de pruebas y Kestrel están bloqueados por el sandbox: ambos necesitan abrir sockets locales (`SocketException: Permission denied`). No es un fallo del servicio.

Pendiente para David: ejecutar fuera de este sandbox:

```bash
dotnet test service/tests/DuoDesktop.Service.Tests.csproj --no-restore --filter FullyQualifiedName~LiveEventStreamTests
```

No pude crear commit: el metadata Git compartido está en solo lectura. Además, la rama cambió externamente a `codex/t-026-…` durante la tarea; dejé el archivo nuevo sin commitear para no modificar ese estado.
