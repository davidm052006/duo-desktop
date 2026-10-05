using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Security.Cryptography;

namespace DuoLauncher;

public sealed class ProcessRunner
{
    public async Task<RunningDuo> StartAsync(string versionDirectory, string dataRoot, string? duoProject, CancellationToken ct)
    {
        ReleaseStore.ValidatePayload(versionDirectory);
        var port = GetLoopbackPort();
        var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
        var service = Start(Path.Combine(versionDirectory, "service", "DuoDesktop.Service.exe"), $"--urls http://127.0.0.1:{port}", port, token, dataRoot, duoProject);
        try
        {
            await WaitForHealthAsync(port, service, ct);
            var app = Start(Path.Combine(versionDirectory, "app", "duo_desktop.exe"), "", port, token, dataRoot, duoProject);
            return new RunningDuo(service, app);
        }
        catch { Stop(service); throw; }
    }

    private static Process Start(string executable, string arguments, int port, string token, string dataRoot, string? duoProject)
    {
        if (!File.Exists(executable)) throw new FileNotFoundException("Required executable not found", executable);
        var info = new ProcessStartInfo(executable, arguments) { UseShellExecute = false, CreateNoWindow = true, WorkingDirectory = Path.GetDirectoryName(executable)! };
        info.Environment["DUO_SERVICE_PORT"] = port.ToString();
        info.Environment["DUO_TOKEN"] = token;
        info.Environment["DUO_DATA_DIR"] = dataRoot;
        if (!string.IsNullOrWhiteSpace(duoProject)) info.Environment["DUO_P"] = duoProject;
        return Process.Start(info) ?? throw new InvalidOperationException("Could not start Duo process.");
    }

    private static async Task WaitForHealthAsync(int port, Process service, CancellationToken ct)
    {
        using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(2) };
        var until = DateTime.UtcNow.AddSeconds(15);
        while (DateTime.UtcNow < until)
        {
            ct.ThrowIfCancellationRequested();
            if (service.HasExited) throw new InvalidOperationException("Duo service ended before it was ready.");
            try { if ((await client.GetAsync($"http://127.0.0.1:{port}/health", ct)).IsSuccessStatusCode) return; } catch (HttpRequestException) { }
            await Task.Delay(250, ct);
        }
        throw new TimeoutException("Duo service did not respond to /health in 15 seconds.");
    }

    private static int GetLoopbackPort()
    {
        using var listener = new TcpListener(IPAddress.Loopback, 0); listener.Start();
        return ((IPEndPoint)listener.LocalEndpoint).Port;
    }

    internal static void Stop(Process process)
    {
        try { if (!process.HasExited) process.Kill(entireProcessTree: true); } catch (InvalidOperationException) { }
        process.Dispose();
    }
}

public sealed class RunningDuo(Process service, Process app) : IDisposable
{
    public Process Service { get; } = service;
    public Process App { get; } = app;
    public void Dispose() => ProcessRunner.Stop(Service);
}
