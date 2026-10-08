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

    public static async Task<int> Main(string[] args)
    {
        if (args.Contains("--apply-update", StringComparer.OrdinalIgnoreCase)) await Task.Delay(750);
        // A self-contained single-file publish extracts managed assemblies to
        // ~/.net, so AppContext.BaseDirectory is not the user's installation.
        // Environment.ProcessPath remains the real DuoLauncher path.
        var installRoot = Path.GetDirectoryName(Environment.ProcessPath ?? AppContext.BaseDirectory) ?? AppContext.BaseDirectory;
        var dataRoot = Path.Combine(Environment.GetEnvironmentVariable("XDG_DATA_HOME") ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".local", "share"), "DuoDesktop");
        Directory.CreateDirectory(Path.Combine(dataRoot, "logs"));
        Directory.CreateDirectory(Path.Combine(dataRoot, "updates", "downloads"));
        Directory.CreateDirectory(Path.Combine(dataRoot, "updates", "staging"));
        LauncherLog.Write(dataRoot, $"Launcher iniciado. Install root: {installRoot}; data root: {dataRoot}.");

        await using var instance = await LauncherInstanceLock.TryAcquireAsync(Path.Combine(dataRoot, "updates", "launcher.lock"), TimeSpan.FromSeconds(5));
        if (instance is null)
        {
            const string message = "Duo Desktop ya está iniciándose o actualizándose. Espera unos segundos e inténtalo de nuevo.";
            LauncherLog.Write(dataRoot, message); Console.Error.WriteLine(message); return 0;
        }

        using var progress = DesktopProgress.Create(dataRoot);
        try
        {
            var store = new LinuxReleaseStore(installRoot, dataRoot);
            var config = store.ReadConfig();
            var current = store.ReadCurrent();
            Versioning.Require(current.Version);
            LauncherLog.Write(dataRoot, $"Versión actual: {current.Version}.");
            if (config.CheckForUpdates)
            {
                try
                {
                    using var http = new HttpClient { Timeout = Timeout.InfiniteTimeSpan };
                    var updater = new LinuxUpdater(http, store, dataRoot, LauncherVersion, progress);
                    updater.CleanupInterruptedDownloads();
                    progress.Report(new ProgressInfo(3, "Buscando actualizaciones…"));
                    LauncherLog.Write(dataRoot, "Buscando release de Linux en GitHub.");
                    var update = await updater.GetLatestAsync(config, CancellationToken.None);
                    if (update is null) LauncherLog.Write(dataRoot, "La release no contiene latest-linux.json.");
                    else if (Versioning.IsNewerCompatible(update, current, config.Channel, LauncherVersion))
                    {
                        progress.Report(new ProgressInfo(7, "Actualización disponible", $"Instalando versión {update.Version}."));
                        LauncherLog.Write(dataRoot, $"Release detectada: versión remota {update.Version}; actualización necesaria.");
                        current = await updater.InstallAsync(current, update, CancellationToken.None);
                        LauncherLog.Write(dataRoot, $"current.json actualizado a {current.Version}; anterior: {current.PreviousVersion}.");
                    }
                    else { LauncherLog.Write(dataRoot, $"Release detectada: versión remota {update.Version}; no se necesita actualización compatible."); progress.Report(new ProgressInfo(100, "Duo Desktop está actualizado.")); }
                }
                catch (Exception ex) { LauncherLog.Write(dataRoot, $"Update check skipped: {ex}"); progress.Report(new ProgressInfo(100, "Iniciando versión instalada…", "No se pudo buscar actualización.")); }
            }
            progress.Report(new ProgressInfo(100, "Iniciando Duo Desktop…"));
            progress.Close();
            await RunWithRollbackAsync(store, current, config.DuoProject);
            store.KeepCurrentAndPrevious();
            return 0;
        }
        catch (Exception ex) { LauncherLog.Write(dataRoot, ex.ToString()); Console.Error.WriteLine($"Duo Desktop no pudo iniciarse: {ex.Message}"); return 1; }
    }

    private static async Task RunWithRollbackAsync(LinuxReleaseStore store, CurrentRelease current, string? duoProject)
    {
        try
        {
            LauncherLog.Write(store.DataRoot, $"Iniciando versión {current.Version}.");
            await RunVersionAsync(store.VersionDirectory(current.Version), store.DataRoot, duoProject, true);
        }
        catch (Exception ex) when (!string.IsNullOrWhiteSpace(current.PreviousVersion))
        {
            LauncherLog.Write(store.DataRoot, $"La versión {current.Version} falló al iniciar: {ex}. Realizando rollback a {current.PreviousVersion}.");
            var previous = new CurrentRelease { Version = current.PreviousVersion! };
            store.WriteCurrentAtomically(previous);
            Console.Error.WriteLine($"La versión {current.Version} no inició; se restauró {previous.Version}.");
            await RunVersionAsync(store.VersionDirectory(previous.Version), store.DataRoot, duoProject, false);
        }
    }

    private static async Task RunVersionAsync(string versionDirectory, string dataRoot, string? duoProject, bool checkEarlyExit)
    {
        LinuxReleaseStore.ValidatePayload(versionDirectory);
        var port = GetLoopbackPort(); var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
        using var service = Start(Path.Combine(versionDirectory, "service", "DuoDesktop.Service"), $"--urls http://127.0.0.1:{port}", port, token, dataRoot, duoProject);
        try
        {
            await WaitForHealthAsync(port, service);
            using var app = Start(Path.Combine(versionDirectory, "app", "duo_desktop"), "", port, token, dataRoot, duoProject);
            if (checkEarlyExit) { await Task.Delay(TimeSpan.FromSeconds(3)); if (app.HasExited) throw new InvalidOperationException("La aplicación terminó inmediatamente."); }
            await app.WaitForExitAsync();
        }
        finally { if (!service.HasExited) service.Kill(entireProcessTree: true); }
    }

    private static Process Start(string executable, string arguments, int port, string token, string dataRoot, string? duoProject)
    {
        var info = new ProcessStartInfo(executable, arguments) { UseShellExecute = false, WorkingDirectory = Path.GetDirectoryName(executable)! };
        info.Environment["DUO_SERVICE_PORT"] = port.ToString(); info.Environment["DUO_TOKEN"] = token; info.Environment["DUO_DATA_DIR"] = dataRoot;
        info.Environment["DUO_LAUNCHER_PATH"] = Environment.ProcessPath ?? throw new InvalidOperationException("No se pudo determinar el lanzador.");
        info.Environment["DUO_VERSION"] = Directory.GetParent(Path.GetDirectoryName(executable)!)?.Name ?? "";
        if (!string.IsNullOrWhiteSpace(duoProject)) info.Environment["DUO_P"] = duoProject;
        return Process.Start(info) ?? throw new InvalidOperationException($"No se pudo iniciar {Path.GetFileName(executable)}.");
    }

    private static async Task WaitForHealthAsync(int port, Process service)
    {
        using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(2) }; var until = DateTime.UtcNow.AddSeconds(15);
        while (DateTime.UtcNow < until)
        {
            if (service.HasExited) throw new InvalidOperationException("El servicio de Duo terminó antes de estar listo.");
            try { if ((await client.GetAsync($"http://127.0.0.1:{port}/health")).IsSuccessStatusCode) return; } catch (HttpRequestException) { }
            await Task.Delay(250);
        }
        throw new TimeoutException("El servicio de Duo no respondió en 15 segundos.");
    }
    private static int GetLoopbackPort() { using var listener = new TcpListener(IPAddress.Loopback, 0); listener.Start(); return ((IPEndPoint)listener.LocalEndpoint).Port; }
}

[SupportedOSPlatform("linux")]
internal sealed class LinuxUpdater(HttpClient http, LinuxReleaseStore store, string dataRoot, string launcherVersion, IProgress<ProgressInfo>? progress = null)
{
    private static readonly JsonSerializerOptions Json = new() { PropertyNameCaseInsensitive = true, WriteIndented = true };
    private static readonly TimeSpan ManifestTimeout = TimeSpan.FromSeconds(7), DownloadHeaderTimeout = TimeSpan.FromSeconds(15), DownloadTimeout = TimeSpan.FromMinutes(15);
    public async Task<UpdateManifest?> GetLatestAsync(LauncherConfig config, CancellationToken ct)
    {
        using var releaseResponse = await SendWithRetriesAsync($"https://api.github.com/repos/{config.ReleasesOwner}/{config.ReleasesRepository}/releases/latest", ManifestTimeout, ct);
        using var release = JsonDocument.Parse(await releaseResponse.Content.ReadAsStreamAsync(ct));
        var asset = release.RootElement.GetProperty("assets").EnumerateArray().FirstOrDefault(a => a.GetProperty("name").GetString() == "latest-linux.json");
        if (asset.ValueKind == JsonValueKind.Undefined) return null;
        var url = asset.GetProperty("browser_download_url").GetString() ?? throw new InvalidDataException("latest-linux.json has no download URL.");
        using var manifestResponse = await SendWithRetriesAsync(url, ManifestTimeout, ct);
        var manifest = await JsonSerializer.DeserializeAsync<UpdateManifest>(await manifestResponse.Content.ReadAsStreamAsync(ct), Json, ct) ?? throw new InvalidDataException("latest-linux.json is empty.");
        Versioning.ValidateManifest(manifest); return manifest;
    }
    public async Task<CurrentRelease> InstallAsync(CurrentRelease current, UpdateManifest update, CancellationToken ct)
    {
        Console.WriteLine($"Actualizando Duo Desktop a {update.Version}…");
        progress?.Report(new ProgressInfo(8, "Preparando descarga…"));
        var archive = await DownloadVerifiedAsync(update, ct);
        progress?.Report(new ProgressInfo(72, "Verificando…", "Verificando SHA-256…"));
        // DownloadVerifiedAsync already verified the temporary archive before promotion.
        LauncherLog.Write(dataRoot, $"Extrayendo actualización {update.Version}."); progress?.Report(new ProgressInfo(82, "Extrayendo actualización…")); var staging = store.ExtractToStaging(archive, update.Version);
        store.UpdateLauncherFromStaging(staging);
        LauncherLog.Write(dataRoot, $"Activando versión {update.Version}."); progress?.Report(new ProgressInfo(92, "Instalando actualización…")); store.ActivateStagedVersion(update.Version, staging);
        var activated = new CurrentRelease { Version = update.Version, PreviousVersion = current.Version }; store.WriteCurrentAtomically(activated); return activated;
    }
    public async Task<string> DownloadVerifiedAsync(UpdateManifest update, CancellationToken ct)
    {
        var downloads = Path.Combine(dataRoot, "updates", "downloads"); Directory.CreateDirectory(downloads);
        var destination = Path.Combine(downloads, $"{update.Version}.zip");
        if (File.Exists(destination))
        {
            try { await VerifySha256Async(destination, update.Sha256, ct); LauncherLog.Write(dataRoot, $"Reutilizando ZIP verificado de {update.Version}."); return destination; }
            catch (InvalidDataException) { LauncherLog.Write(dataRoot, $"El ZIP existente de {update.Version} es inválido; se descargará de nuevo."); File.Delete(destination); }
        }
        var temporary = Path.Combine(downloads, $".{update.Version}.{Guid.NewGuid():N}.zip.part");
        try
        {
            LauncherLog.Write(dataRoot, $"Descargando actualización {update.Version}.");
            using var response = await SendWithRetriesAsync(update.Url, DownloadHeaderTimeout, ct, HttpCompletionOption.ResponseHeadersRead);
            await using var input = await response.Content.ReadAsStreamAsync(ct);
            using var downloadCt = CancellationTokenSource.CreateLinkedTokenSource(ct); downloadCt.CancelAfter(DownloadTimeout);
            await using (var output = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None, 81920, FileOptions.Asynchronous | FileOptions.WriteThrough))
            {
                var total = response.Content.Headers.ContentLength;
                var buffer = new byte[81920]; long copied = 0; int read;
                while ((read = await input.ReadAsync(buffer, downloadCt.Token)) != 0)
                {
                    await output.WriteAsync(buffer.AsMemory(0, read), downloadCt.Token);
                    copied += read;
                    var percent = total is > 0 ? 10 + (int)Math.Min(60, copied * 60 / total.Value) : 10;
                    progress?.Report(new ProgressInfo(percent, "Descargando actualización…", total is > 0 ? $"{FormatMegabytes(copied)} / {FormatMegabytes(total.Value)}" : FormatMegabytes(copied)));
                }
                await output.FlushAsync(downloadCt.Token);
            }
            await VerifySha256Async(temporary, update.Sha256, ct); File.Move(temporary, destination, true);
            LauncherLog.Write(dataRoot, $"Descarga de {update.Version} completada y SHA-256 válido."); return destination;
        }
        catch { TryDelete(temporary); throw; }
    }
    public void CleanupInterruptedDownloads()
    {
        var downloads = Path.Combine(dataRoot, "updates", "downloads"); if (!Directory.Exists(downloads)) return;
        foreach (var part in Directory.EnumerateFiles(downloads, "*.part"))
            try { File.Delete(part); LauncherLog.Write(dataRoot, $"Se eliminó descarga parcial abandonada: {Path.GetFileName(part)}."); }
            catch (IOException ex) { LauncherLog.Write(dataRoot, $"No se pudo limpiar descarga parcial {Path.GetFileName(part)}: {ex.Message}"); }
    }
    public static async Task VerifySha256Async(string file, string expected, CancellationToken ct)
    {
        if (!Versioning.IsSha256(expected)) throw new InvalidDataException("El manifiesto contiene un SHA-256 inválido.");
        await using var input = File.OpenRead(file); var actual = await SHA256.HashDataAsync(input, ct);
        if (!CryptographicOperations.FixedTimeEquals(actual, Convert.FromHexString(expected))) throw new InvalidDataException("Actualización dañada o incompleta.");
    }
    private async Task<HttpResponseMessage> SendWithRetriesAsync(string url, TimeSpan timeout, CancellationToken ct, HttpCompletionOption completion = HttpCompletionOption.ResponseContentRead)
    {
        Exception? last = null;
        for (var attempt = 1; attempt <= 2; attempt++)
        {
            try
            {
                using var request = new HttpRequestMessage(HttpMethod.Get, url); request.Headers.UserAgent.Add(new ProductInfoHeaderValue("DuoLauncher", launcherVersion)); request.Headers.Accept.ParseAdd("application/vnd.github+json");
                using var requestCt = CancellationTokenSource.CreateLinkedTokenSource(ct); requestCt.CancelAfter(timeout);
                var response = await http.SendAsync(request, completion, requestCt.Token);
                if (response.IsSuccessStatusCode) return response;
                if (!IsTransient(response.StatusCode) || attempt == 2) { response.EnsureSuccessStatusCode(); }
                last = new HttpRequestException($"HTTP {(int)response.StatusCode} ({response.ReasonPhrase})."); response.Dispose();
            }
            catch (Exception ex) when (IsTransient(ex, ct) && attempt < 2) { last = ex; }
            if (attempt < 2) await Task.Delay(750, ct);
        }
        throw new HttpRequestException("No se pudo completar la solicitud después de reintentar.", last);
    }
    private static bool IsTransient(HttpStatusCode code) => code == HttpStatusCode.RequestTimeout || code == (HttpStatusCode)429 || (int)code >= 500;
    private static bool IsTransient(Exception ex, CancellationToken external) =>
        ex is HttpRequestException request && (request.StatusCode is null || IsTransient(request.StatusCode.Value)) ||
        ex is IOException or TimeoutException ||
        ex is OperationCanceledException && !external.IsCancellationRequested;
    private static void TryDelete(string path) { try { if (File.Exists(path)) File.Delete(path); } catch (IOException) { } }
    private static string FormatMegabytes(long bytes) => $"{bytes / 1024d / 1024d:0.0} MB";
}

[SupportedOSPlatform("linux")]
internal sealed class LinuxReleaseStore(string installRoot, string dataRoot)
{
    private static readonly JsonSerializerOptions Json = new() { PropertyNameCaseInsensitive = true, WriteIndented = true };
    public string InstallRoot { get; } = installRoot; public string DataRoot { get; } = dataRoot; public string VersionsRoot => Path.Combine(InstallRoot, "versions"); public string CurrentPath => Path.Combine(InstallRoot, "current.json");
    public LauncherConfig ReadConfig() => Read<LauncherConfig>(Path.Combine(InstallRoot, "launcher-config.json")); public CurrentRelease ReadCurrent() => Read<CurrentRelease>(CurrentPath); public string VersionDirectory(string version) => Path.Combine(VersionsRoot, version);
    public void WriteCurrentAtomically(CurrentRelease release)
    {
        Directory.CreateDirectory(InstallRoot); var temporary = Path.Combine(InstallRoot, $".current.{Guid.NewGuid():N}.json.tmp");
        try
        {
            using (var stream = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None, 4096, FileOptions.WriteThrough)) using (var writer = new Utf8JsonWriter(stream, new JsonWriterOptions { Indented = true })) { JsonSerializer.Serialize(writer, release, Json); writer.Flush(); stream.Flush(true); }
            File.Move(temporary, CurrentPath, true);
        }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
    public string ExtractToStaging(string archivePath, string version)
    {
        var root = Path.Combine(DataRoot, "updates", "staging", $"{version}-{Guid.NewGuid():N}"); Directory.CreateDirectory(root);
        try
        {
            using var archive = ZipFile.OpenRead(archivePath);
            foreach (var entry in archive.Entries)
            {
                var target = Path.GetFullPath(Path.Combine(root, entry.FullName)); if (!target.StartsWith(Path.GetFullPath(root) + Path.DirectorySeparatorChar, StringComparison.Ordinal)) throw new InvalidDataException("Ruta no segura en la actualización.");
                if (string.IsNullOrEmpty(entry.Name)) { Directory.CreateDirectory(target); continue; }
                Directory.CreateDirectory(Path.GetDirectoryName(target)!); entry.ExtractToFile(target, true);
            }
            SetExecutable(Path.Combine(root, "app", "duo_desktop")); SetExecutable(Path.Combine(root, "service", "DuoDesktop.Service")); ValidatePayload(root); return root;
        }
        catch { if (Directory.Exists(root)) Directory.Delete(root, true); throw; }
    }
    public void ActivateStagedVersion(string version, string staging)
    {
        ValidatePayload(staging); Directory.CreateDirectory(VersionsRoot); var pending = Path.Combine(VersionsRoot, $".{version}.{Guid.NewGuid():N}.installing"); Directory.Move(staging, pending);
        try
        {
            ValidatePayload(pending);
            var destination = VersionDirectory(version);
            if (Directory.Exists(destination))
            {
                // A previous interrupted/manual install must never make us trust
                // an incomplete version directory.
                try { ValidatePayload(destination); Directory.Delete(pending, true); }
                catch (InvalidDataException) { Directory.Delete(destination, true); Directory.Move(pending, destination); }
            }
            else Directory.Move(pending, destination);
        }
        catch { if (Directory.Exists(pending)) Directory.Delete(pending, true); throw; }
    }
    public void UpdateLauncherFromStaging(string staging)
    {
        var candidate = Path.Combine(staging, "launcher", "DuoLauncher");
        if (!File.Exists(candidate)) return; // Older release archives remain compatible.
        if (new FileInfo(candidate).Length == 0) throw new InvalidDataException("El launcher incluido en la actualización está vacío.");
        var temporary = Path.Combine(InstallRoot, $".DuoLauncher.{Guid.NewGuid():N}.tmp");
        try
        {
            File.Copy(candidate, temporary, overwrite: false);
            SetExecutable(temporary);
            File.Move(temporary, Path.Combine(InstallRoot, "DuoLauncher"), overwrite: true);
            Directory.Delete(Path.Combine(staging, "launcher"), true);
            LauncherLog.Write(DataRoot, "Launcher Linux actualizado junto con el payload.");
        }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
    public void KeepCurrentAndPrevious()
    {
        var current = ReadCurrent(); var keep = new HashSet<string>(StringComparer.Ordinal) { current.Version }; if (!string.IsNullOrWhiteSpace(current.PreviousVersion)) keep.Add(current.PreviousVersion);
        if (!Directory.Exists(VersionsRoot)) return; foreach (var directory in Directory.EnumerateDirectories(VersionsRoot)) if (!keep.Contains(Path.GetFileName(directory)) && !Path.GetFileName(directory).StartsWith('.')) Directory.Delete(directory, true);
    }
    public static void ValidatePayload(string directory) { foreach (var path in new[] { Path.Combine("app", "duo_desktop"), Path.Combine("app", "lib", "libflutter_linux_gtk.so"), Path.Combine("service", "DuoDesktop.Service") }) if (!File.Exists(Path.Combine(directory, path))) throw new InvalidDataException($"Payload incompleto: {path}"); }
    private static T Read<T>(string path) => JsonSerializer.Deserialize<T>(File.ReadAllText(path), Json) ?? throw new InvalidDataException($"Archivo vacío: {path}");
    private static void SetExecutable(string path) { if (File.Exists(path)) File.SetUnixFileMode(path, File.GetUnixFileMode(path) | UnixFileMode.UserExecute | UnixFileMode.GroupExecute | UnixFileMode.OtherExecute); }
}

[SupportedOSPlatform("linux")]
internal sealed class LauncherInstanceLock : IAsyncDisposable
{
    private readonly FileStream _stream; private LauncherInstanceLock(FileStream stream) => _stream = stream;
    public static async Task<LauncherInstanceLock?> TryAcquireAsync(string path, TimeSpan wait)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path)!); var deadline = DateTime.UtcNow + wait;
        while (true)
        {
            FileStream? stream = null;
            try
            {
                stream = new FileStream(path, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
                stream.Lock(0, 1);
                return new LauncherInstanceLock(stream);
            }
            catch (IOException)
            {
                stream?.Dispose();
                if (DateTime.UtcNow >= deadline) return null;
                await Task.Delay(200);
            }
        }
    }
    public ValueTask DisposeAsync() { try { _stream.Unlock(0, 1); } catch (IOException) { } _stream.Dispose(); return ValueTask.CompletedTask; }
}

internal static class Versioning
{
    public static bool IsNewerCompatible(UpdateManifest update, CurrentRelease current, string channel, string launcherVersion) => string.Equals(update.Channel, channel, StringComparison.OrdinalIgnoreCase) && Compare(update.Version, current.Version) > 0 && Compare(update.MinimumLauncherVersion, launcherVersion) <= 0;
    public static int Compare(string left, string right) { Require(left); Require(right); return Version.Parse(left).CompareTo(Version.Parse(right)); }
    public static void Require(string value) { if (!Version.TryParse(value, out var version) || version.Revision >= 0) throw new InvalidDataException($"Versión inválida: {value}"); }
    public static bool IsSha256(string value) => value.Length == 64 && value.All(Uri.IsHexDigit);
    public static void ValidateManifest(UpdateManifest manifest) { Require(manifest.Version); Require(manifest.MinimumLauncherVersion); if (!Uri.TryCreate(manifest.Url, UriKind.Absolute, out var uri) || uri.Scheme != Uri.UriSchemeHttps) throw new InvalidDataException("La URL de actualización debe usar HTTPS."); if (!IsSha256(manifest.Sha256)) throw new InvalidDataException("El manifiesto contiene un SHA-256 inválido."); }
}
internal static class LauncherLog { public static void Write(string dataRoot, string message) { try { File.AppendAllText(Path.Combine(dataRoot, "logs", "launcher.log"), $"{DateTimeOffset.Now:O} {message}{Environment.NewLine}"); } catch { } } }
internal sealed record ProgressInfo(int Percent, string Stage, string? Detail = null);

// The launcher must remain usable on every supported Linux desktop. Zenity is
// the most portable GTK implementation; KDialog covers KDE installations.
// Both are optional: a missing/failed dialog only falls back to launcher.log.
internal sealed class DesktopProgress : IProgress<ProgressInfo>, IDisposable
{
    private readonly string _dataRoot;
    private readonly Process? _dialog;
    private readonly StreamWriter? _zenityInput;
    private readonly Task<string?>? _kdialogReference;
    private string? _reference;
    private bool _closed;

    private DesktopProgress(string dataRoot)
    {
        _dataRoot = dataRoot;
        if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable("DISPLAY")) && string.IsNullOrEmpty(Environment.GetEnvironmentVariable("WAYLAND_DISPLAY"))) return;
        try
        {
            if (FindExecutable("zenity") is { } zenity)
            {
                var info = new ProcessStartInfo(zenity) { UseShellExecute = false, RedirectStandardInput = true };
                info.ArgumentList.Add("--progress"); info.ArgumentList.Add("--title=Duo Desktop"); info.ArgumentList.Add("--text=Preparando Duo Desktop…"); info.ArgumentList.Add("--percentage=0"); info.ArgumentList.Add("--auto-close"); info.ArgumentList.Add("--no-cancel");
                _dialog = Process.Start(info); _zenityInput = _dialog?.StandardInput;
            }
            else if (FindExecutable("kdialog") is { } kdialog && FindExecutable("gdbus") is { })
            {
                var info = new ProcessStartInfo(kdialog) { UseShellExecute = false, RedirectStandardOutput = true };
                info.ArgumentList.Add("--title"); info.ArgumentList.Add("Duo Desktop"); info.ArgumentList.Add("--progressbar"); info.ArgumentList.Add("Preparando Duo Desktop…"); info.ArgumentList.Add("100");
                _dialog = Process.Start(info);
                if (_dialog is not null) _kdialogReference = _dialog.StandardOutput.ReadLineAsync();
            }
        }
        catch (Exception ex) { LauncherLog.Write(dataRoot, $"No se pudo mostrar progreso gráfico: {ex.Message}"); }
    }

    public static DesktopProgress Create(string dataRoot) => new(dataRoot);
    public void Report(ProgressInfo progress)
    {
        if (_closed) return;
        try
        {
            var percent = Math.Clamp(progress.Percent, 0, 100);
            if (_zenityInput is not null)
            {
                _zenityInput.WriteLine(percent);
                _zenityInput.WriteLine($"# {progress.Stage}{(string.IsNullOrWhiteSpace(progress.Detail) ? "" : $"\n{progress.Detail}")}");
                _zenityInput.Flush();
                return;
            }
            if (_kdialogReference is { IsCompletedSuccessfully: true } && _reference is null) _reference = _kdialogReference.Result;
            if (!string.IsNullOrWhiteSpace(_reference))
            {
                var parts = _reference.Split(' ', StringSplitOptions.RemoveEmptyEntries);
                if (parts.Length >= 1)
                {
                    var path = parts.Length >= 2 ? parts[1] : "/ProgressDialog";
                    RunGdbus(parts[0], path, "org.freedesktop.DBus.Properties.Set", "org.kde.kdialog.ProgressDialog", "value", $"<int32 {percent}>");
                    RunGdbus(parts[0], path, "org.kde.kdialog.ProgressDialog.setLabelText", $"{progress.Stage}{(string.IsNullOrWhiteSpace(progress.Detail) ? "" : $" — {progress.Detail}")}");
                }
            }
        }
        catch (Exception ex) { LauncherLog.Write(_dataRoot, $"No se pudo actualizar progreso gráfico: {ex.Message}"); }
    }

    public void Close()
    {
        if (_closed) return;
        _closed = true;
        try
        {
            if (_zenityInput is not null) { _zenityInput.Dispose(); return; }
            if (_kdialogReference is { IsCompletedSuccessfully: true })
            {
                _reference ??= _kdialogReference.Result;
                var parts = _reference?.Split(' ', StringSplitOptions.RemoveEmptyEntries);
                if (parts?.Length >= 1) RunGdbus(parts[0], parts.Length >= 2 ? parts[1] : "/ProgressDialog", "org.kde.kdialog.ProgressDialog.close");
            }
        }
        catch (Exception ex) { LauncherLog.Write(_dataRoot, $"No se pudo cerrar progreso gráfico: {ex.Message}"); }
    }

    public void Dispose() { Close(); _dialog?.Dispose(); }
    private static string? FindExecutable(string name) => Environment.GetEnvironmentVariable("PATH")?.Split(Path.PathSeparator).Select(path => Path.Combine(path, name)).FirstOrDefault(File.Exists);
    private static void RunGdbus(string service, string path, string method, params string[] args)
    {
        var executable = FindExecutable("gdbus"); if (executable is null) return;
        var info = new ProcessStartInfo(executable) { UseShellExecute = false, CreateNoWindow = true };
        info.ArgumentList.Add("call"); info.ArgumentList.Add("--session"); info.ArgumentList.Add("--dest"); info.ArgumentList.Add(service); info.ArgumentList.Add("--object-path"); info.ArgumentList.Add(path); info.ArgumentList.Add("--method"); info.ArgumentList.Add(method); foreach (var arg in args) info.ArgumentList.Add(arg);
        using var process = Process.Start(info); process?.WaitForExit(1000);
    }
}
internal sealed class LauncherConfig { public string Channel { get; init; } = "beta"; public bool CheckForUpdates { get; init; } = true; public string ReleasesOwner { get; init; } = "davidm052006"; public string ReleasesRepository { get; init; } = "duo-desktop"; public string? DuoProject { get; init; } }
internal sealed class CurrentRelease { public string Version { get; init; } = ""; public string? PreviousVersion { get; init; } }
internal sealed class UpdateManifest { public string Version { get; init; } = ""; public string Channel { get; init; } = ""; public string Url { get; init; } = ""; public string Sha256 { get; init; } = ""; public string MinimumLauncherVersion { get; init; } = "1.0.0"; public bool Mandatory { get; init; } }
