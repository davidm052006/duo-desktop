# Distribución Linux (.deb)

La distribución Linux de Duo Desktop empaqueta el bundle Release completo de Flutter y CEF en un paquete Debian/Ubuntu instalable.

## Requisitos de build

Se necesita Flutter con soporte Linux, CMake/Ninja y `dpkg-deb`, además de las dependencias nativas que ya requiere el build Linux de Duo/CEF.

## Generar el paquete

Desde `app/`:

```bash
flutter analyze
flutter build linux --release
bash scripts/build-deb.sh --skip-build
```

También se puede dejar que el script construya el Release:

```bash
bash scripts/build-deb.sh
```

El script lee `version: X.Y.Z+N` desde `app/pubspec.yaml`; no mantiene un versionado paralelo. El artefacto queda en:

```text
app/dist/duo-desktop_X.Y.Z_amd64.deb
```

## Inspeccionar

```bash
dpkg-deb -I dist/duo-desktop_X.Y.Z_amd64.deb
dpkg-deb -c dist/duo-desktop_X.Y.Z_amd64.deb
```

El paquete instala una semilla de Duo en `/usr/lib/duo-desktop`, un launcher en
`/usr/bin/duo-desktop`, el desktop entry en `/usr/share/applications` y el
icono en `/usr/share/icons/hicolor/scalable/apps`. Al abrirlo desde el buscador
de aplicaciones, el launcher crea la instalación por usuario en
`~/.local/share/DuoDesktop/install`, arranca juntos el servicio local y Flutter
y desde ahí puede aplicar actualizaciones sin requerir `sudo`.

## Instalar

```bash
sudo apt install ./dist/duo-desktop_X.Y.Z_amd64.deb
```

Después se puede iniciar desde el menú de aplicaciones o con:

```bash
duo-desktop
```

## Launcher portable con actualización automática

Para CachyOS y otras distribuciones no Debian, cada release también publica
`DuoDesktop-beta-linux-x64.zip`. Se extrae una sola vez en una carpeta que no
se vaya a borrar y se inicia siempre con `DuoLauncher`:

```bash
unzip DuoDesktop-beta-linux-x64.zip -d "$HOME/Applications/DuoDesktop"
"$HOME/Applications/DuoDesktop/DuoLauncher"
```

El launcher consulta `latest-linux.json` en GitHub Releases. Cada publicación
desde `main` o por tag publica ese manifiesto y el payload
`DuoDesktop-X.Y.Z-linux-x64-update.zip`. Si hay una versión nueva, la descarga,
comprueba su SHA-256, la activa de forma atómica y conserva la versión anterior
para volver atrás si la nueva no inicia. Los datos, perfiles CEF y registro del
launcher se conservan en `~/.local/share/DuoDesktop`, fuera de las versiones
instaladas.

No se debe ejecutar directamente `versions/*/app/duo_desktop`: así se omite el
servicio local y el mecanismo de actualización.

## Proyecto que verá la app

El instalador inicia el servicio con `DUO_P=duo-desktop`, para que no quede
ambiguo cuando existen varios proyectos de `duo`. Debe existir la configuración
`~/.config/duo/duo-desktop.conf` y su `BOARD` debe apuntar a una pizarra creada
por `duo init`. Si se distribuye Duo para otro proyecto, cambia `duoProject` en
`launcher-config.json` antes de empaquetar.

## Desinstalar

```bash
sudo apt remove duo-desktop
```

## CEF y sandbox

El packaging copia el runtime CEF producido por el build sin introducir flags de seguridad. El script aborta si encuentra switches inseguros conocidos o `cefs.no_sandbox = true`.

`chrome-sandbox` se empaqueta con modo `4755` y propiedad `root:root`, necesaria para el helper SUID cuando el sandbox de user namespaces no está disponible. Tras instalar se puede comprobar con:

```bash
stat -c '%a %U:%G %n' /usr/lib/duo-desktop/seed/versions/*/app/lib/chrome-sandbox
```

El resultado esperado empieza por:

```text
4755 root:root
```

Los perfiles y cachés de CEF no se mueven al directorio de instalación; siguen viviendo en Application Support del usuario.

## Dependencias de ejecución

El `DEBIAN/control` declara GTK 3, X11/Xi, OpenGL, NSS/NSPR, GBM/DRM, Pango/Cairo, audio, CUPS y `xclip`, con alternativas para paquetes renombrados con sufijo `t64` en distribuciones recientes.
