# T-011 — entregable de `codex`

**Rama:** `codex/t-011-implementa-en-el-servicio-c-los-endpoint`  
**Cerrado:** 2026-10-01 15:57

## Cambios contra la base

```
 service/Duo/BoardModels.cs                    |  24 ++++++
 service/Duo/GitHubReader.cs                   | 108 ++++++++++++++++++++++++++
 service/Duo/HistoryReader.cs                  |  36 +++++++++
 service/DuoDesktop.Service.csproj             |   4 +
 service/Program.cs                            |  44 +++++++++++
 service/Properties/AssemblyInfo.cs            |   3 +
 service/tests/DuoDesktop.Service.Tests.csproj |  22 ++++++
 service/tests/GitHubReaderTests.cs            |  31 ++++++++
 service/tests/HistoryReaderTests.cs           |  91 ++++++++++++++++++++++
 9 files changed, 363 insertions(+)
```

## Lo que reportó el agente

+        using (var repo = new Repository(repoDir))
+        {
+            for (var i = 0; i < 51; i++) Commit(repo, $"commit {i}");
+        }
+        ConfigureProject(repoDir);
+
+        var reader = new HistoryReader(
+            new DuoProjectLocator(NullLogger<DuoProjectLocator>.Instance),
+            NullLogger<HistoryReader>.Instance);
+
+        var history = reader.Read();
+
+        Assert.Equal(50, history.Commits.Count);
+        Assert.Equal("commit 50", history.Commits[0].Message);
+        Assert.Equal("commit 1", history.Commits[^1].Message);
+    }
+
+    public void Dispose()
+    {
+        Environment.SetEnvironmentVariable("DUO_CONF", _oldConf);
+        Environment.SetEnvironmentVariable("DUO_P", _oldProject);
+        if (Directory.Exists(_root)) Directory.Delete(_root, recursive: true);
+    }
+
+    private void ConfigureProject(string repoDir)
+    {
+        var confDir = Path.Combine(_root, "conf");
+        Directory.CreateDirectory(confDir);
+        File.WriteAllText(Path.Combine(confDir, "test.conf"),
+            $"set -g DUO_PROJECT test\nset -g REPO_DIR {repoDir}\nset -g BOARD {_root}\n");
+        Environment.SetEnvironmentVariable("DUO_CONF", confDir);
+        Environment.SetEnvironmentVariable("DUO_P", "test");
+    }
+
+    private static void Commit(Repository repo, string message)
+    {
+        var path = Path.Combine(repo.Info.WorkingDirectory, "commits.txt");
+        File.AppendAllText(path, message + Environment.NewLine);
+        Commands.Stage(repo, "commits.txt");
+        var when = DateTimeOffset.UtcNow;
+        var author = new Signature("Test", "test@example.test", when);
+        repo.Commit(message, author, author);
+    }
+}
+
+[CollectionDefinition("environment", DisableParallelization = true)]
+public sealed class EnvironmentCollection;

tokens used
57.625
Implementé en `service/`:

- `GET /history`: últimos 50 commits locales con LibGit2Sharp.
- `GET /github`: ramas y pull requests de `origin` mediante Octokit; admite remotos HTTPS y SSH de GitHub, y usa `GITHUB_TOKEN` o `GH_TOKEN` si existe.
- Ambos reutilizan `Authorization: Bearer` y los códigos/envoltura de error existentes.
- Añadí modelos de respuesta y pruebas xUnit para historial y resolución de remotos.

Verificado: `dotnet build service/DuoDesktop.Service.csproj --no-restore` compila correctamente (solo aviso de auditoría NuGet sin acceso a red).

Pendiente para David: ejecutar `dotnet test service/tests/DuoDesktop.Service.Tests.csproj` en un entorno con acceso a NuGet; aquí fue bloqueado por `NU1301`/acceso denegado a `api.nuget.org`. Tampoco pude crear el commit porque el `.git` del worktree apunta a una ruta de solo lectura fuera del sandbox. No se tocó Flutter.
