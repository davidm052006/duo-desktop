using System.Diagnostics;
using System.IO.Compression;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Sockets;
using System.Runtime.Versioning;
using System.Security.Cryptography;
using System.Text.Json;

namespace DuoLauncher.Linux;

[SupportedOSPlatform("linux")]
internal static class Program
{
    private const string LauncherVersion = "1.0.0";
    private static readonly JsonSerializerOptions Json = new() { PropertyNameCaseInsensitive = true, WriteIndented = true };

    public static async Task<int> Main()
    {
        var root = AppContext.BaseDirectory;
        var dataRoot = Path.Combine(Environment.GetEnvironmentVariable("XDG_DATA_HOME") ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".local", "share"), "DuoDesktop");
        Directory.CreateDirectory(Path.Combine(dataRoot, "logs"));
        Directory.CreateDirectory(Path.Combine(dataRoot, "updates", "downloads"));
        Directory.CreateDirectory(Path.Combine(dataRoot, "updates", "staging"));

        try
        {
            var config = Read<LauncherConfig>(Path.Combine(root, "launcher-config.json"));
            var current = Read<CurrentRelease>(Path.Combine(root, "current.json"));
            RequireVersion(current.Version);

            if (config.CheckForUpdates)
            {
                try
                {
                    var update = await GetLatestAsync(config);
                    if (update is not null && IsNewerCompatible(update, current, config.Channel))
                        current = await InstallAsync(root, dataRoot, current, update);
                }
                catch (Exception ex)
                {
                    Log(dataRoot, $"Update check skipped: {ex.Message}");
                }
            }

            await RunWithRollbackAsync(root, dataRoot, current, config.DuoProject);
            KeepCurrentAndPrevious(root);
            return 0;
        }
        catch (Exception ex)
        {
            Log(dataRoot, ex.ToString());
            Console.Error.WriteLine($"Duo Desktop no pudo iniciarse: {ex.Message}");
            return 1;
        }
    }

    private static async Task<CurrentRelease> InstallAsync(string root, string dataRoot, CurrentRelease current, UpdateManifest update)
    {
        Console.WriteLine($"Actualizando Duo Desktop a {update.Version}…");
        var archive = Path.Combine(dataRoot, "updates", "downloads", $"{update.Version}.zip.part");
        await DownloadAsync(update.Url, archive);
        await VerifySha256Async(archive, update.Sha256);
        var staging = ExtractToStaging(dataRoot, archive, update.Version);
        ActivateStagedVersion(root, update.Version, staging);
        var activated = new CurrentRelease { Version = update.Version, PreviousVersion = current.Version };
        WriteAtomically(Path.Combine(root, "current.json"), activated);
        return activated;
    }

    private static async Task RunWithRollbackAsync(string root, string dataRoot, CurrentRelease current, string? duoProject)
    {
        try
        {
            await RunVersionAsync(VersionDirectory(root, current.Version), dataRoot, duoProject, checkEarlyExit: true);
        }
        catch when (!string.IsNullOrWhiteSpace(current.PreviousVersion))
        {
            var previous = new CurrentRelease { Version = current.PreviousVersion! };
            WriteAtomically(Path.Combine(root, "current.json"), previous);
            Console.Error.WriteLine($"La versión {current.Version} no inició; se restauró {previous.Version}.");
            await RunVersionAsync(VersionDirectory(root, previous.Version), dataRoot, duoProject, checkEarlyExit: false);
        }
    }

    private static async Task RunVersionAsync(string versionDirectory, string dataRoot, string? duoProject, bool checkEarlyExit)
    {
        ValidatePayload(versionDirectory);
        var port = GetLoopbackPort();
        var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
        using var service = Start(Path.Combine(versionDirectory, "service", "DuoDesktop.Service"), $"--urls http://127.0.0.1:{port}", port, token, dataRoot, duoProject);
        try
        {
            await WaitForHealthAsync(port, service);
            using var app = Start(Path.Combine(versionDirectory, "app", "duo_desktop"), "", port, token, dataRoot, duoProject);
            if (checkEarlyExit)
            {
                await Task.Delay(TimeSpan.FromSeconds(3));
                if (app.HasExited) throw new InvalidOperationException("La aplicación terminó inmediatamente.");
            }
            await app.WaitForExitAsync();
        }
        finally
        {
            if (!service.HasExited) service.Kill(entireProcessTree: true);
        }
    }

    private static Process Start(string executable, string arguments, int port, string token, string dataRoot, string? duoProject)
    {
        var info = new ProcessStartInfo(executable, arguments) { UseShellExecute = false, WorkingDirectory = Path.GetDirectoryName(executable)! };
        info.Environment["DUO_SERVICE_PORT"] = port.ToString();
        info.Environment["DUO_TOKEN"] = token;
        info.Environment["DUO_DATA_DIR"] = dataRoot;
        if (!string.IsNullOrWhiteSpace(duoProject)) info.Environment["DUO_P"] = duoProject;
        return Process.Start(info) ?? throw new InvalidOperationException($"No se pudo iniciar {Path.GetFileName(executable)}.");
    }

    private static async Task WaitForHealthAsync(int port, Process service)
    {
        using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(2) };
        var until = DateTime.UtcNow.AddSeconds(15);
        while (DateTime.UtcNow < until)
        {
            if (service.HasExited) throw new InvalidOperationException("El servicio de Duo terminó antes de estar listo.");
            try { if ((await client.GetAsync($"http://127.0.0.1:{port}/health")).IsSuccessStatusCode) return; }
            catch (HttpRequestException) { }
            await Task.Delay(250);
        }
        throw new TimeoutException("El servicio de Duo no respondió en 15 segundos.");
    }

    private static int GetLoopbackPort()
    {
        using var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        return ((IPEndPoint)listener.LocalEndpoint).Port;
    }

    private static async Task<UpdateManifest?> GetLatestAsync(LauncherConfig config)
    {
        using var client = new HttpClient();
        client.DefaultRequestHeaders.UserAgent.Add(new ProductInfoHeaderValue("DuoLauncher", LauncherVersion));
        client.DefaultRequestHeaders.Accept.ParseAdd("application/vnd.github+json");
        using var release = JsonDocument.Parse(await client.GetStringAsync($"https://api.github.com/repos/{config.ReleasesOwner}/{config.ReleasesRepository}/releases/latest"));
        var asset = release.RootElement.GetProperty("assets").EnumerateArray().FirstOrDefault(a => a.GetProperty("name").GetString() == "latest-linux.json");
        if (asset.ValueKind == JsonValueKind.Undefined) return null;
        var url = asset.GetProperty("browser_download_url").GetString() ?? throw new InvalidDataException("latest-linux.json has no download URL.");
        var manifest = JsonSerializer.Deserialize<UpdateManifest>(await client.GetStringAsync(url), Json) ?? throw new InvalidDataException("latest-linux.json is empty.");
        ValidateManifest(manifest);
        return manifest;
    }

    private static async Task DownloadAsync(string url, string output)
    {
        using var client = new HttpClient();
        using var response = await client.GetAsync(url, HttpCompletionOption.ResponseHeadersRead);
        response.EnsureSuccessStatusCode();
        await using var input = await response.Content.ReadAsStreamAsync();
        await using var file = new FileStream(output, FileMode.Create, FileAccess.Write, FileShare.None, 81920, useAsync: true);
        await input.CopyToAsync(file);
    }

    private static async Task VerifySha256Async(string file, string expected)
    {
        if (expected.Length != 64 || !expected.All(Uri.IsHexDigit)) throw new InvalidDataException("El manifiesto contiene un SHA-256 inválido.");
        await using var input = File.OpenRead(file);
        var actual = await SHA256.HashDataAsync(input);
        if (!CryptographicOperations.FixedTimeEquals(actual, Convert.FromHexString(expected))) throw new InvalidDataException("Actualización dañada o incompleta.");
    }

    private static string ExtractToStaging(string dataRoot, string archivePath, string version)
    {
        var root = Path.Combine(dataRoot, "updates", "staging", version);
        if (Directory.Exists(root)) Directory.Delete(root, true);
        Directory.CreateDirectory(root);
        try
        {
            using var archive = ZipFile.OpenRead(archivePath);
            foreach (var entry in archive.Entries)
            {
                var target = Path.GetFullPath(Path.Combine(root, entry.FullName));
                if (!target.StartsWith(Path.GetFullPath(root) + Path.DirectorySeparatorChar, StringComparison.Ordinal)) throw new InvalidDataException("Ruta no segura en la actualización.");
                if (string.IsNullOrEmpty(entry.Name)) { Directory.CreateDirectory(target); continue; }
                Directory.CreateDirectory(Path.GetDirectoryName(target)!);
                entry.ExtractToFile(target, true);
            }
            SetExecutable(Path.Combine(root, "app", "duo_desktop"));
            SetExecutable(Path.Combine(root, "service", "DuoDesktop.Service"));
            ValidatePayload(root);
            return root;
        }
        catch { if (Directory.Exists(root)) Directory.Delete(root, true); throw; }
    }

    private static void ActivateStagedVersion(string root, string version, string staging)
    {
        ValidatePayload(staging);
        var versions = Path.Combine(root, "versions");
        Directory.CreateDirectory(versions);
        var pending = Path.Combine(versions, "." + version + ".installing");
        if (Directory.Exists(pending)) Directory.Delete(pending, true);
        Directory.Move(staging, pending);
        var destination = VersionDirectory(root, version);
        if (Directory.Exists(destination)) Directory.Delete(pending, true);
        else Directory.Move(pending, destination);
    }

    private static void KeepCurrentAndPrevious(string root)
    {
        var current = Read<CurrentRelease>(Path.Combine(root, "current.json"));
        var keep = new HashSet<string>(StringComparer.Ordinal) { current.Version };
        if (!string.IsNullOrWhiteSpace(current.PreviousVersion)) keep.Add(current.PreviousVersion);
        var versions = Path.Combine(root, "versions");
        if (!Directory.Exists(versions)) return;
        foreach (var directory in Directory.EnumerateDirectories(versions))
            if (!keep.Contains(Path.GetFileName(directory))) Directory.Delete(directory, true);
    }

    private static void ValidatePayload(string directory)
    {
        foreach (var path in new[] { Path.Combine("app", "duo_desktop"), Path.Combine("app", "lib", "libflutter_linux_gtk.so"), Path.Combine("service", "DuoDesktop.Service") })
            if (!File.Exists(Path.Combine(directory, path))) throw new InvalidDataException($"Payload incompleto: {path}");
    }

    private static bool IsNewerCompatible(UpdateManifest update, CurrentRelease current, string channel) =>
        string.Equals(update.Channel, channel, StringComparison.OrdinalIgnoreCase) &&
        CompareVersions(update.Version, current.Version) > 0 && CompareVersions(update.MinimumLauncherVersion, LauncherVersion) <= 0;

    private static int CompareVersions(string left, string right)
    {
        RequireVersion(left); RequireVersion(right);
        return Version.Parse(left).CompareTo(Version.Parse(right));
    }

    private static void RequireVersion(string value)
    {
        if (!Version.TryParse(value, out var version) || version.Revision >= 0) throw new InvalidDataException($"Versión inválida: {value}");
    }

    private static void ValidateManifest(UpdateManifest manifest)
    {
        RequireVersion(manifest.Version); RequireVersion(manifest.MinimumLauncherVersion);
        if (!Uri.TryCreate(manifest.Url, UriKind.Absolute, out var uri) || uri.Scheme != Uri.UriSchemeHttps) throw new InvalidDataException("La URL de actualización debe usar HTTPS.");
        if (manifest.Sha256.Length != 64 || !manifest.Sha256.All(Uri.IsHexDigit)) throw new InvalidDataException("El manifiesto contiene un SHA-256 inválido.");
    }

    private static string VersionDirectory(string root, string version) => Path.Combine(root, "versions", version);
    private static T Read<T>(string path) => JsonSerializer.Deserialize<T>(File.ReadAllText(path), Json) ?? throw new InvalidDataException($"Archivo vacío: {path}");
    private static void WriteAtomically<T>(string path, T value)
    {
        var temp = path + ".tmp";
        File.WriteAllText(temp, JsonSerializer.Serialize(value, Json));
        File.Move(temp, path, true);
    }
    private static void SetExecutable(string path)
    {
        if (!File.Exists(path)) return;
        var mode = File.GetUnixFileMode(path);
        File.SetUnixFileMode(path, mode | UnixFileMode.UserExecute | UnixFileMode.GroupExecute | UnixFileMode.OtherExecute);
    }
    private static void Log(string dataRoot, string message) => File.AppendAllText(Path.Combine(dataRoot, "logs", "launcher.log"), $"{DateTimeOffset.Now:O} {message}{Environment.NewLine}");
}

internal sealed class LauncherConfig
{
    public string Channel { get; init; } = "beta";
    public bool CheckForUpdates { get; init; } = true;
    public string ReleasesOwner { get; init; } = "davidm052006";
    public string ReleasesRepository { get; init; } = "duo-desktop";
    public string? DuoProject { get; init; }
}

internal sealed class CurrentRelease
{
    public string Version { get; init; } = "";
    public string? PreviousVersion { get; init; }
}

internal sealed class UpdateManifest
{
    public string Version { get; init; } = "";
    public string Channel { get; init; } = "";
    public string Url { get; init; } = "";
    public string Sha256 { get; init; } = "";
    public string MinimumLauncherVersion { get; init; } = "1.0.0";
    public bool Mandatory { get; init; }
}
