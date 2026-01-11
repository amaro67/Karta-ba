using System;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;
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
        private readonly IConnection? _connection;
        private readonly IModel? _channel;
        private readonly ILogger<RabbitMQService> _logger;
        private readonly IConfiguration _configuration;
        private readonly string _queueName = "email_queue";
        private readonly string _exchangeName = "email_exchange";
        private readonly bool _isEnabled;
        public RabbitMQService(
            IConfiguration configuration,
            ILogger<RabbitMQService> logger)
        {
            _configuration = configuration;
            _logger = logger;
            _isEnabled = _configuration.GetValue<bool>("Email:UseRabbitMQ", false);
            if (!_isEnabled)
            {
                _logger.LogInformation("RabbitMQ is disabled in configuration");
                return;
            }
            try
            {
                var factory = new ConnectionFactory
                {
                    HostName = _configuration["RabbitMQ:HostName"] ?? "localhost",
                    Port = _configuration.GetValue<int>("RabbitMQ:Port", 5672),
                    UserName = _configuration["RabbitMQ:UserName"] ?? "guest",
                    Password = _configuration["RabbitMQ:Password"] ?? "guest"
                };
                _connection = factory.CreateConnection();
                _channel = _connection.CreateModel();
                _channel.ExchangeDeclare(_exchangeName, ExchangeType.Direct, durable: true);
                _channel.QueueDeclare(_queueName, durable: true, exclusive: false, autoDelete: false);
                _channel.QueueBind(_queueName, _exchangeName, "email");
                _logger.LogInformation("RabbitMQ connection established successfully");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to connect to RabbitMQ. Will fallback to direct SMTP.");
            }
        }
        public bool IsConnected()
        {
            return _isEnabled && _connection?.IsOpen == true && _channel?.IsOpen == true;
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
                var properties = _channel!.CreateBasicProperties();
                properties.Persistent = true;
                properties.MessageId = Guid.NewGuid().ToString();
                properties.Timestamp = new AmqpTimestamp(DateTimeOffset.UtcNow.ToUnixTimeSeconds());
                _channel.BasicPublish(
                    exchange: _exchangeName,
                    routingKey: "email",
                    basicProperties: properties,
                    body: body
                );
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
            if (!IsConnected())
            {
                _logger.LogWarning("RabbitMQ not connected, cannot start consuming");
                return;
            }
            var consumer = new EventingBasicConsumer(_channel);
            consumer.Received += async (model, ea) =>
            {
                try
                {
                    var body = ea.Body;
                    var json = Encoding.UTF8.GetString(body);
                    var message = JsonSerializer.Deserialize<EmailMessage>(json);
                    if (message != null)
                    {
                        _logger.LogInformation("Processing email from RabbitMQ for {Email}", message.ToEmail);
                        _logger.LogInformation("Email message received from RabbitMQ: {Email} - {Subject}", message.ToEmail, message.Subject);
                        _channel!.BasicAck(ea.DeliveryTag, false);
                        _logger.LogInformation("Email processed successfully from RabbitMQ to {Email}", message.ToEmail);
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error processing email message from RabbitMQ");
                    _channel!.BasicNack(ea.DeliveryTag, false, false);
                }
            };
            _channel!.BasicConsume(
                queue: _queueName,
                autoAck: false,
                consumer: consumer
            );
            _logger.LogInformation("Started consuming email messages from RabbitMQ");
        }
        public void StopConsuming()
        {
            try
            {
                _channel?.Close();
                _connection?.Close();
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