using System.Security.Claims;
using DuoDesktop.Cloud.Data;
using DuoDesktop.Cloud.Domain;
using Microsoft.EntityFrameworkCore;

namespace DuoDesktop.Cloud.Auth;

public sealed class CurrentUser(IHttpContextAccessor accessor)
{
    public async Task<UserProfile> GetOrCreateAsync(
        DuoCloudDbContext db,
        CancellationToken cancellationToken = default)
    {
        var principal = accessor.HttpContext?.User
            ?? throw new InvalidOperationException("No hay HttpContext autenticado.");

        var subject = principal.FindFirstValue("sub")
            ?? principal.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? throw new InvalidOperationException("El token no contiene subject.");

        var email = principal.FindFirstValue("email")
            ?? principal.FindFirstValue(ClaimTypes.Email)
            ?? throw new InvalidOperationException("El token no contiene email.");

        var displayName = principal.FindFirstValue("name")
            ?? principal.FindFirstValue("preferred_username")
            ?? email.Split('@')[0];

        var normalizedEmail = email.Trim().ToLowerInvariant();
        var now = DateTimeOffset.UtcNow;

        var user = await db.Users.SingleOrDefaultAsync(
            x => x.AuthSubject == subject,
            cancellationToken);

        if (user is null)
        {
            user = new UserProfile
            {
                Id = Guid.NewGuid(),
                AuthSubject = subject,
                Email = normalizedEmail,
                DisplayName = displayName,
                CreatedAt = now,
                LastSeenAt = now,
            };
            db.Users.Add(user);
        }
        else
        {
            user.Email = normalizedEmail;
            user.DisplayName = displayName;
            user.LastSeenAt = now;
        }

        await db.SaveChangesAsync(cancellationToken);
        return user;
    }
}
