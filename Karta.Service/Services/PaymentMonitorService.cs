using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Stripe;
using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Karta.Model;
using Karta.Model.Entities;
namespace Karta.Service.Services
{
    public class PaymentMonitorService : BackgroundService
    {
        private readonly IServiceProvider _serviceProvider;
        private readonly ILogger<PaymentMonitorService> _logger;
        private readonly IConfiguration _configuration;
        private readonly TimeSpan _pollInterval = TimeSpan.FromSeconds(30);
        public PaymentMonitorService(
            IServiceProvider serviceProvider,
            ILogger<PaymentMonitorService> logger,
            IConfiguration configuration)
        {
            _serviceProvider = serviceProvider;
            _logger = logger;
            _configuration = configuration;
            var envKey = Environment.GetEnvironmentVariable("STRIPE_SECRET_KEY");
            var configKey = configuration["Stripe:SecretKey"];
            var stripeSecretKey = envKey ?? configKey;
            _logger.LogInformation("PaymentMonitorService: Initializing Stripe API key. Env var present: {HasEnv}, Config present: {HasConfig}", 
                !string.IsNullOrEmpty(envKey), !string.IsNullOrEmpty(configKey));
            if (!string.IsNullOrEmpty(stripeSecretKey))
            {
                if (stripeSecretKey.Contains("${"))
                {
                    var match = System.Text.RegularExpressions.Regex.Match(stripeSecretKey, @"\$\{[^:]+:(.+)\}");
                    if (match.Success && match.Groups.Count > 1)
                    {
                        stripeSecretKey = match.Groups[1].Value;
                    }
                    else
                    {
                        var varMatch = System.Text.RegularExpressions.Regex.Match(stripeSecretKey, @"\$\{([^:}]+)");
                        if (varMatch.Success && varMatch.Groups.Count > 1)
                        {
                            var envVarName = varMatch.Groups[1].Value;
                            stripeSecretKey = Environment.GetEnvironmentVariable(envVarName) ?? stripeSecretKey;
                        }
                    }
                }
                StripeConfiguration.ApiKey = stripeSecretKey;
                _logger.LogInformation("PaymentMonitorService: Stripe API key initialized successfully. Key prefix: {KeyPrefix}", 
                    stripeSecretKey.Substring(0, Math.Min(10, stripeSecretKey.Length)));
            }
            else
            {
                _logger.LogError("PaymentMonitorService: Stripe API key not configured! Env: {Env}, Config: {Config}", 
                    envKey ?? "null", configKey ?? "null");
            }
        }
        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("💳 Payment Monitor Service pokrenuta - provjerava svake 30 sekundi");
            await Task.Delay(TimeSpan.FromSeconds(10), stoppingToken);
            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    await CheckPendingPayments(stoppingToken);
                    await Task.Delay(_pollInterval, stoppingToken);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "❌ Greška u Payment Monitor Service");
                    await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
                }
            }
            _logger.LogInformation("Payment Monitor Service zaustavljena");
        }
        private async Task CheckPendingPayments(CancellationToken stoppingToken)
        {
            using var scope = _serviceProvider.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var pendingOrdersWithPaymentIntent = await context.Orders
                .Include(o => o.Items)
                    .ThenInclude(oi => oi.Event)
                .Where(o => o.Status == "Pending"
                    && o.CreatedAt < DateTime.UtcNow.AddMinutes(-1)
                    && o.CreatedAt > DateTime.UtcNow.AddHours(-24)
                    && !string.IsNullOrEmpty(o.StripePaymentIntentId))
                .ToListAsync(stoppingToken);
            var pendingOrdersWithoutPaymentIntent = await context.Orders
                .Include(o => o.Items)
                    .ThenInclude(oi => oi.Event)
                .Where(o => o.Status == "Pending"
                    && o.CreatedAt < DateTime.UtcNow.AddMinutes(-1)
                    && o.CreatedAt > DateTime.UtcNow.AddHours(-24)
                    && string.IsNullOrEmpty(o.StripePaymentIntentId))
                .ToListAsync(stoppingToken);
            var totalPending = pendingOrdersWithPaymentIntent.Count + pendingOrdersWithoutPaymentIntent.Count;
            if (totalPending > 0)
            {
                _logger.LogInformation("🔍 Provjeravam {Count} pending plaćanja ({WithPI} sa PaymentIntent, {WithoutPI} bez PaymentIntent)...", 
                    totalPending, pendingOrdersWithPaymentIntent.Count, pendingOrdersWithoutPaymentIntent.Count);
            }
            else if (pendingOrdersWithoutPaymentIntent.Count > 0)
            {
                _logger.LogInformation("🔍 Pronađeno {Count} pending ordera bez PaymentIntent (checkout session flow)", 
                    pendingOrdersWithoutPaymentIntent.Count);
            }
            foreach (var order in pendingOrdersWithPaymentIntent)
            {
                try
                {
                    await ProcessPendingOrder(order, context, stoppingToken);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Greška pri obradi order {OrderId}", order.Id);
                }
            }
            foreach (var order in pendingOrdersWithoutPaymentIntent)
            {
                try
                {
                    await ProcessPendingCheckoutSession(order, context, stoppingToken);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Greška pri obradi checkout session za order {OrderId}", order.Id);
                }
            }
        }
        private async Task ProcessPendingOrder(
            Order order,
            ApplicationDbContext context,
            CancellationToken stoppingToken)
        {
            var paymentIntentService = new PaymentIntentService();
            var paymentIntent = await paymentIntentService.GetAsync(
                order.StripePaymentIntentId!,
                cancellationToken: stoppingToken);
            _logger.LogDebug("Payment {PaymentIntentId} status: {Status}",
                paymentIntent.Id, paymentIntent.Status);
            if (paymentIntent.Status == "succeeded")
            {
                _logger.LogInformation("✅ Plaćanje uspješno (polling): {PaymentIntentId}",
                    paymentIntent.Id);
                if (order.Status == "Paid")
                {
                    _logger.LogInformation("Order {OrderId} already marked as Paid. Skipping.", order.Id);
                    return;
                }
                order.Status = "Paid";
                order.StripePaymentIntentId = paymentIntent.Id;
                foreach (var orderItem in order.Items)
                {
                    var priceTier = await context.PriceTiers.FindAsync(new object[] { orderItem.PriceTierId }, stoppingToken);
                    if (priceTier != null)
                    {
                        priceTier.Sold += orderItem.Qty;
                        _logger.LogInformation("Updated Sold count for PriceTier {PriceTierId}: {Sold} (added {Qty})",
                            priceTier.Id, priceTier.Sold, orderItem.Qty);
                    }
                }
                foreach (var orderItem in order.Items)
                {
                    for (int i = 0; i < orderItem.Qty; i++)
                    {
                        var ticket = new Ticket
                        {
                            Id = Guid.NewGuid(),
                            OrderItemId = orderItem.Id,
                            TicketCode = GenerateTicketCode(),
                            Status = "Valid",
                            IssuedAt = DateTime.UtcNow,
                            QRNonce = Guid.NewGuid().ToString("N")[..32]
                        };
                        context.Tickets.Add(ticket);
                    }
                }
                await context.SaveChangesAsync(stoppingToken);
                _logger.LogInformation("🎫 Ticketi generisani za order {OrderId}", order.Id);
            }
            else if (paymentIntent.Status == "canceled" || paymentIntent.Status == "requires_payment_method")
            {
                _logger.LogWarning("❌ Plaćanje neuspješno: {PaymentIntentId} - Status: {Status}",
                    paymentIntent.Id, paymentIntent.Status);
                order.Status = "Failed";
                await context.SaveChangesAsync(stoppingToken);
            }
        }
        private async Task ProcessPendingCheckoutSession(
            Order order,
            ApplicationDbContext context,
            CancellationToken stoppingToken)
        {
            try
            {
                var stripeSecretKey = Environment.GetEnvironmentVariable("STRIPE_SECRET_KEY") 
                    ?? _configuration["Stripe:SecretKey"];
                if (!string.IsNullOrEmpty(stripeSecretKey))
                {
                    if (stripeSecretKey.Contains("${"))
                    {
                        var match = System.Text.RegularExpressions.Regex.Match(stripeSecretKey, @"\$\{[^:]+:(.+)\}");
                        if (match.Success && match.Groups.Count > 1)
                        {
                            stripeSecretKey = match.Groups[1].Value;
                        }
                        else
                        {
                            var varMatch = System.Text.RegularExpressions.Regex.Match(stripeSecretKey, @"\$\{([^:}]+)");
                            if (varMatch.Success && varMatch.Groups.Count > 1)
                            {
                                var envVarName = varMatch.Groups[1].Value;
                                stripeSecretKey = Environment.GetEnvironmentVariable(envVarName) ?? stripeSecretKey;
                            }
                        }
                    }
                    StripeConfiguration.ApiKey = stripeSecretKey;
                    _logger.LogDebug("PaymentMonitorService: Stripe API key set for checkout session check. Key prefix: {KeyPrefix}", 
                        stripeSecretKey.Substring(0, Math.Min(10, stripeSecretKey.Length)));
                }
                else
                {
                    _logger.LogError("PaymentMonitorService: Cannot check checkout session - Stripe API key not available!");
                    return;
                }
                var sessionService = new Stripe.Checkout.SessionService();
                Stripe.Checkout.Session? matchingSession = null;
                var sessionListOptions = new Stripe.Checkout.SessionListOptions
                {
                    Limit = 100
                };
                StripeList<Stripe.Checkout.Session>? lastSessions = null;
                for (int page = 0; page < 5 && matchingSession == null; page++)
                {
                    if (page > 0 && lastSessions != null && lastSessions.Data.Any())
                    {
                        sessionListOptions.StartingAfter = lastSessions.Data.Last().Id;
                    }
                    var sessions = await sessionService.ListAsync(sessionListOptions, cancellationToken: stoppingToken);
                    lastSessions = sessions;
                    _logger.LogInformation("🔍 Searching checkout sessions for order {OrderId} (page {Page}, found {Count} sessions)", 
                        order.Id, page + 1, sessions.Data.Count);
                    matchingSession = sessions.Data.FirstOrDefault(s => 
                        s.ClientReferenceId == order.Id.ToString() || 
                        (s.Metadata != null && s.Metadata.TryGetValue("orderId", out var orderIdStr) && orderIdStr == order.Id.ToString()));
                    if (matchingSession != null || !sessions.HasMore)
                        break;
                }
                if (matchingSession == null)
                {
                    _logger.LogInformation("⚠️ No checkout session found for order {OrderId} after searching through multiple pages", 
                        order.Id);
                    return;
                }
                _logger.LogInformation("🔍 Found checkout session {SessionId} for order {OrderId}, Status: {Status}, PaymentStatus: {PaymentStatus}",
                    matchingSession.Id, order.Id, matchingSession.Status, matchingSession.PaymentStatus);
                if (matchingSession.Status == "complete" && matchingSession.PaymentStatus == "paid")
                {
                    _logger.LogInformation("✅ Checkout session uspješan (polling): {SessionId} za order {OrderId}",
                        matchingSession.Id, order.Id);
                    if (order.Status == "Paid")
                    {
                        _logger.LogInformation("Order {OrderId} already marked as Paid. Skipping.", order.Id);
                        return;
                    }
                    order.Status = "Paid";
                    if (!string.IsNullOrEmpty(matchingSession.PaymentIntentId))
                    {
                        order.StripePaymentIntentId = matchingSession.PaymentIntentId;
                        _logger.LogInformation("Setting StripePaymentIntentId to {PaymentIntentId} for order {OrderId}", 
                            matchingSession.PaymentIntentId, order.Id);
                    }
                    foreach (var orderItem in order.Items)
                    {
                        var priceTier = await context.PriceTiers.FindAsync(new object[] { orderItem.PriceTierId }, stoppingToken);
                        if (priceTier != null)
                        {
                            priceTier.Sold += orderItem.Qty;
                            _logger.LogInformation("Updated Sold count for PriceTier {PriceTierId}: {Sold} (added {Qty})",
                                priceTier.Id, priceTier.Sold, orderItem.Qty);
                        }
                    }
                    foreach (var orderItem in order.Items)
                    {
                        for (int i = 0; i < orderItem.Qty; i++)
                        {
                            var ticket = new Ticket
                            {
                                Id = Guid.NewGuid(),
                                OrderItemId = orderItem.Id,
                                TicketCode = GenerateTicketCode(),
                                Status = "Valid",
                                IssuedAt = DateTime.UtcNow,
                                QRNonce = Guid.NewGuid().ToString("N")[..32]
                            };
                            context.Tickets.Add(ticket);
                        }
                    }
                    await context.SaveChangesAsync(stoppingToken);
                    _logger.LogInformation("🎫 Ticketi generisani za order {OrderId} (checkout session)", order.Id);
                }
                else if (matchingSession.Status == "expired" || matchingSession.PaymentStatus == "unpaid")
                {
                    _logger.LogWarning("❌ Checkout session neuspješan: {SessionId} - Status: {Status}, PaymentStatus: {PaymentStatus}",
                        matchingSession.Id, matchingSession.Status, matchingSession.PaymentStatus);
                    order.Status = "Failed";
                    await context.SaveChangesAsync(stoppingToken);
                }
            }
            catch (Stripe.StripeException ex)
            {
                _logger.LogError(ex, "Stripe error checking checkout session for order {OrderId}", order.Id);
            }
        }
        private string GenerateTicketCode()
        {
            return $"TK{DateTime.UtcNow:yyyyMMdd}{Guid.NewGuid().ToString("N")[..8].ToUpper()}";
        }
    }
}