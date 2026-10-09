using System.Net;
using System.Net.Mail;

namespace DuoDesktop.Cloud.Email;

public interface IInvitationEmailSender
{
    Task SendAsync(
        string email,
        string token,
        string projectName,
        string role,
        DateTimeOffset expiresAt,
        CancellationToken ct);
}

public sealed class InvitationEmailException(string code, string message, Exception? inner = null)
    : Exception(message, inner)
{
    public string Code { get; } = code;
}

public sealed class SmtpInvitationEmailSender(
    IConfiguration configuration,
    ILogger<SmtpInvitationEmailSender> log) : IInvitationEmailSender
{
    public async Task SendAsync(
        string email,
        string token,
        string projectName,
        string role,
        DateTimeOffset expiresAt,
        CancellationToken ct)
    {
        var host = configuration["Email:SmtpHost"]?.Trim();
        var from = configuration["Email:From"]?.Trim();
        var username = configuration["Email:SmtpUsername"]?.Trim();
        var password = configuration["Email:SmtpPassword"];

        if (string.IsNullOrWhiteSpace(host) || string.IsNullOrWhiteSpace(from))
            throw new InvitationEmailException(
                "email_not_configured",
                "El envío de invitaciones por correo todavía no está configurado.");

        var port = int.TryParse(configuration["Email:SmtpPort"], out var configuredPort)
            ? configuredPort
            : 587;
        var ssl = !bool.TryParse(configuration["Email:SmtpEnableSsl"], out var configuredSsl)
            || configuredSsl;

        using var message = new MailMessage
        {
            From = new MailAddress(from, "Duo Desktop"),
            Subject = $"Invitación a {projectName} en Duo Desktop",
            Body =
                $"Te invitaron al proyecto {projectName} con rol {role}.\n\n" +
                $"Abre Duo Desktop → Proyectos → Aceptar invitación y pega este token:\n\n" +
                $"{token}\n\n" +
                $"El token expira el {expiresAt:yyyy-MM-dd HH:mm} UTC y solo puede usarse una vez.",
            IsBodyHtml = false,
        };
        message.To.Add(new MailAddress(email));

        using var client = new SmtpClient(host, port)
        {
            EnableSsl = ssl,
            DeliveryMethod = SmtpDeliveryMethod.Network,
        };

        if (!string.IsNullOrWhiteSpace(username))
        {
            client.Credentials = new NetworkCredential(username, password ?? "");
        }

        try
        {
            ct.ThrowIfCancellationRequested();
            await client.SendMailAsync(message);
            ct.ThrowIfCancellationRequested();
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception e)
        {
            log.LogError(e, "No se pudo enviar una invitación por correo a {Email}", email);
            throw new InvitationEmailException(
                "email_delivery_failed",
                "No se pudo enviar el correo de invitación. Inténtalo de nuevo.",
                e);
        }
    }
}
