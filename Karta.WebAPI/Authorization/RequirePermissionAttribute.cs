using Microsoft.AspNetCore.Authorization;
namespace Karta.WebAPI.Authorization
{
    public class RequirePermissionAttribute : AuthorizeAttribute
    {
        public RequirePermissionAttribute(string permission) : base()
        {
            Policy = $"Permission.{permission}";
        }
    }
}