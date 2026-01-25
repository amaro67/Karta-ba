using System.Text;
using System.Text.Json;
using Karta.Service.DTO;
using Karta.Service.Services;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

namespace Karta.Worker;

public class EmailWorker : BackgroundService
{
    private readonly ILogger<EmailWorker> _logger;
    private readonly IConfiguration _configuration;
    private readonly IServiceProvider _serviceProvider;
    private IConnection? _connection;
    private IChannel? _channel;
    private const string QueueName = "email_queue";
    private const string ExchangeName = "email_exchange";
    private const int MaxRetryAttempts = 3;
    private const int InitialRetryDelayMs = 1000;

    public EmailWorker(
        ILogger<EmailWorker> logger,
        IConfiguration configuration,
        IServiceProvider serviceProvider)
    {
        _logger = logger;
        _configuration = configuration;
        _serviceProvider = serviceProvider;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("Email Worker starting...");

        await ConnectWithRetryAsync(stoppingToken);

        if (_channel == null || !_channel.IsOpen)
        {
            _logger.LogError("Failed to connect to RabbitMQ. Worker cannot start.");
            return;
        }

        await SetupConsumerAsync(stoppingToken);

        _logger.LogInformation("Email Worker started successfully. Waiting for messages...");

        while (!stoppingToken.IsCancellationRequested)
        {
            if (_connection == null || !_connection.IsOpen)
            {
                _logger.LogWarning("RabbitMQ connection lost. Attempting to reconnect...");
                await ConnectWithRetryAsync(stoppingToken);
                if (_channel != null && _channel.IsOpen)
                {
                    await SetupConsumerAsync(stoppingToken);
                }
            }
            await Task.Delay(5000, stoppingToken);
        }
    }

    private async Task ConnectWithRetryAsync(CancellationToken stoppingToken)
    {
        var hostName = Environment.GetEnvironmentVariable("RABBITMQ_HOSTNAME")
            ?? _configuration["RabbitMQ:HostName"]
            ?? "localhost";
        var portStr = Environment.GetEnvironmentVariable("RABBITMQ_PORT");
        var port = !string.IsNullOrEmpty(portStr) && int.TryParse(portStr, out var p) ? p : _configuration.GetValue<int>("RabbitMQ:Port", 5672);
        var userName = Environment.GetEnvironmentVariable("RABBITMQ_USERNAME")
            ?? _configuration["RabbitMQ:UserName"]
            ?? "guest";
        var password = Environment.GetEnvironmentVariable("RABBITMQ_PASSWORD")
            ?? _configuration["RabbitMQ:Password"]
            ?? "guest";

        var factory = new ConnectionFactory
        {
            HostName = hostName,
            Port = port,
            UserName = userName,
            Password = password
        };

        var retryCount = 0;
        var maxRetries = 10;
        var delay = 2000;

        while (!stoppingToken.IsCancellationRequested && retryCount < maxRetries)
        {
            try
            {
                _logger.LogInformation("Attempting to connect to RabbitMQ at {Host}:{Port} (attempt {Attempt}/{MaxAttempts})",
                    hostName, port, retryCount + 1, maxRetries);

                _connection = await factory.CreateConnectionAsync(stoppingToken);
                _channel = await _connection.CreateChannelAsync(cancellationToken: stoppingToken);

                await _channel.ExchangeDeclareAsync(ExchangeName, ExchangeType.Direct, durable: true, cancellationToken: stoppingToken);
                await _channel.QueueDeclareAsync(QueueName, durable: true, exclusive: false, autoDelete: false, cancellationToken: stoppingToken);
                await _channel.QueueBindAsync(QueueName, ExchangeName, "email", cancellationToken: stoppingToken);

                _logger.LogInformation("Successfully connected to RabbitMQ");
                return;
            }
            catch (Exception ex)
            {
                retryCount++;
                _logger.LogWarning(ex, "Failed to connect to RabbitMQ. Retrying in {Delay}ms...", delay);
                await Task.Delay(delay, stoppingToken);
                delay = Math.Min(delay * 2, 30000);
            }
        }

        _logger.LogError("Failed to connect to RabbitMQ after {MaxRetries} attempts", maxRetries);
    }

    private async Task SetupConsumerAsync(CancellationToken stoppingToken)
    {
        if (_channel == null || !_channel.IsOpen)
        {
            _logger.LogWarning("Cannot setup consumer - channel is not open");
            return;
        }

        var consumer = new AsyncEventingBasicConsumer(_channel);
        consumer.ReceivedAsync += async (model, ea) =>
        {
            var body = ea.Body.ToArray();
            var json = Encoding.UTF8.GetString(body);

            try
            {
                var message = JsonSerializer.Deserialize<EmailMessage>(json);
                if (message != null)
                {
                    _logger.LogInformation("Processing email for {Email} - Subject: {Subject}",
                        message.ToEmail, message.Subject);

                    var success = await SendEmailWithRetryAsync(message, stoppingToken);

                    if (success)
                    {
                        await _channel.BasicAckAsync(ea.DeliveryTag, false, stoppingToken);
                        _logger.LogInformation("Email sent successfully to {Email}", message.ToEmail);
                    }
                    else
                    {
                        await _channel.BasicNackAsync(ea.DeliveryTag, false, false, stoppingToken);
                        _logger.LogError("Failed to send email to {Email} after all retries", message.ToEmail);
                    }
                }
                else
                {
                    _logger.LogWarning("Received null or invalid email message");
                    await _channel.BasicAckAsync(ea.DeliveryTag, false, stoppingToken);
                }
            }
            catch (JsonException ex)
            {
                _logger.LogError(ex, "Failed to deserialize email message: {Json}", json);
                await _channel.BasicAckAsync(ea.DeliveryTag, false, stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing email message");
                await _channel.BasicNackAsync(ea.DeliveryTag, false, true, stoppingToken);
            }
        };

        await _channel.BasicConsumeAsync(
            queue: QueueName,
            autoAck: false,
            consumer: consumer,
            cancellationToken: stoppingToken
        );

        _logger.LogInformation("Email consumer started on queue: {QueueName}", QueueName);
    }

    private async Task<bool> SendEmailWithRetryAsync(EmailMessage message, CancellationToken stoppingToken)
    {
        var attempt = 0;
        var delay = InitialRetryDelayMs;

        while (attempt < MaxRetryAttempts)
        {
            try
            {
                using var scope = _serviceProvider.CreateScope();
                var emailService = scope.ServiceProvider.GetRequiredService<IEmailService>();

                await emailService.SendEmailDirectAsync(
                    message.ToEmail,
                    message.Subject,
                    message.Body,
                    stoppingToken
                );

                return true;
            }
            catch (Exception ex)
            {
                attempt++;
                _logger.LogWarning(ex, "Failed to send email to {Email} (attempt {Attempt}/{MaxAttempts})",
                    message.ToEmail, attempt, MaxRetryAttempts);

                if (attempt < MaxRetryAttempts)
                {
                    await Task.Delay(delay, stoppingToken);
                    delay *= 2;
                }
            }
        }

        return false;
    }

    public override async Task StopAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("Email Worker stopping...");

        if (_channel != null && _channel.IsOpen)
        {
            await _channel.CloseAsync(stoppingToken);
        }

        if (_connection != null && _connection.IsOpen)
        {
            await _connection.CloseAsync(stoppingToken);
        }

        _logger.LogInformation("Email Worker stopped");
        await base.StopAsync(stoppingToken);
    }

    public override void Dispose()
    {
        _channel?.Dispose();
        _connection?.Dispose();
        base.Dispose();
    }
}
