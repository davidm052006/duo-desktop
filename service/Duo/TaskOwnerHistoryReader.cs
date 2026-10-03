using LibGit2Sharp;

namespace DuoDesktop.Service.Duo;

/// Resuelve el dueño de tareas que ya no están en BOARD.md usando el historial
/// Git del worktree team/board. Es una fuente de respaldo: el BOARD actual
/// siempre tiene prioridad y los fallos aquí no deben tumbar /events.
public sealed class TaskOwnerHistoryReader(ILogger<TaskOwnerHistoryReader> log)
{
    private const string BoardPath = ".team/BOARD.md";

    public IReadOnlyDictionary<string, string> Read(
        DuoProject project,
        IReadOnlyCollection<string> taskIds)
    {
        var unresolved = new HashSet<string>(taskIds, StringComparer.Ordinal);
        var owners = new Dictionary<string, string>(StringComparer.Ordinal);
        if (unresolved.Count == 0) return owners;

        try
        {
            var discovered = Repository.Discover(project.BoardDir);
            if (string.IsNullOrWhiteSpace(discovered)) return owners;

            using var repository = new Repository(discovered);
            foreach (var commit in repository.Commits)
            {
                var entry = commit[BoardPath];
                if (entry?.Target is not Blob blob) continue;

                using var content = new StreamReader(blob.GetContentStream());
                while (content.ReadLine() is { } line)
                {
                    if (!line.TrimStart().StartsWith("| T-", StringComparison.Ordinal)) continue;

                    var cells = line.Trim().Trim('|')
                        .Split('|')
                        .Select(cell => cell.Trim().Trim('`').Trim())
                        .ToList();

                    if (cells.Count < 6) continue;

                    var id = cells[0];
                    if (!unresolved.Contains(id)) continue;

                    // Las últimas cuatro columnas son owner, rama, estado y fecha.
                    // Si el título contiene '|', solo aumenta el bloque anterior.
                    var ownerIndex = cells.Count - 4;
                    if (ownerIndex < 2) continue;

                    var owner = cells[ownerIndex];
                    if (string.IsNullOrWhiteSpace(owner)) continue;

                    owners[id] = owner;
                    unresolved.Remove(id);
                    if (unresolved.Count == 0) return owners;
                }
            }
        }
        catch (Exception e) when (e is LibGit2SharpException or IOException or UnauthorizedAccessException)
        {
            log.LogWarning(e, "no pude resolver propietarios históricos de {Project}", project.Name);
        }

        return owners;
    }
}
