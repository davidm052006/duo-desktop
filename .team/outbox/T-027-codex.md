# T-027 — entregable de `codex`

**Rama:** `codex/t-027-prueba-de-owner-nuevo-para-validacion-ph`  
**Cerrado:** 2026-10-03 14:48

## Cambios contra la base

```
(sin cambios)
```

## Lo que reportó el agente

        Directory.CreateDirectory(Path.Combine(board, ".team"));
        Directory.CreateDirectory(conf);
        File.WriteAllText(Path.Combine(board, ".team", "BOARD.md"), """
            | Tarea | Título | Dueño | Rama | Estado | Abierta |
            | --- | --- | --- | --- | --- | --- |
            | T-019 | Implementar streaming | codex | codex/t-019 | haciendo | 2026-10-01 |
            """);
        File.WriteAllText(Path.Combine(board, ".team", "ledger.tsv"), """
            agente	puntos	tareas	ultima
            codex	1	1	2026-10-01
            """);
        File.WriteAllText(Path.Combine(conf, "test.conf"),
            $"set -g DUO_PROJECT test\nset -g REPO_DIR {repo}\nset -g BOARD {board}\n");
        Environment.SetEnvironmentVariable("DUO_CONF", conf);
        Environment.SetEnvironmentVariable("DUO_P", "test");
        return board;
    }
}

codex
La integración aún no está disponible y el rebase de mi rama fue bloqueado por el sandbox: el repositorio compartido guarda su metadato Git fuera del directorio con permiso de escritura. No voy a insertar una prueba que no compilaría contra `main`; confirmaré que el caso sigue sin cobertura en la rama Phase 2 y dejaré la propuesta exacta.
exec
/usr/bin/bash -lc "git ls-tree -r --name-only origin/feature/phase-2-live-tasks service/tests | sort && git log --oneline HEAD..origin/feature/phase-2-live-tasks -- service/tests app/test && git status --short --branch && git diff --exit-code; printf 'diff_exit=%s\\n' \""'$?"' in /home/david/dev/wt/codex-duo-desktop
 succeeded in 188ms:
service/tests/DuoCommandRunnerTests.cs
service/tests/DuoDesktop.Service.Tests.csproj
service/tests/GitHubReaderTests.cs
service/tests/HistoryReaderTests.cs
service/tests/LiveEventContractTests.cs
service/tests/QuestionReaderTests.cs
## codex/t-027-prueba-de-owner-nuevo-para-validacion-ph
diff_exit=0

codex
No está disponible aún: `origin/main` sigue sin Phase 2 ni `TaskOwnerHistoryReader`. La cobertura de owner histórico tampoco existe en `origin/feature/phase-2-live-tasks`.

Intenté rebasar solo esta rama sobre Phase 2 para añadir el test, pero el sandbox bloqueó la escritura del metadato Git compartido fuera del workspace:

`could not create temporary .../.git/worktrees/.../rebase-merge: Read-only file system`

No modifiqué archivos ni hice commits, para no dejar una prueba que no compile contra `main`. El test pendiente debe crear dos revisiones de `.team/BOARD.md` en un repo temporal, retirar `T-NNN` de la revisión actual y comprobar que `TaskOwnerHistoryReader` devuelve el owner de la revisión histórica.

La validación puntual de `LiveEventContractTests` también quedó bloqueada al iniciar VSTest, porque el sandbox niega sockets locales; la compilación sí llegó a completarse.

## PREGUNTA
1. ¿Puedes recrear T-027 desde `origin/feature/phase-2-live-tasks` (o integrar Phase 2 en `main`) para que añada el test ejecutable del owner histórico?
tokens used
50,318
No está disponible aún: `origin/main` sigue sin Phase 2 ni `TaskOwnerHistoryReader`. La cobertura de owner histórico tampoco existe en `origin/feature/phase-2-live-tasks`.

Intenté rebasar solo esta rama sobre Phase 2 para añadir el test, pero el sandbox bloqueó la escritura del metadato Git compartido fuera del workspace:

`could not create temporary .../.git/worktrees/.../rebase-merge: Read-only file system`

No modifiqué archivos ni hice commits, para no dejar una prueba que no compile contra `main`. El test pendiente debe crear dos revisiones de `.team/BOARD.md` en un repo temporal, retirar `T-NNN` de la revisión actual y comprobar que `TaskOwnerHistoryReader` devuelve el owner de la revisión histórica.

La validación puntual de `LiveEventContractTests` también quedó bloqueada al iniciar VSTest, porque el sandbox niega sockets locales; la compilación sí llegó a completarse.

## PREGUNTA
1. ¿Puedes recrear T-027 desde `origin/feature/phase-2-live-tasks` (o integrar Phase 2 en `main`) para que añada el test ejecutable del owner histórico?
