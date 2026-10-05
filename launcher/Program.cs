using System.Diagnostics;

namespace DuoLauncher;

internal static class Program
{
    [STAThread]
    static void Main()
    {
        ApplicationConfiguration.Initialize();
        Application.Run(new LauncherForm());
    }
}

internal sealed class LauncherForm : Form
{
    private readonly Label _stage = new() { AutoSize = true, ForeColor = Color.White, Font = new Font("Segoe UI", 12, FontStyle.Bold) };
    private readonly Label _versions = new() { AutoSize = true, ForeColor = Color.FromArgb(187, 159, 255) };
    private readonly Label _detail = new() { AutoSize = true, ForeColor = Color.FromArgb(190, 210, 225), MaximumSize = new Size(410, 0) };
    private readonly Label _percent = new() { AutoSize = true, ForeColor = Color.FromArgb(61, 231, 235), Font = new Font("Segoe UI", 16, FontStyle.Bold) };
    private readonly ProgressBar _progress = new() { Width = 410, Height = 18, Style = ProgressBarStyle.Continuous };
    private readonly Button _cancel = new() { Text = "Cancelar", AutoSize = true, FlatStyle = FlatStyle.Flat, ForeColor = Color.White };
    private readonly string _root = AppContext.BaseDirectory;
    private readonly string _dataRoot = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DuoDesktop");
    private CancellationTokenSource? _cancellation;
    private bool _installing;

    public LauncherForm()
    {
        Text = "Duo Desktop"; Size = new Size(480, 300); FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false; MinimizeBox = false; StartPosition = FormStartPosition.CenterScreen;
        BackColor = Color.FromArgb(18, 15, 34); ForeColor = Color.White;
        var title = new Label { Text = "DUO DESKTOP", AutoSize = true, ForeColor = Color.FromArgb(232, 94, 255), Font = new Font("Segoe UI", 19, FontStyle.Bold) };
        var layout = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, Padding = new Padding(33, 25, 33, 20), WrapContents = false };
        layout.Controls.AddRange([title, Spacer(14), _stage, Spacer(6), _versions, Spacer(18), _progress, Spacer(4), _percent, Spacer(10), _detail, Spacer(12), _cancel]);
        Controls.Add(layout);
        _cancel.Click += (_, _) => _cancellation?.Cancel();
        Shown += async (_, _) => await RunAsync();
        FormClosing += OnFormClosing;
    }

    private static Control Spacer(int height) => new Panel { Height = height, Width = 1 };
    private void SetProgress(ProgressInfo p)
    {
        if (InvokeRequired) { BeginInvoke(() => SetProgress(p)); return; }
        _progress.Value = Math.Clamp(p.Percent, 0, 100); _percent.Text = $"{p.Percent}%"; _stage.Text = p.Stage; _detail.Text = p.Detail ?? "";
    }

    private async Task RunAsync()
    {
        _cancellation = new CancellationTokenSource();
        try
        {
            Directory.CreateDirectory(_dataRoot);
            foreach (var name in new[] { "logs", "config", "cef", "updates" }) Directory.CreateDirectory(Path.Combine(_dataRoot, name));
            var store = new ReleaseStore(_root);
            var config = store.ReadConfig();
            var current = store.ReadCurrent();
            SemVersion.Parse(current.Version);
            _versions.Text = $"Versión actual: {current.Version}";
            UpdateManifest? update = null;
            if (config.CheckForUpdates)
            {
                SetProgress(new(3, "Buscando actualizaciones…"));
                try
                {
                    using var http = new HttpClient();
                    update = await new UpdateClient(http, _dataRoot).GetLatestAsync(config, _cancellation.Token);
                    if (update is not null && (!string.Equals(update.Channel, config.Channel, StringComparison.OrdinalIgnoreCase) || SemVersion.Parse(update.Version).CompareTo(SemVersion.Parse(current.Version)) <= 0 || SemVersion.Parse(update.MinimumLauncherVersion).CompareTo(SemVersion.Parse("1.0.0")) > 0)) update = null;
                }
                catch (Exception ex) when (ex is not OperationCanceledException)
                {
                    // Offline launch is intentional: a failed check never prevents local Duo from starting.
                    SetProgress(new(5, "Iniciando Duo Desktop…", "No se pudo buscar actualización; se usará la versión instalada."));
                }
            }
            if (update is not null)
            {
                _versions.Text = $"Actual: {current.Version}  ·  Nueva: {update.Version}";
                var choice = update.Mandatory
                    ? MessageBox.Show(this, $"La actualización {update.Version} es obligatoria.", "Duo Desktop", MessageBoxButtons.OK, MessageBoxIcon.Information)
                    : MessageBox.Show(this, $"Nueva versión {update.Version} disponible.\n\n¿Actualizar ahora?", "Duo Desktop", MessageBoxButtons.YesNo, MessageBoxIcon.Information, MessageBoxDefaultButton.Button1);
                if (update.Mandatory || choice == DialogResult.Yes)
                {
                    current = await InstallAsync(store, update, current, _cancellation.Token);
                    _versions.Text = $"Versión actual: {current.Version}";
                }
            }
            _cancel.Visible = false;
            await LaunchWithRollbackAsync(store, current, _cancellation.Token);
        }
        catch (OperationCanceledException) { SetProgress(new(_installing ? 90 : 0, "Operación cancelada.")); }
        catch (Exception ex)
        {
            SetProgress(new(0, "No se pudo iniciar Duo Desktop.", ex.Message));
            _cancel.Text = "Cerrar"; _cancel.Visible = true; _cancel.Click += (_, _) => Close();
        }
    }

    private async Task<CurrentRelease> InstallAsync(ReleaseStore store, UpdateManifest update, CurrentRelease current, CancellationToken ct)
    {
        using var http = new HttpClient(); var client = new UpdateClient(http, _dataRoot);
        SetProgress(new(8, "Preparando descarga…"));
        var zip = await client.DownloadAsync(update, new Progress<ProgressInfo>(SetProgress), ct);
        SetProgress(new(72, "Verificando…", "Verificando SHA-256…"));
        try { await UpdateClient.VerifySha256Async(zip, update.Sha256, ct); }
        catch { if (File.Exists(zip)) File.Delete(zip); throw new InvalidDataException("Actualización dañada o incompleta. Se conservará la versión actual."); }
        SetProgress(new(82, "Extrayendo…"));
        var stage = client.ExtractToStaging(zip, update.Version);
        _installing = true; _cancel.Visible = false;
        SetProgress(new(92, "Instalando…"));
        store.ActivateStagedVersion(update.Version, stage);
        var activated = new CurrentRelease { Version = update.Version, PreviousVersion = current.Version };
        store.WriteCurrentAtomically(activated);
        _installing = false;
        SetProgress(new(100, "Finalizando…"));
        return activated;
    }

    private async Task LaunchWithRollbackAsync(ReleaseStore store, CurrentRelease current, CancellationToken ct)
    {
        SetProgress(new(100, "Iniciando Duo Desktop…"));
        var runner = new ProcessRunner(); RunningDuo? duo = null;
        try
        {
            duo = await runner.StartAsync(store.VersionDirectory(current.Version), _dataRoot, store.ReadConfig().DuoProject, ct);
            await Task.Delay(3000, ct);
            if (duo.App.HasExited) throw new InvalidOperationException("La aplicación terminó inmediatamente.");
        }
        catch (Exception ex) when (ex is not OperationCanceledException && !string.IsNullOrWhiteSpace(current.PreviousVersion))
        {
            duo?.Dispose();
            var previous = new CurrentRelease { Version = current.PreviousVersion! };
            store.WriteCurrentAtomically(previous);
            MessageBox.Show(this, $"La actualización {current.Version} no pudo iniciarse.\n\nDuo restauró automáticamente {previous.Version}.", "Duo Desktop", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            duo = await runner.StartAsync(store.VersionDirectory(previous.Version), _dataRoot, store.ReadConfig().DuoProject, ct);
        }
        store.KeepCurrentAndPrevious();
        Hide();
        try { await duo!.App.WaitForExitAsync(ct); }
        finally { duo?.Dispose(); Close(); }
    }

    private void OnFormClosing(object? sender, FormClosingEventArgs e)
    {
        if (_installing) { e.Cancel = true; SetProgress(new(92, "Instalando…", "No cierres Duo mientras se activa la actualización.")); }
    }
}
