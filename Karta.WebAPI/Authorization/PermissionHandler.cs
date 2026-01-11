using System.Security.Claims;
using System.Threading.Tasks;
using System.Linq;
using Microsoft.AspNetCore.Authorization;
using Karta.WebAPI.Services;
namespace Karta.WebAPI.Authorization
{
    public class PermissionHandler : AuthorizationHandler<PermissionRequirement>
    {
        protected override Task HandleRequirementAsync(AuthorizationHandlerContext context, PermissionRequirement requirement)
        {
            var user = context.User;
            if (!user.Identity.IsAuthenticated)
            {
                return Task.CompletedTask;
            }
            var roles = user.FindAll(ClaimTypes.Role).Select(c => c.Value);
            foreach (var role in roles)
            {
                if (RoleManagementService.HasPermission(role, requirement.Permission))
                {
                    context.Succeed(requirement);
                    return Task.CompletedTask;
                }
            }
            return Task.CompletedTask;
        }
    }
}