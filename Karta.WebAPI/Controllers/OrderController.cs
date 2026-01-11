using System;
using Karta.Service.DTO;
using Karta.Service.Interfaces;
using Karta.Service.Services;
using Karta.WebAPI.Authorization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Logging;
using System.Security.Claims;
namespace Karta.WebAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class OrderController : ControllerBase
    {
        private readonly IOrderService _orderService;
        private readonly IStripeService _stripeService;
        private readonly IWebHostEnvironment _environment;
        private readonly ILogger<OrderController> _logger;
        public OrderController(IOrderService orderService, IStripeService stripeService, IWebHostEnvironment environment, ILogger<OrderController> logger)
        {
            _orderService = orderService;
            _stripeService = stripeService;
            _environment = environment;
            _logger = logger;
        }
        [HttpPost("create-checkout-session")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        public async Task<ActionResult<object>> CreateCheckoutSession(
            [FromBody] CreateCheckoutSessionRequest request,
            CancellationToken ct = default)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Unauthorized();
            try
            {
                var (orderId, sessionId, url) = await _stripeService.CreateCheckoutSessionAsync(request, userId, ct);
                return Ok(new { orderId, sessionId, url });
            }
            catch (ArgumentException ex)
            {
                return Problem(title: "Invalid request", detail: ex.Message, statusCode: 400);
            }
            catch (InvalidOperationException ex)
            {
                return Problem(title: "Operation not allowed", detail: ex.Message, statusCode: 400);
            }
        }
        [HttpPost("create-payment-intent")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        [Obsolete("Use create-checkout-session instead")]
        public async Task<ActionResult<object>> CreatePaymentIntent(
            [FromBody] CreateOrderRequest request,
            CancellationToken ct = default)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Unauthorized();
            request = request with { UserId = userId };
            try
            {
                var (orderId, clientSecret) = await _stripeService.CreatePaymentIntentAsync(request, ct);
                return Ok(new { orderId, clientSecret });
            }
            catch (ArgumentException ex)
            {
                return Problem(title: "Invalid request", detail: ex.Message, statusCode: 400);
            }
            catch (InvalidOperationException ex)
            {
                return Problem(title: "Operation not allowed", detail: ex.Message, statusCode: 400);
            }
        }
        [HttpPost("create-payment-intent-direct")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        public async Task<ActionResult<object>> CreatePaymentIntentDirect(
            [FromBody] CreateCheckoutSessionRequest request,
            CancellationToken ct = default)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Unauthorized();
            var userEmail = User.FindFirstValue(ClaimTypes.Email) ?? "";
            var userName = User.FindFirstValue(ClaimTypes.Name) ?? "User";
            try
            {
                var (orderId, clientSecret, customerId, ephemeralKey) = await _stripeService.CreatePaymentIntentDirectAsync(
                    request, userId, userEmail, userName, ct);
                return Ok(new { orderId, clientSecret, customerId, ephemeralKey });
            }
            catch (ArgumentException ex)
            {
                return Problem(title: "Invalid request", detail: ex.Message, statusCode: 400);
            }
            catch (InvalidOperationException ex)
            {
                return Problem(title: "Operation not allowed", detail: ex.Message, statusCode: 400);
            }
        }
        [HttpPost("confirm-payment")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        public async Task<ActionResult<object>> ConfirmPayment(
            [FromBody] ConfirmPaymentRequest request,
            CancellationToken ct = default)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Unauthorized();
            try
            {
                await _stripeService.ConfirmPaymentAsync(request.OrderId, ct);
                return Ok(new { success = true, message = "Payment confirmed and tickets generated" });
            }
            catch (ArgumentException ex)
            {
                return Problem(title: "Invalid request", detail: ex.Message, statusCode: 400);
            }
            catch (InvalidOperationException ex)
            {
                return Problem(title: "Operation not allowed", detail: ex.Message, statusCode: 400);
            }
        }
        [HttpGet("{id}")]
        [ProducesResponseType(typeof(OrderDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<OrderDto>> GetOrder(Guid id, CancellationToken ct = default)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Unauthorized();
            var order = await _orderService.GetOrderAsync(id, userId, ct);
            if (order == null)
                return NotFound();
            return Ok(order);
        }
        [HttpGet("admin/{id}")]
        [RequirePermission("ViewAllOrders")]
        [ProducesResponseType(typeof(OrderDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(StatusCodes.Status403Forbidden)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<OrderDto>> GetOrderAdmin(Guid id, CancellationToken ct = default)
        {
            var order = await _orderService.GetOrderByIdAsync(id, ct);
            if (order == null)
                return NotFound();
            return Ok(order);
        }
        [HttpGet("my-orders")]
        [ProducesResponseType(typeof(IReadOnlyList<OrderDto>), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        public async Task<ActionResult<IReadOnlyList<OrderDto>>> GetMyOrders(CancellationToken ct = default)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Unauthorized();
            var orders = await _orderService.GetMyOrdersAsync(userId, ct);
            return Ok(orders);
        }
        [HttpGet("all")]
        [RequirePermission("ViewAllOrders")]
        [ProducesResponseType(typeof(PagedResult<OrderDto>), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(StatusCodes.Status403Forbidden)]
        public async Task<ActionResult<PagedResult<OrderDto>>> GetAllOrders(
            [FromQuery] string? query,
            [FromQuery] string? userId,
            [FromQuery] string? status,
            [FromQuery] DateTimeOffset? from,
            [FromQuery] DateTimeOffset? to,
            [FromQuery] int page = 1,
            [FromQuery] int size = 20,
            CancellationToken ct = default)
        {
            if (page < 1) page = 1;
            if (size < 1 || size > 100) size = 20;
            var result = await _orderService.GetAllOrdersAsync(query, userId, status, from, to, page, size, ct);
            return Ok(result);
        }
        [HttpGet("organizer-sales")]
        [ProducesResponseType(typeof(IReadOnlyList<OrganizerOrderDto>), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        public async Task<ActionResult<IReadOnlyList<OrganizerOrderDto>>> GetOrganizerSales(CancellationToken ct = default)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Unauthorized();
            var orders = await _orderService.GetOrganizerOrdersAsync(userId, ct);
            return Ok(orders);
        }
        [HttpPost("webhook")]
        [AllowAnonymous]
        [DisableRateLimiting]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> HandleWebhook(CancellationToken ct = default)
        {
            try
            {
                _logger.LogInformation("Webhook received at {Time}", DateTime.UtcNow);
                Request.EnableBuffering();
                Request.Body.Position = 0;
                using var reader = new StreamReader(Request.Body, leaveOpen: true);
                var json = await reader.ReadToEndAsync();
                Request.Body.Position = 0;
                var signature = Request.Headers["Stripe-Signature"].FirstOrDefault();
                _logger.LogInformation("Webhook payload length: {Length}, Signature present: {HasSignature}", 
                    json.Length, !string.IsNullOrEmpty(signature));
                if (string.IsNullOrEmpty(json))
                {
                    _logger.LogWarning("Webhook payload is empty");
                    return BadRequest("Webhook payload is empty");
                }
                await _orderService.HandleStripeWebhookAsync(json, signature, ct);
                _logger.LogInformation("Webhook processed successfully");
                return Ok();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Webhook processing failed: {Message}", ex.Message);
                return Problem(title: "Webhook processing failed", detail: ex.Message, statusCode: 400);
            }
        }
        [HttpDelete("clear-all")]
        [RequirePermission("ManageUsers")]
        [ApiExplorerSettings(IgnoreApi = true)]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(StatusCodes.Status403Forbidden)]
        public async Task<IActionResult> ClearAllOrders(CancellationToken ct = default)
        {
            if (!_environment.IsDevelopment())
                return Forbid();
            try
            {
                await _orderService.ClearAllOrdersAsync(ct);
                return Ok(new { message = "All orders, order items, and tickets have been cleared successfully" });
            }
            catch (Exception ex)
            {
                return Problem(title: "Error clearing orders", detail: ex.Message, statusCode: 400);
            }
        }
        [HttpGet("success")]
        [AllowAnonymous]
        public async Task<IActionResult> PaymentSuccess([FromQuery] string session_id, [FromQuery] string order_id, CancellationToken ct)
        {
            try
            {
                _logger.LogInformation("Payment success page accessed - Session: {SessionId}, Order: {OrderId}", session_id, order_id);
                var html = $@"
<!DOCTYPE html>
<html>
<head>
    <meta charset='utf-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <title>Payment Successful</title>
    <style>
        body {{
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }}
        .container {{
            text-align: center;
            padding: 2rem;
        }}
        h1 {{
            font-size: 2rem;
            margin-bottom: 1rem;
        }}
        .checkmark {{
            font-size: 4rem;
            margin-bottom: 1rem;
        }}
    </style>
</head>
<body>
    <div class='container'>
        <div class='checkmark'>✓</div>
        <h1>Payment Successful!</h1>
        <p>Your order has been processed successfully.</p>
        <p>Order ID: {order_id}</p>
        <p>You can close this window.</p>
    </div>
</body>
</html>";
                return Content(html, "text/html");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing payment success for order {OrderId}", order_id);
                var errorHtml = $@"
<!DOCTYPE html>
<html>
<head>
    <meta charset='utf-8'>
    <title>Payment Error</title>
</head>
<body>
    <h1>Error processing payment</h1>
    <p>Please contact support.</p>
</body>
</html>";
                return Content(errorHtml, "text/html");
            }
        }
        [HttpGet("cancel")]
        [AllowAnonymous]
        public IActionResult PaymentCancel([FromQuery] string order_id)
        {
            _logger.LogInformation("Payment cancel page accessed - Order: {OrderId}", order_id);
            var html = $@"
<!DOCTYPE html>
<html>
<head>
    <meta charset='utf-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <title>Payment Cancelled</title>
    <style>
        body {{
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
            color: white;
        }}
        .container {{
            text-align: center;
            padding: 2rem;
        }}
        h1 {{
            font-size: 2rem;
            margin-bottom: 1rem;
        }}
        .cancel {{
            font-size: 4rem;
            margin-bottom: 1rem;
        }}
    </style>
</head>
<body>
    <div class='container'>
        <div class='cancel'>✗</div>
        <h1>Payment Cancelled</h1>
        <p>Your payment was cancelled.</p>
        <p>Order ID: {order_id}</p>
        <p>You can close this window.</p>
    </div>
</body>
</html>";
            return Content(html, "text/html");
        }
    }
}