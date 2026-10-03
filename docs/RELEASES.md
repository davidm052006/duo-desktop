# Releases — Duo Desktop

## Cómo publicar una release

1. Asegúrate de que `main` está actualizado y estable.
2. Crea y empuja un tag semántico:

```bash
git switch main
git pull --ff-only
git tag v0.1.0
git push origin v0.1.0
```

El workflow `.github/workflows/release.yml` se dispara automáticamente con el patrón `v*.*.*`.

## Artefactos generados

| Plataforma | Artefacto (actual) | Artefacto (objetivo) |
|---|---|---|
| Linux | `DuoDesktop-X.Y.Z-linux-x64.zip` (fallback) | `duo-desktop_X.Y.Z_amd64.deb` |
| Windows | `DuoDesktop-X.Y.Z-windows-x64.zip` | `DuoDesktop-X.Y.Z-x64.msix` |
| Ambos | `checksums.txt` (SHA-256) | igual |

## Dependencias pendientes

### Linux `.deb`

La rama `build/linux-distribution` (o equivalente) debe aportar:

```text
app/scripts/build-deb.sh
```

Cuando ese script exista y sea ejecutable, el job Linux lo invocará automáticamente en lugar del zip del bundle Flutter.

### Windows MSIX / CEF

El build Windows actual usa el runner Flutter estándar. Si la rama `build/windows-cef` (o similar) introduce CEF o empaquetado MSIX:

- ajustar el paso de empaquetado del job `windows`;
- opcionalmente añadir `app/scripts/build-msix.ps1` o equivalente.

Hasta entonces el artefacto es un zip del directorio `Release`.

### CEF en CI

El plugin local `app/packages/webview_cef_duo` descarga CEF en tiempo de build. En runners de GitHub Actions puede requerir:

- tiempo y espacio suficientes (timeout 90 min);
- dependencias del sistema ya listadas en el job Linux;
- posible pre-cache o artefacto de CEF en el futuro.

Si el build Linux falla por CEF, documentar el error y no introducir `--no-sandbox` ni flags inseguros desde este workflow.

## Permisos y seguridad

- Solo se usa `GITHUB_TOKEN` (permiso `contents: write`).
- No hay secrets hardcodeados.
- Linux y Windows son jobs independientes; el job `release` solo corre si ambos terminan con éxito.
- No se publican artefactos incompletos como release estable.

## Validación estática realizada

- Sintaxis YAML del workflow.
- Trigger por tags `v*.*.*`.
- Paths relativos a `app/`.
- Permisos explícitos mínimos.
- Nombres de artefactos versionados.
- Ausencia de secrets hardcodeados.
- Concurrencia por ref.

## Qué falta comprobar tras merge

1. Ejecutar el workflow con un tag de prueba (p. ej. `v0.0.0-test`) en un entorno controlado.
2. Confirmar que Flutter + CEF compilan en `ubuntu-24.04` y `windows-latest`.
3. Sustituir el zip Linux por `.deb` cuando exista `build-deb.sh`.
4. Sustituir el zip Windows por MSIX cuando exista el empaquetado correspondiente.
5. Verificar que `checksums.txt` se adjunta y es correcto.

## Criterio de éxito

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

debe producir una GitHub Release con artefactos Linux + Windows + checksums cuando todos los pasos necesarios sean exitosos.
