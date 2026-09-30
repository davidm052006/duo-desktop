#!/usr/bin/env fish
# Levanta el servicio y la app juntos. Ctrl+C mata los dos.

set -l raiz (dirname (dirname (status filename)))

if not test -d $raiz/service
    set_color red; echo "Falta service/. Corre primero: scripts/bootstrap.fish"; set_color normal
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
        flutter run -d linux --dart-define=SERVICE_PORT=$port --dart-define=TOKEN=$token
else
    set_color yellow; echo "app/ no existe todavía; solo el servicio está arriba."; set_color normal
    echo "Pruébalo:  curl -H \"X-Duo-Token: $token\" http://127.0.0.1:$port/board"
    wait $svc
end

kill $svc 2>/dev/null
