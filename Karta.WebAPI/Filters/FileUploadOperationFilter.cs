using Microsoft.OpenApi.Models;
using Swashbuckle.AspNetCore.SwaggerGen;
using System.Linq;
using System.Collections.Generic;
using System.Reflection;
using Microsoft.AspNetCore.Http;

namespace Karta.WebAPI.Filters
{
    public class FileUploadOperationFilter : IOperationFilter
    {
        public void Apply(OpenApiOperation operation, OperationFilterContext context)
        {
            // Provjeri da li metoda ima IFormFile parametar
            var fileParameters = context.MethodInfo.GetParameters()
                .Where(p => p.ParameterType == typeof(IFormFile) || 
                           p.ParameterType == typeof(Microsoft.AspNetCore.Http.IFormFile))
                .ToList();

            if (fileParameters.Any())
            {
                // Ukloni sve postojeće parametre jer ćemo koristiti RequestBody
                operation.Parameters?.Clear();
                
                // Kreiraj RequestBody za file upload
                operation.RequestBody = new OpenApiRequestBody
                {
                    Required = true,
                    Content = new Dictionary<string, OpenApiMediaType>
                    {
                        ["multipart/form-data"] = new OpenApiMediaType
                        {
                            Schema = new OpenApiSchema
                            {
                                Type = "object",
                                Properties = new Dictionary<string, OpenApiSchema>
                                {
                                    ["file"] = new OpenApiSchema
                                    {
                                        Type = "string",
                                        Format = "binary",
                                        Description = "Slika za upload (max 5MB, dozvoljeni formati: JPG, JPEG, PNG, GIF, WEBP)"
                                    }
                                },
                                Required = new HashSet<string> { "file" }
                            }
                        }
                    }
                };
            }
        }
    }
}
