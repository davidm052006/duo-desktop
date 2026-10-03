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

El paquete instala el bundle en `/usr/lib/duo-desktop`, un launcher en `/usr/bin/duo-desktop`, el desktop entry en `/usr/share/applications` y el icono en `/usr/share/icons/hicolor/scalable/apps`.

## Instalar

```bash
sudo apt install ./dist/duo-desktop_X.Y.Z_amd64.deb
```

Después se puede iniciar desde el menú de aplicaciones o con:

```bash
duo-desktop
```

## Desinstalar

```bash
sudo apt remove duo-desktop
```

## CEF y sandbox

El packaging copia el runtime CEF producido por el build sin introducir flags de seguridad. El script aborta si encuentra switches inseguros conocidos o `cefs.no_sandbox = true`.

`chrome-sandbox` se empaqueta con modo `4755` y propiedad `root:root`, necesaria para el helper SUID cuando el sandbox de user namespaces no está disponible. Tras instalar se puede comprobar con:

```bash
stat -c '%a %U:%G %n' /usr/lib/duo-desktop/lib/chrome-sandbox
```

El resultado esperado empieza por:

```text
4755 root:root
```

Los perfiles y cachés de CEF no se mueven al directorio de instalación; siguen viviendo en Application Support del usuario.

## Dependencias de ejecución

El `DEBIAN/control` declara GTK 3, X11/Xi, OpenGL, NSS/NSPR, GBM/DRM, Pango/Cairo, audio, CUPS y `xclip`, con alternativas para paquetes renombrados con sufijo `t64` en distribuciones recientes.
