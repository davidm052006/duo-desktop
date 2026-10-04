namespace DuoDesktop.Cloud.Api;

public sealed record CreateProjectRequest(string? Name, string? Slug);
public sealed record InviteMemberRequest(string? Email, string? Role);
public sealed record UpsertTaskRequest(
    string? ExternalId,
    string? Title,
    string? OwnerAgent,
    string? Status,
    string? Branch);
public sealed record AppendTaskEventRequest(
    string? ExternalTaskId,
    string? Type,
    string? Agent,
    string? PayloadJson);
