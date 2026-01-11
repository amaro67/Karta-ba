using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Karta.WebAPI.Migrations
{
    /// <inheritdoc />
    public partial class AddUserDailyEventView : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "UserDailyEventViews",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    Category = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    ViewCount = table.Column<int>(type: "int", nullable: false),
                    Date = table.Column<DateTime>(type: "datetime2", nullable: false),
                    EmailSentToday = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    EmailSentAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserDailyEventViews", x => x.Id);
                    table.ForeignKey(
                        name: "FK_UserDailyEventViews_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_UserDailyEventViews_Category",
                table: "UserDailyEventViews",
                column: "Category");

            migrationBuilder.CreateIndex(
                name: "IX_UserDailyEventViews_Date",
                table: "UserDailyEventViews",
                column: "Date");

            migrationBuilder.CreateIndex(
                name: "IX_UserDailyEventViews_UserId_Category_Date",
                table: "UserDailyEventViews",
                columns: new[] { "UserId", "Category", "Date" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "UserDailyEventViews");
        }
    }
}
