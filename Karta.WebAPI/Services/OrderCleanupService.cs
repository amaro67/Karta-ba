using System;
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
    public class OrderCleanupService : BackgroundService
    {
        private readonly IServiceProvider _serviceProvider;
        private readonly ILogger<OrderCleanupService> _logger;
        private readonly TimeSpan _cleanupInterval;
        private readonly TimeSpan _orderExpirationThreshold;
        public OrderCleanupService(
            IServiceProvider serviceProvider, 
            ILogger<OrderCleanupService> logger,
            IConfiguration configuration)
        {
            _serviceProvider = serviceProvider;
            _logger = logger;
            var cleanupIntervalMinutes = configuration.GetValue<int>("OrderCleanup:CleanupIntervalMinutes", 60);
            var orderExpirationHours = configuration.GetValue<int>("OrderCleanup:OrderExpirationHours", 24);
            _cleanupInterval = TimeSpan.FromMinutes(cleanupIntervalMinutes);
            _orderExpirationThreshold = TimeSpan.FromHours(orderExpirationHours);
        }
        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("OrderCleanupService started. Cleanup interval: {Interval}, Expiration threshold: {Threshold}", 
                _cleanupInterval, _orderExpirationThreshold);
            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    await CleanupExpiredOrders(stoppingToken);
                }
                catch (OperationCanceledException)
                {
                    _logger.LogInformation("OrderCleanupService is stopping");
                    break;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error occurred during order cleanup");
                }
                try
                {
                    await Task.Delay(_cleanupInterval, stoppingToken);
                }
                catch (OperationCanceledException)
                {
                    _logger.LogInformation("OrderCleanupService is stopping");
                    break;
                }
            }
            _logger.LogInformation("OrderCleanupService stopped");
        }
        private async Task CleanupExpiredOrders(CancellationToken cancellationToken)
        {
            using var scope = _serviceProvider.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var cutoffTime = DateTime.UtcNow - _orderExpirationThreshold;
            _logger.LogDebug("Looking for Pending orders older than {CutoffTime}", cutoffTime);
            var expiredOrders = await context.Orders
                .Where(o => o.Status == "Pending" && o.CreatedAt < cutoffTime)
                .ToListAsync(cancellationToken);
            if (expiredOrders.Count == 0)
            {
                _logger.LogDebug("No expired orders found");
                return;
            }
            _logger.LogInformation("Found {Count} expired orders to cleanup", expiredOrders.Count);
            foreach (var order in expiredOrders)
            {
                order.Status = "Expired";
                _logger.LogDebug("Marking order {OrderId} as Expired (created: {CreatedAt})", 
                    order.Id, order.CreatedAt);
            }
            var changesCount = await context.SaveChangesAsync(cancellationToken);
            _logger.LogInformation("Successfully marked {ChangesCount} orders as Expired", changesCount);
        }
    }
}