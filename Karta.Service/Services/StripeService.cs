using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Karta.Model;
using Karta.Model.Entities;
using Karta.Service.DTO;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Stripe;
using Stripe.Checkout;
namespace Karta.Service.Services
{
    public interface IStripeService
    {
        Task<(Guid orderId, string clientSecret)> CreatePaymentIntentAsync(CreateOrderRequest req, CancellationToken ct = default);
        Task<(Guid orderId, string sessionId, string url)> CreateCheckoutSessionAsync(CreateCheckoutSessionRequest req, string userId, CancellationToken ct = default);
        Task HandleWebhookAsync(string json, string? signature, CancellationToken ct = default);
        Task<(Guid orderId, string clientSecret, string customerId, string ephemeralKey)> CreatePaymentIntentDirectAsync(CreateCheckoutSessionRequest req, string userId, string userEmail, string userName, CancellationToken ct = default);
        Task ConfirmPaymentAsync(Guid orderId, CancellationToken ct = default);
    }
    public class StripeService : IStripeService
    {
        private readonly ApplicationDbContext _context;
        private readonly IEmailService _emailService;
        private readonly ILogger<StripeService> _logger;
        private readonly IConfiguration _configuration;
        private readonly string _stripeSecretKey;
        private readonly string _stripeWebhookSecret;
        public StripeService(ApplicationDbContext context, IEmailService emailService, ILogger<StripeService> logger, IConfiguration configuration)
        {
            _context = context;
            _emailService = emailService;
            _logger = logger;
            _configuration = configuration;
            _stripeSecretKey = configuration["Stripe:SecretKey"] ?? throw new ArgumentException("Stripe SecretKey not configured");
            var environment = configuration["ASPNETCORE_ENVIRONMENT"];
            if (environment == "Development")
            {
                _stripeWebhookSecret = configuration["Stripe:WebhookSecret"] ?? string.Empty;
                if (string.IsNullOrEmpty(_stripeWebhookSecret))
                {
                    _logger.LogWarning("⚠️ DEVELOPMENT MODE: Stripe WebhookSecret not configured. Webhook verification will be skipped.");
                }
            }
            else
            {
                _stripeWebhookSecret = configuration["Stripe:WebhookSecret"] ?? throw new ArgumentException("Stripe WebhookSecret not configured");
            }
            StripeConfiguration.ApiKey = _stripeSecretKey;
        }
        public async Task<(Guid orderId, string clientSecret)> CreatePaymentIntentAsync(CreateOrderRequest req, CancellationToken ct = default)
        {
            var priceTier = await _context.PriceTiers
                .Include(pt => pt.Event)
                .FirstOrDefaultAsync(pt => pt.Id == req.PriceTierId, ct);
            if (priceTier == null)
                throw new ArgumentException("Price tier not found");
            if (priceTier.Sold + req.Quantity > priceTier.Capacity)
                throw new InvalidOperationException("Not enough tickets available");
            var totalAmount = priceTier.Price * req.Quantity;
            var order = new Order
            {
                Id = Guid.NewGuid(),
                UserId = req.UserId,
                TotalAmount = totalAmount,
                Currency = priceTier.Currency,
                Status = "Pending",
                CreatedAt = DateTime.UtcNow
            };
            var orderItem = new OrderItem
            {
                Id = Guid.NewGuid(),
                OrderId = order.Id,
                EventId = priceTier.EventId,
                PriceTierId = priceTier.Id,
                Qty = req.Quantity,
                UnitPrice = priceTier.Price
            };
            _context.Orders.Add(order);
            _context.OrderItems.Add(orderItem);
            await _context.SaveChangesAsync(ct);
            _logger.LogInformation("Creating Stripe Payment Intent for order {OrderId}, amount: {Amount} {Currency}", order.Id, totalAmount, priceTier.Currency);
            try
            {
                var paymentIntentService = new PaymentIntentService();
                var paymentIntent = await paymentIntentService.CreateAsync(new PaymentIntentCreateOptions
                {
                    Amount = (long)Math.Round(totalAmount * 100m, MidpointRounding.AwayFromZero),
                    Currency = priceTier.Currency.ToLower(),
                    AutomaticPaymentMethods = new PaymentIntentAutomaticPaymentMethodsOptions
                    {
                        Enabled = true,
                        AllowRedirects = "if_required"
                    },
                    Metadata = new Dictionary<string, string>
                    {
                        { "orderId", order.Id.ToString() },
                        { "userId", req.UserId },
                        { "eventId", priceTier.EventId.ToString() },
                        { "priceTierId", priceTier.Id.ToString() },
                        { "quantity", req.Quantity.ToString() },
                        { "totalAmount", totalAmount.ToString(System.Globalization.CultureInfo.InvariantCulture) }
                    }
                }, new RequestOptions
                {
                    IdempotencyKey = $"pi:{order.Id}:{totalAmount}"
                }, ct);
                _logger.LogInformation("Stripe Payment Intent created successfully: {PaymentIntentId}", paymentIntent.Id);
                order.StripePaymentIntentId = paymentIntent.Id;
                await _context.SaveChangesAsync(ct);
                return (order.Id, paymentIntent.ClientSecret);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to create Stripe Payment Intent for order {OrderId}", order.Id);
                throw new InvalidOperationException($"Failed to create payment intent: {ex.Message}", ex);
            }
        }
        public async Task<(Guid orderId, string sessionId, string url)> CreateCheckoutSessionAsync(CreateCheckoutSessionRequest req, string userId, CancellationToken ct = default)
        {
            var eventEntity = await _context.Events
                .Include(e => e.PriceTiers)
                .FirstOrDefaultAsync(e => e.Id == req.EventId, ct);
            if (eventEntity == null)
                throw new ArgumentException("Event not found");
            decimal totalAmount = 0;
            int totalQuantity = 0;
            var lineItems = new List<SessionLineItemOptions>();
            foreach (var item in req.Items)
            {
                var priceTier = eventEntity.PriceTiers.FirstOrDefault(pt => pt.Id == item.PriceTierId);
                if (priceTier == null)
                    throw new ArgumentException($"Price tier {item.PriceTierId} not found");
                if (priceTier.Sold + item.Quantity > priceTier.Capacity)
                    throw new InvalidOperationException($"Not enough tickets available for {priceTier.Name}");
                var itemTotal = priceTier.Price * item.Quantity;
                totalAmount += itemTotal;
                totalQuantity += item.Quantity;
                lineItems.Add(new SessionLineItemOptions
                {
                    PriceData = new SessionLineItemPriceDataOptions
                    {
                        UnitAmount = (long)Math.Round(priceTier.Price * 100m, MidpointRounding.AwayFromZero),
                        Currency = priceTier.Currency.ToLowerInvariant(),
                        ProductData = new SessionLineItemPriceDataProductDataOptions
                        {
                            Name = $"{eventEntity.Title} - {priceTier.Name}",
                            Description = $"Ticket for {eventEntity.Title}",
                            Metadata = new Dictionary<string, string>
                            {
                                { "priceTierId", priceTier.Id.ToString() },
                                { "eventId", eventEntity.Id.ToString() }
                            }
                        }
                    },
                    Quantity = item.Quantity
                });
            }
            const decimal commissionFeePerTicket = 0.50m;
            decimal commissionFee = commissionFeePerTicket * totalQuantity;
            totalAmount += commissionFee;
            lineItems.Add(new SessionLineItemOptions
            {
                PriceData = new SessionLineItemPriceDataOptions
                {
                    UnitAmount = (long)Math.Round(commissionFeePerTicket * 100m, MidpointRounding.AwayFromZero),
                    Currency = req.Currency.ToLowerInvariant(),
                    ProductData = new SessionLineItemPriceDataProductDataOptions
                    {
                        Name = "Commission Fee",
                        Description = $"Service fee per ticket",
                        Metadata = new Dictionary<string, string>
                        {
                            { "type", "commission" }
                        }
                    }
                },
                Quantity = totalQuantity
            });
            var order = new Order
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                TotalAmount = totalAmount,
                Currency = req.Currency,
                Status = "Pending",
                CreatedAt = DateTime.UtcNow
            };
            var orderItems = new List<OrderItem>();
            foreach (var item in req.Items)
            {
                var priceTier = eventEntity.PriceTiers.First(pt => pt.Id == item.PriceTierId);
                orderItems.Add(new OrderItem
                {
                    Id = Guid.NewGuid(),
                    OrderId = order.Id,
                    EventId = eventEntity.Id,
                    PriceTierId = priceTier.Id,
                    Qty = item.Quantity,
                    UnitPrice = priceTier.Price
                });
            }
            _context.Orders.Add(order);
            _context.OrderItems.AddRange(orderItems);
            await _context.SaveChangesAsync(ct);
            _logger.LogInformation("Creating Stripe Checkout Session for order {OrderId}, amount: {Amount} {Currency}", 
                order.Id, totalAmount, req.Currency);
            try
            {
                var sessionService = new SessionService();
                var options = new SessionCreateOptions
                {
                    Mode = "payment",
                    LineItems = lineItems,
                    SuccessUrl = $"http://localhost:8080/api/order/success?session_id={{CHECKOUT_SESSION_ID}}&order_id={order.Id}",
                    CancelUrl = $"http://localhost:8080/api/order/cancel?order_id={order.Id}",
                    Metadata = new Dictionary<string, string>
                    {
                        ["orderId"] = order.Id.ToString(),
                        ["userId"] = userId,
                        ["eventId"] = eventEntity.Id.ToString()
                    },
                    ClientReferenceId = order.Id.ToString(),
                    Locale = "auto",
                    PaymentIntentData = new SessionPaymentIntentDataOptions
                    {
                        Metadata = new Dictionary<string, string>
                        {
                            ["orderId"] = order.Id.ToString(),
                            ["userId"] = userId,
                            ["eventId"] = eventEntity.Id.ToString()
                        }
                    }
                };
                var session = await sessionService.CreateAsync(options, new RequestOptions
                {
                    IdempotencyKey = $"checkout:{order.Id}"
                }, ct);
                _logger.LogInformation("Stripe Checkout Session created successfully: {SessionId}", session.Id);
                return (order.Id, session.Id, session.Url);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to create Stripe Checkout Session for order {OrderId}", order.Id);
                throw new InvalidOperationException($"Failed to create checkout session: {ex.Message}", ex);
            }
        }
        public async Task HandleWebhookAsync(string json, string? signature, CancellationToken ct = default)
        {
            try
            {
                _logger.LogInformation("Attempting to construct Stripe event. JSON length: {Length}, Has signature: {HasSignature}", 
                    json?.Length ?? 0, !string.IsNullOrEmpty(signature));
                Stripe.Event stripeEvent;
                var environment = _configuration["ASPNETCORE_ENVIRONMENT"];
                if (environment == "Development" && string.IsNullOrEmpty(_stripeWebhookSecret))
                {
                    _logger.LogWarning("⚠️ DEVELOPMENT MODE: Webhook bez verifikacije - PaymentMonitorService će obraditi plaćanja putem polling-a");
                    _logger.LogInformation("Webhook primljen u development modu, ali će biti obrađen putem PaymentMonitorService polling-a");
                    return;
                }
                else
                {
                    stripeEvent = EventUtility.ConstructEvent(json, signature, _stripeWebhookSecret);
                    _logger.LogInformation("✅ Webhook verifikovan: {EventType}", stripeEvent.Type);
                }
                _logger.LogInformation("Received Stripe webhook event: {EventType} with ID: {EventId}", stripeEvent.Type, stripeEvent.Id);
                switch (stripeEvent.Type)
                {
                    case "checkout.session.completed":
                        _logger.LogInformation("Processing checkout.session.completed event");
                        await HandleCheckoutSessionCompleted(stripeEvent, ct);
                        break;
                    case "payment_intent.succeeded":
                        _logger.LogInformation("Processing payment_intent.succeeded event");
                        await HandlePaymentIntentSucceeded(stripeEvent, ct);
                        break;
                    case "payment_intent.payment_failed":
                        _logger.LogInformation("Processing payment_intent.payment_failed event");
                        await HandlePaymentIntentFailed(stripeEvent, ct);
                        break;
                    case "checkout.session.expired":
                        _logger.LogInformation("Processing checkout.session.expired event");
                        await HandleCheckoutSessionExpired(stripeEvent, ct);
                        break;
                    case "checkout.session.cancelled":
                        _logger.LogInformation("Processing checkout.session.cancelled event");
                        await HandleCheckoutSessionCancelled(stripeEvent, ct);
                        break;
                    default:
                        _logger.LogInformation("Unhandled event type: {EventType}", stripeEvent.Type);
                        break;
                }
            }
            catch (StripeException ex)
            {
                _logger.LogError(ex, "Stripe webhook error: {Message}, Type: {Type}", ex.Message, ex.GetType().Name);
                throw new InvalidOperationException($"Stripe webhook error: {ex.Message}", ex);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error processing webhook: {Message}, Type: {Type}", ex.Message, ex.GetType().Name);
                throw;
            }
        }
        private async Task HandleCheckoutSessionCompleted(Stripe.Event stripeEvent, CancellationToken ct)
        {
            var session = stripeEvent.Data.Object as Session;
            if (session == null)
            {
                _logger.LogWarning("Session is null in HandleCheckoutSessionCompleted");
                return;
            }
            _logger.LogInformation("Processing checkout.session.completed for Session: {SessionId}, PaymentIntentId: {PaymentIntentId}", 
                session.Id, session.PaymentIntentId ?? "null");
            if (!session.Metadata.TryGetValue("orderId", out var orderIdStr) || !Guid.TryParse(orderIdStr, out var orderId))
            {
                _logger.LogWarning("Order ID not found in session metadata: {SessionId}", session.Id);
                return;
            }
            var order = await _context.Orders
                .Include(o => o.Items)
                .ThenInclude(oi => oi.Event)
                .FirstOrDefaultAsync(o => o.Id == orderId, ct);
            if (order == null)
            {
                _logger.LogWarning("Order not found for Session: {SessionId}, OrderId: {OrderId}", session.Id, orderId);
                return;
            }
            _logger.LogInformation("Found order {OrderId} for Session: {SessionId}, Current Status: {Status}, Current PaymentIntentId: {PaymentIntentId}", 
                order.Id, session.Id, order.Status, order.StripePaymentIntentId ?? "null");
            if (order.Status == "Paid")
            {
                _logger.LogInformation("Order {OrderId} already marked as Paid. Skipping.", order.Id);
                return;
            }
            order.Status = "Paid";
            if (!string.IsNullOrEmpty(session.PaymentIntentId))
            {
                order.StripePaymentIntentId = session.PaymentIntentId;
                _logger.LogInformation("Setting StripePaymentIntentId to {PaymentIntentId} for order {OrderId}", session.PaymentIntentId, order.Id);
            }
            else
            {
                _logger.LogWarning("Session {SessionId} has no PaymentIntentId. Will be set by payment_intent.succeeded handler.", session.Id);
            }
            foreach (var orderItem in order.Items)
            {
                var priceTier = await _context.PriceTiers.FindAsync(orderItem.PriceTierId);
                if (priceTier != null)
                {
                    priceTier.Sold += orderItem.Qty;
                    _logger.LogInformation("Updated Sold count for PriceTier {PriceTierId}: {Sold} (was {PreviousSold}, added {Qty})", 
                        priceTier.Id, priceTier.Sold, priceTier.Sold - orderItem.Qty, orderItem.Qty);
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
                    _context.Tickets.Add(ticket);
                }
            }
            await _context.SaveChangesAsync(ct);
            await SendTicketConfirmationEmails(order, ct);
            _logger.LogInformation("Order {OrderId} marked as Paid via CheckoutSession. PaymentIntentId: {PaymentIntentId}", 
                order.Id, order.StripePaymentIntentId ?? "null");
        }
        private async Task HandlePaymentIntentSucceeded(Stripe.Event stripeEvent, CancellationToken ct)
        {
            var paymentIntent = stripeEvent.Data.Object as PaymentIntent;
            if (paymentIntent == null) 
            {
                _logger.LogWarning("PaymentIntent is null in HandlePaymentIntentSucceeded");
                return;
            }
            _logger.LogInformation("Processing payment_intent.succeeded for PaymentIntent: {PaymentIntentId}", paymentIntent.Id);
            var order = await _context.Orders
                .Include(o => o.Items)
                .ThenInclude(oi => oi.Event)
                .FirstOrDefaultAsync(o => o.StripePaymentIntentId == paymentIntent.Id, ct);
            if (order == null && paymentIntent.Metadata.TryGetValue("orderId", out var orderIdStr) && Guid.TryParse(orderIdStr, out var orderId))
            {
                order = await _context.Orders
                    .Include(o => o.Items)
                    .ThenInclude(oi => oi.Event)
                    .FirstOrDefaultAsync(o => o.Id == orderId, ct);
            }
            if (order == null) 
            {
                _logger.LogWarning("Order not found for PaymentIntent: {PaymentIntentId}", paymentIntent.Id);
                return;
            }
            _logger.LogInformation("Found order {OrderId} for PaymentIntent: {PaymentIntentId}", order.Id, paymentIntent.Id);
            if (order.Status == "Paid")
            {
                _logger.LogInformation("Order {OrderId} already marked as Paid. Skipping.", order.Id);
                return;
            }
            order.Status = "Paid";
            order.StripePaymentIntentId = paymentIntent.Id;
            foreach (var orderItem in order.Items)
            {
                var priceTier = await _context.PriceTiers.FindAsync(orderItem.PriceTierId);
                if (priceTier != null)
                {
                    priceTier.Sold += orderItem.Qty;
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
                    _context.Tickets.Add(ticket);
                }
            }
            await _context.SaveChangesAsync(ct);
            await SendTicketConfirmationEmails(order, ct);
            _logger.LogInformation("Order {OrderId} successfully processed and marked as Paid", order.Id);
        }
        private async Task SendTicketConfirmationEmails(Order order, CancellationToken ct)
        {
            try
            {
                var user = await _context.Users.FindAsync(order.UserId);
                if (user?.Email == null) return;
                var orderItems = await _context.OrderItems
                    .Include(oi => oi.Event)
                    .Include(oi => oi.Tickets)
                    .Where(oi => oi.OrderId == order.Id)
                    .ToListAsync(ct);
                foreach (var orderItem in orderItems)
                {
                    foreach (var ticket in orderItem.Tickets)
                    {
                        await _emailService.SendTicketConfirmationAsync(
                            user.Email,
                            orderItem.Event.Title,
                            ticket.TicketCode,
                            ct);
                    }
                }
            }
            catch (Exception)
            {
            }
        }
        private async Task HandlePaymentIntentFailed(Stripe.Event stripeEvent, CancellationToken ct)
        {
            var paymentIntent = stripeEvent.Data.Object as PaymentIntent;
            if (paymentIntent == null) return;
            var order = await _context.Orders
                .Include(o => o.Items)
                .FirstOrDefaultAsync(o => o.StripePaymentIntentId == paymentIntent.Id, ct);
            if (order == null) return;
            order.Status = "Failed";
            await _context.SaveChangesAsync(ct);
        }
        private async Task HandleCheckoutSessionExpired(Stripe.Event stripeEvent, CancellationToken ct)
        {
            var session = stripeEvent.Data.Object as Session;
            if (session == null)
            {
                _logger.LogWarning("Session is null in HandleCheckoutSessionExpired");
                return;
            }
            _logger.LogInformation("Processing checkout.session.expired for Session: {SessionId}", session.Id);
            if (!session.Metadata.TryGetValue("orderId", out var orderIdStr) || !Guid.TryParse(orderIdStr, out var orderId))
            {
                _logger.LogWarning("Order ID not found in session metadata: {SessionId}", session.Id);
                return;
            }
            var order = await _context.Orders
                .Include(o => o.Items)
                .FirstOrDefaultAsync(o => o.Id == orderId, ct);
            if (order == null)
            {
                _logger.LogWarning("Order not found for Session: {SessionId}, OrderId: {OrderId}", session.Id, orderId);
                return;
            }
            if (order.Status == "Pending")
            {
                order.Status = "Expired";
                await _context.SaveChangesAsync(ct);
                _logger.LogInformation("Order {OrderId} marked as Expired for Session: {SessionId}", order.Id, session.Id);
            }
            else
            {
                _logger.LogInformation("Order {OrderId} is no longer Pending (Status: {Status}), skipping expiration", order.Id, order.Status);
            }
        }
        private async Task HandleCheckoutSessionCancelled(Stripe.Event stripeEvent, CancellationToken ct)
        {
            var session = stripeEvent.Data.Object as Session;
            if (session == null)
            {
                _logger.LogWarning("Session is null in HandleCheckoutSessionCancelled");
                return;
            }
            _logger.LogInformation("Processing checkout.session.cancelled for Session: {SessionId}", session.Id);
            if (!session.Metadata.TryGetValue("orderId", out var orderIdStr) || !Guid.TryParse(orderIdStr, out var orderId))
            {
                _logger.LogWarning("Order ID not found in session metadata: {SessionId}", session.Id);
                return;
            }
            var order = await _context.Orders
                .Include(o => o.Items)
                .FirstOrDefaultAsync(o => o.Id == orderId, ct);
            if (order == null)
            {
                _logger.LogWarning("Order not found for Session: {SessionId}, OrderId: {OrderId}", session.Id, orderId);
                return;
            }
            if (order.Status == "Pending")
            {
                order.Status = "Cancelled";
                await _context.SaveChangesAsync(ct);
                _logger.LogInformation("Order {OrderId} marked as Cancelled for Session: {SessionId}", order.Id, session.Id);
            }
            else
            {
                _logger.LogInformation("Order {OrderId} is no longer Pending (Status: {Status}), skipping cancellation", order.Id, order.Status);
            }
        }
        public async Task<(Guid orderId, string clientSecret, string customerId, string ephemeralKey)> CreatePaymentIntentDirectAsync(
            CreateCheckoutSessionRequest req, 
            string userId, 
            string userEmail, 
            string userName, 
            CancellationToken ct = default)
        {
            var eventEntity = await _context.Events
                .Include(e => e.PriceTiers)
                .FirstOrDefaultAsync(e => e.Id == req.EventId, ct);
            if (eventEntity == null)
                throw new ArgumentException("Event not found");
            decimal totalAmount = 0;
            int totalQuantity = 0;
            var orderItems = new List<OrderItem>();
            foreach (var item in req.Items)
            {
                var priceTier = eventEntity.PriceTiers.FirstOrDefault(pt => pt.Id == item.PriceTierId);
                if (priceTier == null)
                    throw new ArgumentException($"Price tier {item.PriceTierId} not found for event {req.EventId}");
                if (priceTier.Sold + item.Quantity > priceTier.Capacity)
                    throw new InvalidOperationException($"Not enough tickets available for tier {priceTier.Name}");
                totalAmount += priceTier.Price * item.Quantity;
                totalQuantity += item.Quantity;
                orderItems.Add(new OrderItem
                {
                    Id = Guid.NewGuid(),
                    EventId = eventEntity.Id,
                    PriceTierId = priceTier.Id,
                    Qty = item.Quantity,
                    UnitPrice = priceTier.Price
                });
            }
            const decimal commissionFeePerTicket = 0.50m;
            decimal commissionFee = commissionFeePerTicket * totalQuantity;
            decimal amountBeforeCommission = totalAmount;
            totalAmount += commissionFee;
            _logger.LogInformation("Adding commission fee: {CommissionFeePerTicket} x {TotalQuantity} = {TotalCommissionFee}, amount before: {AmountBefore}, amount after: {AmountAfter}", 
                commissionFeePerTicket, totalQuantity, commissionFee, amountBeforeCommission, totalAmount);
            var order = new Order
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                TotalAmount = totalAmount,
                Currency = req.Currency,
                Status = "Pending",
                CreatedAt = DateTime.UtcNow
            };
            foreach (var item in orderItems)
            {
                item.OrderId = order.Id;
            }
            _context.Orders.Add(order);
            _context.OrderItems.AddRange(orderItems);
            await _context.SaveChangesAsync(ct);
            _logger.LogInformation("Creating Stripe Payment Intent Direct for order {OrderId}, amount: {Amount} {Currency}", 
                order.Id, totalAmount, req.Currency);
            try
            {
                var customerService = new CustomerService();
                Customer customer;
                var existingCustomers = await customerService.ListAsync(new CustomerListOptions
                {
                    Email = userEmail,
                    Limit = 1
                }, cancellationToken: ct);
                if (existingCustomers.Data.Any())
                {
                    customer = existingCustomers.Data.First();
                    _logger.LogInformation("Using existing Stripe Customer: {CustomerId}", customer.Id);
                    if (customer.Name != userName)
                    {
                        customer = await customerService.UpdateAsync(customer.Id, new CustomerUpdateOptions
                        {
                            Name = userName
                        }, cancellationToken: ct);
                        _logger.LogInformation("Updated Stripe Customer name: {CustomerId}", customer.Id);
                    }
                }
                else
                {
                    customer = await customerService.CreateAsync(new CustomerCreateOptions
                    {
                        Email = userEmail,
                        Name = userName,
                        Metadata = new Dictionary<string, string>
                        {
                            { "userId", userId }
                        }
                    }, cancellationToken: ct);
                    _logger.LogInformation("Stripe Customer created: {CustomerId}", customer.Id);
                }
                var ephemeralKeyService = new EphemeralKeyService();
                var ephemeralKey = await ephemeralKeyService.CreateAsync(new EphemeralKeyCreateOptions
                {
                    Customer = customer.Id,
                }, cancellationToken: ct);
                _logger.LogInformation("Ephemeral Key created: {EphemeralKeyId}", ephemeralKey.Id);
                var paymentIntentService = new PaymentIntentService();
                var amountInCents = (long)Math.Round(totalAmount * 100m, MidpointRounding.AwayFromZero);
                _logger.LogInformation("Creating Payment Intent with amount: {Amount} {Currency} (in cents: {AmountInCents})", 
                    totalAmount, req.Currency, amountInCents);
                var paymentIntent = await paymentIntentService.CreateAsync(new PaymentIntentCreateOptions
                {
                    Amount = amountInCents,
                    Currency = req.Currency.ToLower(),
                    Customer = customer.Id,
                    AutomaticPaymentMethods = new PaymentIntentAutomaticPaymentMethodsOptions
                    {
                        Enabled = true
                    },
                    Metadata = new Dictionary<string, string>
                    {
                        { "orderId", order.Id.ToString() },
                        { "userId", userId },
                        { "eventId", eventEntity.Id.ToString() },
                        { "totalAmount", totalAmount.ToString(System.Globalization.CultureInfo.InvariantCulture) },
                        { "commissionIncluded", "true" }
                    }
                }, new RequestOptions
                {
                    IdempotencyKey = $"pi:{order.Id}:{amountInCents}"
                }, ct);
                _logger.LogInformation("Payment Intent created: {PaymentIntentId}, Amount: {Amount} {Currency} (in cents: {AmountInCents}), Stripe Amount: {StripeAmount} cents, Match: {Match}", 
                    paymentIntent.Id, totalAmount, req.Currency, amountInCents, paymentIntent.Amount, paymentIntent.Amount == amountInCents);
                order.StripePaymentIntentId = paymentIntent.Id;
                await _context.SaveChangesAsync(ct);
                return (order.Id, paymentIntent.ClientSecret, customer.Id, ephemeralKey.Secret);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to create Payment Intent Direct for order {OrderId}", order.Id);
                throw new InvalidOperationException($"Failed to create payment intent: {ex.Message}", ex);
            }
        }
        public async Task ConfirmPaymentAsync(Guid orderId, CancellationToken ct = default)
        {
            var order = await _context.Orders
                .Include(o => o.Items)
                .ThenInclude(oi => oi.Event)
                .FirstOrDefaultAsync(o => o.Id == orderId, ct);
            if (order == null)
                throw new ArgumentException($"Order {orderId} not found");
            if (order.Status == "Paid")
            {
                _logger.LogInformation("Order {OrderId} already marked as Paid. Skipping.", order.Id);
                return;
            }
            if (string.IsNullOrEmpty(order.StripePaymentIntentId))
            {
                throw new InvalidOperationException($"Order {orderId} does not have a Payment Intent ID");
            }
            var paymentIntentService = new PaymentIntentService();
            var paymentIntent = await paymentIntentService.GetAsync(order.StripePaymentIntentId, cancellationToken: ct);
            if (paymentIntent.Status != "succeeded")
            {
                throw new InvalidOperationException($"Payment Intent {order.StripePaymentIntentId} is not succeeded. Status: {paymentIntent.Status}");
            }
            order.Status = "Paid";
            order.StripePaymentIntentId = order.StripePaymentIntentId;
            foreach (var orderItem in order.Items)
            {
                var priceTier = await _context.PriceTiers.FindAsync(orderItem.PriceTierId);
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
                    _context.Tickets.Add(ticket);
                }
            }
            await _context.SaveChangesAsync(ct);
            await SendTicketConfirmationEmails(order, ct);
            _logger.LogInformation("Order {OrderId} confirmed and marked as Paid. PaymentIntentId: {PaymentIntentId}", 
                order.Id, order.StripePaymentIntentId);
        }
        private string GenerateTicketCode()
        {
            return $"TK{DateTime.UtcNow:yyyyMMdd}{Guid.NewGuid().ToString("N")[..8].ToUpper()}";
        }
    }
}