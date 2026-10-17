using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.EntityFrameworkCore.Infrastructure;

#nullable disable

namespace DuoDesktop.Cloud.Data.Migrations;

[DbContext(typeof(DuoCloudDbContext))]
[Migration("20261017130000_TaskInstructions")]
public partial class TaskInstructions : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<string>(
            name: "Instructions",
            table: "tasks",
            type: "character varying(20000)",
            maxLength: 20000,
            nullable: false,
            defaultValue: "");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropColumn(name: "Instructions", table: "tasks");
    }
}
