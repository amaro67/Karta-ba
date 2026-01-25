using Karta.Service.Services;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Karta.WebAPI.Services
{
    public class RabbitMQInitializationService : BackgroundService
    {
        private readonly IRabbitMQService _rabbitMQService;
        private readonly ILogger<RabbitMQInitializationService> _logger;
        private const int InitialDelayMs = 10000; // Wait 10 seconds for RabbitMQ to be ready
        private const int MaxRetries = 5;
        private const int RetryDelayMs = 5000;

        public RabbitMQInitializationService(
            IRabbitMQService rabbitMQService,
            ILogger<RabbitMQInitializationService> logger)
        {
            _rabbitMQService = rabbitMQService;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("RabbitMQ initialization service starting...");
            _logger.LogInformation("Waiting {DelayMs}ms for RabbitMQ to be ready...", InitialDelayMs);

            await Task.Delay(InitialDelayMs, stoppingToken);

            for (int attempt = 1; attempt <= MaxRetries; attempt++)
            {
                try
                {
                    _logger.LogInformation("Attempt {Attempt}/{MaxRetries} to connect to RabbitMQ...", attempt, MaxRetries);

                    _rabbitMQService.Initialize();

                    if (_rabbitMQService.IsConnected())
                    {
                        _logger.LogInformation("RabbitMQ connection established successfully on attempt {Attempt}", attempt);
                        return;
                    }
                    else
                    {
                        _logger.LogWarning("RabbitMQ Initialize() completed but IsConnected() returned false");
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Attempt {Attempt} to connect to RabbitMQ failed: {Message}", attempt, ex.Message);
                }

                if (attempt < MaxRetries)
                {
                    _logger.LogInformation("Waiting {DelayMs}ms before retry...", RetryDelayMs);
                    await Task.Delay(RetryDelayMs, stoppingToken);
                }
            }

            _logger.LogError("Failed to connect to RabbitMQ after {MaxRetries} attempts. Email functionality will not work.", MaxRetries);
        }
    }
}
