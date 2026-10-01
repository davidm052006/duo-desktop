using System.Globalization;

namespace DuoDesktop.Service.Duo;

/// Lee la pizarra de `duo` y la traduce al contrato JSON. Solo lectura:
/// no ejecuta `duo`, no toca git, no escribe nada (contrato §13).
public sealed class BoardReader(DuoProjectLocator locator, ILogger<BoardReader> log)
{
    private const int Columns = 6;

    public BoardResponse Read()
    {
        var project = locator.Active();

        if (!File.Exists(project.BoardMd))
            throw BoardException.NotFound($"falta {project.BoardMd}");
        if (!File.Exists(project.LedgerTsv))
            throw BoardException.NotFound($"falta {project.LedgerTsv}");

        string[] boardLines, ledgerLines;
        try
        {
            boardLines = File.ReadAllLines(project.BoardMd);
            ledgerLines = File.ReadAllLines(project.LedgerTsv);
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        {
            log.LogError(e, "no pude leer la pizarra de {Project}", project.Name);
            throw BoardException.ReadFailed(e.Message);
        }

        // Atomicidad lógica (§12): se validan las dos mitades antes de responder.
        var tasks = ParseBoard(boardLines);
        var agents = ParseLedger(ledgerLines);

        return new BoardResponse(
            new ProjectDto(project.Name, project.RepoDir, project.BoardDir),
            new BoardDto(tasks),
            new LedgerDto(agents));
    }

    // ---------- BOARD.md ----------

    private static List<TaskDto> ParseBoard(IEnumerable<string> lines)
    {
        var tasks = new List<TaskDto>();

        foreach (var raw in lines)
        {
            var line = raw.Trim();
            // El parser no es un Markdown genérico (§14): solo filas de datos.
            if (!line.StartsWith("| T-", StringComparison.Ordinal)) continue;

            var cells = SplitRow(line);
            if (cells.Count < Columns)
                throw BoardException.Invalid($"fila con {cells.Count} columnas, esperaba {Columns}");

            // Un título con `|` dentro produciría columnas de sobra. En vez de
            // rechazar la fila, se devuelven al título, que es de donde salieron.
            if (cells.Count > Columns)
            {
                var extra = cells.Count - Columns;
                cells[1] = string.Join(" | ", cells.GetRange(1, extra + 1));
                cells.RemoveRange(2, extra);
            }

            var id = cells[0];
            var title = cells[1];
            var owner = cells[2];
            var branch = cells[3];
            var status = cells[4];
            var opened = cells[5];

            Require(id, "Tarea");
            Require(owner, "Dueño");
            Require(branch, "Rama");
            Require(status, "Estado");
            if (!IsIsoDate(opened))
                throw BoardException.Invalid($"'Abierta' no es una fecha ISO en {id}");

            tasks.Add(new TaskDto(id, title, owner, branch, status, opened));
        }

        // Un tablero válido sin tareas no es error (§9).
        return tasks;
    }

    /// Parte `| a | b | c |` en sus celdas, sin los backticks de adorno.
    private static List<string> SplitRow(string line)
    {
        var inner = line.Trim('|');
        return inner.Split('|')
            .Select(c => c.Trim().Trim('`').Trim())
            .ToList();
    }

    private static void Require(string value, string column)
    {
        if (string.IsNullOrWhiteSpace(value))
            throw BoardException.Invalid($"columna '{column}' vacía");
    }

    // ---------- ledger.tsv ----------

    private static readonly string[] LedgerHeader = ["agente", "puntos", "tareas", "ultima"];

    private static List<AgentDto> ParseLedger(string[] lines)
    {
        var rows = lines.Where(l => !string.IsNullOrWhiteSpace(l)).ToList();
        if (rows.Count == 0)
            throw BoardException.Invalid("ledger.tsv vacío");

        var header = rows[0].Split('\t').Select(h => h.Trim()).ToArray();
        if (!header.SequenceEqual(LedgerHeader))
            throw BoardException.Invalid("cabecera de ledger.tsv inesperada");

        var agents = new List<AgentDto>();
        foreach (var row in rows.Skip(1))
        {
            var cells = row.Split('\t').Select(c => c.Trim()).ToArray();
            if (cells.Length < LedgerHeader.Length)
                throw BoardException.Invalid($"fila de ledger con {cells.Length} columnas");

            if (string.IsNullOrWhiteSpace(cells[0]))
                throw BoardException.Invalid("columna 'agente' vacía");

            if (!int.TryParse(cells[1], NumberStyles.Integer, CultureInfo.InvariantCulture, out var points))
                throw BoardException.Invalid($"'puntos' no es entero para {cells[0]}");
            if (!int.TryParse(cells[2], NumberStyles.Integer, CultureInfo.InvariantCulture, out var tasks))
                throw BoardException.Invalid($"'tareas' no es entero para {cells[0]}");

            // `-` significa "nunca", y el contrato lo quiere como null, no como "-".
            string? last = cells[3] == "-" ? null : cells[3];
            if (last is not null && !IsIsoDate(last))
                throw BoardException.Invalid($"'ultima' no es '-' ni fecha ISO para {cells[0]}");

            agents.Add(new AgentDto(cells[0], points, tasks, last));
        }

        return agents;
    }

    private static bool IsIsoDate(string value) =>
        DateOnly.TryParseExact(value, "yyyy-MM-dd", CultureInfo.InvariantCulture,
            DateTimeStyles.None, out _);
}
