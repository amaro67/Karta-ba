using System;
namespace Karta.Service.Exceptions
{
    public abstract class BaseException : Exception
    {
        public string ErrorCode { get; }
        public int StatusCode { get; }
        public object? Details { get; }
        protected BaseException(string message, string errorCode, int statusCode, object? details = null) 
            : base(message)
        {
            ErrorCode = errorCode;
            StatusCode = statusCode;
            Details = details;
        }
        protected BaseException(string message, string errorCode, int statusCode, Exception innerException, object? details = null) 
            : base(message, innerException)
        {
            ErrorCode = errorCode;
            StatusCode = statusCode;
            Details = details;
        }
    }
}