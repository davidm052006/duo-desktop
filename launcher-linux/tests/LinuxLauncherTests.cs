using System.Net;
using System.Security.Cryptography;
using DuoLauncher.Linux;
using Xunit;

namespace DuoLauncher.Linux.Tests;

public sealed class LinuxLauncherTests : IDisposable
{
    private readonly string _root = Path.Combine(Path.GetTempPath(), "duo-linux-launcher-tests", Guid.NewGuid().ToString("N"));
    public LinuxLauncherTests() => Directory.CreateDirectory(_root);
    public void Dispose() { if (Directory.Exists(_root)) Directory.Delete(_root, true); }

    [Fact]
    public void Remote_version_must_be_newer_and_compatible()
    {
        var current = new CurrentRelease { Version = "1.0.29" };
        Assert.True(Versioning.IsNewerCompatible(Manifest("1.0.30"), current, "beta", "1.0.0"));
        Assert.False(Versioning.IsNewerCompatible(Manifest("1.0.29"), current, "beta", "1.0.0"));
    }

    [Fact]
    public async Task Abandoned_part_is_removed_and_valid_zip_is_promoted()
    {
        var data = Path.Combine(_root, "data"); var store = new LinuxReleaseStore(Path.Combine(_root, "install"), data);
        var stale = Path.Combine(data, "updates", "downloads", "1.0.29.zip.part"); Directory.CreateDirectory(Path.GetDirectoryName(stale)!); await File.WriteAllTextAsync(stale, "old");
        var body = System.Text.Encoding.UTF8.GetBytes("new archive"); var hash = Convert.ToHexString(SHA256.HashData(body));
        using var client = new HttpClient(new DelegateHandler(_ => new HttpResponseMessage(HttpStatusCode.OK) { Content = new ByteArrayContent(body) }));
        var updater = new LinuxUpdater(client, store, data, "1.0.0"); updater.CleanupInterruptedDownloads();
        var downloaded = await updater.DownloadVerifiedAsync(Manifest("1.0.30", hash), CancellationToken.None);
        Assert.False(File.Exists(stale)); Assert.EndsWith("1.0.30.zip", downloaded); Assert.Equal(body, await File.ReadAllBytesAsync(downloaded)); Assert.Empty(Directory.EnumerateFiles(Path.GetDirectoryName(downloaded)!, "*.part"));
    }

    [Fact]
    public async Task Bad_sha_and_interrupted_download_leave_no_part_file()
    {
        var data = Path.Combine(_root, "data"); var store = new LinuxReleaseStore(Path.Combine(_root, "install"), data); var badHash = new string('0', 64);
        using (var client = new HttpClient(new DelegateHandler(_ => new HttpResponseMessage(HttpStatusCode.OK) { Content = new ByteArrayContent([1, 2, 3]) })))
            await Assert.ThrowsAsync<InvalidDataException>(() => new LinuxUpdater(client, store, data, "1.0.0").DownloadVerifiedAsync(Manifest("1.0.30", badHash), CancellationToken.None));
        using (var client = new HttpClient(new DelegateHandler(_ => throw new HttpRequestException("connection reset"))))
            await Assert.ThrowsAsync<HttpRequestException>(() => new LinuxUpdater(client, store, data, "1.0.0").DownloadVerifiedAsync(Manifest("1.0.31", badHash), CancellationToken.None));
        var downloads = Path.Combine(data, "updates", "downloads"); Assert.True(!Directory.Exists(downloads) || !Directory.EnumerateFiles(downloads, "*.part").Any());
    }

    [Fact]
    public void Activation_and_current_json_are_atomic_and_keep_previous_version()
    {
        var install = Path.Combine(_root, "install"); var store = new LinuxReleaseStore(install, Path.Combine(_root, "data"));
        CreatePayload(store.VersionDirectory("1.0.29")); var staging = Path.Combine(_root, "staging"); CreatePayload(staging);
        store.ActivateStagedVersion("1.0.30", staging); store.WriteCurrentAtomically(new CurrentRelease { Version = "1.0.30", PreviousVersion = "1.0.29" });
        var current = store.ReadCurrent(); Assert.Equal("1.0.30", current.Version); Assert.Equal("1.0.29", current.PreviousVersion); Assert.True(Directory.Exists(store.VersionDirectory("1.0.29"))); Assert.True(Directory.Exists(store.VersionDirectory("1.0.30"))); Assert.Empty(Directory.EnumerateFiles(install, "*.tmp"));
    }

    [Fact]
    public void Rollback_restores_previous_pointer_without_deleting_it()
    {
        var store = new LinuxReleaseStore(Path.Combine(_root, "install"), Path.Combine(_root, "data"));
        CreatePayload(store.VersionDirectory("1.0.29")); CreatePayload(store.VersionDirectory("1.0.30"));
        store.WriteCurrentAtomically(new CurrentRelease { Version = "1.0.30", PreviousVersion = "1.0.29" });
        store.WriteCurrentAtomically(new CurrentRelease { Version = "1.0.29" });
        Assert.Equal("1.0.29", store.ReadCurrent().Version);
        Assert.True(Directory.Exists(store.VersionDirectory("1.0.29")));
    }

    [Fact]
    public void Staged_launcher_replaces_the_bootstrap_binary_atomically()
    {
        var install = Path.Combine(_root, "install"); var store = new LinuxReleaseStore(install, Path.Combine(_root, "data"));
        Directory.CreateDirectory(install); File.WriteAllText(Path.Combine(install, "DuoLauncher"), "old");
        var staging = Path.Combine(_root, "staging"); Directory.CreateDirectory(Path.Combine(staging, "launcher")); File.WriteAllText(Path.Combine(staging, "launcher", "DuoLauncher"), "new");
        store.UpdateLauncherFromStaging(staging);
        Assert.Equal("new", File.ReadAllText(Path.Combine(install, "DuoLauncher")));
        Assert.False(Directory.Exists(Path.Combine(staging, "launcher")));
        Assert.Empty(Directory.EnumerateFiles(install, "*.tmp"));
    }

    [Fact]
    public async Task Only_one_launcher_instance_can_hold_the_lock()
    {
        var path = Path.Combine(_root, "launcher.lock"); await using var first = await LauncherInstanceLock.TryAcquireAsync(path, TimeSpan.Zero); Assert.NotNull(first);
        await using var second = await LauncherInstanceLock.TryAcquireAsync(path, TimeSpan.FromMilliseconds(250)); Assert.Null(second);
    }

    [Fact]
    public async Task Github_failure_does_not_invalidate_the_installed_release()
    {
        var store = new LinuxReleaseStore(Path.Combine(_root, "install"), Path.Combine(_root, "data")); store.WriteCurrentAtomically(new CurrentRelease { Version = "1.0.29" });
        using var client = new HttpClient(new DelegateHandler(_ => new HttpResponseMessage(HttpStatusCode.ServiceUnavailable)));
        await Assert.ThrowsAsync<HttpRequestException>(() => new LinuxUpdater(client, store, store.DataRoot, "1.0.0").GetLatestAsync(new LauncherConfig(), CancellationToken.None));
        Assert.Equal("1.0.29", store.ReadCurrent().Version);
    }

    private static UpdateManifest Manifest(string version, string? sha = null) => new() { Version = version, Channel = "beta", Url = "https://example.test/update.zip", Sha256 = sha ?? new string('a', 64), MinimumLauncherVersion = "1.0.0" };
    private static void CreatePayload(string root) { Directory.CreateDirectory(Path.Combine(root, "app", "lib")); Directory.CreateDirectory(Path.Combine(root, "service")); File.WriteAllText(Path.Combine(root, "app", "duo_desktop"), "x"); File.WriteAllText(Path.Combine(root, "app", "lib", "libflutter_linux_gtk.so"), "x"); File.WriteAllText(Path.Combine(root, "service", "DuoDesktop.Service"), "x"); }
    private sealed class DelegateHandler(Func<HttpRequestMessage, HttpResponseMessage> handler) : HttpMessageHandler { protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) => Task.FromResult(handler(request)); }
}
