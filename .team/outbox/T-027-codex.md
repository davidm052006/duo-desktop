# T-027 — entregable de `codex`

**Rama:** `codex/t-027-prueba-de-owner-nuevo-para-validacion-ph`  
**Cerrado:** 2026-10-03 15:03

## Cambios contra la base

```
 service/Duo/LiveEventStream.cs               | 29 +++++++++---
 service/Duo/TaskOwnerHistoryReader.cs        | 67 ++++++++++++++++++++++++++++
 service/Program.cs                           |  1 +
 service/tests/TaskOwnerHistoryReaderTests.cs | 59 ++++++++++++++++++++++++
 4 files changed, 151 insertions(+), 5 deletions(-)
```

## Lo que reportó el agente

+            | --- | --- | --- | --- | --- | --- |
+            | T-027 | título con | separador | nuevo | nuevo/t-027 | integrada | 2026-10-03 |
+            """);
+        Commit(repository, "T-027 integrada", 1);
+        WriteBoard("""
+            | Tarea | Título | Dueño | Rama | Estado | Abierta |
+            | --- | --- | --- | --- | --- | --- |
+            """);
+        Commit(repository, "oculta T-027", 2);
+    }
+
+    var project = new DuoProject("test", root, "main", root, []);
+    var owners = new TaskOwnerHistoryReader(NullLogger<TaskOwnerHistoryReader>.Instance)
+        .Read(project, ["T-027"]);
+    if (owners["T-027"] != "nuevo") throw new InvalidOperationException("owner histórico incorrecto");
+    Console.WriteLine("Owner histórico validado");
+}
+finally
+{
+    if (Directory.Exists(root)) Directory.Delete(root, recursive: true);
+}
+
+void WriteBoard(string content)
+{
+    var team = Path.Combine(root, ".team");
+    Directory.CreateDirectory(team);
+    File.WriteAllText(Path.Combine(team, "BOARD.md"), content);
+}
+
+static void Commit(Repository repository, string message, int sequence)
+{
+    Commands.Stage(repository, ".team/BOARD.md");
+    var when = DateTimeOffset.UnixEpoch.AddMinutes(sequence);
+    var author = new Signature("Test", "test@example.test", when);
+    repository.Commit(message, author, author);
+}
diff --git a//tmp/t027-owner-history-PQvIif/t027-owner-history-PQvIif.csproj b//tmp/t027-owner-history-PQvIif/t027-owner-history-PQvIif.csproj
index 74bf30082c9ce3d31b0d2e2327efd7d7d3f7d63d..e9eaf993d205ede0698c8644767b7bacf15ce976
--- a//tmp/t027-owner-history-PQvIif/t027-owner-history-PQvIif.csproj
+++ b//tmp/t027-owner-history-PQvIif/t027-owner-history-PQvIif.csproj
@@ -8,4 +8,7 @@
     <Nullable>enable</Nullable>
   </PropertyGroup>
 
+  <ItemGroup>
+    <ProjectReference Include="/home/david/dev/wt/codex-duo-desktop/service/DuoDesktop.Service.csproj" />
+  </ItemGroup>
 </Project>

tokens used
86,043
T-027 quedó aplicada y registrada en `60bc352`.

- Se conserva el owner histórico de sesiones aunque la tarea ya no esté en `BOARD.md`.
- Añadí la prueba de regresión para `T-027` con owner `nuevo`.
- Verifiqué el escenario directamente: `Owner histórico validado`.
- `dotnet build service/tests/DuoDesktop.Service.Tests.csproj --no-restore` pasó.
- `git diff --check` pasó; árbol de trabajo limpio.

El runner normal de VSTest sigue bloqueado por la restricción de sockets del sandbox, pero la regresión se ejecutó mediante un arnés directo equivalente.
