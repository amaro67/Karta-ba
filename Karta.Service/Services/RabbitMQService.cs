using System;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using RabbitMQ.Client;
using Karta.Service.DTO;
namespace Karta.Service.Services
{
    public interface IRabbitMQService
    {
        void PublishEmailMessage(EmailMessage message);
        void StartConsuming();
        void StopConsuming();
        bool IsConnected();
    }
    public class NullRabbitMQService : IRabbitMQService
    {
        public void PublishEmailMessage(EmailMessage message)
        {
        }
        public void StartConsuming()
        {
        }
        public void StopConsuming()
        {
        }
        public bool IsConnected()
        {
            return false;
        }
    }
    public class RabbitMQService : IRabbitMQService, IDisposable
    {
        private IConnection? _connection;
        private IChannel? _channel;
        private readonly ILogger<RabbitMQService> _logger;
        private readonly IConfiguration _configuration;
        private readonly string _queueName = "email_queue";
        private readonly string _exchangeName = "email_exchange";
        private readonly object _initLock = new();
        private bool _initialized;
        private bool _initializationFailed;
        private Exception? _lastError;

        public RabbitMQService(
            IConfiguration configuration,
            ILogger<RabbitMQService> logger)
        {
            _configuration = configuration;
            _logger = logger;
        }

        private void EnsureInitialized()
        {
            if (_initialized) return;
            if (_initializationFailed)
            {
                _logger.LogWarning("RabbitMQ initialization previously failed: {Error}", _lastError?.Message);
                return;
            }

            lock (_initLock)
            {
                if (_initialized || _initializationFailed) return;

                try
                {
                    var hostName = _configuration["RabbitMQ:HostName"] ?? "localhost";
                    var port = _configuration.GetValue<int>("RabbitMQ:Port", 5672);
                    var userName = _configuration["RabbitMQ:UserName"] ?? "guest";
                    var password = _configuration["RabbitMQ:Password"] ?? "guest";

                    _logger.LogInformation("Connecting to RabbitMQ at {Host}:{Port}",
                        hostName, port);

                    var factory = new ConnectionFactory
                    {
                        HostName = hostName,
                        Port = port,
                        UserName = userName,
                        Password = password
                    };

                    _connection = factory.CreateConnectionAsync().GetAwaiter().GetResult();
                    _channel = _connection.CreateChannelAsync().GetAwaiter().GetResult();

                    _channel.ExchangeDeclareAsync(_exchangeName, ExchangeType.Direct, durable: true)
                        .GetAwaiter().GetResult();
                    _channel.QueueDeclareAsync(_queueName, durable: true, exclusive: false, autoDelete: false)
                        .GetAwaiter().GetResult();
                    _channel.QueueBindAsync(_queueName, _exchangeName, "email")
                        .GetAwaiter().GetResult();

                    _initialized = true;
                    _logger.LogInformation("RabbitMQ connection established successfully");
                }
                catch (Exception ex)
                {
                    _initializationFailed = true;
                    _lastError = ex;
                    _logger.LogError(ex, "Failed to connect to RabbitMQ at {Host}:{Port}",
                        _configuration["RabbitMQ:HostName"], _configuration.GetValue<int>("RabbitMQ:Port", 5672));
                }
            }
        }

        public bool IsConnected()
        {
            EnsureInitialized();
            return _initialized && _connection?.IsOpen == true && _channel?.IsOpen == true;
        }

        public void PublishEmailMessage(EmailMessage message)
        {
            if (!IsConnected())
            {
                _logger.LogWarning("RabbitMQ not connected, cannot publish message for {Email}", message.ToEmail);
                return;
            }
            try
            {
                var json = JsonSerializer.Serialize(message);
                var body = Encoding.UTF8.GetBytes(json);
                var properties = new BasicProperties
                {
                    Persistent = true,
                    MessageId = Guid.NewGuid().ToString(),
                    Timestamp = new AmqpTimestamp(DateTimeOffset.UtcNow.ToUnixTimeSeconds())
                };
                _channel!.BasicPublishAsync(
                    exchange: _exchangeName,
                    routingKey: "email",
                    mandatory: false,
                    basicProperties: properties,
                    body: body
                ).GetAwaiter().GetResult();
                _logger.LogInformation("Email message published to RabbitMQ for {Email}", message.ToEmail);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to publish email message to RabbitMQ for {Email}", message.ToEmail);
                throw;
            }
        }

        public void StartConsuming()
        {
            _logger.LogInformation("StartConsuming called - this is now handled by the separate worker container");
        }

        public void StopConsuming()
        {
            try
            {
                _channel?.CloseAsync().GetAwaiter().GetResult();
                _connection?.CloseAsync().GetAwaiter().GetResult();
                _logger.LogInformation("RabbitMQ connection closed");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error closing RabbitMQ connection");
            }
        }

        public void Dispose()
        {
            StopConsuming();
            _channel?.Dispose();
            _connection?.Dispose();
        }
    }
}
