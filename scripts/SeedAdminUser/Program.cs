using Karta.Model;
using Karta.WebAPI.Services;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

var connectionString = Environment.GetEnvironmentVariable("CONNECTION_STRING") 
    ?? "Server=localhost,1433;Database=KartaDb;User Id=sa;Password=KartaPassword2024!;TrustServerCertificate=true;MultipleActiveResultSets=true;";

var services = new ServiceCollection();

// Add DbContext
services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(connectionString, b => b.MigrationsAssembly("Karta.WebAPI")));

// Add Identity
services.AddIdentity<ApplicationUser, ApplicationRole>(options =>
{
    options.Password.RequireDigit = true;
    options.Password.RequireLowercase = true;
    options.Password.RequireNonAlphanumeric = true;
    options.Password.RequireUppercase = true;
    options.Password.RequiredLength = 12;
    options.Password.RequiredUniqueChars = 3;
})
.AddEntityFrameworkStores<ApplicationDbContext>()
.AddDefaultTokenProviders();

// Add logging
services.AddLogging(builder => 
{
    builder.AddConsole();
    builder.SetMinimumLevel(LogLevel.Information);
});

var serviceProvider = services.BuildServiceProvider();

try
{
    Console.WriteLine("Initializing core roles...");
    await RoleManagementService.InitializeCoreRoles(serviceProvider);
    Console.WriteLine("Roles initialized.");

    Console.WriteLine("Seeding admin user...");
    await SeedDataService.SeedAdminUser(serviceProvider);
    Console.WriteLine("Seed completed successfully!");
}
catch (Exception ex)
{
    Console.WriteLine($"Error: {ex.Message}");
    Console.WriteLine($"Stack trace: {ex.StackTrace}");
    Environment.Exit(1);
}

