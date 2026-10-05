using System.IO.Compression;
using System.Security.Cryptography;
using System.Text.Json;
using DuoLauncher;
using Xunit;

namespace DuoLauncher.Tests;

public sealed class ReleaseStoreTests : IDisposable
{
    private readonly string _root = Path.Combine(Path.GetTempPath(), "duo-launcher-tests", Guid.NewGuid().ToString("N"));
    public ReleaseStoreTests() => Directory.CreateDirectory(_root);
    public void Dispose() { if (Directory.Exists(_root)) Directory.Delete(_root, true); }

    [Theory]
    [InlineData("0.2.0", "0.1.9", 1)]
    [InlineData("1.0.0-beta.2", "1.0.0-beta.10", -1)]
    [InlineData("1.0.0", "1.0.0-rc.1", 1)]
    public void SemVer_comparison(string left, string right, int expected) => Assert.Equal(expected, Math.Sign(SemVersion.Parse(left).CompareTo(SemVersion.Parse(right))));

    [Fact]
    public async Task Sha256_valid_and_invalid()
    {
        var file = Path.Combine(_root, "archive.zip"); await File.WriteAllTextAsync(file, "Duo");
        var hash = Convert.ToHexString(await SHA256.HashDataAsync(File.OpenRead(file)));
        await UpdateClient.VerifySha256Async(file, hash, CancellationToken.None);
        await Assert.ThrowsAsync<InvalidDataException>(() => UpdateClient.VerifySha256Async(file, new string('0', 64), CancellationToken.None));
    }

    [Fact]
    public void Manifest_parsing_keeps_security_fields()
    {
        const string json = "{\"version\":\"0.2.0\",\"channel\":\"beta\",\"url\":\"https://example.test/a.zip\",\"sha256\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"minimumLauncherVersion\":\"1.0.0\",\"mandatory\":true}";
        var manifest = JsonSerializer.Deserialize<UpdateManifest>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true })!;
        Assert.Equal("0.2.0", manifest.Version); Assert.True(manifest.Mandatory); Assert.Equal("1.0.0", manifest.MinimumLauncherVersion);
        UpdateClient.ValidateManifest(manifest);
    }

    [Fact]
    public void Staging_invalid_when_a_required_binary_is_missing()
    {
        var stage = Path.Combine(_root, "stage"); Directory.CreateDirectory(Path.Combine(stage, "app"));
        File.WriteAllText(Path.Combine(stage, "app", "duo_desktop.exe"), "x");
        Assert.Throws<InvalidDataException>(() => ReleaseStore.ValidatePayload(stage));
    }

    [Fact]
    public void Atomic_current_change_and_rollback_preserve_previous_version()
    {
        var store = new ReleaseStore(_root);
        store.WriteCurrentAtomically(new CurrentRelease { Version = "0.1.0" });
        store.WriteCurrentAtomically(new CurrentRelease { Version = "0.2.0", PreviousVersion = "0.1.0" });
        Assert.Equal("0.2.0", store.ReadCurrent().Version);
        store.WriteCurrentAtomically(new CurrentRelease { Version = "0.1.0" });
        Assert.Equal("0.1.0", store.ReadCurrent().Version);
        Assert.False(File.Exists(store.CurrentPath + ".tmp"));
    }

    [Fact]
    public void Activation_requires_both_app_and_service_and_retains_old_version()
    {
        var store = new ReleaseStore(_root); Directory.CreateDirectory(store.VersionDirectory("0.1.0"));
        var invalid = Path.Combine(_root, "invalid"); Directory.CreateDirectory(invalid);
        Assert.Throws<InvalidDataException>(() => store.ActivateStagedVersion("0.2.0", invalid));
        Assert.True(Directory.Exists(store.VersionDirectory("0.1.0")));
    }

    [Fact]
    public void Missing_app_or_service_executable_is_rejected()
    {
        var payload = Path.Combine(_root, "payload"); CreatePayload(payload);
        File.Delete(Path.Combine(payload, "app", "duo_desktop.exe"));
        Assert.Throws<InvalidDataException>(() => ReleaseStore.ValidatePayload(payload));
        CreatePayload(payload); File.Delete(Path.Combine(payload, "service", "DuoDesktop.Service.exe"));
        Assert.Throws<InvalidDataException>(() => ReleaseStore.ValidatePayload(payload));
    }

    private static void CreatePayload(string root)
    {
        Directory.CreateDirectory(Path.Combine(root, "app")); Directory.CreateDirectory(Path.Combine(root, "service"));
        File.WriteAllText(Path.Combine(root, "app", "duo_desktop.exe"), "x");
        File.WriteAllText(Path.Combine(root, "app", "flutter_windows.dll"), "x");
        File.WriteAllText(Path.Combine(root, "service", "DuoDesktop.Service.exe"), "x");
    }
}
