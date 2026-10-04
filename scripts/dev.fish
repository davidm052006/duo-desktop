#!/usr/bin/env fish
# Levanta servicio local, Duo Cloud y Flutter. Ctrl+C mata los procesos.

set -l raiz (realpath (dirname (dirname (status filename))))

# Carga opcional de .env local. Está ignorado por Git.
# Formato admitido: KEY=VALUE. Nunca se imprimen los valores.
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

        if not string match -qr '^[A-Za-z_][A-Za-z0-9_]*$' -- "$key"
            continue
        end

        set value (string replace -r '^"(.*)"$' '$1' -- "$value")
        set value (string replace -r "^'(.*)'\$" '$1' -- "$value")
        set -gx $key "$value"
    end < $env_file
end

if not test -d $raiz/service
    set_color red
    echo "Falta service/. Corre primero: scripts/bootstrap.fish"
    set_color normal
    exit 1
end

set -l rama (git -C $raiz branch --show-current 2>/dev/null)
set_color --bold
echo ""
echo "  ── corriendo desde: $rama"
set_color normal
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

if not set -q SUPABASE_URL; or test -z "$SUPABASE_URL"
    set_color red
    echo "Falta SUPABASE_URL en .env o en el entorno."
    set_color normal
    exit 1
end

if not set -q SUPABASE_PUBLISHABLE_KEY; or test -z "$SUPABASE_PUBLISHABLE_KEY"
    set_color red
    echo "Falta SUPABASE_PUBLISHABLE_KEY en .env o en el entorno."
    set_color normal
    exit 1
end

set -l port (python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
set -l cloud_port (python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
set -l token (uuidgen)

set_color cyan
echo "── servicio local en 127.0.0.1:$port"
set_color normal

DUO_TOKEN=$token dotnet run --project $raiz/service \
    --urls "http://127.0.0.1:$port" &
set -l svc $last_pid

set -l cloud ""
if test -d $raiz/cloud; and set -q ConnectionStrings__DuoCloud; and test -n "$ConnectionStrings__DuoCloud"
    set_color cyan
    echo "── Duo Cloud en 127.0.0.1:$cloud_port"
    set_color normal

    dotnet run --project $raiz/cloud \
        --urls "http://127.0.0.1:$cloud_port" &
    set cloud $last_pid
    set -gx DUO_CLOUD_URL "http://127.0.0.1:$cloud_port"
else if not set -q DUO_CLOUD_URL; or test -z "$DUO_CLOUD_URL"
    set_color yellow
    echo "⚠ Duo Cloud no se levantó: falta ConnectionStrings__DuoCloud."
    echo "  La pantalla Proyectos mostrará el aviso de configuración."
    set_color normal
end

function limpia --on-signal INT --on-signal TERM -V svc -V cloud
    kill $svc 2>/dev/null
    if test -n "$cloud"
        kill $cloud 2>/dev/null
    end
    set_color yellow
    echo ""
    echo "servicios detenidos"
    set_color normal
end

sleep 2

if test -d $raiz/app
    set_color cyan
    echo "── app Flutter"
    set_color normal

    cd $raiz/app
    DUO_SERVICE_URL="http://127.0.0.1:$port" DUO_TOKEN=$token \
        flutter run -d linux \
        --dart-define=SERVICE_PORT=$port \
        --dart-define=TOKEN=$token \
        --dart-define=SUPABASE_URL=$SUPABASE_URL \
        --dart-define=SUPABASE_PUBLISHABLE_KEY=$SUPABASE_PUBLISHABLE_KEY \
        --dart-define=DUO_CLOUD_URL="$DUO_CLOUD_URL"
else
    set_color yellow
    echo "app/ no existe todavía; solo los servicios están arriba."
    set_color normal
    wait $svc
end

kill $svc 2>/dev/null
if test -n "$cloud"
    kill $cloud 2>/dev/null
end
