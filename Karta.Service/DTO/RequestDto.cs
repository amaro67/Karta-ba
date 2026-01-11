using System;
using System.Collections.Generic;
namespace Karta.Service.DTO;
public record CreateEventRequest(string Title, string? Description, string Venue, string City, string Country,
                                 DateTimeOffset StartsAt, DateTimeOffset? EndsAt, string Category, string? Tags,
                                 string? CoverImageUrl, IReadOnlyList<CreatePriceTierRequest>? PriceTiers);
public record CreatePriceTierRequest(string Name, decimal Price, string Currency, int Capacity);
public record UpdateEventRequest(string? Title, string? Description, string? Venue, string? City, string? Country,
                                 DateTimeOffset? StartsAt, DateTimeOffset? EndsAt, string? Category, string? Tags,
                                 string? Status, string? CoverImageUrl);
public record CreateOrderRequest(string UserId, Guid PriceTierId, int Quantity);
public record CreateCheckoutSessionRequest(
    Guid EventId,
    List<CheckoutItem> Items,
    string Currency = "BAM"
);
public record CheckoutItem(
    Guid PriceTierId,
    int Quantity
);
public record ScanTicketRequest(string TicketCode, string GateId, string? Signature);
public record ValidateTicketRequest(string TicketCode);
public record ForgotPasswordRequest(string Email);
public record ResetPasswordRequest(string Token, string NewPassword, string ConfirmPassword);
public record ConfirmPaymentRequest(Guid OrderId);