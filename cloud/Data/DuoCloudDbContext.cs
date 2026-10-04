using DuoDesktop.Cloud.Domain;
using Microsoft.EntityFrameworkCore;

namespace DuoDesktop.Cloud.Data;

public sealed class DuoCloudDbContext(DbContextOptions<DuoCloudDbContext> options)
    : DbContext(options)
{
    public DbSet<UserProfile> Users => Set<UserProfile>();
    public DbSet<Project> Projects => Set<Project>();
    public DbSet<ProjectMember> ProjectMembers => Set<ProjectMember>();
    public DbSet<ProjectInvitation> ProjectInvitations => Set<ProjectInvitation>();
    public DbSet<CloudTask> Tasks => Set<CloudTask>();
    public DbSet<TaskEvent> TaskEvents => Set<TaskEvent>();

    protected override void OnModelCreating(ModelBuilder model)
    {
        model.Entity<UserProfile>(entity =>
        {
            entity.ToTable("users");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => x.AuthSubject).IsUnique();
            entity.HasIndex(x => x.Email);
            entity.Property(x => x.AuthSubject).HasMaxLength(256);
            entity.Property(x => x.Email).HasMaxLength(320);
            entity.Property(x => x.DisplayName).HasMaxLength(160);
        });

        model.Entity<Project>(entity =>
        {
            entity.ToTable("projects");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => x.Slug).IsUnique();
            entity.Property(x => x.Name).HasMaxLength(160);
            entity.Property(x => x.Slug).HasMaxLength(100);
            entity.HasOne(x => x.Owner)
                .WithMany()
                .HasForeignKey(x => x.OwnerUserId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        model.Entity<ProjectMember>(entity =>
        {
            entity.ToTable("project_members");
            entity.HasKey(x => new { x.ProjectId, x.UserId });
            entity.Property(x => x.Role).HasMaxLength(16);
            entity.HasOne(x => x.Project)
                .WithMany(x => x.Members)
                .HasForeignKey(x => x.ProjectId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(x => x.User)
                .WithMany(x => x.Memberships)
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        model.Entity<ProjectInvitation>(entity =>
        {
            entity.ToTable("project_invitations");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => x.TokenHash).IsUnique();
            entity.HasIndex(x => new { x.ProjectId, x.EmailNormalized });
            entity.Property(x => x.EmailNormalized).HasMaxLength(320);
            entity.Property(x => x.Role).HasMaxLength(16);
            entity.Property(x => x.TokenHash).HasMaxLength(64);
            entity.HasOne(x => x.Project)
                .WithMany()
                .HasForeignKey(x => x.ProjectId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(x => x.InvitedByUser)
                .WithMany()
                .HasForeignKey(x => x.InvitedByUserId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        model.Entity<CloudTask>(entity =>
        {
            entity.ToTable("tasks");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => new { x.ProjectId, x.ExternalId }).IsUnique();
            entity.Property(x => x.ExternalId).HasMaxLength(64);
            entity.Property(x => x.Title).HasMaxLength(500);
            entity.Property(x => x.OwnerAgent).HasMaxLength(64);
            entity.Property(x => x.Status).HasMaxLength(64);
            entity.Property(x => x.Branch).HasMaxLength(300);
            entity.HasOne(x => x.Project)
                .WithMany(x => x.Tasks)
                .HasForeignKey(x => x.ProjectId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(x => x.CreatedByUser)
                .WithMany()
                .HasForeignKey(x => x.CreatedByUserId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        model.Entity<TaskEvent>(entity =>
        {
            entity.ToTable("task_events");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => new { x.ProjectId, x.Id });
            entity.Property(x => x.Type).HasMaxLength(80);
            entity.Property(x => x.Agent).HasMaxLength(64);
            entity.Property(x => x.PayloadJson).HasColumnType("jsonb");
            entity.HasOne(x => x.Task)
                .WithMany(x => x.Events)
                .HasForeignKey(x => x.TaskId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(x => x.ActorUser)
                .WithMany()
                .HasForeignKey(x => x.ActorUserId)
                .OnDelete(DeleteBehavior.SetNull);
        });
    }
}
