using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Karta.WebAPI.Migrations
{
    /// <inheritdoc />
    public partial class UpdateUserDailyEventViewCategoryId : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_UserDailyEventViews_Category",
                table: "UserDailyEventViews");

            migrationBuilder.DropIndex(
                name: "IX_UserDailyEventViews_UserId_Category_Date",
                table: "UserDailyEventViews");

            migrationBuilder.AddColumn<Guid>(
                name: "CategoryId",
                table: "UserDailyEventViews",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_UserDailyEventViews_CategoryId",
                table: "UserDailyEventViews",
                column: "CategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_UserDailyEventViews_UserId_Category_Date",
                table: "UserDailyEventViews",
                columns: new[] { "UserId", "Category", "Date" },
                filter: "[CategoryId] IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_UserDailyEventViews_UserId_CategoryId_Date",
                table: "UserDailyEventViews",
                columns: new[] { "UserId", "CategoryId", "Date" },
                unique: true,
                filter: "[CategoryId] IS NOT NULL");

            migrationBuilder.AddForeignKey(
                name: "FK_UserDailyEventViews_Categories_CategoryId",
                table: "UserDailyEventViews",
                column: "CategoryId",
                principalTable: "Categories",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_UserDailyEventViews_Categories_CategoryId",
                table: "UserDailyEventViews");

            migrationBuilder.DropIndex(
                name: "IX_UserDailyEventViews_CategoryId",
                table: "UserDailyEventViews");

            migrationBuilder.DropIndex(
                name: "IX_UserDailyEventViews_UserId_Category_Date",
                table: "UserDailyEventViews");

            migrationBuilder.DropIndex(
                name: "IX_UserDailyEventViews_UserId_CategoryId_Date",
                table: "UserDailyEventViews");

            migrationBuilder.DropColumn(
                name: "CategoryId",
                table: "UserDailyEventViews");

            migrationBuilder.CreateIndex(
                name: "IX_UserDailyEventViews_Category",
                table: "UserDailyEventViews",
                column: "Category");

            migrationBuilder.CreateIndex(
                name: "IX_UserDailyEventViews_UserId_Category_Date",
                table: "UserDailyEventViews",
                columns: new[] { "UserId", "Category", "Date" },
                unique: true);
        }
    }
}
