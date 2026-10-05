using System.Text.RegularExpressions;

namespace DuoDesktop.Service.Duo;

/// Dónde vive la pizarra de un proyecto de `duo`.
///
/// Hallazgo que corrige al contrato v1: `.team/` NO está en la raíz del repo.
/// `duo init` la deja en una rama aparte (`team/board`) con su propio worktree,
/// y la ruta real se guarda en `~/.config/duo/<slug>.conf` como `BOARD`.
/// Buscar `.team/` junto al código daría 404 siempre.
public sealed record DuoProject(
    string Name,
    string RepoDir,
    string BaseBranch,
    string BoardDir,
    IReadOnlyList<string> Worktrees)
{
    public string BoardMd => Path.Combine(BoardDir, ".team", "BOARD.md");
    public string LedgerTsv => Path.Combine(BoardDir, ".team", "ledger.tsv");
    public string QuestionsDir => Path.Combine(BoardDir, ".team", "preguntas");
    public string SessionsDir => Path.Combine(BoardDir, ".team", "sesiones");

    /// Todos los directorios que pertenecen al proyecto: el repo, la pizarra y
    /// los worktrees de cada agente.
    public IEnumerable<string> AllDirs =>
        new[] { RepoDir, BoardDir }.Concat(Worktrees).Where(d => !string.IsNullOrEmpty(d));
}

public sealed class DuoProjectLocator(ILogger<DuoProjectLocator> log)
{
    // Desktop distributions target this project.  Versions released before
    // launcher-config.json gained duoProject did not set DUO_P, so keep those
    // installations usable after an in-place application update.
    private const string DesktopDefaultProject = "duo-desktop";

    // Las conf de duo son fish: `set -g CLAVE valor`, el valor a veces entre
    // comillas. No se ejecuta nada: se lee como texto.
    private static readonly Regex SetLine =
        new(@"^\s*set\s+-g\s+(?<key>[A-Z_]+)\s+(?<val>.+?)\s*$", RegexOptions.Compiled);

    private static string ConfDir =>
        Environment.GetEnvironmentVariable("DUO_CONF")
        ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            ".config", "duo");

    public IReadOnlyList<DuoProject> All()
    {
        if (!Directory.Exists(ConfDir)) return [];

        var found = new List<DuoProject>();
        foreach (var file in Directory.EnumerateFiles(ConfDir, "*.conf").OrderBy(f => f))
        {
            var project = TryParse(file);
            if (project is not null) found.Add(project);
            else log.LogWarning("conf de duo ilegible, la salto: {File}", file);
        }
        return found;
    }

    /// El proyecto activo. `DUO_P` manda, igual que en el CLI; si no está y hay
    /// un solo proyecto, ese. Con varios y sin `DUO_P` no se adivina.
    public DuoProject Active()
    {
        var all = All();
        if (all.Count == 0)
            throw BoardException.NotFound($"no hay ningún *.conf de duo en {ConfDir}");

        var wanted = Environment.GetEnvironmentVariable("DUO_P");
        if (!string.IsNullOrWhiteSpace(wanted))
        {
            var hit = all.FirstOrDefault(p =>
                string.Equals(p.Name, wanted, StringComparison.OrdinalIgnoreCase));
            // Some desktop launchers historically passed the repository or
            // board directory instead of the project's name. Accept that
            // unambiguous legacy value so installed Windows/Linux copies do
            // not fail with board_not_found.
            hit ??= all.FirstOrDefault(p => p.AllDirs.Any(d => SamePath(wanted, d)));
            return hit ?? throw BoardException.NotFound($"DUO_P={wanted} no corresponde a ningún proyecto");
        }

        if (all.Count == 1) return all[0];

        // Como el CLI: si el proceso corre dentro de un directorio del proyecto
        // (el repo, la pizarra o el worktree de un agente), ese es el activo.
        var cwd = Directory.GetCurrentDirectory();
        var byLocation = all.FirstOrDefault(p => p.AllDirs.Any(d => IsInside(cwd, d)));
        if (byLocation is not null) return byLocation;

        // Compatibility for already-installed Windows and Linux launchers.
        // Only choose the default when it is an exact configured project;
        // otherwise retain the CLI's deliberate ambiguity error.
        var desktopDefault = all.FirstOrDefault(p =>
            string.Equals(p.Name, DesktopDefaultProject, StringComparison.OrdinalIgnoreCase));
        if (desktopDefault is not null) return desktopDefault;

        throw BoardException.NotFound(
            $"hay {all.Count} proyectos de duo, DUO_P no está definido y {cwd} " +
            "no está dentro de ninguno: " + string.Join(", ", all.Select(p => p.Name)));
    }

    private static bool IsInside(string path, string root)
    {
        var p = Path.GetFullPath(path).TrimEnd(Path.DirectorySeparatorChar);
        var r = Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar);
        return p == r || p.StartsWith(r + Path.DirectorySeparatorChar, StringComparison.Ordinal);
    }

    private static bool SamePath(string left, string right)
    {
        try
        {
            return string.Equals(
                Path.GetFullPath(left).TrimEnd(Path.DirectorySeparatorChar),
                Path.GetFullPath(right).TrimEnd(Path.DirectorySeparatorChar),
                OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal);
        }
        catch (Exception) { return false; }
    }

    private static DuoProject? TryParse(string confPath)
    {
        var values = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var line in File.ReadLines(confPath))
        {
            var m = SetLine.Match(line);
            if (!m.Success) continue;
            values[m.Groups["key"].Value] = m.Groups["val"].Value.Trim().Trim('"', '\'');
        }

        if (!values.TryGetValue("DUO_PROJECT", out var name)) return null;
        if (!values.TryGetValue("BOARD", out var board)) return null;

        values.TryGetValue("REPO_DIR", out var repo);
        values.TryGetValue("BASE_BRANCH", out var baseBranch);

        var worktrees = values
            .Where(kv => kv.Key.StartsWith("WT_", StringComparison.Ordinal))
            .Select(kv => kv.Value)
            .ToList();

        return new DuoProject(name, repo ?? "", baseBranch ?? "main", board, worktrees);
    }
}
