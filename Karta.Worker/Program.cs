using Karta.Service.Services;
using Karta.Worker;
using Serilog;

var builder = Host.CreateApplicationBuilder(args);

builder.Configuration.AddEnvironmentVariables();

Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .Enrich.FromLogContext()
    .WriteTo.Console(outputTemplate: "[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}")
    .CreateLogger();

builder.Services.AddSerilog();

builder.Services.AddScoped<IEmailService, EmailService>();
builder.Services.AddSingleton<IRabbitMQService>(provider => new NullRabbitMQService());

builder.Services.AddHostedService<EmailWorker>();

var host = builder.Build();

Log.Information("Starting Karta Email Worker");

try
{
    host.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "Email Worker terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}
