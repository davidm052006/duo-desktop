#!/usr/bin/env fish
# Levanta el servicio y la app juntos. Ctrl+C mata los dos.

set -l raiz (realpath (dirname (dirname (status filename))))

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
        --dart-define=SUPABASE_URL=https://qagjowkmgsbxygydjxgo.supabase.co \
        --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_YFBqMrSs3OsBCSS7IAsVHA_Q3PEtfQk
else
    set_color yellow; echo "app/ no existe todavía; solo el servicio está arriba."; set_color normal
    echo "Pruébalo:  curl -H \"Authorization: Bearer $token\" http://127.0.0.1:$port/board"
    wait $svc
end

kill $svc 2>/dev/null
