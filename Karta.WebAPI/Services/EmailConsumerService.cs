using Karta.Service.Services;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
namespace Karta.WebAPI.Services
{
    public class EmailConsumerService : BackgroundService
    {
        private readonly IRabbitMQService _rabbitMQService;
        private readonly ILogger<EmailConsumerService> _logger;
        public EmailConsumerService(
            IRabbitMQService rabbitMQService,
            ILogger<EmailConsumerService> logger)
        {
            _rabbitMQService = rabbitMQService;
            _logger = logger;
        }
        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("Email Consumer Service starting...");
            try
            {
                if (_rabbitMQService.IsConnected())
                {
                    _rabbitMQService.StartConsuming();
                    _logger.LogInformation("Email Consumer Service started successfully");
                    while (!stoppingToken.IsCancellationRequested)
                    {
                        await Task.Delay(1000, stoppingToken);
                    }
                }
                else
                {
                    _logger.LogInformation("RabbitMQ not connected, Email Consumer Service will not start");
                    while (!stoppingToken.IsCancellationRequested)
                    {
                        await Task.Delay(5000, stoppingToken);
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in Email Consumer Service");
            }
            finally
            {
                _rabbitMQService.StopConsuming();
                _logger.LogInformation("Email Consumer Service stopped");
            }
        }
    }
}