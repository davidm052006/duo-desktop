#!/usr/bin/env fish
# Crea los dos proyectos la primera vez. Idempotente: si ya existen, no toca.

# Absoluta: si se resuelve relativa, los `cd` posteriores crean los proyectos
# en el sitio equivocado (flutter create acabó dentro de service/).
set -l raiz (realpath (dirname (dirname (status filename))))
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
if test -d $raiz/service
    ok "service/ ya existe"
else
    dotnet new web -o $raiz/service -n DuoDesktop.Service --no-https || exit 1
    ok "service/ creado"
end
for pkg in Octokit LibGit2Sharp
    if not grep -q "\"$pkg\"" $raiz/service/DuoDesktop.Service.csproj 2>/dev/null
        dotnet add $raiz/service package $pkg >/dev/null 2>&1; and ok "$pkg añadido"; or mal "no pude añadir $pkg"
    else
        ok "$pkg ya estaba"
    end
end

paso "App Flutter"
flutter config --enable-linux-desktop >/dev/null 2>&1
if test -f $raiz/app/pubspec.yaml
    ok "app/ ya existe"
else
    flutter create --platforms=linux --project-name duo_desktop $raiz/app || exit 1
    ok "app/ creada"
end
for p in http web_socket_channel provider
    if not grep -q "^  $p:" $raiz/app/pubspec.yaml 2>/dev/null
        fish -c "cd $raiz/app; and flutter pub add $p" >/dev/null 2>&1
        and ok "$p añadido"; or mal "no pude añadir $p"
    else
        ok "$p ya estaba"
    end
end

paso "Compilando para verificar"
if dotnet build $raiz/service -v q >/dev/null 2>&1
    ok "el servicio compila"
else
    mal "el servicio no compila:"
    dotnet build $raiz/service -v q 2>&1 | grep -iE 'error' | head -3 | sed 's/^/      /'
end
if fish -c "cd $raiz/app; and flutter build linux --debug" >/dev/null 2>&1
    ok "la app compila"
else
    mal "la app no compila (prueba: cd app; flutter build linux --debug)"
end

echo ""
set_color green --bold; echo "  Listo. Levanta todo con: scripts/dev.fish"; set_color normal
echo ""
