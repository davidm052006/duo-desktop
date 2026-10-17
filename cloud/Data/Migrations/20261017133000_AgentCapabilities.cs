using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DuoDesktop.Cloud.Data.Migrations;

[DbContext(typeof(DuoCloudDbContext))]
[Migration("20261017133000_AgentCapabilities")]
public partial class AgentCapabilities : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder) => migrationBuilder.AddColumn<string>(
        name: "AgentCapabilitiesJson", table: "users", type: "character varying(300)", maxLength: 300,
        nullable: false, defaultValue: "[]");

    protected override void Down(MigrationBuilder migrationBuilder) =>
        migrationBuilder.DropColumn(name: "AgentCapabilitiesJson", table: "users");
}
