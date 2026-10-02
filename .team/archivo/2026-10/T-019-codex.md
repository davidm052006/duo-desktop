# T-019 — entregable de `codex`

**Rama:** `codex/t-019-implementa-en-el-servicio-c-el-streaming`  
**Cerrado:** 2026-10-01 17:17

## Cambios contra la base

```
 service/Duo/BoardModels.cs              |  12 +++
 service/Duo/DuoProject.cs               |   2 +
 service/Duo/LiveEventStream.cs          | 127 ++++++++++++++++++++++++++++++++
 service/Duo/QuestionReader.cs           |  44 +++++++++++
 service/Program.cs                      |  51 +++++++++++++
 service/docs/api/WEBSOCKET_EVENTS.md    |  23 ++++++
 service/tests/LiveEventContractTests.cs |  41 +++++++++++
 service/tests/QuestionReaderTests.cs    |  93 +++++++++++++++++++++++
 8 files changed, 393 insertions(+)
```

## Lo que reportó el agente

+        Directory.CreateDirectory(questions);
+        File.WriteAllText(Path.Combine(questions, "T-999.md"), "## PREGUNTA\n\n¿Sigo?\n");
+
+        var error = Assert.Throws<BoardException>(() => NewReader().Read());
+
+        Assert.Equal(422, error.Status);
+        Assert.Equal("invalid_board", error.Code);
+    }
+
+    public void Dispose()
+    {
+        Environment.SetEnvironmentVariable("DUO_CONF", _oldConf);
+        Environment.SetEnvironmentVariable("DUO_P", _oldProject);
+        if (Directory.Exists(_root)) Directory.Delete(_root, recursive: true);
+    }
+
+    private QuestionReader NewReader()
+    {
+        var locator = new DuoProjectLocator(NullLogger<DuoProjectLocator>.Instance);
+        return new QuestionReader(locator, new BoardReader(locator, NullLogger<BoardReader>.Instance),
+            NullLogger<QuestionReader>.Instance);
+    }
+
+    private string ConfigureProject()
+    {
+        var repo = Path.Combine(_root, "repo");
+        var board = Path.Combine(_root, "board");
+        var conf = Path.Combine(_root, "conf");
+        Directory.CreateDirectory(repo);
+        Directory.CreateDirectory(Path.Combine(board, ".team"));
+        Directory.CreateDirectory(conf);
+        File.WriteAllText(Path.Combine(board, ".team", "BOARD.md"), """
+            | Tarea | Título | Dueño | Rama | Estado | Abierta |
+            | --- | --- | --- | --- | --- | --- |
+            | T-019 | Implementar streaming | codex | codex/t-019 | haciendo | 2026-10-01 |
+            """);
+        File.WriteAllText(Path.Combine(board, ".team", "ledger.tsv"), """
+            agente	puntos	tareas	ultima
+            codex	1	1	2026-10-01
+            """);
+        File.WriteAllText(Path.Combine(conf, "test.conf"),
+            $"set -g DUO_PROJECT test\nset -g REPO_DIR {repo}\nset -g BOARD {board}\n");
+        Environment.SetEnvironmentVariable("DUO_CONF", conf);
+        Environment.SetEnvironmentVariable("DUO_P", "test");
+        return board;
+    }
+}

tokens used
49.406
Implementado y compilado en `service/`:

- `GET /questions` autenticado con Bearer; devuelve Markdown real, tarea y agente.
- WebSocket `/events` autenticado; emite `board_snapshot`, `board_changed` y `agent_output` desde `.team/sesiones/`.
- Especificación en [WEBSOCKET_EVENTS.md](/home/david/dev/wt/codex-duo-desktop/service/docs/api/WEBSOCKET_EVENTS.md).
- Tests para preguntas y contrato JSON de eventos.

Verificación: `dotnet build service/tests/DuoDesktop.Service.Tests.csproj --no-restore` pasó. El `dotnet test` dirigido no pudo iniciar: el sandbox bloquea el socket local interno de VSTest (`SocketException: Permission denied`) antes de ejecutar pruebas.

Pendiente: no pude crear commit porque el metadato Git del worktree está en una ruta de solo lectura y no se pudo crear `index.lock`. Tampoco toqué `docs/api/` raíz por la restricción explícita de limitar cambios a `service/`; la documentación quedó dentro de ese territorio.
