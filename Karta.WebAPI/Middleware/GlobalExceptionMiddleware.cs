using System.Net;
using System.Text.Json;
using Karta.Service.DTO;
using Karta.Service.Exceptions;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
namespace Karta.WebAPI.Middleware
{
    public class GlobalExceptionMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly ILogger<GlobalExceptionMiddleware> _logger;
        public GlobalExceptionMiddleware(RequestDelegate next, ILogger<GlobalExceptionMiddleware> logger)
        {
            _next = next;
            _logger = logger;
        }
        public async Task InvokeAsync(HttpContext context)
        {
            try
            {
                await _next(context);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, 
                    "An unhandled exception occurred. RequestId: {RequestId}, Path: {Path}, Method: {Method}, UserAgent: {UserAgent}", 
                    context.TraceIdentifier, 
                    context.Request.Path, 
                    context.Request.Method,
                    context.Request.Headers.UserAgent.ToString());
                await HandleExceptionAsync(context, ex);
            }
        }
        private static async Task HandleExceptionAsync(HttpContext context, Exception exception)
        {
            var response = context.Response;
            response.ContentType = "application/json";
            var errorResponse = exception switch
            {
                ValidationException validationEx => new ApiErrorResponse(
                    Success: false,
                    Error: new ValidationErrorResponse(
                        ErrorCode: validationEx.ErrorCode,
                        Message: validationEx.Message,
                        ValidationErrors: validationEx.ValidationErrors,
                        Timestamp: DateTime.UtcNow,
                        RequestId: context.TraceIdentifier
                    ),
                    StatusCode: validationEx.StatusCode
                ),
                BaseException baseEx => new ApiErrorResponse(
                    Success: false,
                    Error: new ErrorResponse(
                        ErrorCode: baseEx.ErrorCode,
                        Message: baseEx.Message,
                        Details: baseEx.Details,
                        Timestamp: DateTime.UtcNow,
                        RequestId: context.TraceIdentifier,
                        StackTrace: IsDevelopment() ? baseEx.StackTrace : null
                    ),
                    StatusCode: baseEx.StatusCode
                ),
                ArgumentException argEx => new ApiErrorResponse(
                    Success: false,
                    Error: new ErrorResponse(
                        ErrorCode: "INVALID_ARGUMENT",
                        Message: argEx.Message,
                        Timestamp: DateTime.UtcNow,
                        RequestId: context.TraceIdentifier,
                        StackTrace: IsDevelopment() ? argEx.StackTrace : null
                    ),
                    StatusCode: (int)HttpStatusCode.BadRequest
                ),
                UnauthorizedAccessException unauthorizedEx => new ApiErrorResponse(
                    Success: false,
                    Error: new ErrorResponse(
                        ErrorCode: "UNAUTHORIZED",
                        Message: "Unauthorized access",
                        Timestamp: DateTime.UtcNow,
                        RequestId: context.TraceIdentifier
                    ),
                    StatusCode: (int)HttpStatusCode.Unauthorized
                ),
                NotImplementedException notImplEx => new ApiErrorResponse(
                    Success: false,
                    Error: new ErrorResponse(
                        ErrorCode: "NOT_IMPLEMENTED",
                        Message: "This feature is not implemented yet",
                        Timestamp: DateTime.UtcNow,
                        RequestId: context.TraceIdentifier
                    ),
                    StatusCode: (int)HttpStatusCode.NotImplemented
                ),
                TimeoutException timeoutEx => new ApiErrorResponse(
                    Success: false,
                    Error: new ErrorResponse(
                        ErrorCode: "TIMEOUT",
                        Message: "Request timeout",
                        Timestamp: DateTime.UtcNow,
                        RequestId: context.TraceIdentifier
                    ),
                    StatusCode: (int)HttpStatusCode.RequestTimeout
                ),
                _ => new ApiErrorResponse(
                    Success: false,
                    Error: new ErrorResponse(
                        ErrorCode: "INTERNAL_SERVER_ERROR",
                        Message: IsDevelopment() ? exception.Message : "An internal server error occurred",
                        Timestamp: DateTime.UtcNow,
                        RequestId: context.TraceIdentifier,
                        StackTrace: IsDevelopment() ? exception.StackTrace : null
                    ),
                    StatusCode: (int)HttpStatusCode.InternalServerError
                )
            };
            response.StatusCode = errorResponse.StatusCode;
            var jsonResponse = JsonSerializer.Serialize(errorResponse, new JsonSerializerOptions
            {
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                WriteIndented = true
            });
            await response.WriteAsync(jsonResponse);
        }
        private static bool IsDevelopment()
        {
            return Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") == "Development";
        }
    }
}