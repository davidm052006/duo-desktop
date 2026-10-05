# Distribución de Duo Desktop para Windows

El ZIP fuente no es una distribución ejecutable: contiene `app/lib`, `service/*.cs` y proyectos, pero no los binarios que necesita una persona usuaria. En particular, no puede sustituir a `DuoLauncher.exe`, `versions/<versión>/app/duo_desktop.exe` y `versions/<versión>/service/DuoDesktop.Service.exe`.

El artefacto manual de `main`, `DuoDesktop-beta-windows-x64.zip`, contiene una instalación inicial completa. La persona tester lo extrae una vez y ejecuta siempre `DuoLauncher.exe`.

Cada tag `vX.Y.Z` publica un ZIP de actualización con solamente el payload compilado, su archivo `.sha256` y `latest.json`. El launcher descarga el manifiesto desde GitHub Releases, verifica su canal y SemVer, descarga por HTTPS, valida SHA-256, extrae en `%LOCALAPPDATA%\DuoDesktop\updates\staging` y sólo entonces activa `versions/X.Y.Z` y cambia `current.json` atómicamente.

Las preferencias, perfiles CEF, logs y descargas se mantienen en `%LOCALAPPDATA%\DuoDesktop`, fuera de las versiones. Las actualizaciones no los eliminan.

El launcher también propaga `duoProject` desde `launcher-config.json` como
`DUO_P`; la distribución actual selecciona `duo-desktop`. Esto evita
`board_not_found` cuando hay varias configuraciones de Duo. La configuración
del proyecto debe existir y su `BOARD` debe contener `.team/BOARD.md` y
`.team/ledger.tsv`.
