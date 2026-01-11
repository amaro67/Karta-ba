using System;
using System.Collections.Generic;
using System.Linq;
namespace Karta.Service.Exceptions
{
    public class ValidationException : BaseException
    {
        public Dictionary<string, string[]> ValidationErrors { get; }
        public ValidationException(Dictionary<string, string[]> validationErrors) 
            : base("Validation failed", "VALIDATION_ERROR", 400, validationErrors)
        {
            ValidationErrors = validationErrors;
        }
        public ValidationException(string field, string error) 
            : base("Validation failed", "VALIDATION_ERROR", 400, new Dictionary<string, string[]> { { field, new[] { error } } })
        {
            ValidationErrors = new Dictionary<string, string[]> { { field, new[] { error } } };
        }
        public ValidationException(IEnumerable<(string Field, string Error)> errors) 
            : base("Validation failed", "VALIDATION_ERROR", 400, errors.ToDictionary(e => e.Field, e => new[] { e.Error }))
        {
            ValidationErrors = errors.ToDictionary(e => e.Field, e => new[] { e.Error });
        }
    }
}