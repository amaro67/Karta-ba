using System;
namespace Karta.Service.Exceptions
{
    public class ForbiddenException : BaseException
    {
        public ForbiddenException(string message = "Access forbidden", string errorCode = "FORBIDDEN", object? details = null) 
            : base(message, errorCode, 403, details)
        {
        }
    }
}