using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Karta.Model;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Configuration;
namespace Karta.WebAPI.Services
{
    public class EventArchiveService : BackgroundService
    {
        private readonly IServiceProvider _serviceProvider;
        private readonly ILogger<EventArchiveService> _logger;
        private readonly TimeSpan _checkInterval;
        public EventArchiveService(
            IServiceProvider serviceProvider, 
            ILogger<EventArchiveService> logger,
            IConfiguration configuration)
        {
            _serviceProvider = serviceProvider;
            _logger = logger;
            var checkIntervalMinutes = configuration.GetValue<int>("EventArchive:CheckIntervalMinutes", 60);
            _checkInterval = TimeSpan.FromMinutes(checkIntervalMinutes);
        }
        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("EventArchiveService started. Check interval: {Interval}", _checkInterval);
            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    await ArchiveExpiredEvents(stoppingToken);
                }
                catch (OperationCanceledException)
                {
                    _logger.LogInformation("EventArchiveService is stopping");
                    break;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error occurred during event archiving");
                }
                try
                {
                    await Task.Delay(_checkInterval, stoppingToken);
                }
                catch (OperationCanceledException)
                {
                    _logger.LogInformation("EventArchiveService is stopping");
                    break;
                }
            }
            _logger.LogInformation("EventArchiveService stopped");
        }
        private async Task ArchiveExpiredEvents(CancellationToken cancellationToken)
        {
            using var scope = _serviceProvider.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var now = DateTimeOffset.UtcNow;
            var nowDateTime = now.DateTime;
            _logger.LogDebug("Looking for events that should be archived (current time: {Now})", now);
            var eventsToArchive = await context.Events
                .Where(e => e.Status != "Archived" && e.Status != "Cancelled" &&
                           ((e.EndsAt.HasValue && e.EndsAt.Value < now) || 
                            (!e.EndsAt.HasValue && e.StartsAt < now)))
                .ToListAsync(cancellationToken);
            if (eventsToArchive.Count == 0)
            {
                _logger.LogDebug("No events to archive");
                return;
            }
            _logger.LogInformation("Found {Count} event(s) to archive", eventsToArchive.Count);
            foreach (var eventEntity in eventsToArchive)
            {
                var endDate = eventEntity.EndsAt?.ToString() ?? eventEntity.StartsAt.ToString();
                eventEntity.Status = "Archived";
                _logger.LogInformation("Archiving event {EventId} ({Title}) - End date: {EndDate}", 
                    eventEntity.Id, eventEntity.Title, endDate);
            }
            var archivedCount = await context.SaveChangesAsync(cancellationToken);
            _logger.LogInformation("Successfully archived {Count} event(s)", archivedCount);
        }
    }
}