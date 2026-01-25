using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Karta.WebAPI.Migrations
{
    /// <inheritdoc />
    public partial class AddCategoriesVenuesFavorites : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "CategoryId",
                table: "Events",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "VenueId",
                table: "Events",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "Categories",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Slug = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    IconUrl = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    DisplayOrder = table.Column<int>(type: "int", nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false, defaultValue: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Categories", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "UserFavorites",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    EventId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserFavorites", x => x.Id);
                    table.ForeignKey(
                        name: "FK_UserFavorites_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_UserFavorites_Events_EventId",
                        column: x => x.EventId,
                        principalTable: "Events",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "Venues",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Address = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: false),
                    City = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Country = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Capacity = table.Column<int>(type: "int", nullable: true),
                    Latitude = table.Column<double>(type: "float", nullable: true),
                    Longitude = table.Column<double>(type: "float", nullable: true),
                    CreatedBy = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Venues", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Events_CategoryId",
                table: "Events",
                column: "CategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_Events_VenueId",
                table: "Events",
                column: "VenueId");

            migrationBuilder.CreateIndex(
                name: "IX_Categories_DisplayOrder",
                table: "Categories",
                column: "DisplayOrder");

            migrationBuilder.CreateIndex(
                name: "IX_Categories_IsActive",
                table: "Categories",
                column: "IsActive");

            migrationBuilder.CreateIndex(
                name: "IX_Categories_Slug",
                table: "Categories",
                column: "Slug",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_UserFavorites_EventId",
                table: "UserFavorites",
                column: "EventId");

            migrationBuilder.CreateIndex(
                name: "IX_UserFavorites_UserId",
                table: "UserFavorites",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_UserFavorites_UserId_EventId",
                table: "UserFavorites",
                columns: new[] { "UserId", "EventId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Venues_City",
                table: "Venues",
                column: "City");

            migrationBuilder.CreateIndex(
                name: "IX_Venues_City_Country",
                table: "Venues",
                columns: new[] { "City", "Country" });

            migrationBuilder.CreateIndex(
                name: "IX_Venues_Name",
                table: "Venues",
                column: "Name");

            migrationBuilder.AddForeignKey(
                name: "FK_Events_Categories_CategoryId",
                table: "Events",
                column: "CategoryId",
                principalTable: "Categories",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_Events_Venues_VenueId",
                table: "Events",
                column: "VenueId",
                principalTable: "Venues",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            // ============ SEED DATA ============

            // Seed Categories from distinct Event.Category values
            migrationBuilder.Sql(@"
                INSERT INTO Categories (Id, Name, Slug, Description, IconUrl, DisplayOrder, IsActive, CreatedAt)
                SELECT
                    NEWID(),
                    Category,
                    LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(Category, ' ', '-'), 'š', 's'), 'č', 'c'), 'ć', 'c'), 'ž', 'z')),
                    NULL,
                    NULL,
                    ROW_NUMBER() OVER (ORDER BY Category),
                    1,
                    GETUTCDATE()
                FROM (SELECT DISTINCT Category FROM Events WHERE Category IS NOT NULL AND Category <> '') AS DistinctCategories
            ");

            // Update Events with matching CategoryId
            migrationBuilder.Sql(@"
                UPDATE e
                SET e.CategoryId = c.Id
                FROM Events e
                INNER JOIN Categories c ON e.Category = c.Name
                WHERE e.Category IS NOT NULL AND e.Category <> ''
            ");

            // Seed Venues from distinct (Venue, City, Country) combinations
            migrationBuilder.Sql(@"
                INSERT INTO Venues (Id, Name, Address, City, Country, Capacity, Latitude, Longitude, CreatedBy, CreatedAt)
                SELECT
                    NEWID(),
                    Venue,
                    Venue,
                    City,
                    Country,
                    NULL,
                    NULL,
                    NULL,
                    CreatedBy,
                    GETUTCDATE()
                FROM (
                    SELECT DISTINCT Venue, City, Country, MIN(CreatedBy) as CreatedBy
                    FROM Events
                    WHERE Venue IS NOT NULL AND Venue <> ''
                      AND City IS NOT NULL AND City <> ''
                      AND Country IS NOT NULL AND Country <> ''
                    GROUP BY Venue, City, Country
                ) AS DistinctVenues
            ");

            // Update Events with matching VenueId
            migrationBuilder.Sql(@"
                UPDATE e
                SET e.VenueId = v.Id
                FROM Events e
                INNER JOIN Venues v ON e.Venue = v.Name AND e.City = v.City AND e.Country = v.Country
                WHERE e.Venue IS NOT NULL AND e.Venue <> ''
            ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Events_Categories_CategoryId",
                table: "Events");

            migrationBuilder.DropForeignKey(
                name: "FK_Events_Venues_VenueId",
                table: "Events");

            migrationBuilder.DropTable(
                name: "Categories");

            migrationBuilder.DropTable(
                name: "UserFavorites");

            migrationBuilder.DropTable(
                name: "Venues");

            migrationBuilder.DropIndex(
                name: "IX_Events_CategoryId",
                table: "Events");

            migrationBuilder.DropIndex(
                name: "IX_Events_VenueId",
                table: "Events");

            migrationBuilder.DropColumn(
                name: "CategoryId",
                table: "Events");

            migrationBuilder.DropColumn(
                name: "VenueId",
                table: "Events");
        }
    }
}
