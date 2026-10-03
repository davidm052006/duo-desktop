# T-027 — entregable de `codex`

**Rama:** `codex/t-027-prueba-de-owner-nuevo-para-validacion-ph`  
**Cerrado:** 2026-10-03 14:53

## Cambios contra la base

```
 service/Duo/LiveEventStream.cs               | 29 +++++++++---
 service/Duo/TaskOwnerHistoryReader.cs        | 67 ++++++++++++++++++++++++++++
 service/Program.cs                           |  1 +
 service/tests/TaskOwnerHistoryReaderTests.cs | 59 ++++++++++++++++++++++++
 4 files changed, 151 insertions(+), 5 deletions(-)
```

## Lo que reportó el agente

+        using (var repository = new Repository(_root))
+        {
+            WriteBoard("""
+                | Tarea | Título | Dueño | Rama | Estado | Abierta |
+                | --- | --- | --- | --- | --- | --- |
+                | T-027 | título con | separador | nuevo | nuevo/t-027 | integrada | 2026-10-03 |
+                """);
+            Commit(repository, "T-027 integrada", 1);
+
+            WriteBoard("""
+                | Tarea | Título | Dueño | Rama | Estado | Abierta |
+                | --- | --- | --- | --- | --- | --- |
+                """);
+            Commit(repository, "oculta T-027 del tablero actual", 2);
+        }
+
+        var project = new DuoProject("test", _root, "main", _root, []);
+        var owners = new TaskOwnerHistoryReader(NullLogger<TaskOwnerHistoryReader>.Instance)
+            .Read(project, ["T-027"]);
+
+        Assert.Equal("nuevo", owners["T-027"]);
+    }
+
+    public void Dispose()
+    {
+        if (Directory.Exists(_root)) Directory.Delete(_root, recursive: true);
+    }
+
+    private void WriteBoard(string content)
+    {
+        var team = Path.Combine(_root, ".team");
+        Directory.CreateDirectory(team);
+        File.WriteAllText(Path.Combine(team, "BOARD.md"), content);
+    }
+
+    private static void Commit(Repository repository, string message, int sequence)
+    {
+        Commands.Stage(repository, ".team/BOARD.md");
+        var when = DateTimeOffset.UnixEpoch.AddMinutes(sequence);
+        var author = new Signature("Test", "test@example.test", when);
+        repository.Commit(message, author, author);
+    }
+}

tokens used
64,511
Implementé la corrección de owners históricos para eventos de sesión:

- Añadí `TaskOwnerHistoryReader`, que busca el owner de tareas ya ausentes de `BOARD.md` en el historial Git.
- `LiveEventStream` carga esos owners al conectar y conserva prioridad para el tablero actual.
- Registré el lector en DI.
- Añadí la regresión `TaskOwnerHistoryReaderTests`: verifica que `T-027`, retirada del tablero actual, mantiene el owner nuevo incluso con `|` en el título.

Validación:

- `dotnet build service/DuoDesktop.Service.csproj` pasó.
- La prueba fue compilada, pero `dotnet test` no pudo arrancar: el sandbox deniega el socket local que usa VSTest (`SocketException: Permission denied`).
- `git diff --check` pasó.

Pendiente para David: ejecutar `dotnet test service/tests/DuoDesktop.Service.Tests.csproj --filter FullyQualifiedName~TaskOwnerHistoryReaderTests` fuera de este sandbox. No pude rebasar ni commitear: el directorio Git compartido del worktree está montado como solo lectura.
