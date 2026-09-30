#!/usr/bin/env fish
# Crea los dos proyectos la primera vez. Idempotente: si ya existen, no toca.

set -l raiz (dirname (dirname (status filename)))
cd $raiz

function paso; set_color cyan; echo ""; echo "── $argv"; set_color normal; end
function ok;   set_color green; echo "  ✓ $argv"; set_color normal; end
function mal;  set_color red; echo "  ✗ $argv"; set_color normal; end

paso "Comprobando herramientas"
set -l falta 0
for c in dotnet flutter cmake ninja
    if command -v $c >/dev/null
        ok "$c"
    else
        mal "$c no está instalado"
        set falta 1
    end
end
if test $falta -eq 1
    echo ""
    echo "  Instala lo que falte:  sudo pacman -S dotnet-sdk cmake ninja"
    exit 1
end

paso "Servicio C#"
if test -d service
    ok "service/ ya existe"
else
    dotnet new web -o service -n DuoDesktop.Service --no-https || exit 1
    cd service
    dotnet add package Octokit >/dev/null
    dotnet add package LibGit2Sharp >/dev/null
    cd $raiz
    ok "service/ creado con Octokit y LibGit2Sharp"
end

paso "App Flutter"
if test -d app
    ok "app/ ya existe"
else
    flutter config --enable-linux-desktop >/dev/null 2>&1
    flutter create --platforms=linux --project-name duo_desktop app || exit 1
    cd app
    for p in http web_socket_channel provider
        flutter pub add $p >/dev/null 2>&1
    end
    cd $raiz
    ok "app/ creada con http, web_socket_channel y provider"
end

paso "Compilando para verificar"
cd service; and dotnet build -v q >/dev/null; and ok "servicio compila"; or mal "el servicio no compila"
cd $raiz/app; and flutter build linux --debug >/dev/null 2>&1; and ok "app compila"; or mal "la app no compila (mira: flutter doctor)"
cd $raiz

echo ""
set_color green --bold; echo "  Listo. Levanta todo con: scripts/dev.fish"; set_color normal
echo ""
