using System.Text.Json;

namespace DuoLauncher;

public sealed class ReleaseStore
{
    private static readonly JsonSerializerOptions Json = new() { PropertyNameCaseInsensitive = true, WriteIndented = true };
    public ReleaseStore(string installRoot) => InstallRoot = installRoot;
    public string InstallRoot { get; }
    public string VersionsRoot => Path.Combine(InstallRoot, "versions");
    public string CurrentPath => Path.Combine(InstallRoot, "current.json");

    public LauncherConfig ReadConfig()
    {
        var path = Path.Combine(InstallRoot, "launcher-config.json");
        return JsonSerializer.Deserialize<LauncherConfig>(File.ReadAllText(path), Json) ?? throw new InvalidDataException("launcher-config.json is empty.");
    }

    public CurrentRelease ReadCurrent() => JsonSerializer.Deserialize<CurrentRelease>(File.ReadAllText(CurrentPath), Json) ?? throw new InvalidDataException("current.json is empty.");

    public void WriteCurrentAtomically(CurrentRelease current)
    {
        Directory.CreateDirectory(InstallRoot);
        var temp = CurrentPath + ".tmp";
        using (var stream = new FileStream(temp, FileMode.Create, FileAccess.Write, FileShare.None, 4096, FileOptions.WriteThrough))
        using (var writer = new Utf8JsonWriter(stream, new JsonWriterOptions { Indented = true }))
        {
            JsonSerializer.Serialize(writer, current, Json);
            writer.Flush(); stream.Flush(flushToDisk: true);
        }
        if (File.Exists(CurrentPath)) File.Move(temp, CurrentPath, overwrite: true);
        else File.Move(temp, CurrentPath);
    }

    public string VersionDirectory(string version) => Path.Combine(VersionsRoot, version);
    public static void ValidatePayload(string directory)
    {
        var required = new[] { Path.Combine("app", "duo_desktop.exe"), Path.Combine("app", "flutter_windows.dll"), Path.Combine("service", "DuoDesktop.Service.exe") };
        var missing = required.Where(p => !File.Exists(Path.Combine(directory, p))).ToArray();
        if (missing.Length > 0) throw new InvalidDataException("Payload incomplete: " + string.Join(", ", missing));
        // A CEF-enabled build must include its runtime directory; builds without it are valid too.
        var cef = Path.Combine(directory, "app", "cef");
        if (Directory.Exists(cef) && !Directory.EnumerateFileSystemEntries(cef).Any()) throw new InvalidDataException("CEF runtime directory is empty.");
    }

    public void ActivateStagedVersion(string version, string stagingDirectory)
    {
        ValidatePayload(stagingDirectory);
        Directory.CreateDirectory(VersionsRoot);
        var pending = Path.Combine(VersionsRoot, "." + version + ".installing");
        if (Directory.Exists(pending)) Directory.Delete(pending, true);
        CopyDirectory(stagingDirectory, pending);
        ValidatePayload(pending);
        var destination = VersionDirectory(version);
        if (Directory.Exists(destination)) Directory.Delete(pending, true);
        else Directory.Move(pending, destination); // atomic rename within versions volume
    }

    public void KeepCurrentAndPrevious()
    {
        var current = ReadCurrent();
        var keep = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { current.Version };
        if (!string.IsNullOrWhiteSpace(current.PreviousVersion)) keep.Add(current.PreviousVersion);
        if (!Directory.Exists(VersionsRoot)) return;
        foreach (var d in Directory.EnumerateDirectories(VersionsRoot))
            if (!keep.Contains(Path.GetFileName(d))) Directory.Delete(d, true);
    }

    private static void CopyDirectory(string source, string destination)
    {
        Directory.CreateDirectory(destination);
        foreach (var file in Directory.EnumerateFiles(source, "*", SearchOption.AllDirectories))
        {
            var relative = Path.GetRelativePath(source, file); var target = Path.Combine(destination, relative);
            Directory.CreateDirectory(Path.GetDirectoryName(target)!); File.Copy(file, target, true);
        }
    }
}
