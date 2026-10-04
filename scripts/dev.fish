#!/usr/bin/env fish
# Levanta el servicio y la app juntos. Ctrl+C mata los dos.

set -l raiz (realpath (dirname (dirname (status filename))))

# Carga opcional de .env local. El archivo está ignorado por Git.
# Se aceptan líneas KEY=VALUE; nunca se imprimen los valores.
set -l env_file "$raiz/.env"
if test -f $env_file
    while read -l line
        set line (string trim -- "$line")
        if test -z "$line"; or string match -qr '^#' -- "$line"
            continue
        end

        set -l pair (string split -m 1 '=' -- "$line")
        if test (count $pair) -ne 2
            continue
        end

        set -l key (string trim -- "$pair[1]")
        set -l value (string trim -- "$pair[2]")
        if not string match -qr '^[A-Za-z_][A-Za-z0-9_]*
    set_color red; echo "Falta service/. Corre primero: scripts/bootstrap.fish"; set_color normal
    exit 1
end

# QUÉ VERSIÓN ESTÁS VIENDO. Sin esto es facilísimo levantar la app desde la
# rama base, no ver el trabajo del agente, y creer que está mal hecho.
set -l rama (git -C $raiz branch --show-current 2>/dev/null)
set_color --bold; echo ""; echo "  ── corriendo desde: $rama"; set_color normal
echo "     $raiz"

set -l sin_integrar (git -C $raiz for-each-ref --format='%(refname:short)' 'refs/heads/chat/*' 'refs/heads/codex/*' 'refs/heads/cc/*' 2>/dev/null \
    | string match -rv '_base$' \
    | while read -l b
        test (git -C $raiz rev-list --count $rama..$b 2>/dev/null) -gt 0 2>/dev/null; and echo $b
    end)

if test (count $sin_integrar) -gt 0
    set_color yellow
    echo ""
    echo "  ⚠ hay "(count $sin_integrar)" rama(s) con trabajo que NO verás aquí:"
    for b in $sin_integrar
        echo "      $b"
    end
    echo "     Para ver una:   cd ~/dev/wt/<agente>-<proyecto>; and scripts/dev.fish"
    echo "     Para integrar:  duo merge T-NNN"
    set_color normal
end
echo ""

# Configuración pública de Supabase para Auth. No es una credencial de servidor,
# pero se mantiene fuera del repo para poder cambiar de proyecto sin recompilar.
if not set -q SUPABASE_URL; or test -z "$SUPABASE_URL"
    set_color red; echo "Falta SUPABASE_URL en el entorno."; set_color normal
    exit 1
end
if not set -q SUPABASE_PUBLISHABLE_KEY; or test -z "$SUPABASE_PUBLISHABLE_KEY"
    set_color red; echo "Falta SUPABASE_PUBLISHABLE_KEY en el entorno."; set_color normal
    exit 1
end

# Puertos efímeros: servicio local y Duo Cloud son procesos distintos.
set -l port (python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
set -l cloud_port (python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
set -l token (uuidgen)

set_color cyan; echo "── servicio local en 127.0.0.1:$port"; set_color normal

DUO_TOKEN=$token dotnet run --project $raiz/service \
    --urls "http://127.0.0.1:$port" &
set -l svc $last_pid

set -l cloud ""
if test -d $raiz/cloud; and set -q ConnectionStrings__DuoCloud
    set_color cyan; echo "── Duo Cloud en 127.0.0.1:$cloud_port"; set_color normal
    dotnet run --project $raiz/cloud \
        --urls "http://127.0.0.1:$cloud_port" &
    set cloud $last_pid
    set -gx DUO_CLOUD_URL "http://127.0.0.1:$cloud_port"
else if not set -q DUO_CLOUD_URL
    set_color yellow
    echo "⚠ Duo Cloud no se levantó: falta cloud/ o ConnectionStrings__DuoCloud."
    echo "  Proyectos mostrará el aviso de configuración."
    set_color normal
end

function limpia --on-signal INT --on-signal TERM -V svc -V cloud
    kill $svc 2>/dev/null
if test -n "$cloud"
    kill $cloud 2>/dev/null
end
    if test -n "$cloud"
        kill $cloud 2>/dev/null
    end
    set_color yellow; echo ""; echo "servicios detenidos"; set_color normal
end

sleep 2

if test -d $raiz/app
    set_color cyan; echo "── app Flutter"; set_color normal
    cd $raiz/app
    DUO_SERVICE_URL="http://127.0.0.1:$port" DUO_TOKEN=$token \
        flutter run -d linux \
        --dart-define=SERVICE_PORT=$port \
        --dart-define=TOKEN=$token \
        --dart-define=SUPABASE_URL=$SUPABASE_URL \
        --dart-define=SUPABASE_PUBLISHABLE_KEY=$SUPABASE_PUBLISHABLE_KEY \
        --dart-define=DUO_CLOUD_URL="$DUO_CLOUD_URL"
else
    set_color yellow; echo "app/ no existe todavía; solo el servicio está arriba."; set_color normal
    echo "Pruébalo:  curl -H \"Authorization: Bearer $token\" http://127.0.0.1:$port/board"
    wait $svc
end

kill $svc 2>/dev/null
 -- "$key"
            continue
        end

        set value (string replace -r '^"(.*)"
    set_color red; echo "Falta service/. Corre primero: scripts/bootstrap.fish"; set_color normal
    exit 1
end

# QUÉ VERSIÓN ESTÁS VIENDO. Sin esto es facilísimo levantar la app desde la
# rama base, no ver el trabajo del agente, y creer que está mal hecho.
set -l rama (git -C $raiz branch --show-current 2>/dev/null)
set_color --bold; echo ""; echo "  ── corriendo desde: $rama"; set_color normal
echo "     $raiz"

set -l sin_integrar (git -C $raiz for-each-ref --format='%(refname:short)' 'refs/heads/chat/*' 'refs/heads/codex/*' 'refs/heads/cc/*' 2>/dev/null \
    | string match -rv '_base$' \
    | while read -l b
        test (git -C $raiz rev-list --count $rama..$b 2>/dev/null) -gt 0 2>/dev/null; and echo $b
    end)

if test (count $sin_integrar) -gt 0
    set_color yellow
    echo ""
    echo "  ⚠ hay "(count $sin_integrar)" rama(s) con trabajo que NO verás aquí:"
    for b in $sin_integrar
        echo "      $b"
    end
    echo "     Para ver una:   cd ~/dev/wt/<agente>-<proyecto>; and scripts/dev.fish"
    echo "     Para integrar:  duo merge T-NNN"
    set_color normal
end
echo ""

# Configuración pública de Supabase para Auth. No es una credencial de servidor,
# pero se mantiene fuera del repo para poder cambiar de proyecto sin recompilar.
if not set -q SUPABASE_URL; or test -z "$SUPABASE_URL"
    set_color red; echo "Falta SUPABASE_URL en el entorno."; set_color normal
    exit 1
end
if not set -q SUPABASE_PUBLISHABLE_KEY; or test -z "$SUPABASE_PUBLISHABLE_KEY"
    set_color red; echo "Falta SUPABASE_PUBLISHABLE_KEY en el entorno."; set_color normal
    exit 1
end

# Puerto efímero y token compartido: el servicio solo acepta a quien lo sepa.
set -l port (python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
set -l token (uuidgen)

set_color cyan; echo "── servicio en 127.0.0.1:$port"; set_color normal

DUO_TOKEN=$token dotnet run --project $raiz/service \
    --urls "http://127.0.0.1:$port" &
set -l svc $last_pid

function limpia --on-signal INT --on-signal TERM -V svc
    kill $svc 2>/dev/null
    set_color yellow; echo ""; echo "servicio detenido"; set_color normal
end

sleep 2

if test -d $raiz/app
    set_color cyan; echo "── app Flutter"; set_color normal
    cd $raiz/app
    DUO_SERVICE_URL="http://127.0.0.1:$port" DUO_TOKEN=$token \
        flutter run -d linux \
        --dart-define=SERVICE_PORT=$port \
        --dart-define=TOKEN=$token \
        --dart-define=SUPABASE_URL=$SUPABASE_URL \
        --dart-define=SUPABASE_PUBLISHABLE_KEY=$SUPABASE_PUBLISHABLE_KEY \
        --dart-define=DUO_CLOUD_URL="$DUO_CLOUD_URL"
else
    set_color yellow; echo "app/ no existe todavía; solo el servicio está arriba."; set_color normal
    echo "Pruébalo:  curl -H \"Authorization: Bearer $token\" http://127.0.0.1:$port/board"
    wait $svc
end

kill $svc 2>/dev/null
 '$1' -- "$value")
        set value (string replace -r "^'(.*)'\$" '$1' -- "$value")
        set -gx $key "$value"
    end < $env_file
end

if not test -d $raiz/service
    set_color red; echo "Falta service/. Corre primero: scripts/bootstrap.fish"; set_color normal
    exit 1
end

# QUÉ VERSIÓN ESTÁS VIENDO. Sin esto es facilísimo levantar la app desde la
# rama base, no ver el trabajo del agente, y creer que está mal hecho.
set -l rama (git -C $raiz branch --show-current 2>/dev/null)
set_color --bold; echo ""; echo "  ── corriendo desde: $rama"; set_color normal
echo "     $raiz"

set -l sin_integrar (git -C $raiz for-each-ref --format='%(refname:short)' 'refs/heads/chat/*' 'refs/heads/codex/*' 'refs/heads/cc/*' 2>/dev/null \
    | string match -rv '_base$' \
    | while read -l b
        test (git -C $raiz rev-list --count $rama..$b 2>/dev/null) -gt 0 2>/dev/null; and echo $b
    end)

if test (count $sin_integrar) -gt 0
    set_color yellow
    echo ""
    echo "  ⚠ hay "(count $sin_integrar)" rama(s) con trabajo que NO verás aquí:"
    for b in $sin_integrar
        echo "      $b"
    end
    echo "     Para ver una:   cd ~/dev/wt/<agente>-<proyecto>; and scripts/dev.fish"
    echo "     Para integrar:  duo merge T-NNN"
    set_color normal
end
echo ""

# Configuración pública de Supabase para Auth. No es una credencial de servidor,
# pero se mantiene fuera del repo para poder cambiar de proyecto sin recompilar.
if not set -q SUPABASE_URL; or test -z "$SUPABASE_URL"
    set_color red; echo "Falta SUPABASE_URL en el entorno."; set_color normal
    exit 1
end
if not set -q SUPABASE_PUBLISHABLE_KEY; or test -z "$SUPABASE_PUBLISHABLE_KEY"
    set_color red; echo "Falta SUPABASE_PUBLISHABLE_KEY en el entorno."; set_color normal
    exit 1
end

# Puerto efímero y token compartido: el servicio solo acepta a quien lo sepa.
set -l port (python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
set -l token (uuidgen)

set_color cyan; echo "── servicio en 127.0.0.1:$port"; set_color normal

DUO_TOKEN=$token dotnet run --project $raiz/service \
    --urls "http://127.0.0.1:$port" &
set -l svc $last_pid

function limpia --on-signal INT --on-signal TERM -V svc
    kill $svc 2>/dev/null
    set_color yellow; echo ""; echo "servicio detenido"; set_color normal
end

sleep 2

if test -d $raiz/app
    set_color cyan; echo "── app Flutter"; set_color normal
    cd $raiz/app
    DUO_SERVICE_URL="http://127.0.0.1:$port" DUO_TOKEN=$token \
        flutter run -d linux \
        --dart-define=SERVICE_PORT=$port \
        --dart-define=TOKEN=$token \
        --dart-define=SUPABASE_URL=$SUPABASE_URL \
        --dart-define=SUPABASE_PUBLISHABLE_KEY=$SUPABASE_PUBLISHABLE_KEY \
        --dart-define=DUO_CLOUD_URL="$DUO_CLOUD_URL"
else
    set_color yellow; echo "app/ no existe todavía; solo el servicio está arriba."; set_color normal
    echo "Pruébalo:  curl -H \"Authorization: Bearer $token\" http://127.0.0.1:$port/board"
    wait $svc
end

kill $svc 2>/dev/null
