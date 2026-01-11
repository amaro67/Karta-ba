using Karta.Model;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using System.Linq;
namespace Karta.WebAPI.Services
{
    public class DatabaseInitializationService : BackgroundService
    {
        private readonly IServiceProvider _serviceProvider;
        private readonly ILogger<DatabaseInitializationService> _logger;
        private const int MaxRetries = 5;
        private const int InitialDelayMs = 5000;
        public DatabaseInitializationService(
            IServiceProvider serviceProvider,
            ILogger<DatabaseInitializationService> logger)
        {
            _serviceProvider = serviceProvider;
            _logger = logger;
        }
        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("Database initialization service starting...");
            _logger.LogInformation("Waiting {DelayMs}ms for database server to be ready...", InitialDelayMs);
            await Task.Delay(InitialDelayMs, stoppingToken);
            try
            {
                using var scope = _serviceProvider.CreateScope();
                var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
                _logger.LogInformation("Applying database migrations...");
                await ApplyMigrationsWithRetryAsync(context, stoppingToken);
                _logger.LogInformation("Database migrations applied successfully.");
                _logger.LogInformation("Initializing core roles...");
                await RoleManagementService.InitializeCoreRoles(scope.ServiceProvider);
                _logger.LogInformation("Core roles initialized.");
                _logger.LogInformation("Seeding admin user...");
                await SeedDataService.SeedAdminUser(scope.ServiceProvider);
                _logger.LogInformation("Admin user seeding completed.");
                _logger.LogInformation("Seeding all data...");
                await SeedDataService.SeedAllData(scope.ServiceProvider);
                _logger.LogInformation("All data seeding completed.");
                _logger.LogInformation("Database initialization completed successfully.");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during database initialization: {Message}", ex.Message);
                _logger.LogError("Stack trace: {StackTrace}", ex.StackTrace);
            }
        }
        private async Task ApplyMigrationsWithRetryAsync(ApplicationDbContext context, CancellationToken stoppingToken)
        {
            int attempt = 0;
            while (attempt < MaxRetries)
            {
                try
                {
                    attempt++;
                    _logger.LogInformation("Attempt {Attempt}/{MaxRetries} to apply database migrations...", attempt, MaxRetries);
                    bool databaseExists = false;
                    try
                    {
                        databaseExists = await context.Database.CanConnectAsync(stoppingToken);
                        _logger.LogInformation("Database connection check: CanConnect={CanConnect}", databaseExists);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogInformation("Database connection check failed (database may not exist): {Message}", ex.Message);
                        databaseExists = false;
                    }
                    if (!databaseExists)
                    {
                        _logger.LogInformation("Database does not exist. MigrateAsync() will create it...");
                    }
                    await context.Database.MigrateAsync(stoppingToken);
                    _logger.LogInformation("Database migrations applied successfully on attempt {Attempt}", attempt);
                    try
                    {
                        var pendingMigrations = await context.Database.GetPendingMigrationsAsync(stoppingToken);
                        var pendingMigrationsList = pendingMigrations.ToList();
                        if (pendingMigrationsList.Any())
                        {
                            _logger.LogInformation("Applied {Count} migration(s): {Migrations}", 
                                pendingMigrationsList.Count, string.Join(", ", pendingMigrationsList));
                        }
                        else
                        {
                            _logger.LogInformation("No pending migrations. Database is up to date.");
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning("Could not check pending migrations: {Message}", ex.Message);
                    }
                    var canConnectAfter = await context.Database.CanConnectAsync(stoppingToken);
                    if (canConnectAfter)
                    {
                        _logger.LogInformation("Database connection verified after migrations on attempt {Attempt}", attempt);
                        return;
                    }
                    else
                    {
                        throw new InvalidOperationException("Database connection failed after migrations");
                    }
                }
                catch (Exception ex) when (attempt < MaxRetries)
                {
                    var delayMs = (int)(InitialDelayMs * Math.Pow(2, attempt - 1));
                    _logger.LogWarning(ex, "Attempt {Attempt} failed: {Message}. Retrying in {DelayMs}ms...", 
                        attempt, ex.Message, delayMs);
                    await Task.Delay(delayMs, stoppingToken);
                }
            }
            throw new InvalidOperationException($"Failed to apply database migrations after {MaxRetries} attempts");
        }
    }
}