using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text.Json;
using System.IO.Compression;

namespace DuoLauncher;

public sealed class UpdateClient(HttpClient http, string dataRoot)
{
    private static readonly JsonSerializerOptions Json = new() { PropertyNameCaseInsensitive = true };

    public async Task<UpdateManifest?> GetLatestAsync(LauncherConfig config, CancellationToken ct)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, $"https://api.github.com/repos/{config.ReleasesOwner}/{config.ReleasesRepository}/releases/latest");
        request.Headers.UserAgent.Add(new ProductInfoHeaderValue("DuoLauncher", "1.0"));
        request.Headers.Accept.ParseAdd("application/vnd.github+json");
        using var response = await http.SendAsync(request, ct);
        response.EnsureSuccessStatusCode();
        using var release = JsonDocument.Parse(await response.Content.ReadAsStreamAsync(ct));
        var assets = release.RootElement.GetProperty("assets").EnumerateArray();
        string? url = null;
        foreach (var asset in assets)
            if (asset.GetProperty("name").GetString() == "latest.json") { url = asset.GetProperty("browser_download_url").GetString(); break; }
        if (url is null) return null;
        using var manifestRequest = new HttpRequestMessage(HttpMethod.Get, url);
        manifestRequest.Headers.UserAgent.Add(new ProductInfoHeaderValue("DuoLauncher", "1.0"));
        using var manifestResponse = await http.SendAsync(manifestRequest, ct);
        manifestResponse.EnsureSuccessStatusCode();
        var manifest = await JsonSerializer.DeserializeAsync<UpdateManifest>(await manifestResponse.Content.ReadAsStreamAsync(ct), Json, ct);
        if (manifest is null) throw new InvalidDataException("latest.json is empty.");
        ValidateManifest(manifest);
        return manifest;
    }

    public async Task<string> DownloadAsync(UpdateManifest manifest, IProgress<ProgressInfo> progress, CancellationToken ct)
    {
        Directory.CreateDirectory(Path.Combine(dataRoot, "updates", "downloads"));
        var output = Path.Combine(dataRoot, "updates", "downloads", $"{manifest.Version}.zip.part");
        try
        {
            using var response = await http.GetAsync(manifest.Url, HttpCompletionOption.ResponseHeadersRead, ct);
            response.EnsureSuccessStatusCode();
            var total = response.Content.Headers.ContentLength;
            await using var input = await response.Content.ReadAsStreamAsync(ct);
            await using var file = new FileStream(output, FileMode.Create, FileAccess.Write, FileShare.None, 81920, useAsync: true);
            var buffer = new byte[81920]; long read = 0; int count;
            while ((count = await input.ReadAsync(buffer, ct)) != 0)
            {
                await file.WriteAsync(buffer.AsMemory(0, count), ct); read += count;
                var percent = total is > 0 ? 10 + (int)(read * 60 / total.Value) : 10;
                progress.Report(new ProgressInfo(percent, "Descargando…", total is > 0 ? $"{Format(read)} / {Format(total.Value)}" : Format(read)));
            }
            await file.FlushAsync(ct);
            return output;
        }
        catch { if (File.Exists(output)) File.Delete(output); throw; }
    }

    public static async Task VerifySha256Async(string file, string expected, CancellationToken ct)
    {
        if (!IsSha256(expected)) throw new InvalidDataException("The update manifest contains an invalid SHA-256.");
        await using var input = File.OpenRead(file);
        var actual = await SHA256.HashDataAsync(input, ct);
        var expectedBytes = Convert.FromHexString(expected);
        if (!CryptographicOperations.FixedTimeEquals(actual, expectedBytes)) throw new InvalidDataException("Actualización dañada o incompleta.");
    }

    public static void ValidateManifest(UpdateManifest manifest)
    {
        SemVersion.Parse(manifest.Version);
        SemVersion.Parse(manifest.MinimumLauncherVersion);
        if (!Uri.TryCreate(manifest.Url, UriKind.Absolute, out var uri) || uri.Scheme != Uri.UriSchemeHttps)
            throw new InvalidDataException("Update URL must use HTTPS.");
        if (!IsSha256(manifest.Sha256)) throw new InvalidDataException("The update manifest contains an invalid SHA-256.");
    }

    public string ExtractToStaging(string zip, string version)
    {
        var root = Path.Combine(dataRoot, "updates", "staging", version);
        if (Directory.Exists(root)) Directory.Delete(root, true);
        Directory.CreateDirectory(root);
        try
        {
            using var archive = ZipFile.OpenRead(zip);
            foreach (var entry in archive.Entries)
            {
                var target = Path.GetFullPath(Path.Combine(root, entry.FullName));
                if (!target.StartsWith(Path.GetFullPath(root) + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase)) throw new InvalidDataException("Unsafe path in update archive.");
                if (string.IsNullOrEmpty(entry.Name)) { Directory.CreateDirectory(target); continue; }
                Directory.CreateDirectory(Path.GetDirectoryName(target)!); entry.ExtractToFile(target, true);
            }
            ReleaseStore.ValidatePayload(root);
            return root;
        }
        catch { if (Directory.Exists(root)) Directory.Delete(root, true); throw; }
    }

    private static bool IsSha256(string s) => s.Length == 64 && s.All(Uri.IsHexDigit);
    private static string Format(long bytes) => $"{bytes / 1024d / 1024d:0.0} MB";
}
