# Brief Codex — Validación Fase 2

## Rol

Codex es el validador de esta fase. No diseñar arquitectura ni reestructurar
código de producción.

Rama a validar:

```text
feature/phase-2-live-tasks
```

## Territorio permitido

Puedes crear o modificar pruebas en:

```text
service/tests/**
app/test/**
```

Puedes añadir scripts de validación claramente acotados si hacen falta.

No modificar contratos, modelos de producción, navegación, UI ni arquitectura.
Si una prueba demuestra un fallo de producción, reporta primero el archivo,
comando, error exacto y corrección mínima propuesta.

## Validación estática y tests

Desde la raíz:

```bash
git switch feature/phase-2-live-tasks

dotnet build service
dotnet test service/tests/DuoDesktop.Service.Tests.csproj

cd app
flutter pub get
flutter analyze
flutter test
flutter build linux --debug
```

## Casos que deben quedar cubiertos

### Backend

- `POST /tasks` rechaza token inválido.
- texto vacío devuelve `422 invalid_request`.
- `DuoCommandRunner` pasa la descripción como un solo argumento.
- código de salida no cero se convierte en `duo_command_failed`.
- `/events` exige WebSocket y Bearer válido.
- primer evento válido es `board_snapshot`.
- cambios posteriores producen `board_changed`.
- append de una sesión `T-NNN.txt` produce `agent_output`.

### Flutter

- parser acepta `board_snapshot`, `board_changed` y `agent_output`.
- evento de tablero sustituye el estado visible.
- `agent_output` se acumula sin superar el límite de 400 bloques.
- error de WebSocket conserva el tablero anterior.
- al perder WebSocket vuelve el sondeo.
- al reconectar se marca el canal como conectado.
- limpiar salida no modifica la pizarra.

## Prueba manual de extremo a extremo

```bash
scripts/dev.fish
```

Después:

1. abrir Inicio;
2. crear una tarea corta;
3. confirmar que aparece sin esperar al siguiente sondeo;
4. abrir “Salida en vivo”;
5. confirmar que llegan bloques asociados a `T-NNN`;
6. detener temporalmente el servicio;
7. comprobar que la UI conserva la última pizarra y muestra reconexión;
8. arrancar de nuevo y comprobar recuperación.

## Regresión CEF

No tocar el fork CEF. Solo verificar:

```bash
grep -RInE \
  'no-sandbox|disable-web-security|allow-running-insecure-content|ignore-certificate-errors|no_sandbox' \
  app/packages/webview_cef_duo/common \
  app/packages/webview_cef_duo/linux
```

Es válido `cefs.no_sandbox = false`. No debe aparecer un switch inseguro.
El documento de CEF exige mantener el sandbox activo y no reintroducir
`--no-sandbox`.

## Entrega de Codex

Entregar únicamente:

```text
Comandos ejecutados:
Resultados:
Tests añadidos/modificados:
Fallos encontrados:
Correcciones mínimas sugeridas:
Estado E2E:
Regresiones:
```

No hacer merge.
