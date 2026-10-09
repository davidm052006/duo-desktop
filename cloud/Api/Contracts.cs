namespace DuoDesktop.Cloud.Api;

public sealed record CreateProjectRequest(
    string? Name,
    string? Slug,
    string? RepositoryFullName,
    string? TargetBranch);
public sealed record InviteMemberRequest(string? Email, string? Role);
public sealed record UpsertTaskRequest(
    string? ExternalId,
    string? Title,
    string? OwnerAgent,
    string? Status,
    string? Branch,
    Guid? AssignedUserId,
    string? WorkProvider);
public sealed record AppendTaskEventRequest(
    string? ExternalTaskId,
    string? Type,
    string? Agent,
    string? PayloadJson);
public sealed record SubmitTaskRequest(string? Result);

public sealed record UpsertPullRequestRequest(
    int GitHubNumber,
    string? Url,
    string? SourceBranch,
    string? TargetBranch,
    string? State,
    string? ReviewState,
    DateTimeOffset? MergedAt,
    string? MergedByLogin);
