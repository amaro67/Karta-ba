using System;
using System.Collections.Generic;
namespace Karta.Service.DTO;
public record CreateEventRequest(
    string Title,
    string? Description,
    Guid VenueId,           // Required - must select from venues table
    DateTimeOffset StartsAt,
    DateTimeOffset? EndsAt,
    Guid CategoryId,        // Required - must select from categories table
    string? Tags,
    string? CoverImageUrl,
    IReadOnlyList<CreatePriceTierRequest>? PriceTiers
);
public record CreatePriceTierRequest(string Name, decimal Price, string Currency, int Capacity);
public record UpdateEventRequest(
    string? Title,
    string? Description,
    Guid? VenueId,
    DateTimeOffset? StartsAt,
    DateTimeOffset? EndsAt,
    Guid? CategoryId,
    string? Tags,
    string? Status,
    string? CoverImageUrl
);
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