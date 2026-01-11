using Karta.Model;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
namespace Karta.WebAPI.Services
{
    public class DailyResetService : BackgroundService
    {
        private readonly IServiceProvider _serviceProvider;
        private readonly ILogger<DailyResetService> _logger;
        public DailyResetService(
            IServiceProvider serviceProvider,
            ILogger<DailyResetService> logger)
        {
            _serviceProvider = serviceProvider;
            _logger = logger;
        }
        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("Daily Reset Service started");
            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    var now = DateTime.UtcNow;
                    var nextMidnight = now.Date.AddDays(1);
                    var delay = nextMidnight - now;
                    _logger.LogInformation($"Next reset scheduled at: {nextMidnight:yyyy-MM-dd HH:mm:ss} UTC (in {delay.TotalHours:F1} hours)");
                    await Task.Delay(delay, stoppingToken);
                    if (!stoppingToken.IsCancellationRequested)
                    {
                        await ResetDailyViews();
                    }
                }
                catch (OperationCanceledException)
                {
                    _logger.LogInformation("Daily Reset Service is stopping due to cancellation");
                    break;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error in Daily Reset Service main loop");
                    await Task.Delay(TimeSpan.FromMinutes(5), stoppingToken);
                }
            }
            _logger.LogInformation("Daily Reset Service stopped");
        }
        private async Task ResetDailyViews()
        {
            using var scope = _serviceProvider.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            try
            {
                var today = DateTime.UtcNow.Date;
                var yesterday = today.AddDays(-1);
                var oldRecords = await context.UserDailyEventViews
                    .Where(x => x.Date < yesterday)
                    .ToListAsync();
                if (oldRecords.Any())
                {
                    context.UserDailyEventViews.RemoveRange(oldRecords);
                    await context.SaveChangesAsync();
                    _logger.LogInformation($"🔄 Daily reset: Deleted {oldRecords.Count} old view records from before {yesterday:yyyy-MM-dd}");
                }
                else
                {
                    _logger.LogInformation($"🔄 Daily reset: No old records to delete (checked before {yesterday:yyyy-MM-dd})");
                }
                var todayRecords = await context.UserDailyEventViews
                    .Where(x => x.Date == today)
                    .GroupBy(x => x.Category)
                    .Select(g => new { Category = g.Key, Count = g.Count(), TotalViews = g.Sum(x => x.ViewCount) })
                    .ToListAsync();
                if (todayRecords.Any())
                {
                    _logger.LogInformation($"📊 Today's tracking stats:");
                    foreach (var stat in todayRecords)
                    {
                        _logger.LogInformation($"   - {stat.Category}: {stat.Count} users, {stat.TotalViews} total views");
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during daily reset");
            }
        }
    }
}