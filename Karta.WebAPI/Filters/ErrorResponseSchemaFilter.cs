using Microsoft.OpenApi.Models;
using Swashbuckle.AspNetCore.SwaggerGen;
using Karta.Service.DTO;
namespace Karta.WebAPI.Filters
{
    public class ErrorResponseSchemaFilter : ISchemaFilter
    {
        public void Apply(OpenApiSchema schema, SchemaFilterContext context)
        {
            if (context.Type == typeof(ErrorResponse))
            {
                schema.Example = new Microsoft.OpenApi.Any.OpenApiObject
                {
                    ["errorCode"] = new Microsoft.OpenApi.Any.OpenApiString("VALIDATION_ERROR"),
                    ["message"] = new Microsoft.OpenApi.Any.OpenApiString("Validation failed"),
                    ["details"] = new Microsoft.OpenApi.Any.OpenApiNull(),
                    ["validationErrors"] = new Microsoft.OpenApi.Any.OpenApiObject
                    {
                        ["email"] = new Microsoft.OpenApi.Any.OpenApiArray
                        {
                            new Microsoft.OpenApi.Any.OpenApiString("Email is required"),
                            new Microsoft.OpenApi.Any.OpenApiString("Email format is invalid")
                        }
                    },
                    ["timestamp"] = new Microsoft.OpenApi.Any.OpenApiString(DateTime.UtcNow.ToString("O")),
                    ["requestId"] = new Microsoft.OpenApi.Any.OpenApiString("0HMQ8VQKJQ2Q1"),
                    ["stackTrace"] = new Microsoft.OpenApi.Any.OpenApiNull()
                };
            }
            else if (context.Type == typeof(ApiErrorResponse))
            {
                schema.Example = new Microsoft.OpenApi.Any.OpenApiObject
                {
                    ["success"] = new Microsoft.OpenApi.Any.OpenApiBoolean(false),
                    ["error"] = new Microsoft.OpenApi.Any.OpenApiObject
                    {
                        ["errorCode"] = new Microsoft.OpenApi.Any.OpenApiString("NOT_FOUND"),
                        ["message"] = new Microsoft.OpenApi.Any.OpenApiString("Event with ID '123' was not found."),
                        ["details"] = new Microsoft.OpenApi.Any.OpenApiObject
                        {
                            ["resourceType"] = new Microsoft.OpenApi.Any.OpenApiString("Event"),
                            ["id"] = new Microsoft.OpenApi.Any.OpenApiString("123")
                        },
                        ["timestamp"] = new Microsoft.OpenApi.Any.OpenApiString(DateTime.UtcNow.ToString("O")),
                        ["requestId"] = new Microsoft.OpenApi.Any.OpenApiString("0HMQ8VQKJQ2Q1")
                    },
                    ["statusCode"] = new Microsoft.OpenApi.Any.OpenApiInteger(404)
                };
            }
        }
    }
}