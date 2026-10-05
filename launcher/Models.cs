using System.Text.Json.Serialization;

namespace DuoLauncher;

public sealed class LauncherConfig
{
    public string Channel { get; init; } = "beta";
    public bool CheckForUpdates { get; init; } = true;
    public string ReleasesOwner { get; init; } = "davidm052006";
    public string ReleasesRepository { get; init; } = "duo-desktop";
    // Optional project selected for desktop launches. The service otherwise
    // cannot choose when the user has more than one duo configuration.
    public string? DuoProject { get; init; }
}

public sealed class CurrentRelease
{
    public string Version { get; init; } = "";
    public string? PreviousVersion { get; init; }
}

public sealed class UpdateManifest
{
    public string Version { get; init; } = "";
    public string Channel { get; init; } = "";
    public string Url { get; init; } = "";
    public string Sha256 { get; init; } = "";
    public string MinimumLauncherVersion { get; init; } = "1.0.0";
    public bool Mandatory { get; init; }
}

public sealed record ProgressInfo(int Percent, string Stage, string? Detail = null);
