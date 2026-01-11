using System;
namespace Karta.Service.Exceptions
{
    public class NotFoundException : BaseException
    {
        public NotFoundException(string message, string errorCode = "NOT_FOUND", object? details = null) 
            : base(message, errorCode, 404, details)
        {
        }
        public NotFoundException(string resourceType, object id, string errorCode = "NOT_FOUND") 
            : base($"{resourceType} with ID '{id}' was not found.", errorCode, 404, new { ResourceType = resourceType, Id = id })
        {
        }
    }
}