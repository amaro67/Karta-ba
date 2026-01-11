using System;
using System.Collections.Generic;
namespace Karta.Service.DTO
{
    public record ErrorResponse(
        string ErrorCode,
        string Message,
        object? Details = null,
        Dictionary<string, string[]>? ValidationErrors = null,
        DateTime Timestamp = default,
        string? RequestId = null,
        string? StackTrace = null
    )
    {
        public ErrorResponse() : this(string.Empty, string.Empty)
        {
            Timestamp = DateTime.UtcNow;
        }
    }
    public record ValidationErrorResponse(
        string ErrorCode,
        string Message,
        Dictionary<string, string[]> ValidationErrors,
        DateTime Timestamp = default,
        string? RequestId = null
    ) : ErrorResponse(ErrorCode, Message, null, ValidationErrors, Timestamp, RequestId);
    public record ApiErrorResponse(
        bool Success = false,
        ErrorResponse? Error = null,
        int StatusCode = 500
    );
}