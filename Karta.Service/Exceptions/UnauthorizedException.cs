using System;
namespace Karta.Service.Exceptions
{
    public class UnauthorizedException : BaseException
    {
        public UnauthorizedException(string message = "Unauthorized access", string errorCode = "UNAUTHORIZED", object? details = null) 
            : base(message, errorCode, 401, details)
        {
        }
    }
}