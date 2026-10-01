# T-014 — entregable de `codex`

**Rama:** `codex/t-014-implementa-en-el-servicio-c-los-endpoint`  
**Cerrado:** 2026-10-01 16:27

## Cambios contra la base

```
 service/Duo/BoardModels.cs             |  6 +++
 service/Duo/DuoCommandRunner.cs        | 95 ++++++++++++++++++++++++++++++++++
 service/Program.cs                     | 49 ++++++++++++++++++
 service/tests/DuoCommandRunnerTests.cs | 86 ++++++++++++++++++++++++++++++
 4 files changed, 236 insertions(+)
```

## Lo que reportó el agente

+        ConfigureProject("exit 0", createDirectories: false);
+        var runner = NewRunner();
+
+        var error = await Assert.ThrowsAsync<DuoCommandException>(() =>
+            runner.CreateTaskAsync("una tarea válida", CancellationToken.None));
+
+        Assert.Equal(404, error.Status);
+        Assert.Equal("project_not_found", error.Code);
+    }
+
+    public void Dispose()
+    {
+        Environment.SetEnvironmentVariable("DUO_CONF", _oldConf);
+        Environment.SetEnvironmentVariable("DUO_P", _oldProject);
+        Environment.SetEnvironmentVariable("DUO_EXECUTABLE", _oldExecutable);
+        if (Directory.Exists(_root)) Directory.Delete(_root, recursive: true);
+    }
+
+    private DuoCommandRunner NewRunner() => new(
+        new DuoProjectLocator(NullLogger<DuoProjectLocator>.Instance),
+        NullLogger<DuoCommandRunner>.Instance);
+
+    private string ConfigureProject(string scriptBody, bool createDirectories = true)
+    {
+        var repo = Path.Combine(_root, "repo");
+        var board = Path.Combine(_root, "board");
+        var conf = Path.Combine(_root, "conf");
+        var capture = Path.Combine(_root, "arguments.txt");
+        Directory.CreateDirectory(conf);
+        if (createDirectories)
+        {
+            Directory.CreateDirectory(repo);
+            Directory.CreateDirectory(board);
+        }
+        var executable = Path.Combine(_root, "fake-duo.sh");
+        File.WriteAllText(executable, "#!/bin/sh\n" + scriptBody + "\n");
+        File.SetUnixFileMode(executable, UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.UserExecute);
+        File.WriteAllText(Path.Combine(conf, "test.conf"),
+            $"set -g DUO_PROJECT test\nset -g REPO_DIR {repo}\nset -g BOARD {board}\n");
+        Environment.SetEnvironmentVariable("DUO_CONF", conf);
+        Environment.SetEnvironmentVariable("DUO_P", "test");
+        Environment.SetEnvironmentVariable("DUO_EXECUTABLE", executable);
+        Environment.SetEnvironmentVariable("CAPTURE", capture);
+        return capture;
+    }
+}

tokens used
52.991
Implementado en `service/`:

- `POST /tasks`: requiere Bearer, valida `text`, ejecuta `duo <texto>` y devuelve `{ "id": "T-NNN" }`.
- `POST /questions/{id}/answer`: requiere Bearer, valida `text`, ejecuta `duo answer <id> <texto>`.
- Errores: 401 `unauthorized`, 422 `invalid_request`, 404 `project_not_found`, 500 `duo_command_failed`, con la envoltura existente.
- Añadidas pruebas del ejecutor: creación, reanudación y proyecto inexistente.
- No toqué Flutter.

Verificación: `dotnet build service/tests/DuoDesktop.Service.Tests.csproj --no-restore` compila correctamente. `dotnet test` no pudo ejecutarse porque el sandbox deniega el socket local que usa VSTest.

Pendiente: no pude crear el commit por permisos de solo lectura en el `gitdir` compartido (`/home/david/dev/activo/.../index.lock`). David debe verificar los endpoints en un proceso local con `DUO_TOKEN` y poder de escritura sobre ese gitdir.
