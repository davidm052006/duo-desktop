using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace DuoDesktop.Service.Duo;

/// Convierte los archivos que duo ya mantiene en una secuencia WebSocket. El
/// CLI continúa siendo el dueño de los procesos; aquí solo se siguen los
/// apéndices de sesión y el estado publicado de la pizarra.
public sealed class LiveEventStream(DuoProjectLocator locator, BoardReader boardReader, ILogger<LiveEventStream> log)
{
    private static readonly Regex SessionFile = new(@"^(?<id>T-\d+)\.txt$", RegexOptions.Compiled);
    private static readonly TimeSpan PollInterval = TimeSpan.FromMilliseconds(350);
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    public async Task SendAsync(WebSocket socket, CancellationToken cancellationToken)
    {
        var project = locator.Active();
        string? previousBoardJson = null;
        var positions = new Dictionary<string, long>(StringComparer.Ordinal);

        while (!cancellationToken.IsCancellationRequested && socket.State == WebSocketState.Open)
        {
            try
            {
                var board = boardReader.Read();
                // Los records contienen listas, cuya igualdad es por referencia.
                // La representación JSON estable sí compara el estado publicado,
                // no la instancia recién leída en cada sondeo.
                var boardJson = JsonSerializer.Serialize(board, Json);
                if (!string.Equals(previousBoardJson, boardJson, StringComparison.Ordinal))
                {
                    await SendEventAsync(socket, new BoardEvent(
                        previousBoardJson is null ? "board_snapshot" : "board_changed", board), cancellationToken);
                    previousBoardJson = boardJson;
                }

                await SendSessionAppendsAsync(socket, project, board, positions, cancellationToken);
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                break;
            }
            catch (WebSocketException)
            {
                break;
            }
            catch (BoardException) when (previousBoardJson is null)
            {
                // No hay una instantánea válida que conservar: comunicar el
                // fallo al handler para que cierre la conexión explícitamente.
                throw;
            }
            catch (Exception e)
            {
                // Una escritura de duo puede coincidir con el sondeo. Se
                // conserva la última instantánea válida y se reintenta.
                log.LogWarning(e, "no pude actualizar los eventos en vivo de {Project}", project.Name);
            }

            try
            {
                await Task.Delay(PollInterval, cancellationToken);
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                break;
            }
        }
    }

    private static async Task SendSessionAppendsAsync(
        WebSocket socket,
        DuoProject project,
        BoardResponse board,
        Dictionary<string, long> positions,
        CancellationToken cancellationToken)
    {
        if (!Directory.Exists(project.SessionsDir)) return;

        var agents = board.Board.Tasks.ToDictionary(task => task.Id, task => task.Owner, StringComparer.Ordinal);
        var liveFiles = new HashSet<string>(StringComparer.Ordinal);
        foreach (var path in Directory.EnumerateFiles(project.SessionsDir, "*.txt").OrderBy(path => path))
        {
            var match = SessionFile.Match(Path.GetFileName(path));
            if (!match.Success) continue;
            liveFiles.Add(path);

            var length = new FileInfo(path).Length;
            var position = positions.GetValueOrDefault(path);
            if (length < position) position = 0; // nueva sesión o truncado
            if (length == position) continue;

            byte[] bytes;
            await using (var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
            {
                stream.Seek(position, SeekOrigin.Begin);
                bytes = new byte[checked((int)(length - position))];
                var read = 0;
                while (read < bytes.Length)
                {
                    var count = await stream.ReadAsync(bytes.AsMemory(read), cancellationToken);
                    if (count == 0) break;
                    read += count;
                }
                if (read != bytes.Length) Array.Resize(ref bytes, read);
            }

            positions[path] = position + bytes.Length;
            if (bytes.Length == 0) continue;

            var id = match.Groups["id"].Value;
            agents.TryGetValue(id, out var agent);
            await SendEventAsync(socket, new AgentOutputEvent("agent_output", id, agent, Encoding.UTF8.GetString(bytes)), cancellationToken);
        }

        foreach (var oldPath in positions.Keys.Where(path => !liveFiles.Contains(path)).ToList())
            positions.Remove(oldPath);
    }

    private static Task SendEventAsync(WebSocket socket, object message, CancellationToken cancellationToken)
    {
        var payload = JsonSerializer.SerializeToUtf8Bytes(message, Json);
        return socket.SendAsync(payload, WebSocketMessageType.Text, true, cancellationToken);
    }
}
