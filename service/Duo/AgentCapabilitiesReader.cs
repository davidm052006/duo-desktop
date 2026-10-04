namespace DuoDesktop.Service.Duo;

/// Metadatos locales de CLIs disponibles. No abre configuraciones de los
/// proveedores ni ejecuta los binarios: sólo verifica que el ejecutable pueda
/// resolverse en PATH.
public sealed class AgentCapabilitiesReader(IExecutableLocator executables)
{
    private static readonly string[] Providers = ["codex", "claude", "gemini"];

    public IReadOnlyList<AgentCapability> Read() => Providers
        .Select(provider =>
        {
            var executable = executables.Find(provider);
            return new AgentCapability(provider, executable is not null, executable);
        })
        .ToArray();
}

public sealed record AgentCapability(string Provider, bool Available, string? Executable);

public interface IExecutableLocator
{
    string? Find(string executable);
}

public sealed class PathExecutableLocator : IExecutableLocator
{
    public string? Find(string executable)
    {
        var path = Environment.GetEnvironmentVariable("PATH");
        if (string.IsNullOrWhiteSpace(path)) return null;

        foreach (var directory in path.Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries))
        {
            foreach (var candidate in Candidates(directory, executable))
            {
                if (IsExecutable(candidate)) return candidate;
            }
        }

        return null;
    }

    private static IEnumerable<string> Candidates(string directory, string executable)
    {
        yield return Path.Combine(directory, executable);
        if (OperatingSystem.IsWindows() && Path.GetExtension(executable).Length == 0)
        {
            yield return Path.Combine(directory, executable + ".exe");
            yield return Path.Combine(directory, executable + ".cmd");
            yield return Path.Combine(directory, executable + ".bat");
        }
    }

    private static bool IsExecutable(string candidate)
    {
        if (!File.Exists(candidate)) return false;
        if (OperatingSystem.IsWindows()) return true;

        try
        {
            const UnixFileMode execute = UnixFileMode.UserExecute |
                                         UnixFileMode.GroupExecute |
                                         UnixFileMode.OtherExecute;
            return (File.GetUnixFileMode(candidate) & execute) != 0;
        }
        catch (PlatformNotSupportedException)
        {
            return false;
        }
    }
}
