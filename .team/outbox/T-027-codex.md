# T-027 — entregable de `codex`

**Rama:** `codex/t-027-prueba-de-owner-nuevo-para-validacion-ph`  
**Cerrado:** 2026-10-03 14:42

## Cambios contra la base

```
(sin cambios)
```

## Lo que reportó el agente

service/Duo/BoardModels.cs:75:public sealed record BoardEvent(string Type, BoardResponse Board);
service/Duo/LiveEventStream.cs:11:public sealed class LiveEventStream(DuoProjectLocator locator, BoardReader boardReader, ILogger<LiveEventStream> log)
service/Duo/LiveEventStream.cs:34:                    await SendEventAsync(socket, new BoardEvent(
service/Duo/LiveEventStream.cs:115:            await SendEventAsync(socket, new AgentOutputEvent("agent_output", id, agent, Encoding.UTF8.GetString(bytes)), cancellationToken);

codex
He localizado el objetivo probable: el cambio de Phase 2 que preserva el alias de una sesión histórica (`T-NNN.txt`) cuando la tarea ya no está en `BOARD.md`. La rama asignada, sin embargo, parte de `origin/main`, donde ese lector histórico aún no existe; una prueba de ese comportamiento no compilaría allí. Voy a confirmar el desfase y dejar la decisión de base explícita, sin introducir una prueba rota.
exec
/usr/bin/bash -lc 'dotnet test service/tests/DuoDesktop.Service.Tests.csproj --filter FullyQualifiedName~LiveEventContractTests --no-restore' in /home/david/dev/wt/codex-duo-desktop
 exited 1 in 14469ms:
/home/david/dev/wt/codex-duo-desktop/service/DuoDesktop.Service.csproj : warning NU1900: Error occurred while getting package vulnerability data: Unable to load the service index for source https://api.nuget.org/v3/index.json.
  DuoDesktop.Service -> /home/david/dev/wt/codex-duo-desktop/service/bin/Debug/net10.0/DuoDesktop.Service.dll
/home/david/dev/wt/codex-duo-desktop/service/tests/DuoCommandRunnerTests.cs(77,9): warning CA1416: This call site is reachable on all platforms. 'File.SetUnixFileMode(string, UnixFileMode)' is unsupported on: 'windows'. (https://learn.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca1416) [/home/david/dev/wt/codex-duo-desktop/service/tests/DuoDesktop.Service.Tests.csproj]
  DuoDesktop.Service.Tests -> /home/david/dev/wt/codex-duo-desktop/service/tests/bin/Debug/net10.0/DuoDesktop.Service.Tests.dll
Test run for /home/david/dev/wt/codex-duo-desktop/service/tests/bin/Debug/net10.0/DuoDesktop.Service.Tests.dll (.NETCoreApp,Version=v10.0)
VSTest version 18.0.2-dev (x64)

Starting test execution, please wait...
A total of 1 test files matched the specified pattern.
System.Net.Sockets.SocketException (13): Permission denied
   at System.Net.Sockets.Socket..ctor(AddressFamily addressFamily, SocketType socketType, ProtocolType protocolType)
   at System.Net.Sockets.TcpListener..ctor(IPEndPoint localEP)
   at Microsoft.VisualStudio.TestPlatform.CommunicationUtilities.SocketServer.Start(String endPoint) in /_/src/vstest/src/Microsoft.TestPlatform.CommunicationUtilities/SocketServer.cs:line 63
   at Microsoft.VisualStudio.TestPlatform.CommunicationUtilities.TestRequestSender.InitializeCommunication() in /_/src/vstest/src/Microsoft.TestPlatform.CommunicationUtilities/TestRequestSender.cs:line 168
   at Microsoft.VisualStudio.TestPlatform.CrossPlatEngine.Client.ProxyOperationManager.SetupChannel(IEnumerable`1 sources, String runSettings) in /_/src/vstest/src/Microsoft.TestPlatform.CrossPlatEngine/Client/ProxyOperationManager.cs:line 207
   at Microsoft.VisualStudio.TestPlatform.CrossPlatEngine.Client.ProxyExecutionManager.InitializeTestRun(TestRunCriteria testRunCriteria, IInternalTestRunEventsHandler eventHandler) in /_/src/vstest/src/Microsoft.TestPlatform.CrossPlatEngine/Client/ProxyExecutionManager.cs:line 184

Test Run Aborted.

codex
Alcance mínimo: pruebas de `service/tests/**` para la conservación del owner en eventos Phase 2.

No hice cambios ni commits: la rama asignada parte de `origin/main`, que no contiene `TaskOwnerHistoryReader` ni la lógica Phase 2 que se debe validar. Añadir la prueba aquí dejaría el proyecto sin compilar.

Comando ejecutado: `dotnet test ...LiveEventContractTests --no-restore`.

Resultado: compiló, pero el runner abortó porque el sandbox impide abrir el socket local de VSTest (`SocketException: Permission denied`). Además, no existe `backend/` en este workspace, por lo que no es posible usar el comando pytest indicado.

Pendiente: añadir la prueba del caso histórico (sesión `T-NNN.txt` cuya tarea ya no figura en BOARD, conservando su alias) sobre la base que sí contiene Phase 2.

David debe verificar la base correcta para T-027.

## PREGUNTA
1. ¿Autorizas rebasear esta rama sobre `origin/feature/phase-2-live-tasks` para añadir y validar la prueba del owner histórico, o T-027 debe quedarse sobre `origin/main` con otro caso de owner?
tokens used
36,257
Alcance mínimo: pruebas de `service/tests/**` para la conservación del owner en eventos Phase 2.

No hice cambios ni commits: la rama asignada parte de `origin/main`, que no contiene `TaskOwnerHistoryReader` ni la lógica Phase 2 que se debe validar. Añadir la prueba aquí dejaría el proyecto sin compilar.

Comando ejecutado: `dotnet test ...LiveEventContractTests --no-restore`.

Resultado: compiló, pero el runner abortó porque el sandbox impide abrir el socket local de VSTest (`SocketException: Permission denied`). Además, no existe `backend/` en este workspace, por lo que no es posible usar el comando pytest indicado.

Pendiente: añadir la prueba del caso histórico (sesión `T-NNN.txt` cuya tarea ya no figura en BOARD, conservando su alias) sobre la base que sí contiene Phase 2.

David debe verificar la base correcta para T-027.

## PREGUNTA
1. ¿Autorizas rebasear esta rama sobre `origin/feature/phase-2-live-tasks` para añadir y validar la prueba del owner histórico, o T-027 debe quedarse sobre `origin/main` con otro caso de owner?
